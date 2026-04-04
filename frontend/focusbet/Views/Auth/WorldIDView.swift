import SwiftUI

struct WorldIDView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var verified = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if verified {
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
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bgPrimary)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    verified = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isLoggedIn = true
                }
            }
        }
    }
}
