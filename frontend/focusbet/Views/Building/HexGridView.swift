import SwiftUI

struct HexGridView: View {
    let territory: [TerritoryEntry]
    let floorPlan: BuildingFloorPlan
    @Binding var highlightedUser: Int?

    private let hexRadius: CGFloat = 10
    private var hexHeight: CGFloat { hexRadius * sqrt(3) }
    private var colSpacing: CGFloat { hexRadius * 1.5 }
    private var rowSpacing: CGFloat { hexRadius * sqrt(3) }

    // Persistent grid state — built once, mutated by shift simulation
    @State private var liveInsideCells: [CellData] = []
    @State private var neighborMap: [[Int]] = []
    @State private var computedSize: CGSize = .zero
    @State private var flashingCells: Set<Int> = []
    @State private var shiftTimer: Timer?

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // Floor plan outline
                let outlinePath = floorPlanPath(size: size)
                context.stroke(outlinePath, with: .color(AppColors.border.opacity(0.3)), lineWidth: 1.5)

                for cell in liveInsideCells {
                    let path = hexPath(center: cell.center, radius: hexRadius)
                    let ownerIdx = cell.owner
                    let isFlashing = flashingCells.contains(cell.gridIndex)

                    let fillColor: Color
                    let opacity: Double
                    if ownerIdx >= 0 && ownerIdx < territory.count {
                        let colorIdx = territory[ownerIdx].colorIndex
                        fillColor = AppColors.userColors[colorIdx % AppColors.userColors.count]
                        if let hl = highlightedUser {
                            opacity = ownerIdx == hl ? 1.0 : 0.25
                        } else {
                            opacity = isFlashing ? 1.0 : 0.7
                        }
                    } else {
                        fillColor = AppColors.bgTertiary
                        opacity = highlightedUser != nil ? 0.1 : 0.25
                    }

                    context.fill(path, with: .color(fillColor.opacity(opacity)))
                    context.stroke(path, with: .color(AppColors.bgPrimary), lineWidth: 1.0)
                }
            }
            .overlay {
                HexHoverOverlay(
                    cells: liveInsideCells,
                    territory: territory,
                    hexRadius: hexRadius,
                    highlightedUser: $highlightedUser
                )
            }
            .onChange(of: geo.size) { _, newSize in
                let widthChanged = abs(newSize.width - computedSize.width) > 5
                let heightChanged = abs(newSize.height - computedSize.height) > 5
                if widthChanged || heightChanged {
                    recomputeGrid(size: newSize)
                }
            }
            .onAppear {
                if liveInsideCells.isEmpty {
                    recomputeGrid(size: geo.size)
                }
                startShiftTimer()
            }
            .onDisappear {
                shiftTimer?.invalidate()
                shiftTimer = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Grid recomputation

    private func recomputeGrid(size: CGSize) {
        guard size.width > 10, size.height > 10 else { return }
        let result = buildGrid(size: size)
        liveInsideCells = result.cells
        neighborMap = result.neighborMap
        computedSize = size
    }

    // MARK: - Floor plan + hex geometry

    private func floorPlanPath(size: CGSize) -> Path {
        var path = Path()
        let pts = floorPlan.points
        guard pts.count >= 3 else { return path }
        path.move(to: CGPoint(x: pts[0].0 * size.width, y: pts[0].1 * size.height))
        for i in 1..<pts.count {
            path.addLine(to: CGPoint(x: pts[i].0 * size.width, y: pts[i].1 * size.height))
        }
        path.closeSubpath()
        return path
    }

    private func hexCenter(col: Int, row: Int) -> CGPoint {
        let x = hexRadius + CGFloat(col) * colSpacing
        let yOffset: CGFloat = (col % 2 == 1) ? hexHeight * 0.5 : 0
        let y = hexHeight * 0.5 + CGFloat(row) * rowSpacing + yOffset
        return CGPoint(x: x, y: y)
    }

    private func hexPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3.0
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Grid data types

    struct CellData {
        let gridIndex: Int
        let col: Int
        let row: Int
        let center: CGPoint
        var owner: Int
    }

    // MARK: - BFS grid builder (Problem 1: guaranteed connected blobs)

    private func buildGrid(size: CGSize) -> (cells: [CellData], neighborMap: [[Int]]) {
        let cols = max(1, Int(size.width / colSpacing))
        let rows = max(1, Int(size.height / (hexHeight * 0.5)) + 2)

        // Step 1: collect all cells inside the floor plan
        var insideCells: [CellData] = []
        var gridToInside = Array(repeating: -1, count: cols * rows)

        for row in 0..<rows {
            for col in 0..<cols {
                let center = hexCenter(col: col, row: row)
                let nx = Double(center.x / size.width)
                let ny = Double(center.y / size.height)
                if floorPlan.contains(x: nx, y: ny) {
                    let gridIdx = row * cols + col
                    gridToInside[gridIdx] = insideCells.count
                    insideCells.append(CellData(
                        gridIndex: gridIdx, col: col, row: row,
                        center: center, owner: -1
                    ))
                }
            }
        }

        let totalInside = insideCells.count

        // Step 2: build hex adjacency (odd-q offset coords)
        let oddQOffsets: [[(Int, Int)]] = [
            [(-1, -1), (-1, 0), (0, -1), (0, 1), (1, -1), (1, 0)],
            [(-1,  0), (-1, 1), (0, -1), (0, 1), (1,  0), (1, 1)],
        ]

        var neighborMap = [[Int]](repeating: [], count: totalInside)
        for i in 0..<totalInside {
            let cell = insideCells[i]
            var nbrs: [Int] = []
            for (dc, dr) in oddQOffsets[cell.col & 1] {
                let nc = cell.col + dc
                let nr = cell.row + dr
                if nc >= 0 && nc < cols && nr >= 0 && nr < rows {
                    let iIdx = gridToInside[nr * cols + nc]
                    if iIdx >= 0 { nbrs.append(iIdx) }
                }
            }
            neighborMap[i] = nbrs
        }

        guard totalInside > 0, !territory.isEmpty else {
            return (insideCells, neighborMap)
        }

        // Step 3: place one seed per user at evenly spread positions
        var rng = StableRNG(seed: 42)

        let seedFracs: [(Double, Double)] = [
            (0.50, 0.50), (0.75, 0.22), (0.22, 0.75), (0.22, 0.22),
            (0.78, 0.78), (0.08, 0.48), (0.92, 0.48), (0.50, 0.08),
            (0.50, 0.92), (0.35, 0.35),
        ]

        func closestUnclaimedCell(fx: Double, fy: Double) -> Int? {
            let tx = fx * Double(size.width)
            let ty = fy * Double(size.height)
            // BFS from the nearest point to find the closest unclaimed cell
            var bestIdx = -1
            var bestDist = Double.infinity
            for i in 0..<totalInside where insideCells[i].owner == -1 {
                let dx = Double(insideCells[i].center.x) - tx
                let dy = Double(insideCells[i].center.y) - ty
                let d = dx * dx + dy * dy
                if d < bestDist { bestDist = d; bestIdx = i }
            }
            return bestIdx >= 0 ? bestIdx : nil
        }

        var remaining: [Int] = territory.map { entry in
            max(2, Int(entry.ownershipPercent / 100.0 * Double(totalInside)))
        }

        var frontiers: [[Int]] = []
        var inFrontier: [Set<Int>] = []

        for i in 0..<territory.count {
            let frac = seedFracs[i % seedFracs.count]
            if let seedIdx = closestUnclaimedCell(fx: frac.0, fy: frac.1) {
                insideCells[seedIdx].owner = i
                remaining[i] -= 1
                // Seed's unclaimed neighbors become the initial frontier
                let nbrs = neighborMap[seedIdx].filter { insideCells[$0].owner == -1 }
                frontiers.append(nbrs)
                inFrontier.append(Set(nbrs))
            } else {
                frontiers.append([])
                inFrontier.append(Set())
            }
        }

        // Step 4: round-robin BFS — each user claims 1 adjacent cell per round
        // NO random-unclaimed fallback → connected blobs guaranteed
        var active = true
        while active {
            active = false
            for i in 0..<territory.count {
                guard remaining[i] > 0 else { continue }
                var claimed = false
                while !frontiers[i].isEmpty && !claimed {
                    let current = frontiers[i].removeFirst()
                    inFrontier[i].remove(current)
                    guard insideCells[current].owner == -1 else { continue }

                    insideCells[current].owner = i
                    remaining[i] -= 1
                    claimed = true
                    active = true

                    // Add unclaimed neighbors — shuffled for organic shape
                    var nbrs = neighborMap[current].filter { insideCells[$0].owner == -1 }
                    for j in stride(from: nbrs.count - 1, through: 1, by: -1) {
                        nbrs.swapAt(j, rng.next(upperBound: j + 1))
                    }
                    for n in nbrs where !inFrontier[i].contains(n) {
                        inFrontier[i].insert(n)
                        frontiers[i].append(n)
                    }
                }
                // Frontier empty and cells remain: this user is done — skip silently
                // (flood-fill below will handle any leftover unclaimed cells)
            }
        }

        // Step 5: flood-fill any unclaimed cells to nearest claimed territory
        // Multi-source BFS from all claimed cells simultaneously → no islands, connectivity preserved
        var floodQueue: [Int] = []
        for i in 0..<totalInside where insideCells[i].owner != -1 {
            floodQueue.append(i)
        }
        while !floodQueue.isEmpty {
            let cur = floodQueue.removeFirst()
            let owner = insideCells[cur].owner
            for n in neighborMap[cur] where insideCells[n].owner == -1 {
                insideCells[n].owner = owner
                floodQueue.append(n)
            }
        }

        return (insideCells, neighborMap)
    }

    // MARK: - Territory shift simulation (Problem 2: boundary-only stealing)

    private func startShiftTimer() {
        shiftTimer?.invalidate()
        shiftTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            simulateTerritoryShift()
        }
    }

    private func simulateTerritoryShift() {
        guard !liveInsideCells.isEmpty, liveInsideCells.count == neighborMap.count else { return }

        // Collect all boundary cells: cell i is a boundary if it has a neighbor owned by a different user
        var boundaryCells: [(cellIndex: Int, currentOwner: Int, adjacentOwner: Int)] = []
        for i in 0..<liveInsideCells.count {
            let owner = liveInsideCells[i].owner
            guard owner >= 0 else { continue }
            for n in neighborMap[i] {
                let nOwner = liveInsideCells[n].owner
                if nOwner >= 0 && nOwner != owner {
                    boundaryCells.append((i, owner, nOwner))
                }
            }
        }

        guard !boundaryCells.isEmpty else { return }

        // Flip up to 2 boundary cells, one at a time
        // Only steal if the losing user keeps ≥ 2 adjacent same-owner cells (stays connected)
        var shuffled = boundaryCells.shuffled()
        var flipped = 0
        var newFlashing = Set<Int>()

        for pick in shuffled {
            if flipped >= 2 { break }
            let ownerAdjacentCount = neighborMap[pick.cellIndex].filter {
                liveInsideCells[$0].owner == pick.currentOwner
            }.count
            if ownerAdjacentCount >= 2 {
                liveInsideCells[pick.cellIndex].owner = pick.adjacentOwner
                newFlashing.insert(liveInsideCells[pick.cellIndex].gridIndex)
                flipped += 1
            }
        }

        guard flipped > 0 else { return }

        withAnimation(.easeInOut(duration: 0.6)) {
            flashingCells = newFlashing
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.6)) {
                flashingCells.removeAll()
            }
        }
    }
}

