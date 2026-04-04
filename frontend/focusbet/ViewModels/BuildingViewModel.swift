import Foundation

@Observable
@MainActor
class BuildingViewModel {
    var building: Building?
    var territory: [TerritoryEntry] = []
    var activityFeed: [ActivityFeedItem] = []

    func load(buildingId: String) {
        building = MockData.buildings.first { $0.id == buildingId }
        territory = MockData.walcTerritory
        activityFeed = MockData.activityFeed
    }
}
