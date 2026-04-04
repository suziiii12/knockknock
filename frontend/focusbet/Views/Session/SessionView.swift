import SwiftUI

struct SessionView: View {
    let duration: Int
    let buildingId: String
    let onNavigate: (Route) -> Void

    @State private var remainingSeconds: Int
    @State private var focusScore: Int = 87
    @State private var scores = FocusScoreData(gaze: 91, posture: 85, blink: 88, keyMouse: 82, tabs: 79, checkIn: 95)
    @State private var showCheckIn = false
    @State private var timer: Timer?
    @State private var scoreTimer: Timer?
    @State private var checkInTimer: Timer?
    @State private var cameraService = CameraService()

    init(duration: Int, buildingId: String, onNavigate: @escaping (Route) -> Void) {
        self.duration = duration
        self.buildingId = buildingId
        self.onNavigate = onNavigate
        _remainingSeconds = State(initialValue: duration * 60)
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

                // Tracking badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Tracking active")
                        .font(AppFonts.small)
                        .foregroundStyle(Color.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.leading, 36)
                .padding(.top, 36)

                // Simulated gaze dots
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.green.opacity(0.7))
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
                    SignalBarsView(scores: scores)

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
                            Text("Consistency")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textMuted)
                            Spacer()
                            Text("5/7 days")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
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
                focusScore = Int.random(in: 80...95)
                scores.gaze = Int.random(in: 82...96)
                scores.posture = Int.random(in: 78...92)
                scores.blink = Int.random(in: 80...94)
                scores.keyMouse = Int.random(in: 72...90)
                scores.tabs = Int.random(in: 70...88)
                scores.checkIn = Int.random(in: 85...100)
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
