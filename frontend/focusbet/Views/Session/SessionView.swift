import SwiftUI

struct SessionView: View {
    let duration: Int
    let buildingId: String
    let onNavigate: (Route) -> Void

    @State private var vm            = SessionViewModel()
    @State private var focusTracking = FocusTrackingService()
    @State private var screenCapture = ScreenCaptureService()
    @State private var cameraService = CameraService()
    @State private var recordingPulse = false

    @State private var remainingSeconds: Int
    @State private var showCheckIn = false
    @State private var countdownTimer: Timer?
    @State private var scoreTimer: Timer?
    @State private var checkInTimer: Timer?

    init(duration: Int, buildingId: String, onNavigate: @escaping (Route) -> Void) {
        self.duration   = duration
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

    private var totalSeconds: Int { duration == 1 ? 30 : duration * 60 }

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
                            .fill(vm.sessionId != nil ? AppColors.accent : AppColors.warning)
                            .frame(width: 6, height: 6)
                        Text(vm.sessionId != nil ? "Tracking active" : "Connecting...")
                            .font(AppFonts.small)
                            .foregroundStyle(vm.sessionId != nil ? AppColors.accent : AppColors.warning)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((vm.sessionId != nil ? AppColors.accent : AppColors.warning).opacity(0.1))
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

                // Check-in modal
                if showCheckIn {
                    CheckInModalView(
                        sessionId: vm.sessionId,
                        onDismiss: { passed in
                            withAnimation { showCheckIn = false }
                            if passed { vm.postCheckInSnapshot() }
                        }
                    )
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
                    FocusGaugeView(score: vm.focusScore)

                    SignalBarsView(scores: vm.scores)

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
                            Text("Session ID")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textMuted)
                            Spacer()
                            Text(vm.sessionId.map { "#\($0)" } ?? "—")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.accent)
                        }
                        HStack {
                            Text("Session Score")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textMuted)
                            Spacer()
                            Text("\(FocusScoreData.sessionScore(focusLevel: vm.focusScore, durationMinutes: (totalSeconds - remainingSeconds) / 60))pts")
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

    // MARK: - Session control

    private func startSession() {
        cameraService.configure()
        cameraService.start()

        vm.startSession(
            duration: duration,
            buildingId: buildingId,
            focusTracking: focusTracking,
            screenCapture: screenCapture
        )

        // Countdown
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                stopSession()
                onNavigate(.result(focusScore: vm.focusScore, buildingId: buildingId, duration: duration))
            }
        }

        // Read signals from FocusTrackingService every 5s
        scoreTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            withAnimation {
                vm.updateScores(from: focusTracking.currentScores)
            }
        }

        // Check-in every 5 minutes
        checkInTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            withAnimation { showCheckIn = true }
        }
    }

    private func stopSession() {
        countdownTimer?.invalidate()
        scoreTimer?.invalidate()
        checkInTimer?.invalidate()
        countdownTimer = nil
        scoreTimer     = nil
        checkInTimer   = nil
        cameraService.stop()
        vm.endSession()
    }
}
