import Foundation

@Observable
@MainActor
class SessionViewModel {
    var isActive = false
    var remainingSeconds: Int = 0
    var focusScore: Int = 0
    var scores = FocusScoreData(gaze: 0, posture: 0, blink: 0, keyMouse: 0, tabs: 0, checkIn: 0)
    var buildingId: String = ""
    var duration: Int = 0

    var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var buildingScore: Int {
        FocusScoreData.buildingScore(focusScore: focusScore, durationMinutes: duration, daysStudiedThisWeek: 5)
    }

    func startSession(duration: Int, buildingId: String) {
        self.duration = duration
        self.buildingId = buildingId
        self.remainingSeconds = duration * 60
        self.isActive = true
        self.focusScore = 85
    }

    func endSession() {
        isActive = false
    }
}
