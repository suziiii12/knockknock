import Foundation

/// Singleton store that passes session result data from SessionView → ResultView.
/// SessionView populates this after analysis; ResultView reads it for display.
/// When the user exits ResultView, `submitToBackend()` posts /sessions/end.
@Observable
@MainActor
final class SessionResultStore {
    static let shared = SessionResultStore()
    private init() {}

    // Display data
    var summary: SessionSummary?
    var claudeFeedback: String = ""
    var isFetchingFeedback: Bool = false
    var finalScore: Double = 0

    // Engagement data to send to backend on exit
    var engagementScores: [Double]?
    var avgEngagement: Double?
    var studyPct: Double?
    var distractionCount: Int?

    // Track if already submitted
    private(set) var hasSubmitted: Bool = false

    func clear() {
        summary = nil
        claudeFeedback = ""
        isFetchingFeedback = false
        finalScore = 0
        engagementScores = nil
        avgEngagement = nil
        studyPct = nil
        distractionCount = nil
        hasSubmitted = false
    }

    /// Called when user exits ResultView — sends engagement data to backend via POST /sessions/end.
    /// Updates weekly_score, building_score, territory on the server.
    func submitToBackend() {
        guard !hasSubmitted else {
            print("[ResultStore] Already submitted — skipping")
            return
        }
        hasSubmitted = true

        Task {
            do {
                let serverScore = try await APIService.shared.endSession(
                    engagementScores: engagementScores,
                    avgEngagement: avgEngagement,
                    studyPct: studyPct,
                    distractionCount: distractionCount
                )
                finalScore = serverScore
                print("[ResultStore] POST /sessions/end success — final_score=\(serverScore)")
                NotificationCenter.default.post(name: .sessionDidEnd, object: nil)
            } catch {
                print("[ResultStore] POST /sessions/end error: \(error.localizedDescription)")
            }
        }
    }
}
