import AVFoundation
import ScreenCaptureKit
import CoreMedia

// MARK: - Screen Recorder

/// Records screen clips using ScreenCaptureKit at 1280x720, 5fps, H.264.
/// Excludes the app's own windows from the capture.
class ScreenRecorder {
    func recordClip(duration: TimeInterval) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("focusbet_clip_\(Int(Date().timeIntervalSince1970)).mp4")

        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw NSError(domain: "FocusBet", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }
        let ownWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        let config = SCStreamConfiguration()
        config.width = 1280
        config.height = 720
        config.minimumFrameInterval = CMTime(value: 1, timescale: 5)
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
            sampleHandlerQueue: DispatchQueue(label: "focusbet.capture", qos: .userInitiated)
        )
        try await stream.startCapture()
        print("[recorder] Recording for \(Int(duration))s at 5fps")

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

// MARK: - Frame Capture

class FrameCapture: NSObject, SCStreamOutput {
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let writeQueue = DispatchQueue(label: "focusbet.framewrite", qos: .userInitiated)
    private var _frameCount: Int64 = 0
    private var _lastWriteTime: CFAbsoluteTime = 0
    private let minInterval: CFAbsoluteTime = 0.2
    var frameCount: Int64 { writeQueue.sync { _frameCount } }

    init(input: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor) {
        self.input = input
        self.adaptor = adaptor
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, CMSampleBufferIsValid(buffer),
              let pb = CMSampleBufferGetImageBuffer(buffer) else { return }
        writeQueue.async { [weak self] in
            guard let self else { return }
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
