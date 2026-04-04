import SwiftUI

struct ResultView: View {
    let focusScore: Int
    let buildingId: String
    let duration: Int
    let onNavigate: (Route) -> Void

    private var building: Building {
        MockData.buildings.first { $0.id == buildingId } ?? MockData.buildings[0]
    }

    private var isSuccess: Bool { focusScore >= 70 }

    private var buildingScore: Int {
        FocusScoreData.buildingScore(focusScore: focusScore, durationMinutes: duration, daysStudiedThisWeek: 5)
    }

    private var scores: FocusScoreData {
        FocusScoreData(
            gaze: min(focusScore + 4, 100),
            posture: max(focusScore - 2, 0),
            blink: min(focusScore + 1, 100),
            keyMouse: max(focusScore - 5, 0),
            tabs: max(focusScore - 8, 0),
            checkIn: min(focusScore + 8, 100)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 20)

                // Success/fail banner
                VStack(spacing: 8) {
                    Text(isSuccess ? "Session Complete!" : "Session Ended")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(isSuccess ? AppColors.accent : AppColors.danger)
                    Text(isSuccess ? "Great focus session!" : "Try to stay more focused next time.")
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.textSecondary)
                }

                // Score gauge
                FocusGaugeView(score: focusScore)

                // Signal bars
                SignalBarsView(scores: scores)
                    .frame(maxWidth: 400)

                // Building score
                VStack(spacing: 12) {
                    HStack {
                        Text("Building Score Earned")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("+\(buildingScore)pts")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.accent)
                    }
                    HStack {
                        Text("Building")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(building.abbreviation)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    HStack {
                        Text("Duration")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("\(duration / 60)h")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    HStack {
                        Text("Rank Change")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("\(building.abbreviation): 3rd \u{2192} 2nd!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                    }
                }
                .padding(20)
                .background(AppColors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .frame(maxWidth: 400)

                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        onNavigate(.start)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Start Another")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.bgPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onNavigate(.building(id: buildingId))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2")
                            Text("View Building")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton)
                                .stroke(AppColors.accent, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }
}
