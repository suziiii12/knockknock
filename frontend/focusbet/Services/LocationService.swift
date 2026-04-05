import CoreLocation

/// Detects which campus building the user is currently inside.
///
/// Two detection strategies run in parallel:
///  1. **Region monitoring** (CLCircularRegion, 50 m radius) — low-power, event-driven.
///  2. **Continuous location** — used as a real-time fallback and to pick the nearest
///     building whenever a position fix arrives.
///
/// Falls back to WALC if neither strategy produces a match (e.g., location denied).
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {

    var currentLocation:  CLLocationCoordinate2D?
    var detectedBuilding: Building?
    var isAuthorized      = false
    var isLocating        = true

    private let manager = CLLocationManager()

    // Region identifier prefix — used to tell our regions apart from others
    private static let regionPrefix = "com.focusbet.building."

    override init() {
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    // MARK: - Public

    func startUpdating() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        isLocating = true
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        stopRegionMonitoring()
    }

    /// Returns the building id the user is currently inside, or nil.
    func detectCurrentBuilding() -> String? {
        detectedBuilding?.id
    }

    // MARK: - Region monitoring

    private func startRegionMonitoring() {
        stopRegionMonitoring()

        for building in MockData.buildings {
            let center = CLLocationCoordinate2D(
                latitude:  building.latitude,
                longitude: building.longitude
            )
            let region = CLCircularRegion(
                center:     center,
                radius:     50,                              // metres
                identifier: Self.regionPrefix + building.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit  = true
            manager.startMonitoring(for: region)
        }
    }

    private func stopRegionMonitoring() {
        for region in manager.monitoredRegions
            where region.identifier.hasPrefix(Self.regionPrefix) {
            manager.stopMonitoring(for: region)
        }
    }

    // MARK: - Nearest-building helper

    private func findNearestBuilding(to coord: CLLocationCoordinate2D) -> Building? {
        let userLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        var best: (building: Building, distance: Double)?

        for building in MockData.buildings {
            let d = userLoc.distance(from: CLLocation(
                latitude:  building.latitude,
                longitude: building.longitude
            ))
            if d < 50, (best == nil || d < best!.distance) {
                best = (building, d)
            }
        }

        return best?.building
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        isAuthorized = status == .authorizedAlways
        if isAuthorized {
            manager.startUpdatingLocation()
            startRegionMonitoring()
        } else if status == .denied || status == .restricted {
            isLocating = false
            if detectedBuilding == nil {
                detectedBuilding = MockData.buildings.first { $0.id == "walc" }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        isLocating      = false

        if let match = findNearestBuilding(to: location.coordinate) {
            detectedBuilding = match
        } else if detectedBuilding == nil {
            // Outside all 50 m radii — keep last known building or default to WALC
            detectedBuilding = MockData.buildings.first { $0.id == "walc" }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        if detectedBuilding == nil {
            detectedBuilding = MockData.buildings.first { $0.id == "walc" }
        }
    }

    // MARK: Region entry / exit

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier.hasPrefix(Self.regionPrefix) else { return }
        let slug = String(region.identifier.dropFirst(Self.regionPrefix.count))
        if let building = MockData.buildings.first(where: { $0.id == slug }) {
            detectedBuilding = building
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier.hasPrefix(Self.regionPrefix),
              let current = detectedBuilding else { return }
        let slug = String(region.identifier.dropFirst(Self.regionPrefix.count))
        // Only clear if the exited region is the one we were tracking
        if current.id == slug {
            detectedBuilding = nil
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: Error
    ) {
        // Region monitoring failed (e.g., exceeded max regions) — silent fallback to GPS
    }
}
