import SwiftUI
import MapKit

struct HomeView: View {
    let onNavigate: (Route) -> Void

    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4274, longitude: -86.9137),
        span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
    ))

    private let leaderboard: [(rank: Int, name: String, initials: String, colorIndex: Int, score: Int, kingCount: Int, isYou: Bool)] = [
        (1, "Yewon", "YC", 0, 4820, 3, true),
        (2, "NakJun", "NJ", 1, 4210, 2, false),
        (3, "Suji", "SJ", 2, 3890, 2, false),
        (4, "Eunho", "EH", 3, 3450, 0, false),
        (5, "Mia K.", "MK", 4, 2980, 1, false),
        (6, "Alex T.", "AT", 5, 2650, 0, false),
        (7, "Chris P.", "CP", 6, 2340, 0, false),
        (8, "Jordan", "JD", 7, 2100, 0, false),
        (9, "Emma W.", "EW", 8, 1870, 0, false),
        (10, "Jake R.", "JR", 9, 1650, 0, false),
    ]

    private var maxScore: Int { leaderboard.first?.score ?? 1 }

    var body: some View {
        VStack(spacing: 16) {
            // Top section: Map (2/3) + Leaderboard (1/3)
            HStack(spacing: 16) {
                // Left: Campus Map
                VStack(alignment: .leading, spacing: 8) {
                    Text("Campus Territory")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Map(position: $cameraPosition) {
                        // "You are here" dot
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: 40.4273891, longitude: -86.9132292), anchor: .center) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 20, height: 20)
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            }
                            .allowsHitTesting(false)
                        }

                        // Building markers
                        ForEach(MockData.buildings) { building in
                            Annotation("", coordinate: building.coordinate, anchor: .center) {
                                Button {
                                    onNavigate(.building(id: building.id))
                                } label: {
                                    HomeMapMarker(building: building)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                    .preferredColorScheme(.dark)
                    .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                    .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
                }
                .frame(maxWidth: .infinity)

                // Right: Global Leaderboard
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text("\u{1F3C6}")
                            .font(.system(size: 16))
                        Text("Top Focused Students")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(leaderboard, id: \.rank) { entry in
                                leaderboardRow(entry)
                            }
                        }
                    }
                }
                .padding(16)
                .background(AppColors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
                .frame(width: 300)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Bottom: CTA button
            Button {
                onNavigate(.start)
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\u{1F3F4}")
                        Text("Start Conquering Territory")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Text("Begin a study session to claim buildings")
                        .font(.system(size: 12))
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }

    // MARK: - Leaderboard row

    private func leaderboardRow(_ entry: (rank: Int, name: String, initials: String, colorIndex: Int, score: Int, kingCount: Int, isYou: Bool)) -> some View {
        let isFirst = entry.rank == 1

        return HStack(spacing: 8) {
            // Rank
            if isFirst {
                Text("\u{1F451}")
                    .font(.system(size: 12))
                    .frame(width: 22)
            } else {
                Text("#\(entry.rank)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)
                    .frame(width: 22)
            }

            // Avatar
            UserAvatar(initials: entry.initials, colorIndex: entry.colorIndex, size: 24)

            // Name + YOU badge
            HStack(spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 12, weight: isFirst ? .bold : .medium))
                    .foregroundStyle(isFirst ? AppColors.accent : AppColors.textPrimary)
                    .lineLimit(1)

                if entry.isYou {
                    Text("YOU")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Spacer()

            // King count
            if entry.kingCount > 0 {
                HStack(spacing: 2) {
                    Text("\u{1F451}")
                        .font(.system(size: 8))
                    Text("\(entry.kingCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.warning)
                }
            }

            // Score + bar
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(entry.score.formattedWithCommas)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.bgTertiary)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.userColors[entry.colorIndex % AppColors.userColors.count])
                            .frame(width: geo.size.width * CGFloat(entry.score) / CGFloat(maxScore), height: 3)
                    }
                }
                .frame(width: 50, height: 3)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isFirst ? AppColors.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Compact map marker for home

private struct HomeMapMarker: View {
    let building: Building

    private var markerColor: Color {
        building.kingUserId != nil ? building.color : AppColors.textSecondary
    }

    var body: some View {
        Text(building.abbreviation)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(markerColor.opacity(0.85))
            )
            .contentShape(Rectangle())
    }
}
