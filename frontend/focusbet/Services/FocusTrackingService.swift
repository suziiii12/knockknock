import Foundation

/// Generates focus scores. Simulation-based until the AI team integrates the
/// Vision framework pipeline. ScreenCaptureService drives the real `tabs` score;
/// all other signals use random simulation within realistic ranges.
@Observable
final class FocusTrackingService {
    var currentScores = FocusScoreData(screenCapture: 0, motionDetection: 0)
    var isTracking = false

    private var simulationTask: Task<Void, Never>?

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        // Real tracking via Vision + ScreenCaptureKit will be integrated later
        simulateScores()
    }

    func stopTracking() {
        isTracking = false
        simulationTask?.cancel()
        simulationTask = nil
    }

    private func simulateScores() {
        guard isTracking else { return }
        currentScores = FocusScoreData(
            screenCapture:   Int.random(in: 75...95),  // TRIBEv2 cognitive demand
            motionDetection: Int.random(in: 70...92)   // webcam gaze/posture/blink
        )
    }
}
