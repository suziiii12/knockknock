import Foundation
import AppKit

/// Manages the screen-capture → TRIBE v2 analysis loop.
/// Records 20-second screen clips every 60 seconds and sends them to the TRIBE v2
/// server for cognitive demand analysis.
@Observable
@MainActor
class TribeAnalysisService {
    // MARK: - Published state

    private(set) var isAnalyzing = false
    private(set) var clips: [ClipResult] = []
    private(set) var demand: Double = 0
    private(set) var gate: Double = 0
    private(set) var pfc: Double = 0
    private(set) var dmn: Double = 0
    private(set) var lang: Double = 0
    private(set) var encodingType: EncodingType = .idle
    private(set) var contentLabel: String = ""
    private(set) var contentReason: String = ""
    private(set) var statusMessage: String = "Ready"
    private(set) var inferenceMs: Int = 0

    // MARK: - Configuration

    let serverURL = "http://localhost:8001"
    let clipDuration: TimeInterval = 20
    let sendInterval: TimeInterval = 60

    // MARK: - Private

    private var recorder: ScreenRecorder?
    private var sendTimer: Timer?
    private let store = SessionStore()
    private var captureTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func startAnalysis() {
        let rec = ScreenRecorder()
        recorder = rec
        clips = []
        isAnalyzing = false
        store.start()
        demand = 0; gate = 0; pfc = 0; dmn = 0; lang = 0
        encodingType = .idle
        contentLabel = ""; contentReason = ""
        statusMessage = "Requesting screen capture permission..."

        // Request screen capture permission first, then start capture loop
        let dur = clipDuration
        let interval = sendInterval

        // Check/request screen recording permission
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            print("[tribe] Screen capture permission requested — user must grant in System Preferences")
            statusMessage = "Grant screen recording permission in System Preferences, then restart session"
            // Even if not yet granted, proceed — SCShareableContent will prompt or fail with a clear error
        }

        statusMessage = "Recording screen..."
        print("[tribe] Analysis started — \(Int(dur))s clips every \(Int(interval))s")

        // Schedule recurring timer
        sendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.captureAndSend()
            }
        }

        // Immediate first capture
        captureTask = Task { @MainActor [weak self] in
            await self?.captureAndSend()
        }
    }

    func stopAnalysis() {
        sendTimer?.invalidate()
        sendTimer = nil
        captureTask?.cancel()
        captureTask = nil
        recorder = nil
        statusMessage = "Analysis stopped"
        print("[tribe] Analysis stopped — \(clips.count) clips collected")
    }

    /// Returns the session summary after re-computing clips with LSTM engagement scores.
    func buildSummary(lstm: LSTMService) -> SessionSummary {
        // Try to get real engagement scores from LSTM CSV
        if let csvPath = lstm.findLatestCSV() {
            let scores = lstm.readScores(from: csvPath)
            if !scores.isEmpty {
                clips = clips.enumerated().map { i, clip in
                    let eng = lstm.engagementForClip(index: i, scores: scores)
                    let focus = eng * clip.gate
                    let encoding = classifyEncoding(engagement: eng, gate: clip.gate)
                    return ClipResult(
                        timestamp: clip.timestamp,
                        engagement: eng,
                        gate: clip.gate,
                        focusScore: focus,
                        encodingType: encoding,
                        contentLabel: clip.contentLabel,
                        contentReason: clip.contentReason,
                        brainMapData: clip.brainMapData,
                        pfc: clip.pfc,
                        dmn: clip.dmn,
                        lang: clip.lang
                    )
                }
                store.clips = clips
                print("[tribe] Re-computed \(clips.count) clips with real engagement scores")
            }
        }
        return store.end()
    }

    // MARK: - Capture & Send

    private func captureAndSend() async {
        guard let recorder else {
            print("[tribe] captureAndSend: recorder is nil, skipping")
            return
        }
        statusMessage = "Capturing \(Int(clipDuration))s clip..."
        print("[tribe] Starting \(Int(clipDuration))s screen capture...")

        // Capture the config values before entering detached context
        let dur = clipDuration

        let clipURL: URL
        do {
            // Record clip off the main actor (ScreenCaptureKit needs a non-main queue)
            clipURL = try await recorder.recordClip(duration: dur)
            print("[tribe] Clip recorded: \(clipURL.lastPathComponent)")
        } catch {
            statusMessage = "Recording error: \(error.localizedDescription)"
            print("[tribe] Recording error: \(error)")
            return
        }

        statusMessage = "Sending to TRIBE v2..."
        isAnalyzing = true
        do {
            try await sendClip(clipURL: clipURL)
        } catch {
            statusMessage = "TRIBE error: \(error.localizedDescription)"
            print("[tribe] Send error: \(error)")
        }
        isAnalyzing = false
    }

    private func sendClip(clipURL: URL) async throws {
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

        print("[tribe] Sending \(videoData.count) bytes to \(serverURL)/analyze")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[tribe] Server returned HTTP \(code)")
            throw URLError(.badServerResponse)
        }
        let result = try JSONDecoder().decode(TribeResponse.self, from: data)

        let gateValue = result.gate
        let encoding = classifyEncoding(engagement: 65.0, gate: gateValue)

        var brainData: Data? = nil
        if result.media_type == "mp4", let mediaData = Data(base64Encoded: result.brain_media) {
            brainData = mediaData
        }

        let clip = ClipResult(
            timestamp: Date(),
            engagement: 65.0,
            gate: gateValue,
            focusScore: 65.0 * gateValue,
            encodingType: encoding,
            contentLabel: result.content_label ?? "",
            contentReason: result.content_reason ?? "",
            brainMapData: brainData,
            pfc: result.pfc,
            dmn: result.dmn,
            lang: result.lang
        )

        self.demand = result.demand
        self.gate = gateValue
        self.pfc = result.pfc
        self.dmn = result.dmn
        self.lang = result.lang
        self.contentLabel = result.content_label ?? ""
        self.contentReason = result.content_reason ?? ""
        self.inferenceMs = result.inference_ms
        self.encodingType = encoding
        self.statusMessage = "\(encoding.emoji) \(result.content_label ?? "") · \(result.content_reason ?? "")"
        self.clips.append(clip)
        self.store.addClip(clip)
        print("[tribe] clip \(self.clips.count): gate=\(gateValue) label=\(result.content_label ?? "")")

        try? FileManager.default.removeItem(at: clipURL)
    }
}
