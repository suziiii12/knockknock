import CoreLocation

@Observable
class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?
    var detectedBuilding: Building?
    var isAuthorized = false
    var isLocating = true

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func startUpdating() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        isLocating = true
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        isAuthorized = status == .authorizedAlways || status == .authorized
        if isAuthorized {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        detectedBuilding = findNearestBuilding(to: location.coordinate)
        isLocating = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // On failure, default to WALC
        isLocating = false
        if detectedBuilding == nil {
            detectedBuilding = MockData.buildings.first { $0.id == "walc" }
        }
    }

    private func findNearestBuilding(to coordinate: CLLocationCoordinate2D) -> Building? {
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var closest: Building?
        var minDistance: Double = 100 // 100m radius

        for building in MockData.buildings {
            let buildingLocation = CLLocation(latitude: building.latitude, longitude: building.longitude)
            let distance = userLocation.distance(from: buildingLocation)
            if distance < minDistance {
                minDistance = distance
                closest = building
            }
        }

        // If no building within 100m, default to WALC (hackathon venue)
        return closest ?? MockData.buildings.first { $0.id == "walc" }
    }
}
