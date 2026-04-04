import Foundation

@Observable
class MockDataService {
    static let shared = MockDataService()

    var buildings: [Building] = MockData.buildings
    var currentUser: User = MockData.currentUser
    var sessionHistory: [StudySession] = MockData.sessionHistory
    var walcTerritory: [TerritoryEntry] = MockData.walcTerritory
    var activityFeed: [ActivityFeedItem] = MockData.activityFeed

    func building(id: String) -> Building? {
        buildings.first { $0.id == id }
    }

    func territory(for buildingId: String) -> [TerritoryEntry] {
        // All buildings use WALC territory data for now
        walcTerritory
    }
}
