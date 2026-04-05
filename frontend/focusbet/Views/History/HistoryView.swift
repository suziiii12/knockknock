import SwiftUI

struct HistoryView: View {
    @State private var vm = HistoryViewModel()

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

                if vm.isLoading {
                    ProgressView()
                        .tint(AppColors.accent)
                        .padding(.top, 60)
                } else if let error = vm.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(AppColors.warning)
                        Text(error)
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await vm.loadHistory() }
                        } label: {
                            Text("Retry")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(AppColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 32)
                } else if vm.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColors.textMuted)
                        Text("No sessions yet")
                            .font(AppFonts.heading)
                            .foregroundStyle(AppColors.textSecondary)
                        Text("Complete a focus session to see your history here.")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 32)
                } else {
                    // Quick stats
                    HStack(spacing: 24) {
                        QuickStat(label: "Total Sessions", value: "\(vm.totalSessions)")
                        QuickStat(label: "Avg Score", value: "\(vm.avgScore)")
                        QuickStat(label: "Total Hours", value: vm.totalHours.oneDecimal)
                    }
                    .padding(.horizontal, 32)

                    // Session list
                    VStack(spacing: 12) {
                        ForEach(vm.sessions) { session in
                            SessionCard(session: session)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
        .task {
            await vm.loadHistory()
        }
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

    private var winBadge: (text: String, color: Color)? {
        if session.focusScore >= 70 { return ("WIN", AppColors.accent) }
        if session.focusScore < 50  { return ("LOSS", AppColors.danger) }
        return nil
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

            // Win/loss badge
            if let badge = winBadge {
                Text(badge.text)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(badge.color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Building score + duration
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(session.sessionScore)pts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                Text(session.duration >= 60
                     ? "\(session.duration / 60)h \(session.duration % 60 > 0 ? "\(session.duration % 60)m" : "")"
                     : "\(session.duration)m")
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
