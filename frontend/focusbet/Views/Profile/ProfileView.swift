import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var profile: UserProfile? = nil
    @State private var isLoading = true
    @State private var showEditSheet = false
    @State private var refreshID = UUID()

    // Profile text — prefer API data → UserDefaults → MockData fallback
    private var displayName: String {
        if let name = profile?.name, !name.isEmpty { return name }
        return UserDefaults.standard.string(forKey: "userName") ?? MockData.currentUser.name
    }
    private var displaySchool: String {
        if let v = profile?.school, !v.isEmpty { return v }
        return UserDefaults.standard.string(forKey: "userSchool") ?? ""
    }
    private var displayMajor: String {
        if let v = profile?.major, !v.isEmpty { return v }
        return UserDefaults.standard.string(forKey: "userMajor") ?? ""
    }
    private var displayYear: String {
        if let v = profile?.year, !v.isEmpty { return v }
        return UserDefaults.standard.string(forKey: "userYear") ?? ""
    }
    private var displayGraduation: String {
        UserDefaults.standard.string(forKey: "userGraduation") ?? ""
    }

    private var userInitials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let result = parts.map { String($0.prefix(1)) }.joined().uppercased()
        return result.isEmpty ? MockData.currentUser.initials : result
    }
    private var colorIndex: Int {
        profile.map { ($0.id - 1) % 10 } ?? MockData.currentUser.colorIndex
    }
    private var kingBuildings: [Building] {
        profile?.kingBuildingIds.compactMap { id in
            guard let slug = APIService.buildingSlug(for: id) else { return nil }
            return MockData.buildings.first { $0.id == slug }
        } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // 1. User info card
                VStack(spacing: 16) {
                    UserAvatar(initials: userInitials, colorIndex: colorIndex, size: 72, showCrown: !kingBuildings.isEmpty)

                    Text(displayName)
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

                    VStack(spacing: 8) {
                        if !displaySchool.isEmpty     { profileInfoRow("School",     displaySchool) }
                        if !displayMajor.isEmpty      { profileInfoRow("Major",      displayMajor) }
                        if !displayYear.isEmpty       { profileInfoRow("Year",       displayYear) }
                        if !displayGraduation.isEmpty { profileInfoRow("Graduation", displayGraduation) }
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
                .sheet(isPresented: $showEditSheet, onDismiss: {
                    refreshID = UUID()
                    Task { await loadProfile() }
                }) {
                    EditProfileView()
                }

                // 3. Stats grid
                let sessionCount = profile?.sessionCount ?? MockData.currentUser.totalSessions
                let totalHours   = (profile?.totalMinutes ?? (MockData.currentUser.totalHours * 60)) / 60.0
                let avgScore     = Int((profile?.avgFocusScore ?? Double(MockData.currentUser.avgFocusScore)).rounded())
                let weeklyPts    = Int((profile?.weeklyScore ?? Double(MockData.currentUser.totalScore)).rounded())

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ProfileStat(label: "Total Sessions", value: "\(sessionCount)")
                    ProfileStat(label: "Total Hours",    value: totalHours.oneDecimal)
                    ProfileStat(label: "Avg Score",      value: "\(avgScore)")
                    ProfileStat(label: "Weekly Pts",     value: "\(weeklyPts)pts")
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

                    if kingBuildings.isEmpty {
                        Text("No buildings claimed this week")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.textMuted)
                    } else {
                        ForEach(kingBuildings, id: \.id) { building in
                            HStack(spacing: 12) {
                                Text("\u{1F451}")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(building.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("King this week")
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)

                // 5. Past weeks — no backend endpoint yet, using MockData
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

                // 6. This Week's Scores by Building — MockData until per-building endpoint exists
                VStack(alignment: .leading, spacing: 12) {
                    Text("This Week's Scores")
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.textPrimary)

                    ForEach(MockData.weeklyBuildingScores, id: \.buildingId) { entry in
                        HStack {
                            Text(entry.abbreviation)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(width: 48, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColors.bgTertiary)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColors.accent)
                                        .frame(width: geo.size.width * min(Double(entry.score) / 200.0, 1.0), height: 6)
                                }
                            }
                            .frame(height: 6)
                            Text("+\(entry.score)pts")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .padding(12)
                        .background(AppColors.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    HStack {
                        Text("Total")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.textMuted)
                        Spacer()
                        Text("\(weeklyPts)pts")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)

                // 7. Log Out
                Button {
                    authViewModel.logout()
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
        .task { await loadProfile() }
    }

    // MARK: - Data fetching

    private func loadProfile() async {
        isLoading = true
        do {
            let fetched = try await APIService.shared.fetchUserProfile()
            profile = fetched
            // Mirror to UserDefaults so EditProfileView always pre-fills correctly
            if let name = fetched.name,   !name.isEmpty   { UserDefaults.standard.set(name,   forKey: "userName") }
            if let school = fetched.school, !school.isEmpty { UserDefaults.standard.set(school, forKey: "userSchool") }
            if let major = fetched.major,  !major.isEmpty  { UserDefaults.standard.set(major,  forKey: "userMajor") }
            if let year = fetched.year,   !year.isEmpty   { UserDefaults.standard.set(year,   forKey: "userYear") }
            if let gender = fetched.gender, !gender.isEmpty { UserDefaults.standard.set(gender, forKey: "userGender") }
        } catch {
            print("[ProfileView] loadProfile error: \(error.localizedDescription)")
            // profile stays nil — computed props fall back to UserDefaults / MockData
        }
        isLoading = false
    }

    // MARK: - Sub-views

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
