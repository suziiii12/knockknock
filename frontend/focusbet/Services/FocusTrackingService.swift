import Foundation

@Observable
class FocusTrackingService {
    var currentScores = FocusScoreData(screenCapture: 0, motionDetection: 0)
    var isTracking = false

    func startTracking() {
        isTracking = true
        // Real tracking via Vision + ScreenCaptureKit will be integrated later
        simulateScores()
    }

    func stopTracking() {
        isTracking = false
    }

    private func simulateScores() {
        guard isTracking else { return }
        currentScores = FocusScoreData(
            screenCapture:   Int.random(in: 75...95),  // TRIBEv2 cognitive demand
            motionDetection: Int.random(in: 70...92)   // webcam gaze/posture/blink
        )
    }
}
