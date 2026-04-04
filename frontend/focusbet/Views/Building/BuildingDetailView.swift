import SwiftUI

struct BuildingDetailView: View {
    let buildingId: String

    private var building: Building {
        MockData.buildings.first { $0.id == buildingId } ?? MockData.buildings[0]
    }

    private var territory: [TerritoryEntry] {
        MockData.walcTerritory
    }

    @State private var animatingCells = Set<Int>()
    @State private var highlightedUser: Int? = nil // territory index

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

                HexGridView(
                    territory: territory,
                    animatingCells: animatingCells,
                    floorPlan: building.floorPlan,
                    highlightedUser: $highlightedUser
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
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
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Live")
                                .font(AppFonts.small)
                                .foregroundStyle(Color.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.1))
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
        .onAppear { startCellAnimation() }
    }

    private func colorForActivity(_ type: ActivityFeedItem.ActivityType) -> Color {
        switch type {
        case .sessionComplete: return AppColors.accent
        case .studying: return .green
        case .overtake: return AppColors.warning
        case .kingTakeover: return AppColors.userColors[1]
        }
    }

    private func startCellAnimation() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            let cellCount = 400
            let randomCells = Set((0..<12).map { _ in Int.random(in: 0..<cellCount) })
            withAnimation(.easeInOut(duration: 0.6)) {
                animatingCells = randomCells
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    animatingCells.removeAll()
                }
            }
        }
    }
}
