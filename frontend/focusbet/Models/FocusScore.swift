import Foundation

struct FocusScoreData: Sendable {
    var gaze: Int
    var posture: Int
    var blink: Int
    var keyMouse: Int
    var tabs: Int
    var checkIn: Int

    var overall: Int {
        let total = gaze + posture + blink + keyMouse + tabs + checkIn
        return total / 6
    }

    static func buildingScore(focusScore: Int, durationMinutes: Int, daysStudiedThisWeek: Int) -> Int {
        let focus = Double(focusScore) * 0.5
        let time = min(Double(durationMinutes) / 240.0 * 100.0, 100.0) * 0.3
        let consistency = (Double(daysStudiedThisWeek) / 7.0) * 100.0 * 0.2
        return Int(focus + time + consistency)
    }
}
