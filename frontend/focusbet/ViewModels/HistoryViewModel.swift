import Foundation

@Observable
@MainActor
class HistoryViewModel {
    var sessions: [StudySession] = MockData.sessionHistory

    var totalSessions: Int { sessions.count }
    var avgScore: Int {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.focusScore).reduce(0, +) / sessions.count
    }
    var totalHours: Double {
        Double(sessions.map(\.duration).reduce(0, +)) / 60.0
    }
}
