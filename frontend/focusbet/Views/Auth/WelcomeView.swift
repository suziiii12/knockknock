import SwiftUI

struct WelcomeView: View {
    var onSignIn: () -> Void
    @State private var showAdminLogin = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 88, height: 88)
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.accent)
                }

                Text("LockIn")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("AI-Powered Study Competition")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            VStack(spacing: 16) {
                Button {
                    onSignIn()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .font(.system(size: 18))
                        Text("Sign in with World ID")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 280, height: 50)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                }
                .buttonStyle(.plain)

                Text("Learn More")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)

                Button("Admin Access") {
                    showAdminLogin = true
                }
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textMuted)
                .buttonStyle(.plain)
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bgPrimary)
        .sheet(isPresented: $showAdminLogin) {
            AdminLoginView()
        }
    }
}
