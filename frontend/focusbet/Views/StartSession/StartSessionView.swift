import SwiftUI
import AppKit
import CoreImage

struct StartSessionView: View {
    let onNavigate: (Route) -> Void
    @State private var selectedDuration: Int = 120
    @State private var locationService = LocationService()
    @State private var kingName: String? = nil
    @State private var showSelfieCheck = false
    @State private var selfieConnectorURL: URL? = nil
    @State private var selfieError: String? = nil
    @State private var selfieVerifying = false
    private let durations = [1, 60, 120, 240]

    private var building: Building {
        locationService.detectedBuilding ?? MockData.buildings.first { $0.id == "walc" }!
    }

    var body: some View {
        ZStack {
            VStack(spacing: 32) {
                Spacer()

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

                Button {
                    startSelfieCheck()
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

            if showSelfieCheck {
                SelfieCheckOverlay(
                    connectorURL: selfieConnectorURL,
                    error: selfieError,
                    isVerifying: selfieVerifying,
                    onCancel: { showSelfieCheck = false }
                )
            }
        }
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

    private func startSelfieCheck() {
#if IDKIT_ENABLED
        showSelfieCheck = true
        selfieError = nil
        selfieVerifying = true

        Task {
            do {
                let token = await APIService.shared.currentToken
                guard let token else {
                    selfieError = "Not logged in"
                    selfieVerifying = false
                    return
                }
                let verified = try await WorldIDService.shared.requestSelfieVerification(
                    authToken: token,
                    onConnectorURL: { url in selfieConnectorURL = url }
                )
                selfieVerifying = false
                selfieConnectorURL = nil

                if verified {
                    showSelfieCheck = false
                    onNavigate(.session(duration: selectedDuration, buildingId: building.id))
                } else {
                    selfieError = "Selfie verification did not pass"
                }
            } catch {
                selfieVerifying = false
                selfieConnectorURL = nil
                selfieError = error.localizedDescription
            }
        }
#else
        onNavigate(.session(duration: selectedDuration, buildingId: building.id))
#endif
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

private struct SelfieCheckOverlay: View {
    let connectorURL: URL?
    let error: String?
    let isVerifying: Bool
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Identity Verification")
                    .font(AppFonts.title)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Scan with World App to verify your identity before starting the session.")
                    .font(AppFonts.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                if let error {
                    Text(error)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.danger)
                        .padding(8)
                        .background(AppColors.danger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if let connectorURL {
                    QRCodeView(url: connectorURL)
                        .frame(width: 200, height: 200)
                } else if isVerifying {
                    ProgressView("Verifying...")
                        .controlSize(.large)
                }

                Button("Cancel") { onCancel() }
                    .font(AppFonts.body)
                    .foregroundStyle(AppColors.textMuted)
                    .buttonStyle(.plain)
            }
            .padding(32)
            .background(AppColors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
            .shadow(color: AppColors.cardShadow, radius: 20)
        }
    }
}

private struct QRCodeView: View {
    let url: URL

    var body: some View {
        if let image = generateQRCode(from: url.absoluteString) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Text("QR Error")
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.textMuted)
        }
    }

    private func generateQRCode(from string: String) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator"),
              let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
