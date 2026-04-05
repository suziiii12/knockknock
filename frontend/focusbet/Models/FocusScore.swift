import Foundation

struct FocusScoreData: Sendable {
    var screenCapture: Int    // 0-100  TRIBEv2 cognitive demand (40% of focus)
    var motionDetection: Int  // 0-100  webcam gaze/posture/blink (40% of focus)

    /// Combined focus level: average of screen capture and motion detection
    var focusLevel: Int {
        (screenCapture + motionDetection) / 2
    }

    /// Session Score = Focus (80%) + Duration (20%)
    static func sessionScore(focusLevel: Int, durationMinutes: Int) -> Int {
        let focus    = Double(focusLevel) * 0.8
        let duration = min(Double(durationMinutes) / 240.0 * 100.0, 100.0) * 0.2
        return Int(focus + duration)
    }
}
