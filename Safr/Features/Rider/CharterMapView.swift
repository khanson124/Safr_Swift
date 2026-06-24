//
//  CharterMapView.swift
//  Safr
//

import CoreLocation
import SwiftUI

private enum CharterFlowState {
    case idle
    case matching
    case matched
}

struct CharterMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session

    let onOpenTrip: (String) -> Void

    @StateObject private var locationReader = LocationReader()
    @State private var flowState: CharterFlowState = .idle
    @State private var pickup = "Current location"
    @State private var destination = ""
    @State private var activeTrip: Trip?
    @State private var driverLocation: DriverLocationSnapshot?
    @State private var isRequesting = false
    @State private var errorMessage: String?
    @State private var showCancelConfirm = false
    @State private var liveNotice: String?
    @State private var realtime = RealtimeService()

    var body: some View {
        ZStack(alignment: .bottom) {
            JourneyMapView(
                origin: userCoordinate,
                destination: destinationCoordinate,
                driver: driverCoordinate
            )
            .ignoresSafeArea()

            VStack(spacing: SafrTheme.Spacing.sm) {
                if let liveNotice {
                    Text(liveNotice)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SafrTheme.Colors.background)
                        .padding(.horizontal, SafrTheme.Spacing.md)
                        .padding(.vertical, SafrTheme.Spacing.sm)
                        .background(SafrTheme.Colors.accent)
                        .clipShape(Capsule())
                }

                bottomSheet
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .navigationTitle("Charter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { handleBack() }
            }
        }
        .alert("Cancel charter request?", isPresented: $showCancelConfirm) {
            Button("Keep waiting", role: .cancel) {}
            Button("Cancel request", role: .destructive) {
                Task { await cancelPendingRequest() }
            }
        } message: {
            Text("Your pending charter request will be cancelled.")
        }
        .onAppear {
            locationReader.requestLocation()
            Task { await loadExistingCharter() }
        }
        .onDisappear {
            realtime.disconnect()
        }
        .task(id: activeTrip?.id) {
            guard let trip = activeTrip, let token = session.accessToken else { return }
            configureRealtime(token: token, trip: trip)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let refreshed = try? await APIClient.shared.getTrip(token: token, tripId: trip.id) else { continue }
                activeTrip = refreshed
                if [.accepted, .inProgress].contains(refreshed.status) {
                    flowState = .matched
                }
            }
        }
    }

    @ViewBuilder
    private var bottomSheet: some View {
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.md) {
            switch effectiveState {
            case .idle:
                Text("Request a private charter")
                    .font(.headline)
                    .foregroundStyle(SafrTheme.Colors.textPrimary)

                SafrTextField(title: "Pickup", text: $pickup)
                SafrTextField(title: "Destination", text: $destination)

                SafrPrimaryButton(
                    title: "Request charter",
                    isLoading: isRequesting,
                    isDisabled: destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await requestCharter() }
                }

            case .matching:
                Text("Matching with a driver…")
                    .font(.headline)
                    .foregroundStyle(SafrTheme.Colors.textPrimary)

                if let trip = activeTrip {
                    Text(trip.destinationAddress)
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                    StatusChip(label: "Waiting for driver", tone: .warning)
                }

                SafrSecondaryButton(title: "Cancel request") {
                    showCancelConfirm = true
                }

            case .matched:
                Text("Driver matched")
                    .font(.headline)
                    .foregroundStyle(SafrTheme.Colors.textPrimary)

                if let trip = activeTrip {
                    Text(trip.routeSnapshot ?? "\(trip.originAddress) → \(trip.destinationAddress)")
                        .foregroundStyle(SafrTheme.Colors.textSecondary)

                    if let driver = trip.driverProfile?.user {
                        Text(driver.fullName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SafrTheme.Colors.textPrimary)
                    }

                    StatusChip(
                        label: TripStatusHelpers.badge(for: trip).label,
                        tone: TripStatusHelpers.badge(for: trip).tone
                    )

                    SafrPrimaryButton(title: "Open trip monitor") {
                        onOpenTrip(trip.id)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(SafrTheme.Colors.danger)
            }
        }
        .padding(SafrTheme.Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
    }

    private var effectiveState: CharterFlowState {
        if let trip = activeTrip {
            if trip.tripType == .charter, trip.status == .requested {
                return .matching
            }
            if trip.tripType == .charter,
               [.accepted, .inProgress, .driverEnded, .disputed].contains(trip.status) {
                return .matched
            }
        }
        return flowState
    }

    private var userCoordinate: CLLocationCoordinate2D? {
        locationReader.coordinate
    }

    private var destinationCoordinate: CLLocationCoordinate2D? {
        if let lat = activeTrip?.destinationLatitude, let lng = activeTrip?.destinationLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard let base = locationReader.coordinate,
              !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return MapCoordinateHelper.destinationOffset(from: base, destination: destination)
    }

    private var driverCoordinate: CLLocationCoordinate2D? {
        if let driverLocation {
            return CLLocationCoordinate2D(latitude: driverLocation.latitude, longitude: driverLocation.longitude)
        }
        if let lat = activeTrip?.lastLatitude, let lng = activeTrip?.lastLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return nil
    }

    private func handleBack() {
        if activeTrip?.status == .requested {
            showCancelConfirm = true
        } else {
            dismiss()
        }
    }

    private func loadExistingCharter() async {
        guard let token = session.accessToken else { return }
        do {
            let active = try await APIClient.shared.getMyActiveTrip(token: token)
            if let active, active.tripType == .charter {
                activeTrip = active
                if [.accepted, .inProgress, .driverEnded, .disputed].contains(active.status) {
                    flowState = .matched
                } else if active.status == .requested {
                    flowState = .matching
                }
            }
        } catch {
            // Keep charter screen usable offline.
        }
    }

    private func requestCharter() async {
        guard let token = session.accessToken else { return }
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDestination.isEmpty else { return }

        isRequesting = true
        defer { isRequesting = false }

        do {
            let trip = try await APIClient.shared.createTrip(
                token: token,
                request: CreateTripRequest(
                    pickupLocation: pickup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Current location"
                        : pickup.trimmingCharacters(in: .whitespacesAndNewlines),
                    destination: trimmedDestination,
                    tripType: .charter,
                    originLatitude: locationReader.coordinate?.latitude,
                    originLongitude: locationReader.coordinate?.longitude,
                    destinationLatitude: destinationCoordinate?.latitude,
                    destinationLongitude: destinationCoordinate?.longitude
                )
            )
            activeTrip = trip
            flowState = .matching
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelPendingRequest() async {
        guard let token = session.accessToken, let trip = activeTrip, trip.status == .requested else {
            dismiss()
            return
        }

        do {
            _ = try await APIClient.shared.cancelTrip(token: token, tripId: trip.id)
            activeTrip = nil
            flowState = .idle
            realtime.disconnect()
            dismiss()
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func configureRealtime(token: String, trip: Trip) {
        realtime.connect(token: token, tripId: trip.id) { snapshot in
            driverLocation = snapshot
        } onTripEvent: { event in
            if let body = event.body, !body.isEmpty {
                liveNotice = body
            }
        }
    }
}
