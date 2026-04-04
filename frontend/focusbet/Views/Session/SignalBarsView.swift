import SwiftUI

struct SignalBarsView: View {
    let scores: FocusScoreData

    private var signals: [(String, Int, String)] {
        [
            ("Gaze", scores.gaze, "eye"),
            ("Posture", scores.posture, "figure.stand"),
            ("Blink", scores.blink, "eye.slash"),
            ("Keys/Mouse", scores.keyMouse, "keyboard"),
            ("Tabs", scores.tabs, "square.on.square"),
            ("Check-in", scores.checkIn, "checkmark.circle"),
        ]
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(signals, id: \.0) { name, value, icon in
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textMuted)
                        .frame(width: 16)
                    Text(name)
                        .font(AppFonts.small)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 60, alignment: .leading)
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
        }
        .padding(16)
        .background(AppColors.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func colorForScore(_ score: Int) -> Color {
        if score >= 80 { return AppColors.accent }
        if score >= 60 { return AppColors.warning }
        return AppColors.danger
    }
}
