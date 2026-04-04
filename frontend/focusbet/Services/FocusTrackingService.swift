import Foundation

/// Generates focus scores. Simulation-based until the AI team integrates the
/// Vision framework pipeline. ScreenCaptureService drives the real `tabs` score;
/// all other signals use random simulation within realistic ranges.
@Observable
final class FocusTrackingService {
    var currentScores = FocusScoreData(
        gaze: 0, posture: 0, blink: 0, keyMouse: 0, tabs: 0, checkIn: 0
    )
    var isTracking = false

    private var simulationTask: Task<Void, Never>?

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        startSimulation()
    }

    func stopTracking() {
        isTracking = false
        simulationTask?.cancel()
        simulationTask = nil
    }

    // External write: ScreenCaptureService updates tabs directly
    func updateTabScore(_ score: Int) {
        currentScores.tabs = score
    }

    private func startSimulation() {
        simulationTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.isTracking {
                // TODO (AI team): replace gaze + posture with Vision framework results
                let gaze     = Int.random(in: 75...96)
                let posture  = Int.random(in: 70...92)
                let blink    = Int.random(in: 72...94)
                let keyMouse = Int.random(in: 68...90)
                let checkIn  = self.currentScores.checkIn  // preserved from check-in events
                let tabs     = self.currentScores.tabs     // driven by ScreenCaptureService

                await MainActor.run {
                    self.currentScores = FocusScoreData(
                        gaze:     gaze,
                        posture:  posture,
                        blink:    blink,
                        keyMouse: keyMouse,
                        tabs:     tabs,
                        checkIn:  checkIn
                    )
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
