import SwiftUI

struct StartSessionView: View {
    let onNavigate: (Route) -> Void
    @State private var selectedDuration: Int = 120
    private let durations = [60, 120, 240]
    private let detectedBuilding = MockData.buildings[0] // WALC

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // GPS detection banner
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("GPS Detected")
                        .font(AppFonts.caption)
                        .foregroundStyle(Color.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(detectedBuilding.name)
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.textPrimary)

                if let king = detectedBuilding.kingName {
                    HStack(spacing: 4) {
                        Text("\u{1F451}")
                            .font(.system(size: 12))
                        Text("King: \(king)")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.warning)
                    }
                }
            }

            // Duration picker
            VStack(spacing: 16) {
                Text("Select Duration")
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 16) {
                    ForEach(durations, id: \.self) { duration in
                        Button {
                            selectedDuration = duration
                        } label: {
                            VStack(spacing: 6) {
                                Text("\(duration / 60)h")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                Text("\(duration) min")
                                    .font(AppFonts.caption)
                            }
                            .foregroundStyle(selectedDuration == duration ? AppColors.bgPrimary : AppColors.textPrimary)
                            .frame(width: 120, height: 100)
                            .background(
                                selectedDuration == duration
                                    ? AppColors.accent
                                    : AppColors.bgSecondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                                    .stroke(
                                        selectedDuration == duration ? AppColors.accent : AppColors.border,
                                        lineWidth: selectedDuration == duration ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Session summary
            VStack(spacing: 12) {
                SummaryRow(label: "Building", value: detectedBuilding.abbreviation)
                SummaryRow(label: "Duration", value: "\(selectedDuration / 60) hour\(selectedDuration >= 120 ? "s" : "")")
                SummaryRow(label: "Max Time Score", value: "\(min(selectedDuration * 100 / 240, 100))pts")
            }
            .padding(20)
            .background(AppColors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
            .overlay(
                RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .frame(maxWidth: 400)

            // Start button
            Button {
                onNavigate(.session(duration: selectedDuration, buildingId: detectedBuilding.id))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Focus")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.bgPrimary)
                .frame(width: 240, height: 52)
                .background(AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}
