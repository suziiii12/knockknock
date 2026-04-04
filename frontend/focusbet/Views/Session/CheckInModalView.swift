import SwiftUI

struct CheckInModalView: View {
    let onDismiss: () -> Void
    @State private var selectedOption: Int?

    private let questions = [
        "What are you working on right now?",
        "Rate your current focus level",
        "Are you still engaged with your task?",
    ]

    private let options = ["Deep focus", "Moderate focus", "Distracted", "Taking a break"]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(AppColors.accent)
                    Text("AI Check-in")
                        .font(AppFonts.heading)
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textMuted)
                        .frame(width: 24, height: 24)
                        .background(AppColors.bgTertiary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(questions.randomElement() ?? questions[0])
                .font(AppFonts.body)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 8) {
                ForEach(0..<options.count, id: \.self) { i in
                    Button {
                        selectedOption = i
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onDismiss()
                        }
                    } label: {
                        Text(options[i])
                            .font(AppFonts.caption)
                            .foregroundStyle(selectedOption == i ? AppColors.bgPrimary : AppColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedOption == i ? AppColors.accent : AppColors.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .frame(maxWidth: 500)
    }
}
