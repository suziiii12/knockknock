import SwiftUI

struct ProfileView: View {
    private let user = MockData.currentUser
    @State private var showEditSheet = false
    @State private var refreshID = UUID()

    private var savedName: String { UserDefaults.standard.string(forKey: "userName") ?? user.name }
    private var savedSchool: String { UserDefaults.standard.string(forKey: "userSchool") ?? "" }
    private var savedMajor: String { UserDefaults.standard.string(forKey: "userMajor") ?? "" }
    private var savedYear: String { UserDefaults.standard.string(forKey: "userYear") ?? "" }
    private var savedGraduation: String { UserDefaults.standard.string(forKey: "userGraduation") ?? "" }
    private var savedGender: String { UserDefaults.standard.string(forKey: "userGender") ?? "" }

    private var userInitials: String {
        let parts = savedName.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // 1. User info card
                VStack(spacing: 16) {
                    UserAvatar(initials: userInitials.isEmpty ? user.initials : userInitials, colorIndex: user.colorIndex, size: 72, showCrown: !user.kingBuildings.isEmpty)

                    Text(savedName)
                        .font(AppFonts.title)
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.accent)
                        Text("World ID Verified")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Profile details
                    VStack(spacing: 8) {
                        if !savedSchool.isEmpty { profileInfoRow("School", savedSchool) }
                        if !savedMajor.isEmpty { profileInfoRow("Major", savedMajor) }
                        if !savedYear.isEmpty { profileInfoRow("Year", savedYear) }
                        if !savedGraduation.isEmpty { profileInfoRow("Graduation", savedGraduation) }
                    }
                    .padding(.horizontal, 60)
                }
                .padding(.top, 24)
                .id(refreshID)

                // 2. Edit Profile button
                Button {
                    showEditSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                        Text("Edit Profile")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 160, height: 36)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showEditSheet, onDismiss: { refreshID = UUID() }) {
                    EditProfileView()
                }

                // 3. Stats grid
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

                // 4. Territory
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

                // 5. Past weeks
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

                // 6. Streak
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
                                                .foregroundStyle(.white)
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

                // 7. Log Out
                Button {
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    UserDefaults.standard.set(false, forKey: "isProfileComplete")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14))
                        Text("Log Out")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(AppColors.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.danger.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                            .stroke(AppColors.danger.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }

    private func profileInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.textMuted)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
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
