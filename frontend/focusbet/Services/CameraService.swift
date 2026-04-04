import AVFoundation

@Observable
class CameraService {
    let captureSession = AVCaptureSession()
    private var isConfigured = false

    func configure() {
        guard !isConfigured else { return }
        captureSession.beginConfiguration()

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front
        ) ?? AVCaptureDevice.default(for: .video),
        let input = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        captureSession.commitConfiguration()
        isConfigured = true
    }

    func start() {
        guard !captureSession.isRunning else { return }
        Task.detached { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stop() {
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
    }
}
