import SwiftUI

struct StartSessionView: View {
    let onNavigate: (Route) -> Void
    @State private var selectedDuration: Int = 120
    @State private var locationService = LocationService()
    @State private var kingName: String? = nil
    private let durations = [1, 60, 120, 240] // 1 = 30s test mode

    private var building: Building {
        locationService.detectedBuilding ?? MockData.buildings.first { $0.id == "walc" }!
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // GPS detection banner
            HStack(spacing: 12) {
                if locationService.isLocating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppColors.warning)
                        Text("Locating...")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.warning)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.warning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text("Defaulting to WALC")
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 8, height: 8)
                        Text(locationService.isAuthorized ? "GPS Detected" : "GPS Off")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(building.name)
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.textPrimary)

                    if let king = kingName {
                        HStack(spacing: 4) {
                            Text("\u{1F451}")
                                .font(.system(size: 12))
                            Text("King: \(king)")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.warning)
                        }
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
                                Text(duration == 1 ? "30s" : "\(duration / 60)h")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                Text(duration == 1 ? "Test" : "\(duration) min")
                                    .font(AppFonts.caption)
                            }
                            .foregroundStyle(selectedDuration == duration ? .white : AppColors.textPrimary)
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
                SummaryRow(label: "Building", value: building.abbreviation)
                SummaryRow(label: "Duration", value: selectedDuration == 1 ? "30 seconds (test)" : "\(selectedDuration / 60) hour\(selectedDuration >= 120 ? "s" : "")")
                SummaryRow(label: "Duration Bonus", value: selectedDuration == 1 ? "N/A" : "+\(Int(min(Double(selectedDuration) / 240.0 * 100.0, 100.0) * 0.2))pts (20%)")
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
                onNavigate(.session(duration: selectedDuration, buildingId: building.id))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Focus")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
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
        .onAppear {
            locationService.startUpdating()
        }
        .onDisappear {
            locationService.stopUpdating()
        }
        .task(id: building.id) {
            kingName = await APIService.shared.fetchBuildingKing(buildingSlug: building.id)
        }
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
