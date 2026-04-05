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
            let fetched = try await APIService.shared.fetchSessionHistory()
            print("[HistoryViewModel] fetched \(fetched.count) sessions")
            sessions = fetched
        } catch {
            print("[HistoryViewModel] fetchSessionHistory error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
