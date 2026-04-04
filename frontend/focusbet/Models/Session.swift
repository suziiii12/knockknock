import Foundation

struct StudySession: Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    let buildingId: String
    let buildingName: String
    let startTime: Date
    let duration: Int // minutes
    let focusScore: Int
    let buildingScore: Int
    let gazeScore: Int
    let postureScore: Int
    let blinkScore: Int
    let keyMouseScore: Int
    let tabScore: Int
    let checkInScore: Int
    let isComplete: Bool
}
