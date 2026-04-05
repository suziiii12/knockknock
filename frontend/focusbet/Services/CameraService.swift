import AVFoundation

class CameraService {
    let captureSession = AVCaptureSession()
    private var isConfigured = false
    // All AVCaptureSession calls must happen on a single serial queue (Apple requirement)
    private let sessionQueue = DispatchQueue(label: "com.focusbet.camera.session")

    func configure() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }
            self.captureSession.beginConfiguration()
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                      ?? AVCaptureDevice.default(for: .video)
            guard let camera,
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.captureSession.canAddInput(input) else {
                self.captureSession.commitConfiguration()
                return
            }
            self.captureSession.addInput(input)
            self.captureSession.commitConfiguration()
            self.isConfigured = true
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }
}
