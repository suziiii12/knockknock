import SwiftUI
import CoreImage.CIFilterBuiltins

struct WorldIDView: View {
    @Environment(AuthViewModel.self) private var auth
    @AppStorage("isLoggedIn") private var isLoggedIn = false

    var body: some View {
        HStack(spacing: 0) {
            // LEFT: Branding
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(AppColors.accent)
                    }
                    VStack(spacing: 8) {
                        Text("FocusBet")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("AI-Powered Study Competition")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer()
                VStack(spacing: 12) {
                    FeaturePill(icon: "location.fill",    text: "Compete at Purdue buildings")
                    FeaturePill(icon: "eye.fill",         text: "AI focus tracking")
                    FeaturePill(icon: "shield.checkered", text: "Verified human identity")
                }
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.bgSecondary)

            AppColors.border.frame(width: 1)

            // RIGHT: Auth
            VStack(spacing: 0) {
                Spacer()

                if auth.isAuthenticated {
                    SuccessContent()
                } else if auth.isLoading {
                    LoadingContent(connectorURL: auth.connectorURL)
                } else {
                    IdleContent(
                        errorMessage: auth.errorMessage,
                        onWorldID: { Task { await auth.triggerWorldIDFlow(mode: .worldID) } },
                        onDev:     { Task { await auth.triggerWorldIDFlow(mode: .dev)     } }
                    )
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.bgPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .automatic)
        .onChange(of: auth.isAuthenticated) { _, newValue in
            if newValue { isLoggedIn = true }
        }
    }
}

// MARK: - Idle (both buttons)

private struct IdleContent: View {
    let errorMessage: String?
    let onWorldID: () -> Void
    let onDev:     () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 72, height: 72)
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                VStack(spacing: 6) {
                    Text("Sign in with World ID")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Verify you're a unique human\nusing your World App")
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.textMuted)
                        .multilineTextAlignment(.center)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                // Primary: real World App
                Button(action: onWorldID) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 16))
                        Text("Continue with World ID")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 260, height: 50)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                // Secondary: dev stub
                Button(action: onDev) {
                    HStack(spacing: 6) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 12))
                        Text("Dev Login (skip verification)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(AppColors.textMuted)
                    .frame(width: 260, height: 36)
                    .background(AppColors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Text("Powered by Worldcoin")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textMuted)
        }
    }
}

// MARK: - Loading (QR code or spinner)

private struct LoadingContent: View {
    let connectorURL: URL?

    var body: some View {
        VStack(spacing: 28) {
            if let url = connectorURL {
                VStack(spacing: 16) {
                    Text("Scan with World App")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    if let qr = generateQRCode(from: url.absoluteString) {
                        Image(nsImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 200, height: 200)
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text("Open World App on your phone\nand scan this code")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small).tint(AppColors.textMuted)
                        Text("Waiting for approval…")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.08)).frame(width: 72, height: 72)
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 32)).foregroundStyle(Color.black)
                    }
                    ProgressView().controlSize(.large).tint(AppColors.accent)
                    Text("Connecting…")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()
        filter.message         = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let ci = filter.outputImage else { return nil }
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }
}

// MARK: - Success

private struct SuccessContent: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(AppColors.accent.opacity(0.15)).frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48)).foregroundStyle(AppColors.accent)
            }
            Text("Verified!")
                .font(.system(size: 22, weight: .bold)).foregroundStyle(AppColors.accent)
            Text("Identity confirmed. Welcome to FocusBet.")
                .font(AppFonts.body).foregroundStyle(AppColors.textMuted)
        }
    }
}

// MARK: - Feature pill

private struct FeaturePill: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(AppColors.accent).frame(width: 20)
            Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
