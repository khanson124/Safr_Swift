//
//  DriverSafetyView.swift
//  Safr
//

import SwiftUI

struct DriverSafetyView: View {
    @Environment(SessionManager.self) private var session

    let onOpenTrip: (String) -> Void

    @State private var trips: [Trip] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private var flaggedTrips: [Trip] {
        trips.filter { trip in
            trip.incidents?.contains { $0.status != .resolved } == true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                Text("Review open SOS and reported safety issues tied to your monitored rides.")
                    .font(.subheadline)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)

                if isLoading && trips.isEmpty {
                    SafrLoadingStateView(message: "Loading safety activity…")
                } else if let errorMessage, trips.isEmpty {
                    SafrErrorStateView(message: errorMessage) {
                        Task { await load(silent: false) }
                    }
                } else {
                    InfoCard(title: "Open safety items") {
                        if flaggedTrips.isEmpty {
                            SafrEmptyStateView(
                                title: "No open driver-side safety issues right now.",
                                systemImage: "checkmark.shield"
                            )
                        } else {
                            ForEach(flaggedTrips) { trip in
                                Button {
                                    onOpenTrip(trip.id)
                                } label: {
                                    HStack(alignment: .top, spacing: SafrTheme.Spacing.md) {
                                        VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
                                            Text(tripLabel(trip))
                                                .font(.headline)
                                                .foregroundStyle(SafrTheme.Colors.textPrimary)
                                                .multilineTextAlignment(.leading)

                                            Text("\(trip.rider?.fullName ?? "Passenger pending") • \(trip.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)")
                                                .font(.caption)
                                                .foregroundStyle(SafrTheme.Colors.textSecondary)
                                        }

                                        Spacer()

                                        StatusChip(
                                            label: trip.hasActiveSos ? "SOS" : "Issue",
                                            tone: trip.hasActiveSos ? .danger : .warning
                                        )
                                    }
                                }
                                .padding(.vertical, SafrTheme.Spacing.xs)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(SafrTheme.Colors.danger)
                    }
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Driver safety")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load(silent: true) }
        .task { await load(silent: false) }
    }

    private func tripLabel(_ trip: Trip) -> String {
        trip.routeSnapshot ?? "\(trip.originAddress) to \(trip.destinationAddress)"
    }

    private func load(silent: Bool) async {
        guard let token = session.accessToken else { return }

        if silent {
            isRefreshing = true
        } else {
            isLoading = true
        }
        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            trips = try await APIClient.shared.listTrips(token: token)
            errorMessage = nil
        } catch let error as APIError {
            if !silent || trips.isEmpty { errorMessage = error.message }
        } catch {
            if !silent || trips.isEmpty { errorMessage = error.localizedDescription }
        }
    }
}
