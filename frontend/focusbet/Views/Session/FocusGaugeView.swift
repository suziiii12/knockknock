import SwiftUI

struct FocusGaugeView: View {
    let score: Int

    private var gaugeColor: Color {
        if score >= 80 { return AppColors.accent }
        if score >= 60 { return AppColors.warning }
        return AppColors.danger
    }

    private var progress: Double {
        Double(score) / 100.0
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.0, to: 0.75)
                    .stroke(AppColors.bgTertiary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: 120, height: 120)

                // Progress arc
                Circle()
                    .trim(from: 0.0, to: progress * 0.75)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: 120, height: 120)
                    .animation(.easeInOut(duration: 0.5), value: score)

                // Score text
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(AppFonts.scoreLarge)
                        .foregroundStyle(gaugeColor)
                    Text("Focus")
                        .font(AppFonts.small)
                        .foregroundStyle(AppColors.textMuted)
                }
            }

            Text("Focus Score")
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
