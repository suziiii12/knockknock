import ScreenCaptureKit

@Observable
class ScreenCaptureService {
    private var stream: SCStream?
    private var isCapturing = false

    func listAvailableContent() async throws -> SCShareableContent {
        try await SCShareableContent.current
    }

    func startCapture(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws {
        guard !isCapturing else { return }
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try await stream?.startCapture()
        isCapturing = true
    }

    func stopCapture() async throws {
        guard isCapturing else { return }
        try await stream?.stopCapture()
        stream = nil
        isCapturing = false
    }
}
