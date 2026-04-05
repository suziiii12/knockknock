// FocusLensApp.swift
// macOS app — records screen, sends to TRIBE v2 server, shows brain animation
// Controlled via local HTTP server on port 9876

import SwiftUI
import AVFoundation
import ScreenCaptureKit
import AppKit
import AVKit
import Network

// ── Response model ────────────────────────────────────────────────────────────

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

// ── Clip result ───────────────────────────────────────────────────────────────

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

// ── Session summary ───────────────────────────────────────────────────────────

struct SessionSummary {
    let startTime: Date
    let endTime:   Date
    let clips:     [ClipResult]

    var durationMinutes:   Double { endTime.timeIntervalSince(startTime) / 60 }
    var averageFocus:      Double { clips.isEmpty ? 0 : clips.map(\.focusScore).reduce(0,+) / Double(clips.count) }
    var sessionScore:      Double { round((averageFocus * 0.8 + durationMinutes * 0.2) * 10) / 10 }
    var averageEngagement: Double { clips.isEmpty ? 0 : clips.map(\.engagement).reduce(0,+) / Double(clips.count) }
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

    var sessionStartFormatted: String { formatTime(startTime) }
    var sessionEndFormatted:   String { formatTime(endTime) }

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
        let grouped = Dictionary(grouping: clips) { calendar.component(.hour, from: $0.timestamp) }
        return grouped.sorted(by: { $0.key < $1.key }).map { hour, clips in
            let avg = clips.map(\.focusScore).reduce(0,+) / Double(clips.count)
            return (hour: String(format: "%02d:00", hour), avgFocus: avg)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// ── Session store ─────────────────────────────────────────────────────────────

class SessionStore: ObservableObject {
    @Published var clips: [ClipResult] = []
    @Published var sessionStart: Date = Date()
    @Published var isActive: Bool = false

    func start() { clips = []; sessionStart = Date(); isActive = true }
    func addClip(_ clip: ClipResult) { clips.append(clip) }
    func end() -> SessionSummary {
        isActive = false
        return SessionSummary(startTime: sessionStart, endTime: Date(), clips: clips)
    }
    func reset() { clips = []; isActive = false }
}

// ── LSTM client ───────────────────────────────────────────────────────────────

class RealLSTM {
    let baseURL = "http://localhost:8000"
    private var sessionId: Int? = nil

    func startSession(contentType: String = "studying") async {
        guard let url = URL(string: "\(baseURL)/sessions/start") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "content_type": contentType,
            "external_session_id": "focuslens_\(Int(Date().timeIntervalSince1970))"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["session_id"] as? Int {
                sessionId = id
                print("[lstm] Session started — id=\(id)")
            }
        } catch { print("[lstm] Failed to start: \(error)") }
    }

    func stopSession() async -> String? {
        guard let id = sessionId,
              let url = URL(string: "\(baseURL)/sessions/\(id)/stop") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let path = json["csv_export"] as? String {
                print("[lstm] Session \(id) stopped — export: \(path)")
                sessionId = nil
                return path
            }
        } catch { print("[lstm] Stop failed: \(error)") }
        sessionId = nil
        return nil
    }

    // read scores from CSV — format: "scores","67.5","37.5",...
    func readScores(from csvPath: String) -> [Double] {
        let expanded = (csvPath as NSString).expandingTildeInPath
        guard let content = try? String(contentsOfFile: expanded, encoding: .utf8) else {
            print("[lstm] Could not read CSV at: \(expanded)")
            return []
        }
        var scores: [Double] = []
        for line in content.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
            let cleaned = line.replacingOccurrences(of: "\"", with: "")
            let parts   = cleaned.components(separatedBy: ",")
            if parts.first?.trimmingCharacters(in: .whitespaces).lowercased() == "scores" {
                for part in parts.dropFirst() {
                    if let v = Double(part.trimmingCharacters(in: .whitespaces)) { scores.append(v) }
                }
                continue
            }
            for part in parts {
                if let v = Double(part.trimmingCharacters(in: .whitespaces)) { scores.append(v) }
            }
        }
        print("[lstm] Read \(scores.count) scores from CSV")
        return scores
    }

    func engagementForClip(index: Int, scores: [Double]) -> Double {
        guard !scores.isEmpty else { return 65.0 }
        return scores[min(index, scores.count - 1)]
    }

    func reset() { sessionId = nil }
}

