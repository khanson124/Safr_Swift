//
//  DriverCharterRequestsView.swift
//  Safr
//

import SwiftUI

struct DriverCharterRequestsView: View {
    @Environment(SessionManager.self) private var session

    let onSelectTrip: (String) -> Void
    let onOpenTrip: (String) -> Void

    @State private var availableTrips: [Trip] = []
    @State private var assignedTrips: [Trip] = []
    @State private var dismissedTripIds: Set<String> = []
    @State private var charterAvailable = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var visibleAvailable: [Trip] {
        availableTrips.filter { !dismissedTripIds.contains($0.id) }
    }

    private var activeAssigned: Trip? {
        assignedTrips.first { [.accepted, .inProgress, .driverEnded, .disputed].contains($0.status) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                Text("Private ride requests separate from your default taxi workflow.")
                    .font(.subheadline)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)

                InfoCard(title: "Charter availability") {
                    Toggle(isOn: Binding(
                        get: { charterAvailable },
                        set: { updateCharterAvailable($0) }
                    )) {
                        Text(charterAvailable ? "Receiving charter requests" : "Charter requests paused")
                            .foregroundStyle(SafrTheme.Colors.textPrimary)
                    }
                    .tint(SafrTheme.Colors.accent)
                }

                if let activeAssigned {
                    InfoCard(title: "Active charter trip") {
                        Text(tripLabel(activeAssigned))
                            .foregroundStyle(SafrTheme.Colors.textPrimary)
                        SafrPrimaryButton(title: "Open charter trip") {
                            onOpenTrip(activeAssigned.id)
                        }
                    }
                }

                if !visibleAvailable.isEmpty {
                    InfoCard(title: "Open requests") {
                        ForEach(visibleAvailable) { trip in
                            charterRow(trip, isOpen: true)
                        }
                    }
                }

                if !assignedTrips.isEmpty {
                    InfoCard(title: "Assigned charter trips") {
                        ForEach(assignedTrips) { trip in
                            charterRow(trip, isOpen: false)
                        }
                    }
                }

                if visibleAvailable.isEmpty && assignedTrips.isEmpty && !isLoading {
                    Text("No charter requests right now.")
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
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
        .navigationTitle("Charter requests")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadRequests() }
        .task { await loadRequests() }
        .overlay {
            if isLoading && availableTrips.isEmpty && assignedTrips.isEmpty {
                ProgressView().tint(SafrTheme.Colors.accent)
            }
        }
    }

    private func charterRow(_ trip: Trip, isOpen: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tripLabel(trip))
                    .foregroundStyle(SafrTheme.Colors.textPrimary)
                Text(trip.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
            }
            Spacer()
            if isOpen {
                Button("Dismiss") {
                    dismissedTripIds.insert(trip.id)
                }
                .font(.caption)
                .foregroundStyle(SafrTheme.Colors.textSecondary)
            }
            Button("Review") {
                onSelectTrip(trip.id)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(SafrTheme.Colors.accent)
        }
        .padding(.vertical, SafrTheme.Spacing.xs)
    }

    private func tripLabel(_ trip: Trip) -> String {
        trip.routeSnapshot ?? "\(trip.originAddress) to \(trip.destinationAddress)"
    }

    private func updateCharterAvailable(_ enabled: Bool) {
        guard let userId = session.user?.id else { return }
        charterAvailable = enabled
        var preferences = DriverPreferencesStore.load(userId: userId)
        preferences.charterAvailable = enabled
        DriverPreferencesStore.save(preferences, userId: userId)
    }

    private func loadRequests() async {
        guard let token = session.accessToken, let userId = session.user?.id else { return }
        isLoading = true
        defer { isLoading = false }

        charterAvailable = DriverPreferencesStore.load(userId: userId).charterAvailable

        do {
            async let availableTask = APIClient.shared.listAvailableTrips(token: token)
            async let assignedTask = APIClient.shared.listTrips(token: token)
            let (available, assigned) = try await (availableTask, assignedTask)
            availableTrips = available.filter { $0.tripType == .charter }
            assignedTrips = assigned.filter {
                $0.tripType == .charter &&
                [.requested, .accepted, .inProgress, .driverEnded, .disputed].contains($0.status)
            }
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
