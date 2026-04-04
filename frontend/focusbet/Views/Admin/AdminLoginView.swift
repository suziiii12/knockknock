import SwiftUI

struct AdminLoginView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isAdmin") private var isAdmin = false
    @State private var code = ""
    @State private var showError = false
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppColors.accent)

            Text("Admin Access")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Enter admin code")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 8) {
                SecureField("Admin code", text: $code)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(12)
                    .background(AppColors.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(showError ? AppColors.danger : AppColors.border, lineWidth: 1)
                    )
                    .frame(width: 250)
                    .offset(x: shakeOffset)

                if showError {
                    Text("Invalid code")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.danger)
                }
            }

            Button {
                if code == "hello" {
                    isAdmin = true
                    dismiss()
                } else {
                    showError = true
                    withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                        shakeOffset = 10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        shakeOffset = 0
                    }
                }
            } label: {
                Text("Enter")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 160, height: 44)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton))
            }
            .buttonStyle(.plain)

            Button("Cancel") { dismiss() }
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textMuted)
                .buttonStyle(.plain)
        }
        .padding(40)
        .frame(width: 400, height: 360)
        .background(AppColors.bgPrimary)
    }
}
