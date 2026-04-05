// FocusLensApp.swift
// macOS app — records screen, sends to TRIBE v2 server, shows brain animation

import SwiftUI
import AVFoundation
import ScreenCaptureKit
import AppKit
import AVKit

// ── Response model ────────────────────────────────────────────────────────────

struct TribeResponse: Codable {
    let demand: Double
    let gate: Double          // 1.0 / 0.5 / 0.0
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

// ── Encoding type ─────────────────────────────────────────────────────────────

enum EncodingType: String {
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

// ── Clip result (session store entry) ─────────────────────────────────────────

struct ClipResult {
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

// ── Session store ────────────────────────────────────────────────────────────

struct SessionSummary {
    let startTime:          Date
    let endTime:            Date
    let clips:              [ClipResult]

    var durationMinutes:    Double { endTime.timeIntervalSince(startTime) / 60 }
    var averageFocus:       Double { clips.isEmpty ? 0 : clips.map(\.focusScore).reduce(0,+) / Double(clips.count) }
    var sessionScore:       Double { round((averageFocus * 0.8 + durationMinutes * 0.2) * 10) / 10 }
    var averageEngagement:  Double { clips.isEmpty ? 0 : clips.map(\.engagement).reduce(0,+) / Double(clips.count) }
    var studyingFraction:   Double { clips.isEmpty ? 0 : Double(clips.filter { $0.gate >= 1.0 }.count) / Double(clips.count) }
    var distractionCount:   Int    { clips.filter { $0.gate == 0.0 }.count }

    var peakClip:           ClipResult? { clips.filter { $0.gate >= 1.0 }.max(by: { $0.focusScore < $1.focusScore }) }
    var lowestStudyClip:    ClipResult? { clips.filter { $0.gate >= 1.0 }.min(by: { $0.focusScore < $1.focusScore }) }
    var distractionClip:    ClipResult? { clips.first(where: { $0.gate == 0.0 }) }

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

    // time of day helpers
    var sessionStartFormatted: String { formatTime(startTime) }
    var sessionEndFormatted: String   { formatTime(endTime) }

    var peakFocusTime: String? {
        guard let clip = peakClip else { return nil }
        return formatTime(clip.timestamp)
    }

    var firstDistractionTime: String? {
        guard let clip = clips.first(where: { $0.gate == 0.0 }) else { return nil }
        return formatTime(clip.timestamp)
    }

