import SwiftUI

struct ProfileView: View {
    private let user = MockData.currentUser

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Avatar + Name
                VStack(spacing: 12) {
                    UserAvatar(initials: user.initials, colorIndex: user.colorIndex, size: 72, showCrown: !user.kingBuildings.isEmpty)

                    Text(user.name)
                        .font(AppFonts.title)
                        .foregroundStyle(AppColors.textPrimary)

                    if user.isDeviceVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.accent)
                            Text("Device Verified")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.accent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.top, 24)

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ProfileStat(label: "Total Sessions", value: "\(user.totalSessions)")
                    ProfileStat(label: "Total Hours", value: user.totalHours.oneDecimal)
                    ProfileStat(label: "Avg Score", value: "\(user.avgFocusScore)")
                    ProfileStat(label: "Consistency", value: "\(Int(user.weeklyConsistency * 100))%")
                }
                .padding(.horizontal, 40)

                // Territory - Week 14
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your Territory")
                            .font(AppFonts.heading)
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Week \(MockData.weekNumber)")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColors.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if user.kingBuildings.isEmpty {
                        Text("No buildings claimed this week")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.textMuted)
                    } else {
                        ForEach(user.kingBuildings, id: \.self) { buildingId in
                            if let building = MockData.buildings.first(where: { $0.id == buildingId }) {
                                HStack(spacing: 12) {
                                    Text("\u{1F451}")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(building.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(AppColors.textPrimary)
                                        Text("King - \(building.totalScore.formattedWithCommas)pts")
                                            .font(AppFonts.caption)
                                            .foregroundStyle(AppColors.accent)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(AppColors.bgTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)

                // Past weeks
                VStack(alignment: .leading, spacing: 12) {
                    Text("Past Weeks")
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.textPrimary)

                    ForEach(MockData.pastWeeks, id: \.week) { week in
                        HStack {
                            Text("Week \(week.week)")
                                .font(AppFonts.body)
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            Text("\(week.score.formattedWithCommas)pts")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("\(week.sessions) sessions")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textMuted)
                            if !week.kingBuildings.isEmpty {
                                Text("\u{1F451} \(week.kingBuildings.count)")
                                    .font(AppFonts.caption)
                            }
                        }
                        .padding(12)
                        .background(AppColors.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)

                // Streak
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text("\u{1F525}")
                        Text("\(MockData.streakDays) Day Streak")
                            .font(AppFonts.heading)
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    HStack(spacing: 8) {
                        let days = ["M", "T", "W", "T", "F", "S", "S"]
                        ForEach(0..<7, id: \.self) { i in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(MockData.streakDots[i] ? AppColors.accent : AppColors.bgTertiary)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        MockData.streakDots[i]
                                            ? Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(AppColors.bgPrimary)
                                            : nil
                                    )
                                Text(days[i])
                                    .font(AppFonts.small)
                                    .foregroundStyle(AppColors.textMuted)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }
}

private struct ProfileStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accent)
            Text(label)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
