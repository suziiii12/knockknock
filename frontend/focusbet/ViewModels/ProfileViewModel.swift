import Foundation

@Observable
@MainActor
class ProfileViewModel {
    var user:         User = MockData.currentUser
    var isLoading     = false
    var errorMessage: String?

    var kingBuildings: [Building] {
        MockData.buildings.filter { user.kingBuildings.contains($0.id) }
    }

    /// Fetches live profile data from GET /users/me and merges it with local
    /// UserDefaults fields (name, school) set during ProfileSetupView.
    func load() {
        isLoading    = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let profile = try await APIService.shared.fetchUserProfile()

                // Overlay live backend stats onto the existing user model.
                // Name / initials come from UserDefaults (set in ProfileSetupView).
                let savedName = UserDefaults.standard.string(forKey: "userName") ?? user.name
                let initials  = String(savedName.split(separator: " ")
                    .compactMap(\.first)
                    .prefix(2)
                    .map(String.init)
                    .joined())
                    .uppercased()

                user = User(
                    id:               String(profile.id),
                    name:             savedName.isEmpty ? user.name : savedName,
                    initials:         initials.isEmpty ? user.initials : initials,
                    colorIndex:       user.colorIndex,
                    totalScore:       Int(profile.totalScore),
                    totalSessions:    profile.sessionCount,
                    totalHours:       Double(profile.totalMinutes) / 60.0,
                    avgFocusScore:    Int(profile.avgFocusScore),
                    weeklyConsistency: user.weeklyConsistency,
                    kingBuildings:    user.kingBuildings,   // string slugs — kept from mock until backend stores them
                    isDeviceVerified: user.isDeviceVerified
                )
            } catch APIError.unauthorized {
                errorMessage = "Session expired. Please sign in again."
            } catch {
                // Backend unavailable — keep MockData user
                print("[ProfileViewModel] fetchUserProfile error: \(error.localizedDescription)")
            }
        }
    }
}
