import SwiftUI

struct CheckInModalView: View {
    let sessionId: Int?
    let onDismiss: (Bool) -> Void   // passes `passed` back to SessionView

    @State private var selectedOption: Int?
    @State private var feedback: String?
    @State private var isEvaluating = false

    private let question = [
        "What are you working on right now?",
        "Rate your current focus level",
        "Are you still engaged with your task?",
    ].randomElement() ?? "What are you working on right now?"

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
                Button(action: { onDismiss(false) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textMuted)
                        .frame(width: 24, height: 24)
                        .background(AppColors.bgTertiary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(question)
                .font(AppFonts.body)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 8) {
                ForEach(0..<options.count, id: \.self) { i in
                    Button {
                        guard !isEvaluating else { return }
                        selectedOption = i
                        evaluate(answer: options[i])
                    } label: {
                        Text(options[i])
                            .font(AppFonts.caption)
                            .foregroundStyle(selectedOption == i ? .white : AppColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedOption == i ? AppColors.accent : AppColors.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Feedback / loading
            if isEvaluating {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Evaluating...")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.textMuted)
                }
            } else if let fb = feedback {
                Text(fb)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
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

    private func evaluate(answer: String) {
        guard let sid = sessionId else {
            // No backend session — dismiss after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDismiss(false) }
            return
        }

        isEvaluating = true
        Task {
            do {
                let result = try await APIService.shared.evaluateCheckIn(
                    sessionId: sid,
                    prompt: question,
                    answer: answer
                )
                withAnimation {
                    feedback = result.feedback
                    isEvaluating = false
                }
                try? await Task.sleep(for: .seconds(2))
                onDismiss(result.passed)
            } catch {
                isEvaluating = false
                onDismiss(false)
            }
        }
    }
}
