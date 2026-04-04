import Foundation

actor APIService {
    static let shared = APIService()
    private let baseURL = "https://api.focusbet.app/v1"

    func fetchBuildings() async throws -> [Building] {
        // Will connect to FastAPI backend later
        return MockData.buildings
    }

    func fetchTerritory(buildingId: String) async throws -> [TerritoryEntry] {
        // Will connect to FastAPI backend later
        return MockData.walcTerritory
    }

    func submitSession(_ session: StudySession) async throws {
        // Will connect to FastAPI backend later
    }

    func fetchUserProfile(userId: String) async throws -> User {
        // Will connect to FastAPI backend later
        return MockData.currentUser
    }
}
