//
//  LocationTrackingService.swift
//  Safr
//

import CoreLocation
import Foundation

@MainActor
final class LocationTrackingService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTrackingService()

    private let locationManager = CLLocationManager()
    private var trackingTimer: Timer?
    private var activeKey: String?
    private var token: String?
    private var tripId: String?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func start(token: String, tripId: String) async throws {
        let key = "\(token):\(tripId)"
        guard activeKey != key else { return }

        stop()

        let granted = await requestPermission()
        guard granted else {
            throw APIError(message: "Location permission is required during active trips.")
        }

        self.token = token
        self.tripId = tripId
        activeKey = key

        await postCurrentLocation()
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.postCurrentLocation()
            }
        }
    }

    func stop() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        activeKey = nil
        token = nil
        tripId = nil
    }

    private func requestPermission() async -> Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                locationManager.requestWhenInUseAuthorization()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let status = self.locationManager.authorizationStatus
                    continuation.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
                }
            }
        default:
            return false
        }
    }

    private func fetchLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func postCurrentLocation() async {
        guard let token, let tripId else { return }
        guard let location = await fetchLocation() else { return }

        let request = DriverLocationPost(
            tripId: tripId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
            speed: location.speed >= 0 ? location.speed : nil,
            heading: location.course >= 0 ? location.course : nil
        )

        _ = try? await APIClient.shared.sendDriverLocation(token: token, request: request)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.last)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(returning: manager.location)
            locationContinuation = nil
        }
    }
}
