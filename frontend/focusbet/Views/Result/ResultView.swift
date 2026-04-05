import SwiftUI
import AVFoundation
import AVKit

struct ResultView: View {
    let focusScore: Int
    let buildingId: String
    let duration: Int
    let onNavigate: (Route) -> Void

    private var resultStore: SessionResultStore { SessionResultStore.shared }

    private var building: Building {
        MockData.buildings.first { $0.id == buildingId } ?? MockData.buildings[0]
    }

    var body: some View {
        Group {
            if let summary = resultStore.summary {
                reportContent(summary: summary)
            } else {
                loadingView
            }
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Finishing analysis...")
                .font(.headline).foregroundStyle(AppColors.textSecondary)
            Text("Waiting for clip analysis and server response...")
                .font(.caption).foregroundStyle(AppColors.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Report Content

    @ViewBuilder
    private func reportContent(summary: SessionSummary) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                // ROW 1 — Score + Stats
                scoreSummary(summary: summary)

                // ROW 2 — Stat boxes
                statBoxes(summary: summary)

                // ROW 3 — Focus Timeline + Encoding Breakdown
                HStack(alignment: .top, spacing: 12) {
                    focusTimeline(summary: summary)
                    encodingBreakdown(summary: summary)
                }

                // ROW 4 — Brain Activity
                if !summary.clips.isEmpty {
                    brainMapsSection(summary: summary)
                }

                // ROW 5 — Claude Feedback
                claudeFeedbackSection

                // ROW 6 — Clip Detail List
                if !summary.clips.isEmpty {
                    clipDetailList(summary: summary)
                }

                // ROW 7 — Buttons
                actionButtons
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Score Summary

    private func scoreSummary(summary: SessionSummary) -> some View {
        HStack(spacing: 36) {
            FocusGaugeView(score: Int(resultStore.finalScore > 0 ? resultStore.finalScore : summary.averageFocus))
                .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 10) {
                Text("Session Report")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppColors.accent)

                Text(String(format: "%.0f min \u{2022} %d clips \u{2022} %@",
                            summary.durationMinutes,
                            summary.clips.count,
                            building.abbreviation))
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Final Score")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textMuted)
                        Text(String(format: "+%.0f pts", resultStore.finalScore > 0 ? resultStore.finalScore : summary.sessionScore))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.accent)
                    }
                    if let peakTime = summary.peakFocusTime {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Peak Focus")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textMuted)
                            Text(peakTime)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                    if let distractTime = summary.firstDistractionTime {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("First Distraction")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textMuted)
                            Text(distractTime)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Stat Boxes

    private func statBoxes(summary: SessionSummary) -> some View {
        HStack(spacing: 10) {
            ResultStatBox(title: "Session Score",
                          value: String(format: "%.1f", resultStore.finalScore > 0 ? resultStore.finalScore : summary.sessionScore),
                          color: .green)
            ResultStatBox(title: "Engagement",
                          value: String(Int(summary.averageEngagement)),
                          color: .blue)
            ResultStatBox(title: "Study Time",
                          value: String(format: "%.0f%%", summary.studyingFraction * 100),
                          color: .teal)
            ResultStatBox(title: "Distractions",
                          value: String(summary.distractionCount),
                          color: .red)
            ResultStatBox(title: "Focus Streak",
                          value: "\(summary.longestFocusStreak) clips",
                          color: .orange)
        }
    }

    // MARK: - Focus Timeline

    private func focusTimeline(summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus Timeline")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            if summary.clips.isEmpty {
                Text("No clips recorded")
                    .font(.caption).foregroundStyle(AppColors.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                FocusScoreGraphView(clips: summary.clips)
                    .frame(maxWidth: .infinity, minHeight: 160)
            }

            HStack(spacing: 14) {
                zoneLegend(.green, "Deep")
                zoneLegend(.blue, "Shallow")
                zoneLegend(.orange, "Overload")
                zoneLegend(.red, "Distracted")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    private func zoneLegend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9)).foregroundStyle(AppColors.textMuted)
        }
    }

    private func regionLabel(_ name: String, detail: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.2 + value * 0.8))
                .frame(width: 4, height: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(detail) \u{2022} \(Int(value * 100))%")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.textMuted)
            }
        }
    }

    // MARK: - Encoding Breakdown

    private func encodingBreakdown(summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Encoding Breakdown")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 8) {
                ForEach([EncodingType.deep, .shallow, .overload, .distracted], id: \.rawValue) { type in
                    let count = summary.encodingBreakdown[type] ?? 0
                    HStack(spacing: 8) {
                        Text(type.emoji).font(.title3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(type.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("\(count) clip\(count == 1 ? "" : "s")")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(type.color)
                    }
                    .padding(8)
                    .background(type.color.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .frame(width: 220)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Brain Activity

    private func brainMapsSection(summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Brain Activity Analysis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("TRIBEv2")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.textMuted)
            }

            // Aggregate brain region averages across all clips
            let avgPfc = summary.clips.isEmpty ? 0 : summary.clips.map(\.pfc).reduce(0, +) / Double(summary.clips.count)
            let avgDmn = summary.clips.isEmpty ? 0 : summary.clips.map(\.dmn).reduce(0, +) / Double(summary.clips.count)
            let avgLang = summary.clips.isEmpty ? 0 : summary.clips.map(\.lang).reduce(0, +) / Double(summary.clips.count)

            HStack(spacing: 20) {
                // Region bars
                HStack(spacing: 12) {
                    RegionBarView(label: "PFC", value: avgPfc, color: .blue)
                    RegionBarView(label: "DMN", value: avgDmn, color: .purple)
                    RegionBarView(label: "Lang", value: avgLang, color: .teal)
                }
                .frame(height: 100)

                // Region descriptions
                VStack(alignment: .leading, spacing: 6) {
                    regionLabel("Prefrontal Cortex", detail: "Planning & Focus", value: avgPfc, color: .blue)
                    regionLabel("Default Mode", detail: "Mind-wandering", value: avgDmn, color: .purple)
                    regionLabel("Language", detail: "Processing", value: avgLang, color: .teal)
                }
            }

            // Brain map cards for peak/lowest/distraction if available
            if summary.peakClip != nil || summary.lowestStudyClip != nil || summary.distractionClip != nil {
                Divider()
                HStack(alignment: .top, spacing: 16) {
                    if let clip = summary.peakClip {
                        BrainMapCardView(title: "Peak Focus", clip: clip, color: .green)
                    }
                    if let clip = summary.lowestStudyClip {
                        BrainMapCardView(title: "Lowest Study", clip: clip, color: .orange)
                    }
                    if let clip = summary.distractionClip {
                        BrainMapCardView(title: "Distraction", clip: clip, color: .red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Claude Feedback

    private var claudeFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Claude Feedback")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if resultStore.isFetchingFeedback {
                    ProgressView().scaleEffect(0.6)
                    Text("Generating...").font(.system(size: 10)).foregroundStyle(AppColors.textMuted)
                }
            }

            if resultStore.claudeFeedback.isEmpty && !resultStore.isFetchingFeedback {
                Text("No feedback available")
                    .font(.system(size: 11)).foregroundStyle(AppColors.textMuted)
            } else if !resultStore.claudeFeedback.isEmpty {
                Text(resultStore.claudeFeedback)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(4)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.accentLight.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Clip Detail List

    private func clipDetailList(summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clip Details")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            ForEach(Array(summary.clips.enumerated()), id: \.offset) { i, clip in
                HStack(spacing: 8) {
                    Text("\(i + 1)")
                        .font(.system(size: 10)).foregroundStyle(AppColors.textMuted)
                        .frame(width: 18)
                    Circle()
                        .fill(clip.encodingType.color)
                        .frame(width: 8, height: 8)
                    Text("\(Int(clip.focusScore))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 24)
                    Text("\(clip.encodingType.emoji) \(clip.contentLabel)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if !clip.contentReason.isEmpty {
                        Text(clip.contentReason)
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.textMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(AppColors.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
        .shadow(color: AppColors.cardShadow, radius: 8, y: 2)
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

// MARK: - Focus Score Graph (real clip data)

struct FocusScoreGraphView: View {
    let clips: [ClipResult]

    private let padTop: CGFloat    = 16
    private let padBottom: CGFloat = 28
    private let padLeft: CGFloat   = 36
    private let padRight: CGFloat  = 12

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    private func xPos(_ i: Int, graphW: CGFloat) -> CGFloat {
        clips.count <= 1
            ? padLeft + graphW / 2
            : padLeft + CGFloat(i) / CGFloat(clips.count - 1) * graphW
    }

    private func yPos(_ score: Double, graphH: CGFloat) -> CGFloat {
        padTop + graphH * (1 - score / 100.0)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let graphW = w - padLeft - padRight
            let graphH = h - padTop - padBottom

            ZStack(alignment: .topLeading) {
                // Y gridlines
                ForEach([0, 25, 50, 75, 100], id: \.self) { val in
                    let y = yPos(Double(val), graphH: graphH)
                    Path { p in
                        p.move(to: CGPoint(x: padLeft, y: y))
                        p.addLine(to: CGPoint(x: w - padRight, y: y))
                    }
                    .stroke(AppColors.border.opacity(0.4), lineWidth: 0.5)
                    Text("\(val)")
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.textMuted)
                        .frame(width: 26, alignment: .trailing)
                        .position(x: padLeft - 6, y: y)
                }

                // Distraction shading
                ForEach(Array(clips.enumerated()), id: \.offset) { i, clip in
                    if clip.gate == 0 && clips.count > 1 {
                        Rectangle()
                            .fill(Color.red.opacity(0.06))
                            .frame(width: graphW / CGFloat(clips.count - 1), height: graphH)
                            .position(x: xPos(i, graphW: graphW), y: padTop + graphH / 2)
                    }
                }

                // Connecting line
                if clips.count > 1 {
                    Path { p in
                        for (i, clip) in clips.enumerated() {
                            let pt = CGPoint(x: xPos(i, graphW: graphW), y: yPos(clip.focusScore, graphH: graphH))
                            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                        }
                    }
                    .stroke(AppColors.accentLight.opacity(0.5), lineWidth: 1.5)
                }

                // Dots + labels
                ForEach(Array(clips.enumerated()), id: \.offset) { i, clip in
                    let x = xPos(i, graphW: graphW)
                    let y = yPos(clip.focusScore, graphH: graphH)
                    Circle()
                        .fill(clip.encodingType.color)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                    Text("\(Int(clip.focusScore))")
                        .font(.system(size: 8))
                        .foregroundStyle(AppColors.textMuted)
                        .position(x: x, y: y - 10)
                    Text(timeFormatter.string(from: clip.timestamp))
                        .font(.system(size: 8))
                        .foregroundStyle(AppColors.textMuted)
                        .frame(width: 32, alignment: .center)
                        .position(x: x, y: h - 8)
                }

                // Axes
                Path { p in
                    p.move(to: CGPoint(x: padLeft, y: padTop + graphH))
                    p.addLine(to: CGPoint(x: w - padRight, y: padTop + graphH))
                    p.move(to: CGPoint(x: padLeft, y: padTop))
                    p.addLine(to: CGPoint(x: padLeft, y: padTop + graphH))
                }
                .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Stat Box

struct ResultStatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Brain Map Card

struct BrainMapCardView: View {
    let title: String
    let clip: ClipResult
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)

            if let data = clip.brainMapData,
               let url = saveBrainVideo(data: data, name: title) {
                BrainVideoPlayerView(url: url)
                    .frame(width: 160, height: 160)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Fallback: show region bars
                HStack(spacing: 6) {
                    RegionBarView(label: "PFC", value: clip.pfc, color: .blue)
                    RegionBarView(label: "DMN", value: clip.dmn, color: .purple)
                    RegionBarView(label: "Lang", value: clip.lang, color: .teal)
                }
                .frame(width: 160, height: 100)
                .padding(8)
                .background(AppColors.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(String(format: "focus: %d \u{2022} %@", Int(clip.focusScore), clip.encodingType.rawValue))
                .font(.system(size: 9)).foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func saveBrainVideo(data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("report_brain_\(name.replacingOccurrences(of: " ", with: "_")).mp4")
        try? data.write(to: url)
        return url
    }
}

// MARK: - Region Bar

struct RegionBarView: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 9)).foregroundStyle(AppColors.textMuted)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(height: geo.size.height * max(0, min(1, value)))
                }
            }
            .frame(width: 16)
            Text(String(format: "%.1f", value))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(AppColors.textMuted)
        }
    }
}

// MARK: - Brain Video Player

struct BrainVideoPlayerView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.white.cgColor
        let player = AVPlayer(url: url)
        nsView.player = player
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
    }
}
