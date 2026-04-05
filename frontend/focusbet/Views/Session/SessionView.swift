import SwiftUI

struct SessionView: View {
    let duration: Int
    let buildingId: String
    let onNavigate: (Route) -> Void

    @State private var remainingSeconds: Int
    @State private var scores = FocusScoreData(screenCapture: 85, motionDetection: 85)

    private var focusScore: Int { scores.focusLevel }
    private var totalSeconds: Int { duration == 1 ? 30 : duration * 60 }
    @State private var showCheckIn = false
    @State private var timer: Timer?
    @State private var scoreTimer: Timer?
    @State private var checkInTimer: Timer?
    @State private var cameraService = CameraService()
    @State private var recordingPulse = false

    init(duration: Int, buildingId: String, onNavigate: @escaping (Route) -> Void) {
        self.duration = duration
        self.buildingId = buildingId
        self.onNavigate = onNavigate
        _remainingSeconds = State(initialValue: duration == 1 ? 30 : duration * 60)
    }

    private var building: Building {
        MockData.buildings.first { $0.id == buildingId } ?? MockData.buildings[0]
    }

    private var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var body: some View {
        HStack(spacing: 0) {
            // LEFT: Camera (70%)
            ZStack(alignment: .topLeading) {
                CameraPreview(session: cameraService.captureSession)
                    .clipShape(RoundedRectangle(cornerRadius: AppDimensions.cornerRadiusCard))
                    .padding(24)

                // Status badges
                HStack(spacing: 8) {
                    // Tracking badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 6, height: 6)
                        Text("Tracking active")
                            .font(AppFonts.small)
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Screen recording badge
                    HStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.4))
                                .frame(width: 12, height: 12)
                                .scaleEffect(recordingPulse ? 1.0 : 0.5)
                                .opacity(recordingPulse ? 0.0 : 0.6)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: recordingPulse)
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                        Text("Screen is being recorded")
                            .font(AppFonts.small)
                            .foregroundStyle(Color.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.leading, 36)
                .padding(.top, 36)
                .onAppear { recordingPulse = true }

                // Simulated gaze dots
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(AppColors.accent.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .position(
                            x: CGFloat.random(in: 200...500),
                            y: CGFloat.random(in: 150...350)
                        )
                }

                // Check-in modal
                if showCheckIn {
                    CheckInModalView(onDismiss: {
                        withAnimation { showCheckIn = false }
                    })
                    .transition(.move(edge: .bottom))
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.bgPrimary)

            // Divider
            AppColors.border.frame(width: 1)

            // RIGHT: Stats (30%)
            ScrollView {
                VStack(spacing: 24) {
                    // Focus gauge
                    FocusGaugeView(score: focusScore)

                    // Signal bars
                    SignalBarsView(
                        scores: scores,
                        elapsedSeconds: totalSeconds - remainingSeconds,
                        totalSeconds: totalSeconds
                    )

                    // Timer
                    VStack(spacing: 4) {
                        Text("Time Remaining")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.textMuted)
                        Text(timeString)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    // Building info
                    VStack(spacing: 8) {
                        HStack {
                            Text("Building")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textMuted)
                            Spacer()
                            Text(building.abbreviation)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        HStack {
                            Text("Current Rank")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textMuted)
                            Spacer()
                            Text("#3")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.accent)
                        }
                        HStack {
                            Text("Session Score")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textMuted)
                            Spacer()
                            Text("\(FocusScoreData.sessionScore(focusLevel: focusScore, durationMinutes: (totalSeconds - remainingSeconds) / 60))pts")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                    .padding(16)
                    .background(AppColors.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(24)
            }
            .frame(width: 300)
            .background(AppColors.bgSecondary)
        }
        .background(AppColors.bgPrimary)
        .toolbar(.hidden, for: .automatic)
        .onAppear { startSession() }
        .onDisappear { stopSession() }
    }

    private func startSession() {
        cameraService.configure()
        cameraService.start()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                stopSession()
                onNavigate(.result(focusScore: focusScore, buildingId: buildingId, duration: duration))
            }
        }

        scoreTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            withAnimation {
                scores.screenCapture = Int.random(in: 75...95)
                scores.motionDetection = Int.random(in: 70...92)
            }
        }

        checkInTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            withAnimation { showCheckIn = true }
        }
    }

    private func stopSession() {
        timer?.invalidate()
        scoreTimer?.invalidate()
        checkInTimer?.invalidate()
        cameraService.stop()
    }
}