    var focusByHour: [(hour: String, avgFocus: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: clips) { clip -> Int in
            calendar.component(.hour, from: clip.timestamp)
        }
        return grouped.sorted(by: { $0.key < $1.key }).map { hour, clips in
            let avg = clips.map(\.focusScore).reduce(0,+) / Double(clips.count)
            let label = String(format: "%02d:00", hour)
            return (hour: label, avgFocus: avg)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

class SessionStore: ObservableObject {
    @Published var clips: [ClipResult] = []
    @Published var sessionStart: Date = Date()
    @Published var isActive: Bool = false

    func start() {
        clips = []
        sessionStart = Date()
        isActive = true
    }

    func addClip(_ clip: ClipResult) {
        clips.append(clip)
    }

    func end() -> SessionSummary {
        isActive = false
        return SessionSummary(
            startTime: sessionStart,
            endTime:   Date(),
            clips:     clips
        )
    }

    func reset() {
        clips = []
        isActive = false
    }
}

// ── Real LSTM client (connects to focus_pipeline FastAPI server) ─────────────

class RealLSTM {
    let baseURL = "http://localhost:8000"
    private var sessionId: Int? = nil
    var cachedScore: Double = 65.0

    // start a new LSTM session when study session begins
    func startSession(contentType: String = "studying") async {
        guard let url = URL(string: "\(baseURL)/sessions/start") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["content_type": contentType, "external_session_id": "focuslens_\(Int(Date().timeIntervalSince1970))"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["session_id"] as? Int {
                sessionId = id
                print("[lstm] Session started — id=\(id)")
            }
        } catch {
            print("[lstm] Failed to start session: \(error)")
        }
    }

    // stop LSTM session — returns export path
    func stopSession() async -> String? {
        guard let id = sessionId,
              let url = URL(string: "\(baseURL)/sessions/\(id)/stop") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let exportPath = json["csv_export"] as? String {
                print("[lstm] Session \(id) stopped — export: \(exportPath)")
                sessionId = nil
                return exportPath
            }
        } catch {
            print("[lstm] Stop failed: \(error)")
        }
        sessionId = nil
        return nil
    }

    // read engagement scores from the exported CSV file
    // CSV columns: index, window_start, window_end, window_start_iso, window_end_iso,
    //              score, daisee_class, inferred_state, body_engagement, confidence,
    //              mean_gaze, mean_head_yaw, mean_ear, mean_kpm, mean_posture
    func fetchExport(exportPath: String? = nil) async -> [[String: Any]]? {
        // if export path provided directly, use it
        // otherwise fall back to API endpoint
        if let path = exportPath {
            return readCSV(at: path)
        }

        // fallback: use API endpoint
        guard let id = sessionId,
              let url = URL(string: "\(baseURL)/sessions/\(id)/export") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let scores = json["scores"] as? [[String: Any]] {
                return scores
            }
        } catch { }
        return nil
    }

    // parse CSV file into array of score dictionaries
    private func readCSV(at path: String) -> [[String: Any]]? {
        // expand ~ in path
        let expanded = (path as NSString).expandingTildeInPath
        guard let content = try? String(contentsOfFile: expanded, encoding: .utf8) else {
            print("[lstm] Could not read CSV at: \(expanded)")
            return nil
        }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }

        // parse header
        let headers = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        var results: [[String: Any]] = []
        for line in lines.dropFirst() {
            let values = line.components(separatedBy: ",")
            guard values.count == headers.count else { continue }

            var row: [String: Any] = [:]
            for (i, header) in headers.enumerated() {
                let val = values[i].trimmingCharacters(in: .whitespaces)
                // try to parse as Double, fall back to String
                if let num = Double(val) {
                    row[header] = num
                } else {
                    row[header] = val
                }
            }
            results.append(row)
        }

        print("[lstm] Parsed \(results.count) rows from CSV")
        return results
    }

    // match a clip timestamp to the nearest LSTM score window
    func engagementAt(timestamp: Date, exportScores: [[String: Any]]) -> Double {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()

        // find the export window closest to this timestamp
        var best: Double = cachedScore
        var bestDiff: TimeInterval = .infinity

        for window in exportScores {
            guard let startStr = window["window_start_iso"] as? String,
                  let score = window["score"] as? Double else { continue }
            let date = iso.date(from: startStr) ?? iso2.date(from: startStr)
            if let date = date {
                let diff = abs(timestamp.timeIntervalSince(date))
                if diff < bestDiff {
                    bestDiff = diff
                    best = score
                }
            }
        }
        return best
    }

    func reset() {
        sessionId = nil
        cachedScore = 65.0
    }
}

// ── Encoding classifier ───────────────────────────────────────────────────────

func classifyEncoding(engagement: Double, gate: Double) -> EncodingType {
    guard gate > 0 else { return .distracted }
    if engagement >= 70 { return .deep }
    if engagement >= 40 { return gate >= 1.0 ? .shallow : .shallow }
    return .overload
}

// ── Main app ──────────────────────────────────────────────────────────────────

@main
struct FocusLensApp: App {
    var body: some Scene {
        WindowGroup("FocusLens") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 700)
    }
}

// ── View model ────────────────────────────────────────────────────────────────

@MainActor
class FocusViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isAnalyzing = false
    @Published var demand: Double = 0
    @Published var gate: Double = 0
    @Published var pfc: Double = 0
    @Published var dmn: Double = 0
    @Published var lang: Double = 0
    @Published var engagement: Double = 0
    @Published var focusScore: Double = 0
    @Published var encodingType: EncodingType = .idle
    @Published var contentLabel: String = ""
    @Published var contentReason: String = ""
    @Published var sessionClips: [ClipResult] = []
    @Published var brainVideoURL: URL?
    @Published var statusMessage = "Ready"
    @Published var errorMessage: String?
    @Published var inferenceMs: Int = 0
    @Published var recordedClipURL: URL?

