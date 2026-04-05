import SwiftUI

struct SignalBarsView: View {
    let scores: FocusScoreData
    let elapsedSeconds: Int
    let totalSeconds: Int

    private var elapsedMinutes: Int { elapsedSeconds / 60 }
    private var targetMinutes: Int  { max(totalSeconds / 60, 1) }
    private var durationProgress: Double {
        totalSeconds > 0 ? min(Double(elapsedSeconds) / Double(totalSeconds), 1.0) : 0
    }
    private var durationScore: Int {
        Int(min(Double(targetMinutes) / 240.0 * 100.0, 100.0) * 0.2)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Screen Analysis bar
            signalBar(
                label: "Screen Analysis",
                detail: "TRIBEv2",
                value: scores.screenCapture,
                icon: "display"
            )

            // Motion Detection bar
            signalBar(
                label: "Motion Detection",
                detail: "Webcam",
                value: scores.motionDetection,
                icon: "figure.stand"
            )

            Divider()
                .background(AppColors.border)

            // Duration progress
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textMuted)
                        Text("Duration")
                            .font(AppFonts.small)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Text("\(elapsedMinutes)m / \(targetMinutes)m")
                        .font(AppFonts.small)
                        .foregroundStyle(AppColors.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.bgTertiary)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.accent)
                            .frame(width: geo.size.width * durationProgress, height: 6)
                            .animation(.easeInOut(duration: 0.5), value: durationProgress)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("Duration bonus")
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.textMuted)
                    Spacer()
                    Text("+\(durationScore)pts (20%)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppColors.textMuted)
                }
            }
        }
        .padding(16)
        .background(AppColors.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func signalBar(label: String, detail: String, value: Int, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textMuted)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(AppFonts.small)
                    .foregroundStyle(AppColors.textSecondary)
                Text(detail)
                    .font(.system(size: 8))
                    .foregroundStyle(AppColors.textMuted)
            }
            .frame(width: 72, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.bgTertiary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForScore(value))
                        .frame(width: geo.size.width * Double(value) / 100, height: 6)
                        .animation(.easeInOut(duration: 0.5), value: value)
                }
            }
            .frame(height: 6)

            Text("\(value)")
                .font(AppFonts.small)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    private func colorForScore(_ score: Int) -> Color {
        if score >= 80 { return AppColors.accent }
        if score >= 60 { return AppColors.warning }
        return AppColors.danger
    }
}
