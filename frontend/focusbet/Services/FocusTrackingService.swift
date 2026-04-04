import Foundation

@Observable
class FocusTrackingService {
    var currentScores = FocusScoreData(gaze: 0, posture: 0, blink: 0, keyMouse: 0, tabs: 0, checkIn: 0)
    var isTracking = false

    func startTracking() {
        isTracking = true
        // Real tracking via Vision framework will be integrated later
        // For now, simulate with random scores
        simulateScores()
    }

    func stopTracking() {
        isTracking = false
    }

    private func simulateScores() {
        guard isTracking else { return }
        currentScores = FocusScoreData(
            gaze: Int.random(in: 75...96),
            posture: Int.random(in: 70...92),
            blink: Int.random(in: 72...94),
            keyMouse: Int.random(in: 68...90),
            tabs: Int.random(in: 65...88),
            checkIn: Int.random(in: 80...100)
        )
    }
}