    private let lstm = RealLSTM()
    let store = SessionStore()
    @Published var sessionSummary: SessionSummary? = nil
    @Published var showReport: Bool = false
    @Published var claudeFeedback: String = ""
    @Published var isFetchingFeedback: Bool = false
    @Published var lstmExportScores: [[String: Any]] = []

    let serverURL = "http://localhost:8001"
    let clipDuration: TimeInterval = 20
    let sendInterval: TimeInterval = 60

    private var recorder: ScreenRecorder?
    private var sendTimer: Timer?

    func startSession() {
        isRecording = true
        statusMessage = "Recording screen..."
        errorMessage = nil
        recorder = ScreenRecorder()
        sessionClips = []
        lstm.reset()
        store.start()
        Task { await lstm.startSession(contentType: "studying") }
        engagement = 0
        focusScore = 0
        encodingType = .idle
        contentLabel = ""
        contentReason = ""

        sendTimer = Timer.scheduledTimer(withTimeInterval: sendInterval, repeats: true) { [weak self] _ in
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.captureAndSend()
            }
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.captureAndSend()
        }
    }

    func stopSession() {
        isRecording = false
        sendTimer?.invalidate()
        sendTimer = nil
        recorder = nil
        statusMessage = "Finishing analysis..."

        // show report sheet immediately with loading state
        self.showReport = true

        // finish analysis in background, then populate report
        Task { @MainActor in
            print("[stop] isAnalyzing=\(self.isAnalyzing) clips=\(self.sessionClips.count)")
            var waited = 0
            while self.isAnalyzing && waited < 360 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                waited += 1
            }
            print("[stop] done waiting — generating report with \(self.sessionClips.count) clips")
            // stop LSTM server and get export
            let exportPath = await self.lstm.stopSession()
            if let path = exportPath {
                print("[lstm] Export saved to: \(path)")
            }
            // fetch full score timeline from CSV and re-compute engagement per clip
            if let scores = await self.lstm.fetchExport(exportPath: exportPath) {
                self.lstmExportScores = scores
                print("[lstm] Loaded \(scores.count) score windows from export")

                // update each clip with real engagement from LSTM export
                self.sessionClips = self.sessionClips.map { clip in
                    let engagement = self.lstm.engagementAt(
                        timestamp: clip.timestamp,
                        exportScores: scores
                    )
                    let focus = engagement * clip.gate
                    let encoding = classifyEncoding(engagement: engagement, gate: clip.gate)
                    return ClipResult(
                        timestamp:     clip.timestamp,
                        engagement:    engagement,
                        gate:          clip.gate,
                        focusScore:    focus,
                        encodingType:  encoding,
                        contentLabel:  clip.contentLabel,
                        contentReason: clip.contentReason,
                        brainMapData:  clip.brainMapData,
                        pfc:           clip.pfc,
                        dmn:           clip.dmn,
                        lang:          clip.lang
                    )
                }
                self.store.clips = self.sessionClips
                print("[lstm] Re-computed engagement for \(self.sessionClips.count) clips")
            }
            let summary = self.store.end()
            self.sessionSummary = summary
            self.statusMessage = "Session complete — \(self.sessionClips.count) clips · session score \(Int(summary.sessionScore))"
            self.claudeFeedback = ""
            // fetch Claude feedback in background
            Task {
                await self.fetchClaudeFeedback(summary: summary)
            }
        }
    }

    func fetchClaudeFeedback(summary: SessionSummary) async {
        await MainActor.run { self.isFetchingFeedback = true }

        guard let url = URL(string: "\(serverURL)/report") else { return }

        struct ClipPayload: Encodable {
            let timestamp: String
            let focus_score: Double
            let engagement: Double
            let gate: Double
            let encoding_type: String
            let content_label: String
            let content_reason: String
            let pfc: Double
            let dmn: Double
            let lang: Double
        }

        struct ReportPayload: Encodable {
            let duration_minutes: Double
            let clips: [ClipPayload]
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let clipsData = summary.clips.map { clip in
            ClipPayload(
                timestamp:      formatter.string(from: clip.timestamp),
                focus_score:    clip.focusScore,
                engagement:     clip.engagement,
                gate:           clip.gate,
                encoding_type:  clip.encodingType.rawValue,
                content_label:  clip.contentLabel,
                content_reason: clip.contentReason,
                pfc:            clip.pfc,
                dmn:            clip.dmn,
                lang:           clip.lang
            )
        }

        let payload = ReportPayload(
            duration_minutes: summary.durationMinutes,
            clips: clipsData
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)
            request.timeoutInterval = 60

            let (data, response) = try await URLSession.shared.data(for: request)

            // debug — print raw server response
            let rawResponse = String(data: data, encoding: .utf8) ?? "unreadable"
            print("[report] HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            print("[report] Raw response: \(rawResponse.prefix(500))")

            struct ReportResponse: Decodable {
                let feedback: String?
                let error: String?
            }
            let result = try JSONDecoder().decode(ReportResponse.self, from: data)

            await MainActor.run {
                self.claudeFeedback = result.feedback ?? result.error ?? "No feedback returned"
                self.isFetchingFeedback = false
            }
            print("[report] Feedback received")
        } catch {
            await MainActor.run {
                self.claudeFeedback = "Could not generate feedback: \(error.localizedDescription)"
                self.isFetchingFeedback = false
            }
        }
    }

    func captureAndSend() async {
        guard let recorder = recorder else { return }
        await MainActor.run { statusMessage = "Capturing \(Int(clipDuration))s clip..." }

        // use unstructured Task so recording is NOT cancelled when Stop is pressed
        let clipURL: URL
        do {
            clipURL = try await Task.detached(priority: .userInitiated) {
                try await recorder.recordClip(duration: self.clipDuration)
            }.value
        } catch {
            await MainActor.run { statusMessage = "Recording error: \(error.localizedDescription)" }
            return
        }

        // send to server — this CAN be cancelled, clip is already saved
        await MainActor.run {
            statusMessage = "Sending to TRIBE v2..."
            isAnalyzing = true
        }
        do {
            try await sendClip(clipURL: clipURL)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
        await MainActor.run { isAnalyzing = false }
    }

    func sendClip(clipURL: URL) async throws {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        let savedClipURL = docsURL.appendingPathComponent("focuslens_clip_\(Int(Date().timeIntervalSince1970)).mp4")
        try FileManager.default.copyItem(at: clipURL, to: savedClipURL)
        print("Saved screen recording to: \(savedClipURL.path)")
        await MainActor.run { self.recordedClipURL = savedClipURL }

        guard let url = URL(string: "\(serverURL)/analyze?format=mp4") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let videoData = try Data(contentsOf: clipURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"clip.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let result = try JSONDecoder().decode(TribeResponse.self, from: data)

        // engagement will be matched from LSTM export at end of session
        // use cached score during session (replaced at report time)
        let engagementScore = lstm.cachedScore
        let gateValue       = result.gate
        let focus           = engagementScore * gateValue
        let encoding        = classifyEncoding(engagement: engagementScore, gate: gateValue)

        // save brain map data
        var brainData: Data? = nil
        var brainTmpURL: URL? = nil
        if result.media_type == "mp4", let mediaData = Data(base64Encoded: result.brain_media) {
            let brainURL = docsURL.appendingPathComponent("brain_activation_\(Int(Date().timeIntervalSince1970)).mp4")
            try mediaData.write(to: brainURL)
            print("Saved brain animation to: \(brainURL.path)")
            brainData = mediaData
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("brain_\(Int(Date().timeIntervalSince1970)).mp4")
            try mediaData.write(to: tmpURL)
            brainTmpURL = tmpURL
        }

        // build clip result
        let clip = ClipResult(
            timestamp:     Date(),
            engagement:    engagementScore,
            gate:          gateValue,
            focusScore:    focus,
            encodingType:  encoding,
            contentLabel:  result.content_label ?? "",
            contentReason: result.content_reason ?? "",
            brainMapData:  brainData,
            pfc:           result.pfc,
            dmn:           result.dmn,
            lang:          result.lang
        )

        await MainActor.run {
            self.demand        = result.demand
            self.gate          = gateValue
            self.pfc           = result.pfc
            self.dmn           = result.dmn
            self.lang          = result.lang
            self.engagement    = engagementScore
            self.focusScore    = focus
            self.encodingType  = encoding
            self.contentLabel  = result.content_label ?? ""
            self.contentReason = result.content_reason ?? ""
            self.inferenceMs   = result.inference_ms
            self.statusMessage = "\(encoding.emoji) \(encoding.rawValue) · focus=\(Int(focus)) · \(result.content_label ?? "")"
            if let url = brainTmpURL { self.brainVideoURL = url }
            self.sessionClips.append(clip)
            self.store.addClip(clip)
            print("[session] clip \(self.sessionClips.count): engagement=\(Int(engagementScore)) gate=\(gateValue) focus=\(Int(focus)) encoding=\(encoding.rawValue)")
        }

        try? FileManager.default.removeItem(at: clipURL)
    }
}

// ── Screen recorder ───────────────────────────────────────────────────────────

class ScreenRecorder {
    func recordClip(duration: TimeInterval) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("focuslens_clip_\(Int(Date().timeIntervalSince1970)).mp4")

        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw NSError(domain: "FocusLens", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        let ownWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter      = SCContentFilter(display: display, excludingWindows: ownWindows)
        let config      = SCStreamConfiguration()
        config.width    = 1280
        config.height   = 720
        config.minimumFrameInterval = CMTime(value: 1, timescale: 5)  // 5fps
        config.queueDepth = 12

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 1_000_000,
                AVVideoExpectedSourceFrameRateKey: 5,
                AVVideoMaxKeyFrameIntervalKey: 5,
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        writer.add(input)

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: nil
        )

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameCapture = FrameCapture(input: input, adaptor: adaptor)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(
            frameCapture,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "focuslens.capture", qos: .userInitiated)
        )
        try await stream.startCapture()
        print("[recorder] Stream started — recording for \(duration)s at 5fps")

        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        print("[recorder] Captured \(frameCapture.frameCount) frames")

        try await stream.stopCapture()
        input.markAsFinished()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
        }

        print("[recorder] Saved to \(outputURL.lastPathComponent)")
        return outputURL
    }
}

