import SwiftUI
import MapKit

struct CampusMapView: View {
    let onNavigate: (Route) -> Void

    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4274, longitude: -86.9137),
        span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
    ))

    /// Backend-fetched king data keyed by building slug.
    @State private var buildingKings: [String: (kingName: String, kingScore: Int)] = [:]

    private var resetTimeString: String {
        let hours = Int(MockData.weekResetTimeInterval / 3600)
        let days = hours / 24
        let remainingHours = hours % 24
        return "\(days)d \(remainingHours)h"
    }

    /// Merge MockData buildings with live king data from the backend.
    /// Buildings without backend data show as unclaimed (gray) — MockData kings are ignored.
    private var buildings: [Building] {
        MockData.buildings.map { b in
            var updated = b
            if let king = buildingKings[b.id] {
                updated.kingName = king.kingName
                updated.kingUserId = king.kingName   // non-nil signals "claimed"
            } else {
                // No backend data → force unclaimed regardless of MockData
                updated.kingName = nil
                updated.kingUserId = nil
            }
            return updated
        }
    }

    /// Legend entries: users who are currently kings of at least one building.
    private var legendEntries: [(name: String, count: Int, color: Color)] {
        var counts: [String: Int] = [:]
        for (_, king) in buildingKings {
            counts[king.kingName, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .enumerated()
            .map { idx, pair in
                (name: pair.key,
                 count: pair.value,
                 color: AppColors.userColors[idx % AppColors.userColors.count])
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Purdue Campus Territory")
                        .font(AppFonts.title)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Week \(MockData.weekNumber)")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("Resets in \(resetTimeString)")
                        .font(AppFonts.caption)
                }
                .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppColors.bgSecondary)
            .overlay(alignment: .bottom) {
                AppColors.border.frame(height: 1)
            }

            // Apple MapKit Map — annotations inlined to avoid MapContentBuilder/ChartContentBuilder ambiguity
            Map(position: $cameraPosition) {
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: 40.4273891, longitude: -86.9132292), anchor: .center) {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.3))
                                .frame(width: 24, height: 24)
                            Circle()
                                .fill(AppColors.accent)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                        Text("You are here")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                    }
                    .allowsHitTesting(false)
                }
                ForEach(buildings) { building in
                    Annotation("", coordinate: building.coordinate, anchor: .center) {
                        Button {
                            onNavigate(.building(id: building.id))
                        } label: {
                            BuildingMarkerView(building: building)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))

            // Legend
            HStack(spacing: 16) {
                if !legendEntries.isEmpty {
                    ForEach(legendEntries.indices, id: \.self) { idx in
                        let entry = legendEntries[idx]
                        HStack(spacing: 6) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: 8, height: 8)
                            Text(entry.name)
                                .font(AppFonts.small)
                                .foregroundStyle(AppColors.textSecondary)
                            Text("\(entry.count)")
                                .font(AppFonts.small)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.textMuted)
                        .frame(width: 8, height: 8)
                    Text("Unclaimed")
                        .font(AppFonts.small)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(AppColors.bgSecondary)
            .overlay(alignment: .top) {
                AppColors.border.frame(height: 1)
            }
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
        .task { await loadBuildingKings() }
    }

    // MARK: - Data fetching

    private func loadBuildingKings() async {
        let kings = await APIService.shared.fetchBuildingKings()
        if !kings.isEmpty {
            buildingKings = kings
        }
        // If empty (backend down), buildings stays unmodified → MockData kings shown
    }

}

// MARK: - Building marker annotation view

struct BuildingMarkerView: View {
    let building: Building

    private var markerColor: Color {
        if building.kingUserId != nil {
            return building.color
        }
        return AppColors.textSecondary
    }

    var body: some View {
        VStack(spacing: 2) {
            if building.kingUserId != nil {
                Text("\u{1F451}")
                    .font(.system(size: 10))
            }
            Text(building.abbreviation)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
            if let king = building.kingName {
                Text(king)
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(markerColor.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(markerColor, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }
}
