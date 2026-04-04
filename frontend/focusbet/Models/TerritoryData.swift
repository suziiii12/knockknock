import Foundation

struct TerritoryEntry: Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    let userName: String
    let userInitials: String
    let colorIndex: Int
    let score: Int
    let ownershipPercent: Double
    let isStudying: Bool
    let rank: Int
}

struct ActivityFeedItem: Identifiable, Sendable {
    let id: String
    let message: String
    let timestamp: Date
    let type: ActivityType

    enum ActivityType: Sendable {
        case sessionComplete
        case studying
        case overtake
        case kingTakeover
    }
}
