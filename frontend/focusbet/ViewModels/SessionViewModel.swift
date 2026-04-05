import Foundation

@Observable
@MainActor
class SessionViewModel {
    var isActive         = false
    var remainingSeconds = 0
    var scores           = FocusScoreData(screenCapture: 0, motionDetection: 0)
    var buildingId       = ""
    var duration         = 0

    private(set) var sessionId: Int?

    private var focusPostingTask: Task<Void, Never>?
    private var screenCaptureService: ScreenCaptureService?
    private var focusTrackingService: FocusTrackingService?

    // MARK: - Computed

    var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var focusScore: Int { scores.focusLevel }

    var sessionScore: Int {
        FocusScoreData.sessionScore(focusLevel: scores.focusLevel, durationMinutes: duration)
    }

    // MARK: - Session lifecycle

    func startSession(
        duration: Int,
        buildingId: String,
        focusTracking: FocusTrackingService,
        screenCapture: ScreenCaptureService
    ) {
        self.duration             = duration
        self.buildingId           = buildingId
        self.remainingSeconds     = duration * 60
        self.isActive             = true
        self.scores               = FocusScoreData(screenCapture: 85, motionDetection: 85)
        self.focusTrackingService = focusTracking
        self.screenCaptureService = screenCapture

        Task {
            await PermissionService.shared.requestAllPermissions()
            screenCapture.startMonitoring(focusTrackingService: focusTracking)
            focusTracking.startTracking()
        }

        Task {
            do {
                let sid = try await APIService.shared.startSoloSession(
                    durationMinutes: duration,
                    buildingSlug: buildingId
                )
                sessionId = sid
                startPeriodicFocusPosting()
                print("[SessionViewModel] Session started: id=\(sid)")
            } catch {
                print("[SessionViewModel] startSoloSession error: \(error.localizedDescription)")
            }
        }
    }

    func endSession() {
        isActive = false
        focusPostingTask?.cancel()
        focusPostingTask = nil
        screenCaptureService?.stopMonitoring()
        focusTrackingService?.stopTracking()
        screenCaptureService = nil
        focusTrackingService = nil

        guard let sid = sessionId else { return }
        Task {
            await postFocusLevel(sessionId: sid)
            do {
                let finalScore = try await APIService.shared.endSession()
                print("[SessionViewModel] Session \(sid) ended — final score: \(finalScore)")
                NotificationCenter.default.post(name: .sessionDidEnd, object: nil)
            } catch {
                print("[SessionViewModel] endSession error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Score updates (called by SessionView timer)

    func updateScores(from data: FocusScoreData) {
        scores = data
    }

    // MARK: - Check-in

    func postCheckInSnapshot() {
        guard let sid = sessionId else { return }
        Task { await postFocusLevel(sessionId: sid) }
    }

    // MARK: - Private

    private func startPeriodicFocusPosting() {
        focusPostingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled, let sid = self.sessionId else { break }
                await self.postFocusLevel(sessionId: sid)
            }
        }
    }

    private func postFocusLevel(sessionId: Int) async {
        let level = Double(scores.focusLevel) / 100.0
        do {
            try await APIService.shared.postFocusLevel(sessionId: sessionId, level: level)
        } catch {
            print("[SessionViewModel] postFocusLevel error: \(error.localizedDescription)")
        }
    }
}
