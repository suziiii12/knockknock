import SwiftUI

struct HomeView: View {
    let onNavigate: (Route) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Hero section
                VStack(spacing: 16) {
                    Spacer().frame(height: 40)

                    Text("Bet on Your ")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    + Text("Focus")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(AppColors.accent)

                    Text("AI-powered study tracking with campus territory competition.\nStudy hard. Claim buildings. Become the King.")
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    HStack(spacing: 16) {
                        Button {
                            onNavigate(.start)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start Studying")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.bgPrimary)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(AppColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onNavigate(.map)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "map")
                                Text("View Campus Map")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton)
                                    .stroke(AppColors.accent, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                }

                // Feature cards 2x2
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                ], spacing: 16) {
                    FeatureCard(icon: "eye.fill", title: "AI Verified", description: "Webcam + screen analysis ensures real focus, not just open books.", color: AppColors.accent)
                    FeatureCard(icon: "trophy.fill", title: "Compete", description: "Compete against classmates for building territory ownership.", color: AppColors.userColors[1])
                    FeatureCard(icon: "hexagon.fill", title: "Own Territory", description: "Study to claim hex cells in campus buildings. Top scorer is King.", color: AppColors.userColors[2])
                    FeatureCard(icon: "checkmark.shield.fill", title: "World ID", description: "Device-verified identity ensures one person, one account.", color: AppColors.userColors[3])
                }
                .padding(.horizontal, 60)

                // Live stats
                HStack(spacing: 60) {
                    StatNumber(value: "1,247", label: "Active Students")
                    StatNumber(value: "14", label: "Campus Buildings")
                    StatNumber(value: "8,432", label: "Sessions This Week")
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }
}

private struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            Text(title)
                .font(AppFonts.heading)
                .foregroundStyle(AppColors.textPrimary)
            Text(description)
                .font(AppFonts.body)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

private struct StatNumber: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accent)
            Text(label)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.textMuted)
        }
    }
}
