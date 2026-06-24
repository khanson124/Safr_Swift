//
//  RiderHomeView.swift
//  Safr
//

import SwiftUI

struct RiderHomeView: View {
    @Environment(SessionManager.self) private var session

    @State private var path = NavigationPath()
    @State private var activeTrip: Trip?
    @State private var monitoredTrip: Trip?
    @State private var pendingCharter: Trip?
    @State private var recentTrips: [Trip] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showManualMonitoring = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                    header

                    if let monitoredTrip {
                        activeTripBanner(monitoredTrip, title: "Monitored ride live")
                    }

                    if let pendingCharter {
                        charterPendingBanner(pendingCharter)
                    }

                    SafrPrimaryButton(title: "Scan Driver QR") {
                        path.append(RiderRoute.scanQr)
                    }
                    .accessibilityLabel("Scan driver QR code")

                    SafrSecondaryButton(title: "Request charter") {
                        path.append(RiderRoute.charter)
                    }

                    monitorWithoutQRSection

                    if isLoading && recentTrips.isEmpty && monitoredTrip == nil {
                        SafrLoadingStateView(message: "Loading your trips…")
                    } else if let errorMessage, recentTrips.isEmpty && monitoredTrip == nil {
                        SafrErrorStateView(message: errorMessage) {
                            Task { await loadTrips() }
                        }
                    } else {
                        tripHistorySection
                    }

                    if let errorMessage, !recentTrips.isEmpty {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(SafrTheme.Colors.danger)
                    }
                }
                .padding(SafrTheme.Spacing.lg)
            }
            .safrScreenBackground()
            .safrDismissKeyboardOnTap()
            .navigationTitle("Rider")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title3)
                            .foregroundStyle(SafrTheme.Colors.accent)
                    }
                }
            }
            .navigationDestination(for: RiderRoute.self) { route in
                switch route {
                case .scanQr:
                    ScanQrView { next in
                        path.append(next)
                    }
                case .verification(let data):
                    VerificationView(
                        routeData: data,
                        onNavigate: { path.append($0) },
                        onPopToScan: { path.append(RiderRoute.scanQr) }
                    )
                case .tripDetails(let tripId):
                    TripDetailsView(tripId: tripId, isRider: true)
                case .charter:
                    CharterMapView { tripId in
                        path.append(RiderRoute.tripDetails(tripId: tripId))
                    }
                }
            }
            .refreshable { await loadTrips() }
            .task { await loadTrips() }
            .sheet(isPresented: $showManualMonitoring) {
                ManualMonitoringSheet { trip in
                    path.append(RiderRoute.tripDetails(tripId: trip.id))
                }
            }
        }
        .tint(SafrTheme.Colors.accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
            if let user = session.user {
                Text("Hello, \(user.fullName)")
                    .font(.title2.bold())
                    .foregroundStyle(SafrTheme.Colors.textPrimary)
            }
            Text("Scan a verified taxi QR before you board.")
                .foregroundStyle(SafrTheme.Colors.textSecondary)
        }
    }

    @ViewBuilder
    private var tripHistorySection: some View {
        let historyTrips = historyOnlyTrips
        InfoCard(title: "Trip history") {
            if historyTrips.isEmpty {
                SafrEmptyStateView(
                    title: "No past trips yet",
                    message: "Your completed and recent trips will appear here.",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                ForEach(historyTrips.prefix(5)) { trip in
                    Button {
                        path.append(RiderRoute.tripDetails(tripId: trip.id))
                    } label: {
                        HStack(alignment: .top, spacing: SafrTheme.Spacing.md) {
                            VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
                                Text(trip.routeSnapshot ?? trip.destinationAddress)
                                    .foregroundStyle(SafrTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                Text(formattedTripDate(trip))
                                    .font(.caption)
                                    .foregroundStyle(SafrTheme.Colors.textSecondary)
                            }
                            Spacer()
                            StatusChip(
                                label: TripStatusHelpers.badge(for: trip).label,
                                tone: TripStatusHelpers.badge(for: trip).tone
                            )
                        }
                    }
                    .padding(.vertical, SafrTheme.Spacing.xs)
                }
            }
        }
    }

    private var historyOnlyTrips: [Trip] {
        recentTrips.filter { trip in
            if let activeTrip, trip.id == activeTrip.id { return false }
            if let monitoredTrip, trip.id == monitoredTrip.id { return false }
            return true
        }
    }

    private func formattedTripDate(_ trip: Trip) -> String {
        let source = trip.completedAt ?? trip.endedAt ?? trip.requestedAt
        if let date = ISO8601DateFormatter().date(from: source) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return source
    }

    private var monitorWithoutQRSection: some View {
        InfoCard(title: "Roadside monitoring") {
            Text("Start monitoring when you board without scanning a driver QR.")
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textSecondary)

            SafrSecondaryButton(title: "Monitor without QR") {
                showManualMonitoring = true
            }
        }
    }

    private func activeTripBanner(_ trip: Trip, title: String) -> some View {
        Button {
            path.append(RiderRoute.tripDetails(tripId: trip.id))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SafrTheme.Colors.accent)
                    Text(trip.routeSnapshot ?? trip.destinationAddress)
                        .font(.headline)
                        .foregroundStyle(SafrTheme.Colors.textPrimary)
                        .lineLimit(1)
                    StatusChip(label: TripStatusHelpers.badge(for: trip).label, tone: TripStatusHelpers.badge(for: trip).tone)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(SafrTheme.Colors.accent)
            }
            .padding(SafrTheme.Spacing.md)
            .background(SafrTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
        }
    }

    private func charterPendingBanner(_ trip: Trip) -> some View {
        Button {
            path.append(RiderRoute.charter)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
                    Text("Charter request pending")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SafrTheme.Colors.accentWarm)
                    Text(trip.destinationAddress)
                        .font(.headline)
                        .foregroundStyle(SafrTheme.Colors.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Text("Continue")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SafrTheme.Colors.accent)
            }
            .padding(SafrTheme.Spacing.md)
            .background(SafrTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
        }
    }

    private func loadTrips() async {
        guard let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let active = APIClient.shared.getMyActiveTrip(token: token)
            async let history = APIClient.shared.listMyTrips(token: token)
            activeTrip = try await active
            recentTrips = try await history
            monitoredTrip = resolveMonitoredTrip(active: activeTrip, history: recentTrips)
            pendingCharter = resolvePendingCharter(active: activeTrip, history: recentTrips)
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveMonitoredTrip(active: Trip?, history: [Trip]) -> Trip? {
        if let active, Trip.isRoadsideMonitoring(active) {
            return active
        }
        return history.first { Trip.isRoadsideMonitoring($0) }
    }

    private func resolvePendingCharter(active: Trip?, history: [Trip]) -> Trip? {
        if let active, active.tripType == .charter, active.status == .requested {
            return active
        }
        return history.first { $0.tripType == .charter && $0.status == .requested }
    }
}
