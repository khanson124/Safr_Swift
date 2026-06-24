//
//  DriverCharterRequestDetailView.swift
//  Safr
//

import SwiftUI

struct DriverCharterRequestDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session

    let tripId: String
    let onAccepted: (String) -> Void

    @State private var trip: Trip?
    @State private var isLoading = false
    @State private var isAccepting = false
    @State private var errorMessage: String?

    private var isAssigned: Bool {
        guard let trip else { return false }
        return [.accepted, .inProgress, .driverEnded, .disputed].contains(trip.status)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                Text("Confirm pickup and destination before accepting a private charter.")
                    .font(.subheadline)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)

                if isLoading && trip == nil {
                    ProgressView().tint(SafrTheme.Colors.accent).frame(maxWidth: .infinity)
                } else if let trip {
                    InfoCard(title: "Trip overview") {
                        Text(tripLabel(trip))
                            .font(.headline)
                            .foregroundStyle(SafrTheme.Colors.textPrimary)
                        detailRow("Pickup", trip.originAddress)
                        detailRow("Destination", trip.destinationAddress)
                        if let count = trip.passengerCount {
                            detailRow("Passengers", "\(count)")
                        }
                        detailRow("Requested", formattedDate(trip.requestedAt))
                    }

                    InfoCard(title: "Passenger context") {
                        Text(trip.rider?.fullName ?? "Passenger details appear after assignment")
                            .foregroundStyle(SafrTheme.Colors.textPrimary)
                        if let notes = trip.notes, !notes.isEmpty {
                            detailRow("Notes", notes)
                        }
                    }

                    if isAssigned {
                        SafrPrimaryButton(title: "Open charter trip") {
                            onAccepted(trip.id)
                        }
                    } else {
                        SafrPrimaryButton(title: "Accept charter", isLoading: isAccepting) {
                            Task { await acceptTrip() }
                        }
                    }

                    SafrSecondaryButton(title: isAssigned ? "Back to requests" : "Decline for now") {
                        dismiss()
                    }
                } else {
                    InfoCard(title: "Request unavailable") {
                        Text("This charter request is no longer in the queue.")
                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                        SafrSecondaryButton(title: "Back to requests") { dismiss() }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.danger)
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Charter request")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTrip() }
    }

    private func tripLabel(_ trip: Trip) -> String {
        trip.routeSnapshot ?? "\(trip.originAddress) to \(trip.destinationAddress)"
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
            Text(label).font(.caption).foregroundStyle(SafrTheme.Colors.textSecondary)
            Text(value).foregroundStyle(SafrTheme.Colors.textPrimary)
        }
    }

    private func formattedDate(_ iso: String) -> String {
        if let date = ISO8601DateFormatter().date(from: iso) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return iso
    }

    private func loadTrip() async {
        guard let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let availableTask = APIClient.shared.listAvailableTrips(token: token)
            async let assignedTask = APIClient.shared.listTrips(token: token)
            let (available, assigned) = try await (availableTask, assignedTask)
            trip = assigned.first(where: { $0.id == tripId }) ?? available.first(where: { $0.id == tripId })
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func acceptTrip() async {
        guard let token = session.accessToken else { return }
        isAccepting = true
        defer { isAccepting = false }

        do {
            let accepted = try await APIClient.shared.acceptTrip(token: token, tripId: tripId)
            trip = accepted
            onAccepted(accepted.id)
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
