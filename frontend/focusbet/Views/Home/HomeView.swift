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
    ]

    private var maxScore: Int { leaderboard.first?.score ?? 1 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // SECTION 1 — Hero Banner
                heroSection
                    .padding(.horizontal, 32)
                    .padding(.top, 40)
                    .padding(.bottom, 32)

                // SECTION 2 — Map + Leaderboard
                mapSection
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                // SECTION 3 — CTA
                ctaButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }

    // MARK: - Section 1: Hero

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 40) {
            // Left: text + buttons
            VStack(alignment: .leading, spacing: 16) {
                Text("Start. Focus.\nConquer.")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(4)

                Text("Track your study sessions with AI.\nCompete for campus territory.\nProve you're the most focused student.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(4)

                HStack(spacing: 12) {
                    Button {
                        onNavigate(.start)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13))
                            Text("Start Studying")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onNavigate(.howItWorks)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 13))
                            Text("How it Works")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                                .stroke(AppColors.accent, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: 3 step cards
            VStack(spacing: 12) {
                stepCard("\u{1F4CD}", "Check in at a building", "GPS auto-detects your location", rotation: -3)
                stepCard("\u{1F9E0}", "AI tracks your focus", "Webcam + screen analysis in real-time", rotation: 2)
                stepCard("\u{1F451}", "Claim territory", "Top scorer becomes Building King", rotation: -1)
            }
            .frame(width: 260)
        }
    }

    private func stepCard(_ emoji: String, _ title: String, _ subtitle: String, rotation: Double) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: AppColors.cardShadow, radius: 6, y: 2)
        .rotationEffect(.degrees(rotation))
    }

    // MARK: - Section 2: Map + Leaderboard

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Text("Live Campus Territory")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            HStack(spacing: 16) {
                // Left: Map
                Map(position: $cameraPosition) {
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
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
                .frame(maxWidth: .infinity)

                // Right: Leaderboard (top 5)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("\u{1F3C6}")
                            .font(.system(size: 14))
                        Text("Top Focused Students")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    VStack(spacing: 2) {
                        ForEach(leaderboard, id: \.rank) { entry in
                            leaderboardRow(entry)
                        }
                    }

                    Button {
                        onNavigate(.map)
                    } label: {
                        HStack(spacing: 4) {
                            Text("View All")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(14)
                .background(AppColors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
                .frame(width: 300)
                .frame(height: 300)
            }
        }
    }

    // MARK: - Section 3: CTA

    private var ctaButton: some View {
        Button {
            onNavigate(.start)
        } label: {
            VStack(spacing: 4) {
                Text("Start Conquering Territory")
                    .font(.system(size: 18, weight: .semibold))
                Text("Begin a study session to claim buildings")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [AppColors.accent.opacity(0.75), AppColors.accent.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
            .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Leaderboard row

    private func leaderboardRow(_ entry: (rank: Int, name: String, initials: String, colorIndex: Int, score: Int, kingCount: Int, isYou: Bool)) -> some View {
        let isFirst = entry.rank == 1

        return HStack(spacing: 8) {
            if isFirst {
                Text("\u{1F451}")
                    .font(.system(size: 11))
                    .frame(width: 20)
            } else {
                Text("#\(entry.rank)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)
                    .frame(width: 20)
            }

            UserAvatar(initials: entry.initials, colorIndex: entry.colorIndex, size: 22)

            HStack(spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 11, weight: isFirst ? .bold : .medium))
                    .foregroundStyle(isFirst ? AppColors.accent : AppColors.textPrimary)
                    .lineLimit(1)

                if entry.isYou {
                    Text("YOU")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            Spacer()

            if entry.kingCount > 0 {
                HStack(spacing: 1) {
                    Text("\u{1F451}")
                        .font(.system(size: 7))
                    Text("\(entry.kingCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppColors.warning)
                }
            }

            Text("\(entry.score.formattedWithCommas)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(isFirst ? AppColors.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Compact map marker

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
