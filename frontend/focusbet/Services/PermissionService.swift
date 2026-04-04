import AVFoundation
import CoreLocation
import AppKit

/// Tracks and requests all permissions required by FocusBet.
///
/// Observe the individual `has*` properties to react to permission changes.
/// Call `requestAllPermissions()` once (e.g., on first launch or session start)
/// to trigger the system permission dialogs in sequence.
@Observable
@MainActor
final class PermissionService {

    static let shared = PermissionService()
    private init() { checkAllPermissions() }

    // MARK: - Observed state

    var hasCamera:        Bool = false
    var hasMicrophone:    Bool = false
    var hasScreenCapture: Bool = false
    var hasLocation:      Bool = false

    var allGranted: Bool {
        hasCamera && hasMicrophone && hasScreenCapture && hasLocation
    }

    // MARK: - Public

    /// Re-reads current permission statuses (does not prompt the user).
    func checkAllPermissions() {
        hasCamera        = AVCaptureDevice.authorizationStatus(for: .video)  == .authorized
        hasMicrophone    = AVCaptureDevice.authorizationStatus(for: .audio)  == .authorized
        hasScreenCapture = CGPreflightScreenCaptureAccess()
        hasLocation      = checkLocationStatus()
    }

    /// Sequentially requests any missing permissions.
    /// Calling this on a permission already granted is a no-op for that permission.
    func requestAllPermissions() async {
        await requestCamera()
        await requestMicrophone()
        requestScreenCapture()   // CGRequestScreenCaptureAccess is synchronous
        // Location is requested by LocationService when startUpdating() is called.
        checkAllPermissions()
    }

    // MARK: - Private helpers

    private func requestCamera() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else { return }
        await AVCaptureDevice.requestAccess(for: .video)
    }

    private func requestMicrophone() async {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    private func requestScreenCapture() {
        guard !CGPreflightScreenCaptureAccess() else { return }
        CGRequestScreenCaptureAccess()
    }

    private func checkLocationStatus() -> Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .authorizedAlways || status == .authorized
    }
}