// ── Frame capture delegate ────────────────────────────────────────────────────

class FrameCapture: NSObject, SCStreamOutput {
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let writeQueue = DispatchQueue(label: "focuslens.framewrite", qos: .userInitiated)
    private var _frameCount: Int64 = 0
    private var _lastWriteTime: CFAbsoluteTime = 0
    private let minInterval: CFAbsoluteTime = 0.2  // 5fps = 1 frame per 200ms
    var frameCount: Int64 { writeQueue.sync { _frameCount } }

    init(input: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor) {
        self.input   = input
        self.adaptor = adaptor
    }

    func stream(_ stream: SCStream,
                didOutputSampleBuffer buffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferIsValid(buffer),
              let pb = CMSampleBufferGetImageBuffer(buffer) else { return }

        // all state mutations happen on writeQueue — no race conditions
        writeQueue.async { [weak self, pb] in
            guard let self = self else { return }

            let now = CFAbsoluteTimeGetCurrent()
            guard now - self._lastWriteTime >= self.minInterval else { return }
            guard self.input.isReadyForMoreMediaData else { return }

            let pts = CMTime(value: self._frameCount, timescale: 5)
            if self.adaptor.append(pb, withPresentationTime: pts) {
                self._frameCount += 1
                self._lastWriteTime = now
            }
        }
    }
}

