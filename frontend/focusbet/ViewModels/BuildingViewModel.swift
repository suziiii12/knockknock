import Foundation

@Observable
@MainActor
class BuildingViewModel {
    var building:     Building?
    var territory:    [TerritoryEntry] = []
    var activityFeed: [ActivityFeedItem] = []
    var isLoading = false
    var errorMessage: String?

    func load(buildingId: String) {
        // Resolve building from MockData immediately so the UI renders
        building     = MockData.buildings.first { $0.id == buildingId }
        activityFeed = MockData.activityFeed

        isLoading    = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let entries = try await APIService.shared.fetchTerritory(buildingId: buildingId)
                territory = entries
            } catch {
                // Backend unavailable or building not yet in backend — use mock
                territory = buildingId == "walc" ? MockData.walcTerritory : []
                if case APIError.unauthorized = error {
                    errorMessage = error.localizedDescription
                }
                // For other errors (network, notFound) we silently fall back to mock
            }
        }
    }
}
