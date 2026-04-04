import Foundation

@Observable
@MainActor
class HistoryViewModel {
    var sessions: [StudySession] = []
    var isLoading = false
    var errorMessage: String?

    var totalSessions: Int { sessions.count }
    var avgScore: Int {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.focusScore).reduce(0, +) / sessions.count
    }
    var totalHours: Double { Double(sessions.map(\.duration).reduce(0, +)) / 60.0 }

    func loadHistory() async {
        isLoading = true
        errorMessage = nil
        do {
            sessions = try await APIService.shared.fetchSessionHistory()
        } catch {
            errorMessage = error.localizedDescription
            if sessions.isEmpty {
                sessions = MockData.sessionHistory
            }
        }
        isLoading = false
    }
}
