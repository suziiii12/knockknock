import SwiftUI
import MapKit

struct CampusMapView: View {
    let onNavigate: (Route) -> Void

    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4274, longitude: -86.9137),
        span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
    ))

    private var resetTimeString: String {
        let hours = Int(MockData.weekResetTimeInterval / 3600)
        let days = hours / 24
        let remainingHours = hours % 24
        return "\(days)d \(remainingHours)h"
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

            // Apple MapKit Map
            Map(position: $cameraPosition) {
                // "You are here" marker at WALC
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

                // All 17 building annotations — tappable
                ForEach(MockData.buildings) { building in
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
                ForEach(MockData.users.prefix(5)) { user in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(user.color)
                            .frame(width: 8, height: 8)
                        Text(user.name)
                            .font(AppFonts.small)
                            .foregroundStyle(AppColors.textSecondary)
                        Text("\(user.kingBuildings.count)")
                            .font(AppFonts.small)
                            .foregroundStyle(AppColors.textMuted)
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
