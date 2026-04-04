import Foundation

@Observable
@MainActor
class ProfileViewModel {
    var user: User = MockData.currentUser
    var kingBuildings: [Building] {
        MockData.buildings.filter { user.kingBuildings.contains($0.id) }
    }
}
