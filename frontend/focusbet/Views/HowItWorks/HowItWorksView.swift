import SwiftUI

struct HowItWorksView: View {
    let onNavigate: (Route) -> Void

    private let steps: [(emoji: String, title: String, description: String)] = [
        ("\u{1F4CD}", "Check In", "Open Lock In at any campus building. GPS automatically detects your location."),
        ("\u{1F9E0}", "Start Studying", "Begin a focus session. AI monitors your concentration through webcam and screen analysis."),
        ("\u{1F4CA}", "Earn Points", "Your Building Score is calculated: Focus (50%) + Study Time (30%) + Consistency (20%)"),
        ("\u{1F451}", "Conquer Territory", "Top scorer at each building becomes the King. Territory resets every Monday."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("How Lock In Works")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.top, 40)

                VStack(spacing: 16) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 20) {
                            // Step number + emoji
                            VStack(spacing: 6) {
                                Text("Step \(index + 1)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppColors.accent)
                                Text(step.emoji)
                                    .font(.system(size: 36))
                            }
                            .frame(width: 70)

                            // Title + description
                            VStack(alignment: .leading, spacing: 6) {
                                Text(step.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(step.description)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineSpacing(3)
                            }

                            Spacer()
                        }
                        .padding(20)
                        .background(AppColors.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
                    }
                }
                .padding(.horizontal, 60)

                Button {
                    onNavigate(.start)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text("Got it — Start Studying!")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 280, height: 50)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }
}
