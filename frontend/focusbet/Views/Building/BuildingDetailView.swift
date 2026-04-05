import SwiftUI

struct BuildingDetailView: View {
    let buildingId: String

    private var building: Building {
        MockData.buildings.first { $0.id == buildingId } ?? MockData.buildings[0]
    }

    private var territory: [TerritoryEntry] {
        MockData.walcTerritory
    }

    @State private var highlightedUser: Int? = nil
    @State private var fetchedFloorPlan: BuildingFloorPlan? = nil
    @State private var isLoadingFootprint = true

    // Use the OSM-fetched plan if available, otherwise fall back to the static polygon
    private var activePlan: BuildingFloorPlan {
        fetchedFloorPlan ?? building.floorPlan
    }

    var body: some View {
        HStack(spacing: 0) {
            // LEFT: Hex grid (60%)
            VStack(spacing: 12) {
                Text("\(building.name) Territory")
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                ZStack {
                    if !isLoadingFootprint {
                        HexGridView(
                            territory: territory,
                            floorPlan: activePlan,
                            highlightedUser: $highlightedUser
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    } else {
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                                .tint(AppColors.accent)
                            Text("Loading building shape…")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textMuted)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.bgPrimary)

            // Divider
            AppColors.border.frame(width: 1)

            // RIGHT: Ranking (40%)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Text(building.abbreviation)
                            .font(AppFonts.title)
                            .foregroundStyle(AppColors.textPrimary)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.accent)
                                .frame(width: 6, height: 6)
                            Text("Live")
                                .font(AppFonts.small)
                                .foregroundStyle(AppColors.accent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("Resets in 4d 13h")
                                .font(AppFonts.caption)
                        }
                        .foregroundStyle(AppColors.textSecondary)
                    }

                    // Rankings with hover highlight
                    RankingListView(entries: territory, highlightedUser: $highlightedUser)

                    // User position (if below top 10)
                    HStack(spacing: 8) {
                        Text("...")
                            .foregroundStyle(AppColors.textMuted)
                        Text("46.")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.textMuted)
                        UserAvatar(initials: "YC", colorIndex: 0, size: 24)
                        Text("Yewon")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text("320pts (2.1%)")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(12)
                    .background(AppColors.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Activity Feed
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity")
                            .font(AppFonts.heading)
                            .foregroundStyle(AppColors.textPrimary)

                        ForEach(MockData.activityFeed) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colorForActivity(item.type))
                                    .frame(width: 6, height: 6)
                                Text(item.message)
                                    .font(AppFonts.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(24)
            }
            .frame(width: 380)
            .background(AppColors.bgSecondary)
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
        .task { await loadFootprint() }
    }

    private func colorForActivity(_ type: ActivityFeedItem.ActivityType) -> Color {
        switch type {
        case .sessionComplete: return AppColors.accent
        case .studying: return AppColors.accent
        case .overtake: return AppColors.warning
        case .kingTakeover: return AppColors.userColors[1]
        }
    }

    // MARK: - OSM footprint loading

    private func loadFootprint() async {
        // Serve from cache instantly — no loading flash on repeat visits
        if let cached = FootprintCache.shared.get(for: buildingId) {
            fetchedFloorPlan = cached
            isLoadingFootprint = false
            return
        }
        let plan = await fetchBuildingFootprint(lat: building.latitude, lon: building.longitude)
        if let plan {
            FootprintCache.shared.set(plan, for: buildingId)
        }
        fetchedFloorPlan = plan   // nil → activePlan falls back to building.floorPlan
        isLoadingFootprint = false
    }

    private func fetchBuildingFootprint(lat: Double, lon: Double) async -> BuildingFloorPlan? {
        let query = "[out:json];way[\"building\"](around:50,\(lat),\(lon));out geom;"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encoded)")
        else { return nil }

        var request = URLRequest(url: url)
        request.setValue("FocusBetApp/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let elements = json["elements"] as? [[String: Any]],
                let first = elements.first,
                let geometry = first["geometry"] as? [[String: Any]]
            else { return nil }

            let coords: [(Double, Double)] = geometry.compactMap { node in
                guard let nodeLat = node["lat"] as? Double,
                      let nodeLon = node["lon"] as? Double else { return nil }
                return (nodeLat, nodeLon)
            }
            guard coords.count >= 3 else { return nil }

            // Compute bounding box
            let lats = coords.map(\.0)
            let lons = coords.map(\.1)
            guard let minLat = lats.min(), let maxLat = lats.max(),
                  let minLon = lons.min(), let maxLon = lons.max() else { return nil }
            let latRange = max(maxLat - minLat, 0.00001)
            let lonRange = max(maxLon - minLon, 0.00001)

            // Normalize to [0.05, 0.95] so cells don't hug the frame edge
            let lo = 0.05, hi = 0.95, span = hi - lo
            let normalized: [(Double, Double)] = coords.map { (nodeLat, nodeLon) in
                let nx = (nodeLon - minLon) / lonRange * span + lo
                let ny = (1.0 - (nodeLat - minLat) / latRange) * span + lo  // flip Y
                return (nx, ny)
            }

            return BuildingFloorPlan(points: normalized)
        } catch {
            return nil  // fall back to static polygon
        }
    }
}

// MARK: - In-memory footprint cache (persists for the app session)

@MainActor
private final class FootprintCache {
    static let shared = FootprintCache()
    private init() {}
    private var cache: [String: BuildingFloorPlan] = [:]

    func get(for id: String) -> BuildingFloorPlan? { cache[id] }
    func set(_ plan: BuildingFloorPlan, for id: String) { cache[id] = plan }
}
