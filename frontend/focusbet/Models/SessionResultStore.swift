import Foundation

/// Singleton store that passes session result data from SessionView → ResultView.
/// SessionView populates this before navigating; ResultView reads it on appear.
@Observable
@MainActor
final class SessionResultStore {
    static let shared = SessionResultStore()
    private init() {}

    var summary: SessionSummary?
    var claudeFeedback: String = ""
    var isFetchingFeedback: Bool = false
    var finalScore: Double = 0

    func clear() {
        summary = nil
        claudeFeedback = ""
        isFetchingFeedback = false
        finalScore = 0
    }
}
