import SwiftUI

struct NavigationBar: View {
    @Binding var activeTab: String
    let onNavigate: (Route) -> Void

    private let tabs: [(label: String, id: String, route: Route)] = [
        ("Focus", "focus", .home),
        ("History", "history", .history),
        ("Map", "map", .map),
        ("Profile", "profile", .profile),
    ]

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
                ScoreBadge(score: MockData.currentUser.totalScore)
                UserAvatar(initials: MockData.currentUser.initials, colorIndex: MockData.currentUser.colorIndex, size: 32)
            }
            .padding(.trailing, 24)
        }
        .frame(height: 56)
        .background(AppColors.bgSecondary)
        .overlay(alignment: .bottom) {
            AppColors.border.frame(height: 1)
        }
    }
}
