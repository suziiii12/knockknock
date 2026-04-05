import SwiftUI

struct NavigationBar: View {
    @Binding var activeTab: String
    let onNavigate: (Route) -> Void

    @State private var weeklyScore: Int = 0

    private let tabs: [(label: String, id: String, route: Route)] = [
        ("Focus", "focus", .home),
        ("History", "history", .history),
        ("Map", "map", .map),
        ("Profile", "profile", .profile),
    ]

    private var navInitials: String {
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let parts = name.split(separator: " ").prefix(2)
        let initials = parts.map { String($0.prefix(1)) }.joined().uppercased()
        return initials.isEmpty ? MockData.currentUser.initials : initials
    }

    var body: some View {
        HStack(spacing: 0) {
            // Logo
            Text("FocusBet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.accent)
                .padding(.leading, 24)

            Spacer()

            // Nav tabs
            HStack(spacing: 4) {
                ForEach(tabs, id: \.id) { tab in
                    Button {
                        activeTab = tab.id
                        onNavigate(tab.route)
                    } label: {
                        Text(tab.label)
                            .font(AppFonts.body)
                            .fontWeight(activeTab == tab.id ? .semibold : .regular)
                            .foregroundStyle(activeTab == tab.id ? AppColors.accent : AppColors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                activeTab == tab.id
                                    ? AppColors.accent.opacity(0.1)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Score badge + Avatar
            HStack(spacing: 12) {
                ScoreBadge(score: weeklyScore)
                UserAvatar(initials: navInitials, colorIndex: MockData.currentUser.colorIndex, size: 32)
            }
            .padding(.trailing, 24)
        }
        .frame(height: 56)
        .background(AppColors.bgSecondary)
        .overlay(alignment: .bottom) {
            AppColors.border.frame(height: 1)
        }
        .task { await refreshScore() }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDidEnd)) { _ in
            Task { await refreshScore() }
        }
    }

    private func refreshScore() async {
        do {
            weeklyScore = try await APIService.shared.fetchWeeklyScore()
        } catch {
            // Keep current value on error
        }
    }
}
