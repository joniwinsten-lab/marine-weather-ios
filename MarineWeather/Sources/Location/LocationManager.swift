import CoreLocation
import Foundation

/// Device location for map recenter (parity with Android `DeviceLocation.kt`).
@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastCoordinate: CLLocationCoordinate2D?
    /// Bumps when GPS fix updates — use with `onChange` (coordinates are not Equatable on iOS 17).
    @Published private(set) var locationUpdateToken = 0

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = manager.authorizationStatus
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func refreshLocation() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else {
            requestWhenInUse()
            return
        }
        manager.requestLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorization = manager.authorizationStatus
            if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            lastCoordinate = location.coordinate
            locationUpdateToken += 1
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silent — map keeps last manual center.
    }
}
