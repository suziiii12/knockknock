import Foundation

@Observable
@MainActor
class SessionViewModel {
    var isActive         = false
    var remainingSeconds: Int = 0
    var focusScore:      Int = 0
    var scores           = FocusScoreData(gaze: 0, posture: 0, blink: 0, keyMouse: 0, tabs: 0, checkIn: 0)
    var buildingId:      String = ""
    var duration:        Int = 0

    // Set this before calling startSession() to enable real backend session tracking.
    // When nil the session runs locally with simulated scores only.
    var challengeId: Int?

    // Backend-assigned session ID; populated after a successful startSession API call.
    private(set) var sessionId: Int?

    private var scorePostingTask: Task<Void, Never>?
    private var screenCaptureService: ScreenCaptureService?
    private var focusTrackingService: FocusTrackingService?

    // MARK: - Computed

    var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var buildingScore: Int {
        FocusScoreData.buildingScore(
            focusScore: focusScore,
            durationMinutes: duration,
            daysStudiedThisWeek: 5
        )
    }

    // MARK: - Session lifecycle

    func startSession(
        duration: Int,
        buildingId: String,
        focusTracking: FocusTrackingService,
        screenCapture: ScreenCaptureService
    ) {
        self.duration         = duration
        self.buildingId       = buildingId
        self.remainingSeconds = duration * 60
        self.isActive         = true
        self.focusScore       = 85
        self.focusTrackingService = focusTracking
        self.screenCaptureService = screenCapture

        // Request all permissions, then start monitoring.
        Task {
            await PermissionService.shared.requestAllPermissions()
            screenCapture.startMonitoring(focusTrackingService: focusTracking)
        }

        // If a challenge is linked, start a backend session and begin score posting.
        if let cid = challengeId {
            Task {
                do {
                    let result = try await APIService.shared.startSession(challengeId: cid)
                    self.sessionId = result.sessionId
                    startPeriodicScorePosting()
                } catch {
                    // Backend unavailable — session continues locally
                    print("[SessionViewModel] startSession API error: \(error.localizedDescription)")
                }
            }
        }
    }

    func endSession() {
        isActive = false
        scorePostingTask?.cancel()
        scorePostingTask = nil
        screenCaptureService?.stopMonitoring()
        screenCaptureService  = nil
        focusTrackingService  = nil

        guard let sid = sessionId else { return }
        Task {
            do {
                let finalScore = try await APIService.shared.endSession()
                print("[SessionViewModel] Session \(sid) ended — final score: \(finalScore)")
            } catch {
                print("[SessionViewModel] endSession API error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Composite score

    /// Weighted composite: 50% gaze (AI team), 30% tab activity, 20% check-in.
    func updateCompositeScore(from data: FocusScoreData) {
        let composite = Int(
            0.5 * Double(data.gaze)    +
            0.3 * Double(data.tabs)    +
            0.2 * Double(data.checkIn)
        )
        scores     = data
        focusScore = min(100, max(0, composite))
    }

    // MARK: - Score posting

    /// Submits the current focus scores to the backend every 30 seconds.
    private func startPeriodicScorePosting() {
        scorePostingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled, let sid = self.sessionId else { break }
                await self.postCurrentScore(sessionId: sid)
            }
        }
    }

    private func postCurrentScore(sessionId: Int) async {
        do {
            try await APIService.shared.postScore(
                sessionId:    sessionId,
                gazeScore:    Double(scores.gaze),
                tabScore:     Double(scores.tabs),
                checkinScore: Double(scores.checkIn)
            )
        } catch {
            print("[SessionViewModel] postScore error: \(error.localizedDescription)")
        }
    }

    /// Call this after a check-in is answered to post an immediate score snapshot.
    func postCheckInScore() {
        guard let sid = sessionId else { return }
        Task { await postCurrentScore(sessionId: sid) }
    }
}
