import AVFoundation

@Observable
@MainActor
class CameraViewModel {
    let cameraService = CameraService()
    var isRunning = false

    func start() {
        cameraService.configure()
        cameraService.start()
        isRunning = true
    }

    func stop() {
        cameraService.stop()
        isRunning = false
    }
}
