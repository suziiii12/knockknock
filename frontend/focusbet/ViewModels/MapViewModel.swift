import Foundation

@Observable
@MainActor
class MapViewModel {
    var buildings:          [Building] = MockData.buildings
    var selectedBuildingId: String?
    var hoveredBuildingId:  String?
    var isLoading = false

    func selectBuilding(_ id: String) {
        selectedBuildingId = id
    }

    /// Refreshes the building list from the backend.
    /// Falls back to the already-loaded MockData on failure.
    func load() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let fetched = try await APIService.shared.fetchBuildings()
                buildings = fetched
            } catch {
                // Backend unavailable — keep existing MockData buildings
                print("[MapViewModel] fetchBuildings error: \(error.localizedDescription)")
            }
        }
    }
}
