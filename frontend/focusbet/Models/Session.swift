import Foundation

struct StudySession: Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    let buildingId: String
    let buildingName: String
    let startTime: Date
    let duration: Int           // minutes
    let focusScore: Int         // focusLevel 0-100 (used for gauge display)
    let sessionScore: Int       // points added to building total
    let screenCapture: Int      // TRIBEv2 screen analysis 0-100
    let motionDetection: Int    // webcam motion/gaze detection 0-100
    let isComplete: Bool
}
