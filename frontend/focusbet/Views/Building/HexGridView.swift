import SwiftUI

struct HexGridView: View {
    let territory: [TerritoryEntry]
    let animatingCells: Set<Int>
    let floorPlan: BuildingFloorPlan
    @Binding var highlightedUser: Int?

    private let hexRadius: CGFloat = 10

    private var hexWidth: CGFloat { hexRadius * 2 }
    private var hexHeight: CGFloat { hexRadius * sqrt(3) }
    private var colSpacing: CGFloat { hexRadius * 1.5 }
    private var rowSpacing: CGFloat { hexRadius * sqrt(3) }

    var body: some View {
        GeometryReader { geo in
            let cols = max(1, Int(geo.size.width / colSpacing))
            let rows = max(1, Int(geo.size.height / (hexHeight * 0.5)) + 2)
            let gridData = buildGridData(cols: cols, rows: rows, size: geo.size)

            Canvas { context, size in
                // Floor plan outline
                let outlinePath = floorPlanPath(size: size)
                context.stroke(outlinePath, with: .color(AppColors.border.opacity(0.3)), lineWidth: 1.5)

                // Draw hex cells
                for cell in gridData.cells {
                    let path = hexPath(center: cell.center, radius: hexRadius)
                    let ownerIdx = cell.owner
                    let isAnimating = animatingCells.contains(cell.gridIndex)

                    let fillColor: Color
                    var opacity: Double
                    if ownerIdx >= 0 && ownerIdx < territory.count {
                        let colorIdx = territory[ownerIdx].colorIndex
                        fillColor = AppColors.userColors[colorIdx % AppColors.userColors.count]

                        if let hl = highlightedUser {
                            if ownerIdx == hl {
                                opacity = 1.0 // highlighted user's cells glow
                            } else {
                                opacity = 0.25 // dim others
                            }
                        } else {
                            opacity = isAnimating ? 1.0 : 0.7
                        }
                    } else {
                        fillColor = AppColors.bgTertiary
                        opacity = highlightedUser != nil ? 0.1 : 0.25
                    }

                    context.fill(path, with: .color(fillColor.opacity(opacity)))
                    context.stroke(path, with: .color(AppColors.bgPrimary), lineWidth: 1.0)
                }
            }
            // Transparent overlay to detect hover position and map to hex owner
            .overlay {
                HexHoverOverlay(
                    cells: gridData.cells,
                    territory: territory,
                    hexRadius: hexRadius,
                    highlightedUser: $highlightedUser
                )
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
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Grid data (public for hover overlay)

    struct CellData {
        let gridIndex: Int
        let col: Int
        let row: Int
        let center: CGPoint
        var owner: Int
    }

    struct GridResult {
        let cells: [CellData]
    }

    // MARK: - Build grid with floor plan masking + round-robin BFS

    private func buildGridData(cols: Int, rows: Int, size: CGSize) -> GridResult {
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
        guard totalInside > 0, !territory.isEmpty else {
            return GridResult(cells: insideCells)
        }

        func neighbors(of insideIdx: Int) -> [Int] {
            let cell = insideCells[insideIdx]
            let col = cell.col
            let row = cell.row
            let oddQNeighbors: [[(Int, Int)]] = [
                [(-1, -1), (-1, 0), (0, -1), (0, 1), (1, -1), (1, 0)],
                [(-1, 0), (-1, 1), (0, -1), (0, 1), (1, 0), (1, 1)],
            ]
            var result: [Int] = []
            for (dc, dr) in oddQNeighbors[col & 1] {
                let nc = col + dc
                let nr = row + dr
                if nc >= 0 && nc < cols && nr >= 0 && nr < rows {
                    let iIdx = gridToInside[nr * cols + nc]
                    if iIdx >= 0 { result.append(iIdx) }
                }
            }
            return result
        }

        var rng = StableRNG(seed: 42)

        var remaining: [Int] = territory.map { entry in
            max(2, Int(entry.ownershipPercent / 100.0 * Double(totalInside)))
        }

        let seedFracs: [(Double, Double)] = [
            (0.50, 0.50), (0.75, 0.22), (0.22, 0.75), (0.22, 0.22),
            (0.78, 0.78), (0.08, 0.48), (0.92, 0.48), (0.50, 0.08),
            (0.50, 0.92), (0.35, 0.35),
        ]

        func closestInsideCell(fx: Double, fy: Double) -> Int? {
            let tx = fx * Double(size.width)
            let ty = fy * Double(size.height)
            var bestIdx = -1
            var bestDist = Double.infinity
            for (i, cell) in insideCells.enumerated() {
                let dx = Double(cell.center.x) - tx
                let dy = Double(cell.center.y) - ty
                let d = dx * dx + dy * dy
                if d < bestDist { bestDist = d; bestIdx = i }
            }
            return bestIdx >= 0 ? bestIdx : nil
        }

        var frontiers: [[Int]] = []
        var visited: [Set<Int>] = []

        for i in 0..<territory.count {
            let frac = seedFracs[i % seedFracs.count]
            if let seedIdx = closestInsideCell(fx: frac.0, fy: frac.1) {
                var queue = [seedIdx]
                var vis = Set([seedIdx])
                var startIdx: Int?
                while !queue.isEmpty {
                    let cur = queue.removeFirst()
                    if insideCells[cur].owner == -1 { startIdx = cur; break }
                    for n in neighbors(of: cur) {
                        if !vis.contains(n) { vis.insert(n); queue.append(n) }
                    }
                }
                if let s = startIdx {
                    insideCells[s].owner = i
                    remaining[i] -= 1
                    let nbrs = neighbors(of: s)
                    frontiers.append(nbrs)
                    visited.append(Set([s] + nbrs))
                } else {
                    frontiers.append([]); visited.append(Set())
                }
            } else {
                frontiers.append([]); visited.append(Set())
            }
        }

        var active = true
        while active {
            active = false
            for i in 0..<territory.count {
                guard remaining[i] > 0 else { continue }
                var claimed = false
                while !frontiers[i].isEmpty && !claimed {
                    let current = frontiers[i].removeFirst()
                    if insideCells[current].owner == -1 {
                        insideCells[current].owner = i
                        remaining[i] -= 1
                        claimed = true; active = true
                        var nbrs = neighbors(of: current)
                        for j in stride(from: nbrs.count - 1, through: 1, by: -1) {
                            let k = rng.next(upperBound: j + 1)
                            nbrs.swapAt(j, k)
                        }
                        for n in nbrs {
                            if !visited[i].contains(n) {
                                visited[i].insert(n)
                                frontiers[i].append(n)
                            }
                        }
                    }
                }
                if remaining[i] > 0 && frontiers[i].isEmpty {
                    for idx in 0..<totalInside where insideCells[idx].owner == -1 {
                        insideCells[idx].owner = i
                        remaining[i] -= 1
                        let nbrs = neighbors(of: idx)
                        frontiers[i] = nbrs
                        visited[i].formUnion(nbrs)
                        visited[i].insert(idx)
                        active = true
                        break
                    }
                }
            }
        }

        return GridResult(cells: insideCells)
    }
}

// MARK: - Hover overlay: detects mouse position and finds nearest hex cell

private struct HexHoverOverlay: NSViewRepresentable {
    let cells: [HexGridView.CellData]
    let territory: [TerritoryEntry]
    let hexRadius: CGFloat
    @Binding var highlightedUser: Int?

    func makeNSView(context: Context) -> HoverTrackingView {
        let view = HoverTrackingView()
        view.onMouseMoved = { [self] point, size in
            // Flip Y since AppKit is bottom-left origin
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