// ── Encoding classifier ───────────────────────────────────────────────────────

func classifyEncoding(engagement: Double, gate: Double) -> EncodingType {
    guard gate > 0 else { return .distracted }
    if engagement >= 70 { return .deep }
    if engagement >= 40 { return .shallow }
    return .overload
}

// ── Local control server (backend calls these endpoints) ──────────────────────

class FocusLensControlServer {
    private var listener: NWListener?
    weak var vm: FocusViewModel?

    func start(vm: FocusViewModel) {
        self.vm = vm
        let params = NWParameters.tcp
        listener = try? NWListener(using: params, on: 9876)
        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global())
            self?.handleConnection(connection)
        }
        listener?.start(queue: .global())
        print("[control] Listening on port 9876")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let data = data, let text = String(data: data, encoding: .utf8) else { return }
            let firstLine = text.components(separatedBy: "\r\n").first ?? ""
            var responseBody = ""

            if firstLine.contains("POST /start_timed") {
                // parse duration from JSON body
                var duration: Double = 3600
                if let bodyRange = text.range(of: "\r\n\r\n"),
                   let bodyData = String(text[bodyRange.upperBound...]).data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                   let d = json["duration"] as? Double {
                    duration = d
                }
                DispatchQueue.main.async {
                    self?.vm?.startSession()
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        self?.vm?.stopSession()
                    }
                }
                responseBody = "{\"status\":\"started\",\"duration\":\(duration)}"
                print("[control] Session started for \(duration)s")

            } else if firstLine.contains("POST /start") {
                DispatchQueue.main.async { self?.vm?.startSession() }
                responseBody = "{\"status\":\"started\"}"

            } else if firstLine.contains("POST /stop") {
                DispatchQueue.main.async { self?.vm?.stopSession() }
                responseBody = "{\"status\":\"stopped\"}"

            } else if firstLine.contains("GET /summary") {
                if let summary = self?.vm?.sessionSummary {
                    // build focus_scores JSON array
                    let scoresArray = summary.clips.map { String(format: "%.2f", $0.focusScore) }.joined(separator: ",")
                    responseBody = """
                    {
                        "ready": true,
                        "session_score": \(summary.sessionScore),
                        "focus_scores": [\(scoresArray)],
                        "avg_focus": \(summary.averageFocus),
                        "avg_engagement": \(summary.averageEngagement),
                        "study_pct": \(summary.studyingFraction * 100),
                        "distraction_count": \(summary.distractionCount),
                        "clip_count": \(summary.clips.count),
                        "duration_minutes": \(summary.durationMinutes),
                        "session_start": "\(summary.sessionStartFormatted)",
                        "session_end": "\(summary.sessionEndFormatted)"
                    }
                    """
                } else {
                    responseBody = "{\"ready\":false}"
                }

            } else if firstLine.contains("GET /status") {
                let recording = self?.vm?.isRecording ?? false
                let analyzing = self?.vm?.isAnalyzing ?? false
                let clips     = self?.vm?.sessionClips.count ?? 0
                responseBody  = "{\"recording\":\(recording),\"analyzing\":\(analyzing),\"clips\":\(clips)}"

            } else {
                responseBody = "{\"error\":\"unknown endpoint. Use POST /start, POST /start_timed, POST /stop, GET /status, GET /summary\"}"
            }

            let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(responseBody.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\n\r\n\(responseBody)"
            connection.send(content: response.data(using: .utf8)!, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}

// ── Main app ──────────────────────────────────────────────────────────────────

@main
struct FocusLensApp: App {
    @StateObject private var vm = FocusViewModel()
    private let controlServer = FocusLensControlServer()

    var body: some Scene {
        WindowGroup("FocusLens") {
            ContentView(vm: vm)
                .onAppear { controlServer.start(vm: vm) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 700)
    }
}

// ── View model ────────────────────────────────────────────────────────────────

@MainActor
class FocusViewModel: ObservableObject {
    @Published var isRecording    = false
    @Published var isAnalyzing    = false
    @Published var demand: Double = 0
    @Published var gate: Double   = 0
    @Published var pfc: Double    = 0
    @Published var dmn: Double    = 0
    @Published var lang: Double   = 0
    @Published var engagement: Double     = 0
    @Published var focusScore: Double     = 0
    @Published var encodingType: EncodingType = .idle
    @Published var contentLabel: String   = ""
    @Published var contentReason: String  = ""
    @Published var sessionClips: [ClipResult] = []
    @Published var brainVideoURL: URL?
    @Published var recordedClipURL: URL?
    @Published var statusMessage  = "Ready"
    @Published var errorMessage: String?
    @Published var inferenceMs: Int = 0
    @Published var sessionSummary: SessionSummary? = nil
    @Published var showReport: Bool = false
    @Published var claudeFeedback: String = ""
    @Published var isFetchingFeedback: Bool = false

    private let lstm = RealLSTM()
    let store = SessionStore()

    let serverURL     = "http://localhost:8001"
    let clipDuration: TimeInterval = 20
    let sendInterval: TimeInterval = 60

    private var recorder: ScreenRecorder?
    private var sendTimer: Timer?

    func startSession() {
        isRecording   = true
        statusMessage = "Recording screen..."
        errorMessage  = nil
        recorder = ScreenRecorder()
        sessionClips  = []
        sessionSummary = nil
        claudeFeedback = ""
        lstm.reset()
        store.start()
        Task { await lstm.startSession(contentType: "studying") }
        engagement   = 0
        focusScore   = 0
        encodingType = .idle
        contentLabel = ""
        contentReason = ""

        sendTimer = Timer.scheduledTimer(withTimeInterval: sendInterval, repeats: true) { [weak self] _ in
            Task.detached(priority: .userInitiated) { [weak self] in await self?.captureAndSend() }
        }
        Task.detached(priority: .userInitiated) { [weak self] in await self?.captureAndSend() }
    }

    func stopSession() {
        isRecording = false
        sendTimer?.invalidate()
        sendTimer = nil
        recorder  = nil
        statusMessage = "Finishing analysis..."
        showReport = true

        Task { @MainActor in
            print("[stop] isAnalyzing=\(self.isAnalyzing) clips=\(self.sessionClips.count)")
            var waited = 0
            while self.isAnalyzing && waited < 360 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                waited += 1
            }
            print("[stop] done waiting — \(self.sessionClips.count) clips")

            // stop LSTM API session if running
            _ = await self.lstm.stopSession()

            // find CSV written by test_pipeline.py
            let csvPath = self.findLatestCSV()
            if let path = csvPath {
                print("[session] Found CSV: \(path)")
                let scores = self.lstm.readScores(from: path)
                if !scores.isEmpty {
                    self.sessionClips = self.sessionClips.enumerated().map { i, clip in
                        let eng      = self.lstm.engagementForClip(index: i, scores: scores)
                        let focus    = eng * clip.gate
                        let encoding = classifyEncoding(engagement: eng, gate: clip.gate)
                        return ClipResult(
                            timestamp:     clip.timestamp,
                            engagement:    eng,
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
                    print("[lstm] Re-computed \(self.sessionClips.count) clips with real engagement")
                }
            } else {
                print("[session] No CSV found — using placeholder engagement")
            }

            let summary = self.store.end()
            self.sessionSummary = summary
            self.statusMessage  = "Session complete — \(self.sessionClips.count) clips · score \(Int(summary.sessionScore))"
            Task { await self.fetchClaudeFeedback(summary: summary) }
        }
    }

    // find the most recently created CSV in the exports folder
    func findLatestCSV() -> String? {
        let exportsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("knockknock/EngagementScoreAI/exports")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: exportsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            print("[session] Exports dir not found: \(exportsDir.path)")
            return nil
        }
        let csvFiles = files.filter { $0.pathExtension == "csv" }
        let latest = csvFiles.max(by: { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return aDate < bDate
        })
        return latest?.path
    }

    func fetchClaudeFeedback(summary: SessionSummary) async {
        await MainActor.run { self.isFetchingFeedback = true }
        guard let url = URL(string: "\(serverURL)/report") else { return }

        struct ClipPayload: Encodable {
            let timestamp, encoding_type, content_label, content_reason: String
            let focus_score, engagement, gate, pfc, dmn, lang: Double
        }
        struct ReportPayload: Encodable {
            let duration_minutes: Double
            let clips: [ClipPayload]
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"

        let payload = ReportPayload(
            duration_minutes: summary.durationMinutes,
            clips: summary.clips.map { clip in
                ClipPayload(
                    timestamp:      fmt.string(from: clip.timestamp),
                    encoding_type:  clip.encodingType.rawValue,
                    content_label:  clip.contentLabel,
                    content_reason: clip.contentReason,
                    focus_score:    clip.focusScore,
                    engagement:     clip.engagement,
                    gate:           clip.gate,
                    pfc:            clip.pfc,
                    dmn:            clip.dmn,
                    lang:           clip.lang
                )
            }
        )

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)
            request.timeoutInterval = 60
            let (data, response) = try await URLSession.shared.data(for: request)
            print("[report] HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            struct ReportResponse: Decodable { let feedback: String?; let error: String? }
            let result = try JSONDecoder().decode(ReportResponse.self, from: data)
            await MainActor.run {
                self.claudeFeedback     = result.feedback ?? result.error ?? "No feedback returned"
                self.isFetchingFeedback = false
            }
        } catch {
            await MainActor.run {
                self.claudeFeedback     = "Could not generate feedback: \(error.localizedDescription)"
                self.isFetchingFeedback = false
            }
        }
    }

    func captureAndSend() async {
        guard let recorder = recorder else { return }
        await MainActor.run { statusMessage = "Capturing \(Int(clipDuration))s clip..." }
        let clipURL: URL
        do {
            clipURL = try await Task.detached(priority: .userInitiated) {
                try await recorder.recordClip(duration: self.clipDuration)
            }.value
        } catch {
            await MainActor.run { statusMessage = "Recording error: \(error.localizedDescription)" }
            return
        }
        await MainActor.run { statusMessage = "Sending to TRIBE v2..."; isAnalyzing = true }
        do { try await sendClip(clipURL: clipURL) } catch {
            await MainActor.run {
                errorMessage  = error.localizedDescription
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
        await MainActor.run { isAnalyzing = false }
    }

    func sendClip(clipURL: URL) async throws {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let savedClipURL = docsURL.appendingPathComponent("focuslens_clip_\(Int(Date().timeIntervalSince1970)).mp4")
        try FileManager.default.copyItem(at: clipURL, to: savedClipURL)
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

        let gateValue = result.gate
        let encoding  = classifyEncoding(engagement: 65.0, gate: gateValue)

        var brainData: Data? = nil
        var brainTmpURL: URL? = nil
        if result.media_type == "mp4", let mediaData = Data(base64Encoded: result.brain_media) {
            let brainURL = docsURL.appendingPathComponent("brain_activation_\(Int(Date().timeIntervalSince1970)).mp4")
            try mediaData.write(to: brainURL)
            brainData = mediaData
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("brain_\(Int(Date().timeIntervalSince1970)).mp4")
            try mediaData.write(to: tmpURL)
            brainTmpURL = tmpURL
        }

        let clip = ClipResult(
            timestamp:     Date(),
            engagement:    65.0,
            gate:          gateValue,
            focusScore:    65.0 * gateValue,
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
            self.contentLabel  = result.content_label ?? ""
            self.contentReason = result.content_reason ?? ""
            self.inferenceMs   = result.inference_ms
            self.statusMessage = "\(encoding.emoji) \(result.content_label ?? "") · \(result.content_reason ?? "")"
            if let url = brainTmpURL { self.brainVideoURL = url }
            self.sessionClips.append(clip)
            self.store.addClip(clip)
            print("[session] clip \(self.sessionClips.count): gate=\(gateValue) label=\(result.content_label ?? "")")
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
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        let config = SCStreamConfiguration()
        config.width = 1280; config.height = 720
        config.minimumFrameInterval = CMTime(value: 1, timescale: 5)
        config.queueDepth = 12

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280, AVVideoHeightKey: 720,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 1_000_000,
                AVVideoExpectedSourceFrameRateKey: 5,
                AVVideoMaxKeyFrameIntervalKey: 5,
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameCapture = FrameCapture(input: input, adaptor: adaptor)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(frameCapture, type: .screen,
                                   sampleHandlerQueue: DispatchQueue(label: "focuslens.capture", qos: .userInitiated))
        try await stream.startCapture()
        print("[recorder] Recording for \(duration)s at 5fps")

        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        print("[recorder] Captured \(frameCapture.frameCount) frames")

        try? await stream.stopCapture()
        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
        print("[recorder] Saved to \(outputURL.lastPathComponent)")
        return outputURL
    }
}

// ── Frame capture ─────────────────────────────────────────────────────────────

class FrameCapture: NSObject, SCStreamOutput {
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let writeQueue = DispatchQueue(label: "focuslens.framewrite", qos: .userInitiated)
    private var _frameCount: Int64 = 0
    private var _lastWriteTime: CFAbsoluteTime = 0
    private let minInterval: CFAbsoluteTime = 0.2
    var frameCount: Int64 { writeQueue.sync { _frameCount } }

    init(input: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor) {
        self.input = input; self.adaptor = adaptor
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, CMSampleBufferIsValid(buffer),
              let pb = CMSampleBufferGetImageBuffer(buffer) else { return }
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

// ── ContentView ───────────────────────────────────────────────────────────────

struct ContentView: View {
    @ObservedObject var vm: FocusViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FocusLens").font(.title2).fontWeight(.semibold)
                    Text(vm.statusMessage).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if vm.isAnalyzing { ProgressView().scaleEffect(0.7).padding(.trailing, 4) }
                Button(vm.isRecording ? "Stop" : "Start Recording") {
                    if vm.isRecording { vm.stopSession() } else { vm.startSession() }
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isRecording ? .red : .blue)
            }
            .padding().background(.ultraThinMaterial)

            Divider()

            HStack(spacing: 0) {
                ZStack {
                    Color.black
                    if let url = vm.brainVideoURL { BrainVideoPlayer(url: url) }
                    else {
                        VStack(spacing: 8) {
                            Image(systemName: "brain.head.profile").font(.system(size: 48)).foregroundStyle(.secondary)
                            Text("Brain activation map will appear here").foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 300)

                Divider()

                ZStack {
                    Color.black
                    if let url = vm.recordedClipURL { BrainVideoPlayer(url: url) }
                    else {
                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.dashed").font(.system(size: 48)).foregroundStyle(.secondary)
                            Text("Screen recording will appear here").foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 300)
            }

            Divider()

            HStack(spacing: 16) {
                if vm.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(vm.gate >= 1.0 ? Color.green : vm.gate >= 0.5 ? Color.orange : Color.red)
                            .frame(width: 8, height: 8)
                        Text(vm.contentLabel.isEmpty ? "Analyzing..." : vm.contentLabel.capitalized)
                            .font(.caption).foregroundStyle(.secondary)
                        if !vm.contentReason.isEmpty {
                            Text("— \(vm.contentReason)").font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("clips: \(vm.sessionClips.count)").font(.caption2).foregroundStyle(.tertiary)
                    if vm.inferenceMs > 0 {
                        Text("\(vm.inferenceMs)ms").font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 10)
        }
        .sheet(isPresented: $vm.showReport) { SessionReportView(vm: vm) }
    }
}

// ── Session report ────────────────────────────────────────────────────────────

struct SessionReportView: View {
    @ObservedObject var vm: FocusViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Report").font(.title2).fontWeight(.semibold)
                    if let s = vm.sessionSummary {
                        Text(String(format: "%.0f min · %d clips · score %.1f",
                             s.durationMinutes, s.clips.count, s.sessionScore))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Finishing analysis...").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding().background(.ultraThinMaterial)
            Divider()
            if let summary = vm.sessionSummary { reportContent(summary: summary) }
            else { loadingView }
        }
        .frame(minWidth: 700, minHeight: 600)
    }

    var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Text("Waiting for analysis to complete...").font(.headline).foregroundStyle(.secondary)
            Text(vm.statusMessage).font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    func reportContent(summary: SessionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    StatBox(title: "Session score", value: String(format: "%.1f", summary.sessionScore), color: .green)
                    StatBox(title: "Engagement",    value: String(Int(summary.averageEngagement)),        color: .blue)
                    StatBox(title: "Study time",    value: String(format: "%.0f%%", summary.studyingFraction * 100), color: .teal)
                    StatBox(title: "Distractions",  value: String(summary.distractionCount),              color: .red)
                    StatBox(title: "Focus streak",  value: "\(summary.longestFocusStreak) clips",          color: .orange)
                }.padding(.horizontal)

                Divider()

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Session time").font(.caption2).foregroundStyle(.secondary)
                        Text("\(summary.sessionStartFormatted) → \(summary.sessionEndFormatted)").font(.caption).fontWeight(.medium)
                    }
                    Spacer()
                    if let t = summary.peakFocusTime {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peak focus at").font(.caption2).foregroundStyle(.secondary)
                            Text(t).font(.caption).fontWeight(.medium).foregroundStyle(.green)
                        }
                    }
                    if let t = summary.firstDistractionTime {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("First distraction at").font(.caption2).foregroundStyle(.secondary)
                            Text(t).font(.caption).fontWeight(.medium).foregroundStyle(.red)
                        }
                    }
                }.padding(.horizontal)

                Divider()

                Text("Encoding breakdown").font(.headline).padding(.horizontal)
                HStack(spacing: 12) {
                    ForEach([EncodingType.deep, .shallow, .overload, .distracted], id: \.rawValue) { type in
                        let count = summary.encodingBreakdown[type] ?? 0
                        VStack(spacing: 4) {
                            Text(type.emoji).font(.title2)
                            Text("\(count)").font(.title3).fontWeight(.medium).foregroundStyle(type.color)
                            Text(type.rawValue).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(12)
                        .background(type.color.opacity(0.08)).cornerRadius(10)
                    }
                }.padding(.horizontal)

                Divider()

                Text("Focus timeline").font(.headline).padding(.horizontal)
                FocusScoreGraph(clips: summary.clips).frame(height: 160).padding(.horizontal)

                VStack(spacing: 4) {
                    ForEach(Array(summary.clips.enumerated()), id: \.offset) { i, clip in
                        HStack(spacing: 10) {
                            Text("\(i+1)").font(.caption2).foregroundStyle(.secondary).frame(width: 20)
                            Circle().fill(clip.encodingType.color).frame(width: 8, height: 8)
                            Text("\(Int(clip.focusScore))").font(.caption2).monospacedDigit().foregroundStyle(.secondary).frame(width: 28)
                            Text(clip.encodingType.emoji + " " + clip.contentLabel).font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            if !clip.contentReason.isEmpty {
                                Text(clip.contentReason).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                            }
                        }.padding(.horizontal)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Claude feedback").font(.headline)
                        Spacer()
                        if vm.isFetchingFeedback {
                            ProgressView().scaleEffect(0.7)
                            Text("Generating...").font(.caption2).foregroundStyle(.secondary)
                        }
                    }.padding(.horizontal)
                    if !vm.claudeFeedback.isEmpty {
                        Text(vm.claudeFeedback)
                            .font(.body).foregroundStyle(.primary).lineSpacing(4)
                            .padding(.horizontal).padding(.vertical, 8)
                            .background(Color.blue.opacity(0.05)).cornerRadius(8)
                            .padding(.horizontal)
                    } else if !vm.isFetchingFeedback {
                        Text("No feedback available").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                    }
                }

                Divider()

                if summary.peakClip != nil || summary.lowestStudyClip != nil || summary.distractionClip != nil {
                    Text("Brain activation maps").font(.headline).padding(.horizontal)
                    HStack(alignment: .top, spacing: 24) {
                        if let clip = summary.peakClip        { BrainMapCard(title: "Peak focus",   clip: clip, color: .green) }
                        if let clip = summary.lowestStudyClip { BrainMapCard(title: "Lowest study", clip: clip, color: .orange) }
                        if let clip = summary.distractionClip { BrainMapCard(title: "Distraction",  clip: clip, color: .red) }
                    }
                    .frame(maxWidth: .infinity, alignment: .center).padding(.horizontal)
                }
            }.padding(.vertical)
        }
    }
}

// ── Focus score graph ─────────────────────────────────────────────────────────

struct FocusScoreGraph: View {
    let clips: [ClipResult]
    let padTop: CGFloat = 16; let padBottom: CGFloat = 28
    let padLeft: CGFloat = 36; let padRight: CGFloat = 12
    let timeFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "h:mm"; return f }()

    func xPos(_ i: Int, graphW: CGFloat) -> CGFloat {
        clips.count <= 1 ? padLeft + graphW / 2
            : padLeft + CGFloat(i) / CGFloat(clips.count - 1) * graphW
    }
    func yPos(_ score: Double, graphH: CGFloat) -> CGFloat { padTop + graphH * (1 - score / 100.0) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            let graphW = w - padLeft - padRight; let graphH = h - padTop - padBottom
            ZStack(alignment: .topLeading) {
                ForEach([0, 25, 50, 75, 100], id: \.self) { val in
                    let y = yPos(Double(val), graphH: graphH)
                    Path { p in p.move(to: CGPoint(x: padLeft, y: y)); p.addLine(to: CGPoint(x: w - padRight, y: y)) }
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                    Text("\(val)").font(.system(size: 10)).foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing).position(x: padLeft - 6, y: y)
                }
                ForEach(Array(clips.enumerated()), id: \.offset) { i, clip in
                    if clip.gate == 0 && clips.count > 1 {
                        Rectangle().fill(Color.red.opacity(0.08))
                            .frame(width: graphW / CGFloat(clips.count - 1), height: graphH)
                            .position(x: xPos(i, graphW: graphW), y: padTop + graphH / 2)
                    }
                }
                if clips.count > 1 {
                    Path { p in
                        for (i, clip) in clips.enumerated() {
                            let pt = CGPoint(x: xPos(i, graphW: graphW), y: yPos(clip.focusScore, graphH: graphH))
                            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                        }
                    }.stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
                }
                ForEach(Array(clips.enumerated()), id: \.offset) { i, clip in
                    let x = xPos(i, graphW: graphW); let y = yPos(clip.focusScore, graphH: graphH)
                    Circle().fill(clip.encodingType.color).frame(width: 10, height: 10).position(x: x, y: y)
                    Text("\(Int(clip.focusScore))").font(.system(size: 9)).foregroundStyle(.secondary).position(x: x, y: y - 12)
                    Text(timeFormatter.string(from: clip.timestamp)).font(.system(size: 9)).foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .center).position(x: x, y: h - 10)
                }
                Path { p in
                    p.move(to: CGPoint(x: padLeft, y: padTop + graphH)); p.addLine(to: CGPoint(x: w - padRight, y: padTop + graphH))
                    p.move(to: CGPoint(x: padLeft, y: padTop)); p.addLine(to: CGPoint(x: padLeft, y: padTop + graphH))
                }.stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
            }
        }
    }
}

