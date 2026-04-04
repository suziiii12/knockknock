import Foundation

@Observable
@MainActor
class MapViewModel {
    var buildings: [Building] = MockData.buildings
    var selectedBuildingId: String?
    var hoveredBuildingId: String?

    func selectBuilding(_ id: String) {
        selectedBuildingId = id
    }
}