// MARK: - Hover overlay: maps mouse position to hex owner

private struct HexHoverOverlay: NSViewRepresentable {
    let cells: [HexGridView.CellData]
    let territory: [TerritoryEntry]
    let hexRadius: CGFloat
    @Binding var highlightedUser: Int?

    func makeNSView(context: Context) -> HoverTrackingView {
        let view = HoverTrackingView()
        view.onMouseMoved = { [self] point, size in
            let flipped = CGPoint(x: point.x, y: size.height - point.y)
            findOwnerAt(flipped)
        }
        view.onMouseExited = { [self] in
            DispatchQueue.main.async { self.highlightedUser = nil }
        }
        return view
    }

    func updateNSView(_ nsView: HoverTrackingView, context: Context) {
        nsView.onMouseMoved = { [self] point, size in
            let flipped = CGPoint(x: point.x, y: size.height - point.y)
            findOwnerAt(flipped)
        }
        nsView.onMouseExited = { [self] in
            DispatchQueue.main.async { self.highlightedUser = nil }
        }
    }

    private func findOwnerAt(_ point: CGPoint) {
        var bestDist = CGFloat.infinity
        var bestOwner: Int?
        let maxDist = hexRadius * 1.2

        for cell in cells {
            let dx = point.x - cell.center.x
            let dy = point.y - cell.center.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < bestDist && dist < maxDist {
                bestDist = dist
                bestOwner = cell.owner >= 0 ? cell.owner : nil
            }
        }

        DispatchQueue.main.async {
            self.highlightedUser = bestOwner
        }
    }
}

class HoverTrackingView: NSView {
    var onMouseMoved: ((CGPoint, CGSize) -> Void)?
    var onMouseExited: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMouseMoved?(point, bounds.size)
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}

// MARK: - Deterministic RNG

private struct StableRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func next(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }
}