// ── Main UI ───────────────────────────────────────────────────────────────────

struct ContentView: View {
    @StateObject private var vm = FocusViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FocusLens").font(.title2).fontWeight(.semibold)
                    Text(vm.statusMessage).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if vm.isAnalyzing {
                    ProgressView().scaleEffect(0.7).padding(.trailing, 4)
                }
                Button(vm.isRecording ? "Stop" : "Start Recording") {
                    if vm.isRecording { vm.stopSession() }
                    else { vm.startSession() }
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isRecording ? .red : .blue)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            HStack(spacing: 0) {
                // brain animation — left
                ZStack {
                    Color.black
                    if let videoURL = vm.brainVideoURL {
                        BrainVideoPlayer(url: videoURL)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Brain activation map will appear here")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)

                Divider()

                // screen recording — right
                ZStack {
                    Color.black
                    if let clipURL = vm.recordedClipURL {
                        BrainVideoPlayer(url: clipURL)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.dashed")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Screen recording will appear here")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            }

            Divider()

            // live session info — minimal, scores shown in report
            HStack(spacing: 16) {
                if vm.isRecording {
                    // content gate verdict
                    HStack(spacing: 6) {
                        Circle()
                            .fill(vm.gate >= 1.0 ? Color.green : vm.gate >= 0.5 ? Color.orange : Color.red)
                            .frame(width: 8, height: 8)
                        Text(vm.contentLabel.isEmpty ? "Analyzing..." : vm.contentLabel.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !vm.contentReason.isEmpty {
                            Text("— \(vm.contentReason)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("clips: \(vm.sessionClips.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if vm.inferenceMs > 0 {
                        Text("\(vm.inferenceMs)ms")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .sheet(isPresented: $vm.showReport) {
            SessionReportView(vm: vm)
        }
    }

    var focusColor: Color {
        vm.focusScore >= 65 ? .green : vm.focusScore >= 40 ? .orange : .red
    }

    var demandColor: Color {
        vm.demand >= 65 ? .green : vm.demand >= 40 ? .orange : .red
    }
}

// ── Session report view ───────────────────────────────────────────────────────

struct SessionReportView: View {
    @ObservedObject var vm: FocusViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Report")
                        .font(.title2).fontWeight(.semibold)
                    if let summary = vm.sessionSummary {
                        Text(String(format: "%.0f min · %d clips · score %.1f",
                             summary.durationMinutes,
                             summary.clips.count,
                             summary.sessionScore))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Finishing analysis...")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            if let summary = vm.sessionSummary {
                reportContent(summary: summary)
            } else {
                loadingView
            }
        }
        .frame(minWidth: 700, minHeight: 600)
    }

    var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Waiting for last clip analysis...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(vm.statusMessage)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    func reportContent(summary: SessionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                    // summary stats
                    HStack(spacing: 16) {
                        StatBox(title: "Session score", value: String(format: "%.1f", summary.sessionScore), color: .green)
                        StatBox(title: "Engagement",    value: String(Int(summary.averageEngagement)), color: .blue)
                        StatBox(title: "Study time",    value: String(format: "%.0f%%", summary.studyingFraction * 100), color: .teal)
                        StatBox(title: "Distractions",  value: String(summary.distractionCount),    color: .red)
                        StatBox(title: "Focus streak",  value: "\(summary.longestFocusStreak) clips", color: .orange)
                    }
                    .padding(.horizontal)

                    Divider()

                    // time of day
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Session time")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("\(summary.sessionStartFormatted) → \(summary.sessionEndFormatted)")
                                .font(.caption).fontWeight(.medium)
                        }
                        Spacer()
                        if let t = summary.peakFocusTime {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Peak focus at")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(t).font(.caption).fontWeight(.medium).foregroundStyle(.green)
                            }
                        }
                        if let t = summary.firstDistractionTime {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("First distraction at")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(t).font(.caption).fontWeight(.medium).foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // focus by hour (if session spans multiple hours)
                    if summary.focusByHour.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Focus by hour")
                                .font(.caption2).foregroundStyle(.secondary)
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(summary.focusByHour, id: \.hour) { entry in
                                    VStack(spacing: 4) {
                                        Text(String(Int(entry.avgFocus)))
                                            .font(.caption2).monospacedDigit()
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(entry.avgFocus >= 65 ? Color.green :
                                                  entry.avgFocus >= 40 ? Color.orange : Color.red)
                                            .frame(width: 28, height: max(4, entry.avgFocus * 0.6))
                                        Text(entry.hour)
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    // encoding breakdown
                    Text("Encoding breakdown")
                        .font(.headline).padding(.horizontal)

                    HStack(spacing: 12) {
                        ForEach([EncodingType.deep, .shallow, .overload, .distracted], id: \.rawValue) { type in
                            let count = summary.encodingBreakdown[type] ?? 0
                            VStack(spacing: 4) {
                                Text(type.emoji).font(.title2)
                                Text("\(count)").font(.title3).fontWeight(.medium).foregroundStyle(type.color)
                                Text(type.rawValue).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(type.color.opacity(0.08))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // focus score graph
                    Text("Focus timeline")
                        .font(.headline).padding(.horizontal)

                    FocusScoreGraph(clips: summary.clips)
                        .frame(height: 160)
                        .padding(.horizontal)

                    // clip detail list
                    VStack(spacing: 4) {
                        ForEach(Array(summary.clips.enumerated()), id: \.offset) { i, clip in
                            HStack(spacing: 10) {
                                Text("\(i+1)").font(.caption2).foregroundStyle(.secondary).frame(width: 20)
                                Circle()
                                    .fill(clip.encodingType.color)
                                    .frame(width: 8, height: 8)
                                Text("\(Int(clip.focusScore))").font(.caption2).monospacedDigit().foregroundStyle(.secondary).frame(width: 28)
                                Text(clip.encodingType.emoji + " " + clip.contentLabel)
                                    .font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                if !clip.contentReason.isEmpty {
                                    Text(clip.contentReason)
                                        .font(.caption2).foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Divider()

                    // claude feedback
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Claude feedback")
                                .font(.headline)
                            Spacer()
                            if vm.isFetchingFeedback {
                                ProgressView().scaleEffect(0.7)
                                Text("Generating...").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)

                        if vm.claudeFeedback.isEmpty && !vm.isFetchingFeedback {
                            Text("No feedback available")
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(.horizontal)
                        } else if !vm.claudeFeedback.isEmpty {
                            Text(vm.claudeFeedback)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }

                    Divider()

                    // brain maps
                    if summary.peakClip != nil || summary.lowestStudyClip != nil || summary.distractionClip != nil {
                        Text("Brain activation maps")
                            .font(.headline).padding(.horizontal)

                        HStack(alignment: .top, spacing: 24) {
                            if let clip = summary.peakClip {
                                BrainMapCard(title: "Peak focus", clip: clip, color: .green)
                            }
                            if let clip = summary.lowestStudyClip {
                                BrainMapCard(title: "Lowest study", clip: clip, color: .orange)
                            }
                            if let clip = summary.distractionClip {
                                BrainMapCard(title: "Distraction", clip: clip, color: .red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }
}

// ── Focus score graph ────────────────────────────────────────────────────────

struct FocusScoreGraph: View {
    let clips: [ClipResult]

    let padTop: CGFloat    = 16
    let padBottom: CGFloat = 28
    let padLeft: CGFloat   = 36
    let padRight: CGFloat  = 12

    let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    func xPos(_ i: Int, graphW: CGFloat) -> CGFloat {
        clips.count <= 1
            ? padLeft + graphW / 2
            : padLeft + CGFloat(i) / CGFloat(clips.count - 1) * graphW
    }

    func yPos(_ score: Double, graphH: CGFloat) -> CGFloat {
        padTop + graphH * (1 - score / 100.0)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let graphW = w - padLeft - padRight
            let graphH = h - padTop - padBottom

            ZStack(alignment: .topLeading) {
                // y gridlines and labels
                ForEach([0, 25, 50, 75, 100], id: \.self) { val in
                    let y = yPos(Double(val), graphH: graphH)
                    Path { p in
                        p.move(to: CGPoint(x: padLeft, y: y))
                        p.addLine(to: CGPoint(x: w - padRight, y: y))
                    }
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                    Text("\(val)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                        .position(x: padLeft - 6, y: y)
                }

                // distraction shading
                ForEach(Array(clips.enumerated()), id: \.offset) { i, clip in
                    if clip.gate == 0 && clips.count > 1 {
                        Rectangle()
                            .fill(Color.red.opacity(0.08))
                            .frame(width: graphW / CGFloat(clips.count - 1), height: graphH)
                            .position(x: xPos(i, graphW: graphW), y: padTop + graphH / 2)
                    }
                }

                // connecting line
                if clips.count > 1 {
                    Path { p in
                        for (i, clip) in clips.enumerated() {
                            let pt = CGPoint(x: xPos(i, graphW: graphW), y: yPos(clip.focusScore, graphH: graphH))
                            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                        }
                    }
                    .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
                }

                // dots + score labels
                ForEach(Array(clips.enumerated()), id: \.offset) { i, clip in
                    let x = xPos(i, graphW: graphW)
                    let y = yPos(clip.focusScore, graphH: graphH)
                    Circle()
                        .fill(clip.encodingType.color)
                        .frame(width: 10, height: 10)
                        .position(x: x, y: y)
                    Text("\(Int(clip.focusScore))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .position(x: x, y: y - 12)
                    Text(timeFormatter.string(from: clip.timestamp))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .center)
                        .position(x: x, y: h - 10)
                }

                // axes
                Path { p in
                    p.move(to: CGPoint(x: padLeft, y: padTop + graphH))
                    p.addLine(to: CGPoint(x: w - padRight, y: padTop + graphH))
                    p.move(to: CGPoint(x: padLeft, y: padTop))
                    p.addLine(to: CGPoint(x: padLeft, y: padTop + graphH))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2).fontWeight(.medium).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}

struct BrainMapCard: View {
    let title: String
    let clip: ClipResult
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).fontWeight(.medium).foregroundStyle(color)
            if let data = clip.brainMapData,
               let url = saveTempVideo(data: data, name: title) {
                BrainVideoPlayerFill(url: url)
                    .frame(width: 180, height: 180)
                    .background(Color.white)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 180, height: 180)
                    .overlay(Text("No data").font(.caption2).foregroundStyle(.secondary))
            }
            Text(String(format: "focus: %d · %@", Int(clip.focusScore), clip.encodingType.rawValue))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

func saveTempVideo(data: Data, name: String) -> URL? {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("report_brain_\(name.replacingOccurrences(of: " ", with: "_")).mp4")
    try? data.write(to: url)
    return url
}

// ── Score card ────────────────────────────────────────────────────────────────

struct ScoreCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title).fontWeight(.medium).foregroundStyle(color).monospacedDigit()
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(minWidth: 64)
    }
}

// ── Region bar ────────────────────────────────────────────────────────────────

struct RegionBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(height: geo.size.height * value)
                }
            }
            .frame(width: 20, height: 50)
            Text(String(format: "%.2f", value))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

// ── Video player ──────────────────────────────────────────────────────────────

struct BrainVideoPlayer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        let player = AVPlayer(url: url)
        nsView.player = player
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
    }
}

// fill variant — crops to fill frame, white background, no black bars
struct BrainVideoPlayerFill: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.white.cgColor
        let player = AVPlayer(url: url)
        nsView.player = player
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
    }
}
