import Foundation

@Observable
@MainActor
class SessionViewModel {
    var isActive = false
    var remainingSeconds: Int = 0
    var scores = FocusScoreData(screenCapture: 0, motionDetection: 0)
    var buildingId: String = ""
    var duration: Int = 0

    var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var sessionScore: Int {
        FocusScoreData.sessionScore(focusLevel: scores.focusLevel, durationMinutes: duration)
    }

    func startSession(duration: Int, buildingId: String) {
        self.duration = duration
        self.buildingId = buildingId
        self.remainingSeconds = duration * 60
        self.isActive = true
        self.scores = FocusScoreData(screenCapture: 85, motionDetection: 85)
    }

    func endSession() {
        isActive = false
    }
}
