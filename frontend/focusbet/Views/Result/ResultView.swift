import SwiftUI
import Charts

struct ResultView: View {
    let focusScore: Int
    let buildingId: String
    let duration: Int
    let onNavigate: (Route) -> Void

    private var building: Building {
        MockData.buildings.first { $0.id == buildingId } ?? MockData.buildings[0]
    }

    private var isSuccess: Bool { focusScore >= 70 }

    private var sessionScore: Int {
        FocusScoreData.sessionScore(focusLevel: focusScore, durationMinutes: duration)
    }

    private var engagementData: [(minute: Int, score: Double)] {
        let base = Double(focusScore)
        return [
            (0, base - 12), (5, base - 5), (10, base + 1), (15, base - 2), (20, base + 3),
            (25, base), (30, base - 5), (35, base - 9), (40, base - 19), (45, base - 32),
            (50, base - 27), (55, base - 15), (60, base - 9), (65, base - 2), (70, base + 1),
            (75, base + 5), (80, base + 2), (85, base - 2), (90, base - 5), (95, base - 9),
            (100, base - 7), (105, base - 4), (110, base - 8), (115, base - 12), (120, base - 10),
        ].map { (m, s) in (m, max(10, min(100, s))) }
         .filter { $0.0 <= duration }
    }

    private let brainRegions: [(name: String, label: String, activation: Double)] = [
        ("Prefrontal", "Planning & Focus", 0.85),
        ("Temporal", "Language", 0.62),
        ("Parietal", "Problem Solving", 0.78),
        ("Occipital", "Visual", 0.45),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // ROW 1 — Score Summary
                scoreSummary

                // ROW 2 — Engagement + Brain (side by side)
                HStack(alignment: .top, spacing: 10) {
                    engagementChart
                    brainActivitySection
                }

                // ROW 3 — AI Insights (side by side)
                HStack(alignment: .top, spacing: 10) {
                    sessionSummaryCard
                    improvementTipsCard
                }

                // ROW 4 — Buttons
                actionButtons
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }

    // MARK: - Score Summary

    private var scoreSummary: some View {
        HStack(spacing: 36) {
            FocusGaugeView(score: focusScore)
                .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 10) {
                Text(isSuccess ? "Session Complete!" : "Needs Improvement")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(isSuccess ? AppColors.accent : AppColors.danger)

                Text("\(building.abbreviation) \u{2022} \(duration >= 60 ? "\(duration / 60)h" : "\(duration)min") session")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Session Score")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textMuted)
                        Text("+\(sessionScore) pts")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Rank Change")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textMuted)
                        Text("\(building.abbreviation): #3 \u{2192} #2 \u{2191}")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Engagement Chart

    private var engagementChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus Engagement Over Time")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            Chart(engagementData, id: \.minute) { point in
                LineMark(x: .value("Min", point.minute), y: .value("Score", point.score))
                    .foregroundStyle(AppColors.accentLight)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                AreaMark(x: .value("Min", point.minute), y: .value("Score", point.score))
                    .foregroundStyle(
                        .linearGradient(colors: [AppColors.accentLight.opacity(0.2), .clear],
                                        startPoint: .top, endPoint: .bottom)
                    )
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 40, 70, 100]) { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(AppColors.border)
                    AxisValueLabel { if let val = v.as(Int.self) { Text("\(val)").font(.system(size: 8)).foregroundStyle(AppColors.textMuted) } }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 30)) { _ in
                    AxisValueLabel().foregroundStyle(AppColors.textMuted)
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 14) {
                zoneLegend(AppColors.accentLight, "Focused")
                zoneLegend(AppColors.warning, "Drifting")
                zoneLegend(AppColors.danger, "Distracted")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    private func zoneLegend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.4)).frame(width: 10, height: 6)
            Text(label).font(.system(size: 9)).foregroundStyle(AppColors.textMuted)
        }
    }

    // MARK: - Brain Activity

    private var brainActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Brain Activity Analysis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("TRIBEv2")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.textMuted)
            }

            HStack(spacing: 16) {
                brainMapView
                    .frame(width: 120, height: 110)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(brainRegions, id: \.name) { region in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.accentLight.opacity(0.2 + region.activation * 0.8))
                                .frame(width: 4, height: 18)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(region.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("\(Int(region.activation * 100))%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                        }
                    }
                }
            }

            // Cognitive demand bar
            VStack(spacing: 4) {
                HStack {
                    Text("Cognitive Demand")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("78/100")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(AppColors.bgTertiary)
                        RoundedRectangle(cornerRadius: 3).fill(AppColors.accentLight).frame(width: geo.size.width * 0.78)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    private var brainMapView: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let w = size.width * 0.85
            let h = size.height * 0.85

            let brainPath = Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
            context.stroke(brainPath, with: .color(AppColors.border), lineWidth: 1.2)

            var midLine = Path()
            midLine.move(to: CGPoint(x: cx, y: cy - h / 2 + 8))
            midLine.addLine(to: CGPoint(x: cx, y: cy + h / 2 - 8))
            context.stroke(midLine, with: .color(AppColors.border.opacity(0.4)), lineWidth: 0.8)

            let regions: [(CGRect, Double)] = [
                (CGRect(x: cx - 25, y: cy - h / 2 + 12, width: 50, height: 30), 0.85),
                (CGRect(x: cx - w / 2 + 8, y: cy - 8, width: 25, height: 36), 0.62),
                (CGRect(x: cx + w / 2 - 33, y: cy - 8, width: 25, height: 36), 0.62),
                (CGRect(x: cx - 22, y: cy - 10, width: 44, height: 30), 0.78),
                (CGRect(x: cx - 18, y: cy + h / 2 - 38, width: 36, height: 25), 0.45),
            ]
            for (rect, activation) in regions {
                context.fill(Path(ellipseIn: rect), with: .color(AppColors.accentLight.opacity(0.15 + activation * 0.55)))
            }
        }
    }

    // MARK: - AI Feedback

    private var sessionSummaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\u{1F4DD} Session Summary")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
            bulletPoint("Studied \(duration >= 60 ? "\(duration / 60)h" : "\(duration)min") at \(building.abbreviation) with avg focus of \(focusScore).")
            bulletPoint("Focus dipped around 45min — common with task-switching fatigue.")
            bulletPoint("Strongest focus between 60-80 min during deep work.")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    private var improvementTipsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\u{1F4A1} Improvement Tips")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
            bulletPoint("Try Pomodoro — 25 min focus + 5 min break.")
            bulletPoint("Take a 2-min mental reset when switching tasks.")
            bulletPoint("Minimize phone notifications during high-focus periods.")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Circle().fill(AppColors.accent).frame(width: 3, height: 3).padding(.top, 5)
            Text(text).font(.system(size: 10)).foregroundStyle(AppColors.textSecondary).lineSpacing(1)
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button { onNavigate(.start) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "play.fill").font(.system(size: 11))
                    Text("Start Another").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton))
            }
            .buttonStyle(.plain)

            Button { onNavigate(.building(id: buildingId)) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "building.2").font(.system(size: 11))
                    Text("View Territory").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusButton).stroke(AppColors.accent, lineWidth: 1.5))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}
