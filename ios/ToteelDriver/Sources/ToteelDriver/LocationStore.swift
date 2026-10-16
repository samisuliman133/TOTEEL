import CoreLocation
import Foundation
import Combine

final class LocationStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var message = "Location not set"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        manager.startUpdatingLocation()
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            message = "Enable location permission in iPhone Settings."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.message = String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.message = "Location error: \(error.localizedDescription)" }
    }
}
