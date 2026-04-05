import Foundation
import AppKit

/// Manages the screen-capture → analysis → backend focus-level posting loop.
///
/// Every `sendInterval` seconds, records a `clipDuration`-second screen clip.
/// If the TRIBE v2 server is reachable, the clip is sent for cognitive analysis.
/// If not, falls back to the frontmost-app classification from ScreenCaptureService.
/// Either way, the derived focus score is posted to the production backend via
/// APIService.postFocusLevel() so the server actually receives data.
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

    // MARK: - Dependencies (set via startAnalysis)

    private var recorder: ScreenRecorder?
    private var sendTimer: Timer?
    private let store = SessionStore()
    private var captureTask: Task<Void, Never>?

    /// Closure to get the current session ID (set by SessionViewModel)
    private var getSessionId: (() -> Int?)?
    /// Reference to ScreenCaptureService for fallback app scoring
    private var screenCaptureService: ScreenCaptureService?
    /// Reference to FocusTrackingService to update scores
    private var focusTrackingService: FocusTrackingService?

    // MARK: - Lifecycle

    func startAnalysis(
        sessionIdProvider: @escaping () -> Int?,
        screenCapture: ScreenCaptureService,
        focusTracking: FocusTrackingService
    ) {
        let rec = ScreenRecorder()
        recorder = rec
        getSessionId = sessionIdProvider
        screenCaptureService = screenCapture
        focusTrackingService = focusTracking

        clips = []
        isAnalyzing = false
        store.start()
        demand = 0; gate = 0; pfc = 0; dmn = 0; lang = 0
        encodingType = .idle
        contentLabel = ""; contentReason = ""

        // Check/request screen recording permission
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            print("[tribe] Screen capture permission requested")
        }

        statusMessage = "Recording screen..."
        let interval = sendInterval
        print("[tribe] Analysis started — \(Int(clipDuration))s clips every \(Int(interval))s")

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

    /// Phase 1: Stop new captures from starting. In-progress capture continues to finish.
    func stopNewCaptures() {
        sendTimer?.invalidate()
        sendTimer = nil
        // Do NOT cancel captureTask or nil recorder — let in-progress clip finish
        print("[tribe] Stopped new captures — waiting for in-progress analysis (\(clips.count) clips so far)")
    }

    /// Wait for the in-progress capture task to complete (do NOT cancel it).
    func awaitPendingCapture() async {
        if let task = captureTask {
            print("[tribe] Awaiting in-progress capture task...")
            await task.value
            print("[tribe] Capture task completed — \(clips.count) clips total")
        }
    }

    /// Phase 2: Full cleanup after in-progress analysis has finished.
    func finalizeStop() {
        // Don't cancel — task should already be done after awaitPendingCapture()
        captureTask = nil
        recorder = nil
        getSessionId = nil
        screenCaptureService = nil
        focusTrackingService = nil
        statusMessage = "Analysis stopped"
        print("[tribe] Analysis finalized — \(clips.count) clips collected")
    }

    /// Legacy single-call stop (cancels everything immediately).
    func stopAnalysis() {
        stopNewCaptures()
        finalizeStop()
    }

    /// Returns the session summary after re-computing clips with LSTM engagement scores.
    func buildSummary(lstm: LSTMService) -> SessionSummary {
        if let csvPath = lstm.findLatestCSV() {
            let scores = lstm.readScores(from: csvPath)
            if !scores.isEmpty {
                clips = clips.enumerated().map { i, clip in
                    let eng = lstm.engagementForClip(index: i, scores: scores)
                    let focus = eng * clip.gate
                    let encoding = classifyEncoding(engagement: eng, gate: clip.gate)
                    return ClipResult(
                        timestamp: clip.timestamp, engagement: eng,
                        gate: clip.gate, focusScore: focus, encodingType: encoding,
                        contentLabel: clip.contentLabel, contentReason: clip.contentReason,
                        brainMapData: clip.brainMapData,
                        pfc: clip.pfc, dmn: clip.dmn, lang: clip.lang
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

        let dur = clipDuration
        let clipURL: URL
        do {
            clipURL = try await recorder.recordClip(duration: dur)
            print("[tribe] Clip recorded: \(clipURL.lastPathComponent)")
        } catch {
            statusMessage = "Recording error: \(error.localizedDescription)"
            print("[tribe] Recording error: \(error)")
            // Even if recording fails, post focus level from app monitoring
            await postFocusLevelFromAppMonitoring()
            return
        }

        // Try TRIBE v2 server first
        statusMessage = "Sending to TRIBE v2..."
        isAnalyzing = true

        var tribeSucceeded = false
        do {
            try await sendClipToTribe(clipURL: clipURL)
            tribeSucceeded = true
        } catch {
            print("[tribe] TRIBE server unavailable: \(error.localizedDescription)")
            statusMessage = "TRIBE offline — using app monitoring"
        }

        // If TRIBE failed, use ScreenCaptureService's app classification as fallback
        if !tribeSucceeded {
            await handleFallbackAnalysis(clipURL: clipURL)
        }

        // Always post focus level to the real backend
        await postFocusLevelToBackend()

        isAnalyzing = false
        try? FileManager.default.removeItem(at: clipURL)
    }

    /// Posts focus level from ScreenCaptureService app monitoring (no clip needed)
    private func postFocusLevelFromAppMonitoring() async {
        let appScore = screenCaptureService?.tabScore ?? 50
        let level = Double(appScore) / 100.0
        let appName = screenCaptureService?.activeAppName ?? "Unknown"

        // Update tracking service scores
        focusTrackingService?.currentScores = FocusScoreData(
            screenCapture: appScore,
            motionDetection: focusTrackingService?.currentScores.motionDetection ?? 50
        )

        // Post to backend
        guard let sessionId = getSessionId?() else {
            print("[tribe] No session ID yet — skipping focus level post")
            return
        }
        do {
            try await APIService.shared.postFocusLevel(sessionId: sessionId, level: level)
            print("[tribe] Posted focus level \(level) to backend (app: \(appName), session: \(sessionId))")
        } catch {
            print("[tribe] Failed to post focus level: \(error)")
        }
    }

    /// When TRIBE server is unavailable, create a clip result from app monitoring data
    private func handleFallbackAnalysis(clipURL: URL) async {
        let appScore = screenCaptureService?.tabScore ?? 50
        let appName = screenCaptureService?.activeAppName ?? "Unknown"

        // Map app score to gate: 100 → 1.0 (studying), 0 → 0.0 (distracted), 40 → 0.5 (neutral)
        let gateValue: Double = appScore >= 80 ? 1.0 : (appScore >= 30 ? 0.5 : 0.0)
        let engagement = Double(appScore)
        let focus = engagement * gateValue
        let encoding = classifyEncoding(engagement: engagement, gate: gateValue)

        // Estimate brain region activation from app type
        // Study apps → high PFC (planning), moderate lang; Distractions → high DMN (mind-wandering)
        let pfcValue: Double = appScore >= 80 ? 0.85 : (appScore >= 30 ? 0.45 : 0.15)
        let dmnValue: Double = appScore >= 80 ? 0.15 : (appScore >= 30 ? 0.40 : 0.80)
        let langValue: Double = appScore >= 80 ? 0.65 : (appScore >= 30 ? 0.35 : 0.10)

        let clip = ClipResult(
            timestamp: Date(), engagement: engagement, gate: gateValue,
            focusScore: focus, encodingType: encoding,
            contentLabel: appName, contentReason: "App monitoring (TRIBE offline)",
            brainMapData: nil, pfc: pfcValue, dmn: dmnValue, lang: langValue
        )

        self.gate = gateValue
        self.encodingType = encoding
        self.contentLabel = appName
        self.contentReason = "App monitoring"
        self.statusMessage = "\(encoding.emoji) \(appName) · app monitoring"
        self.clips.append(clip)
        self.store.addClip(clip)

        // Update tracking service scores
        focusTrackingService?.currentScores = FocusScoreData(
            screenCapture: appScore,
            motionDetection: focusTrackingService?.currentScores.motionDetection ?? 50
        )

        print("[tribe] Fallback clip \(clips.count): app=\(appName) score=\(appScore) gate=\(gateValue)")
    }

    /// Posts the current focus level to the production backend
    private func postFocusLevelToBackend() async {
        guard let sessionId = getSessionId?() else {
            print("[tribe] No session ID — skipping backend post")
            return
        }

        // Use the latest clip's focus score, or app monitoring score
        let focusLevel: Double
        if let lastClip = clips.last {
            focusLevel = lastClip.focusScore / 100.0
        } else {
            focusLevel = Double(screenCaptureService?.tabScore ?? 50) / 100.0
        }

        do {
            try await APIService.shared.postFocusLevel(
                sessionId: sessionId,
                level: max(0.0, min(1.0, focusLevel))
            )
            print("[tribe] Posted focus level \(focusLevel) to backend (session: \(sessionId))")
        } catch {
            print("[tribe] Failed to post focus level: \(error)")
        }
    }

    // MARK: - TRIBE v2 Server Communication

    private func sendClipToTribe(clipURL: URL) async throws {
        guard let url = URL(string: "\(serverURL)/analyze?format=mp4") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300  // TRIBE analysis can take minutes for video processing
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let videoData = try Data(contentsOf: clipURL)
        print("[tribe] Video file: \(clipURL.lastPathComponent) size=\(videoData.count) bytes")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"clip.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        print("[tribe] Sending \(videoData.count) bytes to \(serverURL)/analyze")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let statusCode = http?.statusCode ?? -1
        print("[tribe] TRIBE response: HTTP \(statusCode), \(data.count) bytes")
        if statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "(binary)"
            print("[tribe] TRIBE error response body: \(responseBody.prefix(500))")
            throw URLError(.badServerResponse)
        }
        let result = try JSONDecoder().decode(TribeResponse.self, from: data)

        let gateValue = result.gate
        let engagementScore = 65.0  // placeholder until LSTM provides real value
        let encoding = classifyEncoding(engagement: engagementScore, gate: gateValue)

        var brainData: Data? = nil
        if result.media_type == "mp4", let mediaData = Data(base64Encoded: result.brain_media) {
            brainData = mediaData
            print("[tribe] Brain media decoded: \(mediaData.count) bytes")
        } else {
            print("[tribe] No brain media — media_type=\(result.media_type) brain_media_len=\(result.brain_media.count)")
        }

        let clip = ClipResult(
            timestamp: Date(), engagement: engagementScore, gate: gateValue,
            focusScore: engagementScore * gateValue, encodingType: encoding,
            contentLabel: result.content_label ?? "", contentReason: result.content_reason ?? "",
            brainMapData: brainData,
            pfc: result.pfc, dmn: result.dmn, lang: result.lang
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

        // Update tracking service with TRIBE-derived score
        let tribeScore = Int(result.demand)
        focusTrackingService?.currentScores = FocusScoreData(
            screenCapture: tribeScore,
            motionDetection: focusTrackingService?.currentScores.motionDetection ?? 50
        )

        print("[tribe] TRIBE clip \(clips.count): gate=\(gateValue) label=\(result.content_label ?? "") demand=\(result.demand)")
    }
}
