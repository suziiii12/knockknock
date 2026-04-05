import SwiftUI

// MARK: - TRIBE v2 API Response

struct TribeResponse: Codable {
    let demand: Double
    let gate: Double
    let pfc: Double
    let dmn: Double
    let lang: Double
    let brain_media: String
    let media_type: String
    let inference_ms: Int
    let content_label: String?
    let content_reason: String?
    var error: String?
}

// MARK: - Encoding Type

enum EncodingType: String, Sendable {
    case deep       = "Deep encoding"
    case shallow    = "Shallow encoding"
    case overload   = "Cognitive overload"
    case distracted = "Distracted"
    case idle       = "Idle"

    var color: Color {
        switch self {
        case .deep:       return .green
        case .shallow:    return .blue
        case .overload:   return .orange
        case .distracted: return .red
        case .idle:       return .gray
        }
    }

    var emoji: String {
        switch self {
        case .deep:       return "🧠"
        case .shallow:    return "📖"
        case .overload:   return "😵"
        case .distracted: return "📱"
        case .idle:       return "💤"
        }
    }
}

// MARK: - Clip Result

struct ClipResult: Sendable {
    let timestamp:     Date
    let engagement:    Double
    let gate:          Double
    let focusScore:    Double
    let encodingType:  EncodingType
    let contentLabel:  String
    let contentReason: String
    let brainMapData:  Data?
    let pfc:           Double
    let dmn:           Double
    let lang:          Double
}

// MARK: - Session Summary

struct SessionSummary {
    let startTime: Date
    let endTime:   Date
    let clips:     [ClipResult]

    var durationMinutes:   Double { endTime.timeIntervalSince(startTime) / 60 }
    var averageFocus:      Double { clips.isEmpty ? 0 : clips.map(\.focusScore).reduce(0, +) / Double(clips.count) }
    var sessionScore:      Double { round((averageFocus * 0.8 + durationMinutes * 0.2) * 10) / 10 }
    var averageEngagement: Double { clips.isEmpty ? 0 : clips.map(\.engagement).reduce(0, +) / Double(clips.count) }
    var studyingFraction:  Double { clips.isEmpty ? 0 : Double(clips.filter { $0.gate >= 1.0 }.count) / Double(clips.count) }
    var distractionCount:  Int    { clips.filter { $0.gate == 0.0 }.count }

    var peakClip:        ClipResult? { clips.filter { $0.gate >= 1.0 }.max(by: { $0.focusScore < $1.focusScore }) }
    var lowestStudyClip: ClipResult? { clips.filter { $0.gate >= 1.0 }.min(by: { $0.focusScore < $1.focusScore }) }
    var distractionClip: ClipResult? { clips.first(where: { $0.gate == 0.0 }) }

    var encodingBreakdown: [EncodingType: Int] {
        Dictionary(grouping: clips, by: \.encodingType).mapValues(\.count)
    }

    var longestFocusStreak: Int {
        var best = 0, current = 0
        for clip in clips {
            if clip.focusScore >= 40 { current += 1; best = max(best, current) }
            else { current = 0 }
        }
        return best
    }
}

// MARK: - Session Store

@Observable
class SessionStore {
    var clips: [ClipResult] = []
    var sessionStart: Date = Date()
    var isActive: Bool = false

    func start() { clips = []; sessionStart = Date(); isActive = true }
    func addClip(_ clip: ClipResult) { clips.append(clip) }
    func end() -> SessionSummary {
        isActive = false
        return SessionSummary(startTime: sessionStart, endTime: Date(), clips: clips)
    }
    func reset() { clips = []; isActive = false }
}

// MARK: - Encoding Classifier

func classifyEncoding(engagement: Double, gate: Double) -> EncodingType {
    guard gate > 0 else { return .distracted }
    if engagement >= 70 { return .deep }
    if engagement >= 40 { return .shallow }
    return .overload
}
