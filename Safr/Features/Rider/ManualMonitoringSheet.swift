//
//  ManualMonitoringSheet.swift
//  Safr
//

import CoreLocation
import SwiftUI

struct ManualMonitoringSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session

    let onStarted: (Trip) -> Void

    @StateObject private var locationReader = LocationReader()
    @State private var pickup = "Current location"
    @State private var destination = ""
    @State private var driverName = ""
    @State private var plateNumber = ""
    @State private var vehicleDescription = ""
    @State private var routeDetails = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                    Text("Start roadside monitoring when you board without scanning a QR code.")
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.textSecondary)

                    SafrTextField(title: "Pickup", text: $pickup)
                    SafrTextField(title: "Destination (required)", text: $destination)
                    SafrTextField(title: "Driver name (optional)", text: $driverName)
                    SafrTextField(title: "Plate number (optional)", text: $plateNumber)
                    SafrTextField(title: "Vehicle description (optional)", text: $vehicleDescription)
                    SafrTextField(title: "Route notes (optional)", text: $routeDetails)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(SafrTheme.Colors.danger)
                    }

                    SafrPrimaryButton(
                        title: "Start monitoring",
                        isLoading: isSubmitting,
                        isDisabled: destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        Task { await startMonitoring() }
                    }
                }
                .padding(SafrTheme.Spacing.lg)
            }
            .safrScreenBackground()
            .navigationTitle("Monitor without QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { locationReader.requestLocation() }
        }
    }

    private var destinationCoordinate: CLLocationCoordinate2D? {
        guard let base = locationReader.coordinate, !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return MapCoordinateHelper.destinationOffset(from: base, destination: destination)
    }

    private func startMonitoring() async {
        guard let token = session.accessToken else { return }
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDestination.isEmpty else {
            errorMessage = "Enter a destination so Safr can attach monitoring to this ride."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let trip = try await APIClient.shared.startManualMonitoring(
                token: token,
                request: ManualMonitoringRequest(
                    pickupLocation: pickup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Current location"
                        : pickup.trimmingCharacters(in: .whitespacesAndNewlines),
                    destination: trimmedDestination,
                    driverName: driverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : driverName.trimmingCharacters(in: .whitespacesAndNewlines),
                    plateNumber: plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : plateNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    vehicleDescription: vehicleDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : vehicleDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    routeDetails: routeDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : routeDetails.trimmingCharacters(in: .whitespacesAndNewlines),
                    originLatitude: locationReader.coordinate?.latitude,
                    originLongitude: locationReader.coordinate?.longitude,
                    destinationLatitude: destinationCoordinate?.latitude,
                    destinationLongitude: destinationCoordinate?.longitude
                )
            )
            onStarted(trip)
            dismiss()
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
