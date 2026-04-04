import SwiftUI

struct WorldIDView: View {
    @Environment(AuthViewModel.self) private var auth
    @AppStorage("isLoggedIn") private var isLoggedIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if auth.isLoading {
                // ── Loading: proof is being generated / backend verifying ──
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppColors.accent)

                    Text("Connecting to World ID...")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Verifying you're a unique human")
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.textMuted)
                }

            } else if auth.isAuthenticated {
                // ── Success: briefly visible before ContentView transitions ──
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppColors.accent)
                    }

                    Text("Verified as Human!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent)

                    Text("World ID verification complete")
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.textMuted)
                }

            } else {
                // ── Idle / error: show error + retry button if needed ──
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppColors.accent)

                    Text("Connecting to World ID...")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Verifying you're a unique human")
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.textMuted)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 48)

                        Button {
                            Task { await auth.triggerWorldIDFlow() }
                        } label: {
                            Text("Try Again")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 200, height: 44)
                                .background(AppColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bgPrimary)
        // Sync auth state to @AppStorage so ContentView's gate transitions
        .onChange(of: auth.isAuthenticated) { _, newValue in
            if newValue { isLoggedIn = true }
        }
        // Auto-trigger verification when this screen appears
        .task {
            await auth.triggerWorldIDFlow()
        }
    }
}
