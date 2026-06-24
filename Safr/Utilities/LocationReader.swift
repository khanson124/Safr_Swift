//
//  LocationReader.swift
//  Safr
//

import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationReader: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var authorizationDenied = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            authorizationDenied = true
        @unknown default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                authorizationDenied = true
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            coordinate = locations.last?.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

enum MapCoordinateHelper {
    static func destinationOffset(
        from base: CLLocationCoordinate2D,
        destination: String
    ) -> CLLocationCoordinate2D {
        let offsetSeed = max(1, min(8, Double(destination.trimmingCharacters(in: .whitespacesAndNewlines).count) / 6))
        return CLLocationCoordinate2D(
            latitude: base.latitude + 0.004 + offsetSeed * 0.0004,
            longitude: base.longitude + 0.005 + offsetSeed * 0.00035
        )
    }
}