// ── Helper views ──────────────────────────────────────────────────────────────

struct StatBox: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2).fontWeight(.medium).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(10).background(color.opacity(0.08)).cornerRadius(8)
    }
}

struct BrainMapCard: View {
    let title: String; let clip: ClipResult; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).fontWeight(.medium).foregroundStyle(color)
            if let data = clip.brainMapData, let url = saveTempVideo(data: data, name: title) {
                BrainVideoPlayerFill(url: url).frame(width: 180, height: 180).background(Color.white).cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1))
                    .frame(width: 180, height: 180)
                    .overlay(Text("No data").font(.caption2).foregroundStyle(.secondary))
            }
            Text(String(format: "focus: %d · %@", Int(clip.focusScore), clip.encodingType.rawValue))
                .font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

func saveTempVideo(data: Data, name: String) -> URL? {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("report_brain_\(name.replacingOccurrences(of: " ", with: "_")).mp4")
    try? data.write(to: url)
    return url
}

struct BrainVideoPlayer: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView(); v.controlsStyle = .none; v.videoGravity = .resizeAspect; return v
    }
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        let player = AVPlayer(url: url); nsView.player = player
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem, queue: .main) { _ in player.seek(to: .zero); player.play() }
        player.play()
    }
}

struct BrainVideoPlayerFill: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView(); v.controlsStyle = .none; v.videoGravity = .resizeAspect
        v.wantsLayer = true; v.layer?.backgroundColor = NSColor.white.cgColor; return v
    }
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.white.cgColor
        let player = AVPlayer(url: url); nsView.player = player
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem, queue: .main) { _ in player.seek(to: .zero); player.play() }
        player.play()
    }
}

struct ScoreCard: View {
    let title, value, subtitle: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title).fontWeight(.medium).foregroundStyle(color).monospacedDigit()
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }.frame(minWidth: 64)
    }
}

struct RegionBar: View {
    let label: String; let value: Double; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(height: geo.size.height * value)
                }
            }.frame(width: 20, height: 50)
            Text(String(format: "%.2f", value)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}
