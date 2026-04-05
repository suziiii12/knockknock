import SwiftUI

struct HistoryView: View {
    private let sessions = MockData.sessionHistory

    private var totalSessions: Int { sessions.count }
    private var avgScore: Int {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.focusScore).reduce(0, +) / sessions.count
    }
    private var totalHours: Double {
        Double(sessions.map(\.duration).reduce(0, +)) / 60.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("Session History")
                    .font(AppFonts.title)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                // Quick stats
                HStack(spacing: 24) {
                    QuickStat(label: "Total Sessions", value: "\(totalSessions)")
                    QuickStat(label: "Avg Score", value: "\(avgScore)")
                    QuickStat(label: "Total Hours", value: totalHours.oneDecimal)
                }
                .padding(.horizontal, 32)

                // Session list
                VStack(spacing: 12) {
                    ForEach(sessions) { session in
                        SessionCard(session: session)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }
}

private struct QuickStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accent)
            Text(label)
                .font(AppFonts.caption)
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}

private struct SessionCard: View {
    let session: StudySession

    private var scoreColor: Color {
        if session.focusScore >= 80 { return AppColors.accent }
        if session.focusScore >= 60 { return AppColors.warning }
        return AppColors.danger
    }

    var body: some View {
        HStack(spacing: 16) {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startTime.shortFormatted)
                    .font(AppFonts.body)
                    .foregroundStyle(AppColors.textPrimary)
                Text(session.startTime.timeFormatted)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
            .frame(width: 120, alignment: .leading)

            // Building
            Text(session.buildingName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 60)

            // Focus score circle
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)
                Circle()
                    .trim(from: 0, to: Double(session.focusScore) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 40, height: 40)
                Text("\(session.focusScore)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(scoreColor)
            }

            Spacer()

            // Building score
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(session.sessionScore)pts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                Text("\(session.duration / 60)h")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(16)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
