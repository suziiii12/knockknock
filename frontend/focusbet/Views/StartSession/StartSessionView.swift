import SwiftUI

struct StartSessionView: View {
    let onNavigate: (Route) -> Void
    @State private var selectedDuration: Int = 120
    @State private var selectedBuildingId: String = "walc"
    @State private var locationService = LocationService()
    @State private var kingName: String? = nil
    private let durations = [1, 60, 120, 240] // 1 = 30s test mode

    private var building: Building {
        MockData.buildings.first { $0.id == selectedBuildingId } ?? MockData.buildings[0]
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Building picker
            VStack(spacing: 8) {
                Text("Select Building")
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.textPrimary)

                Picker("Building", selection: $selectedBuildingId) {
                    ForEach(MockData.buildings) { b in
                        Text(b.name).tag(b.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 400)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                        .stroke(AppColors.border, lineWidth: 1)
                )

                if let king = kingName {
                    HStack(spacing: 4) {
                        Text("\u{1F451}")
                            .font(.system(size: 12))
                        Text("King: \(king)")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.warning)
                    }
                }

                // GPS status (secondary)
                if locationService.isAuthorized, let detected = locationService.detectedBuilding {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 6, height: 6)
                        Text("GPS: \(detected.abbreviation)")
                            .font(AppFonts.small)
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
        .onChange(of: locationService.detectedBuilding?.id) { _, newId in
            // Auto-select GPS-detected building
            if let newId { selectedBuildingId = newId }
        }
        .task(id: selectedBuildingId) {
            kingName = nil
            kingName = await APIService.shared.fetchBuildingKing(buildingSlug: selectedBuildingId)
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
