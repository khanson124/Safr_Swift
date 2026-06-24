//
//  DriverHomeViewModel.swift
//  Safr
//

import Foundation

@Observable
@MainActor
final class DriverHomeViewModel {
    var driverProfile: DriverProfile?
    var driverQr: DriverQrPayload?
    var activePassengers: [ActivePassengerSession] = []
    var assignedTrips: [Trip] = []
    var preferences = DriverPreferences.defaults
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var isStartingTrip = false
    var isEndingTrip = false
    var isManualStarting = false
    var originAddress = ""
    var destinationAddress = ""

    private var pollTask: Task<Void, Never>?

    var activeRide: Trip? {
        assignedTrips.first { trip in
            trip.tripType != .charter &&
            [.accepted, .inProgress, .driverEnded, .disputed].contains(trip.status)
        }
    }

    func start(session: SessionManager) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.load(session: session, silent: false)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                await self?.load(session: session, silent: true)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
    }

    func load(session: SessionManager, silent: Bool) async {
        guard let token = session.accessToken, let userId = session.user?.id else { return }

        if silent {
            isRefreshing = true
        } else {
            isLoading = true
        }
        defer {
            isLoading = false
            isRefreshing = false
        }

        preferences = DriverPreferencesStore.load(userId: userId)

        do {
            async let profileTask = APIClient.shared.getMyDriverProfile(token: token)
            async let passengersTask = APIClient.shared.listActivePassengers(token: token)
            async let tripsTask = APIClient.shared.listTrips(token: token)

            let qr = try? await APIClient.shared.getMyDriverQr(token: token)
            let (profile, passengers, trips) = try await (profileTask, passengersTask, tripsTask)

            driverProfile = profile
            driverQr = qr
            activePassengers = passengers
            assignedTrips = trips
            errorMessage = nil
        } catch let error as APIError {
            if !silent { errorMessage = error.message }
        } catch {
            if !silent { errorMessage = error.localizedDescription }
        }
    }

    func updatePreferences(session: SessionManager, taxiOnline: Bool? = nil, charterAvailable: Bool? = nil) {
        guard let userId = session.user?.id else { return }

        var next = preferences
        if let taxiOnline {
            next.taxiOnline = taxiOnline
            next.taxiOnlineSince = taxiOnline
                ? (preferences.taxiOnlineSince ?? JSONCoding.iso8601String())
                : nil
        }
        if let charterAvailable {
            next.charterAvailable = charterAvailable
        }
        preferences = next
        DriverPreferencesStore.save(next, userId: userId)
    }

    func startTrip(session: SessionManager) async -> Bool {
        guard let token = session.accessToken, let trip = activeRide, trip.status == .accepted, trip.verifiedAt != nil else {
            return false
        }

        isStartingTrip = true
        defer { isStartingTrip = false }

        do {
            let updated = try await APIClient.shared.startTrip(token: token, tripId: trip.id)
            assignedTrips = assignedTrips.map { $0.id == updated.id ? updated : $0 }
            return true
        } catch let error as APIError {
            errorMessage = error.message
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func endTrip(session: SessionManager) async -> Bool {
        guard let token = session.accessToken, let trip = activeRide, trip.status == .inProgress else {
            return false
        }

        isEndingTrip = true
        defer { isEndingTrip = false }

        do {
            let updated = try await APIClient.shared.endTripByDriver(token: token, tripId: trip.id)
            assignedTrips = assignedTrips.map { $0.id == updated.id ? updated : $0 }
            return true
        } catch let error as APIError {
            errorMessage = error.message
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func manualStart(session: SessionManager) async -> Trip? {
        guard let token = session.accessToken else { return nil }

        isManualStarting = true
        defer { isManualStarting = false }

        do {
            let trip = try await APIClient.shared.manualStartTrip(
                token: token,
                request: ManualStartTripRequest(
                    tripType: .shared,
                    startedFrom: .roadside,
                    originAddress: originAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : originAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    destinationAddress: destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            await load(session: session, silent: true)
            return trip
        } catch let error as APIError {
            errorMessage = error.message
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func tripLabel(_ trip: Trip) -> String {
        trip.routeSnapshot ?? "\(trip.originAddress) to \(trip.destinationAddress)"
    }
}
