//
//  DriverHomeView.swift
//  Safr
//

import SwiftUI

struct DriverHomeView: View {
    @Environment(SessionManager.self) private var session

    @State private var path = NavigationPath()
    @State private var viewModel = DriverHomeViewModel()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                    header

                    onlineToggleSection

                    SafrSecondaryButton(title: "Show My QR") {
                        path.append(DriverRoute.driverQr(tripId: nil))
                    }

                    SafrSecondaryButton(title: "Driver safety alerts") {
                        path.append(DriverRoute.driverSafety)
                    }

                    if viewModel.isLoading && viewModel.driverProfile == nil {
                        SafrLoadingStateView(message: "Preparing driver tools…")
                    } else if let error = viewModel.errorMessage, viewModel.driverProfile == nil {
                        SafrErrorStateView(message: error) {
                            Task { await viewModel.load(session: session, silent: false) }
                        }
                    }

                    if let activeRide = viewModel.activeRide {
                        activeRideCard(activeRide)
                    }

                    if !viewModel.activePassengers.isEmpty {
                        activePassengersSection
                    }

                    manualStartSection

                    if let error = viewModel.errorMessage, viewModel.driverProfile != nil {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(SafrTheme.Colors.danger)
                    }
                }
                .padding(SafrTheme.Spacing.lg)
            }
            .safrScreenBackground()
            .navigationTitle("Driver")
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
            .navigationDestination(for: DriverRoute.self) { route in
                switch route {
                case .driverQr(let tripId):
                    DriverQrView(tripId: tripId)
                case .tripDetails(let tripId):
                    TripDetailsView(tripId: tripId, isRider: false)
                case .charterRequests:
                    DriverCharterRequestsView(
                        onSelectTrip: { path.append(DriverRoute.charterDetail(tripId: $0)) },
                        onOpenTrip: { path.append(DriverRoute.tripDetails(tripId: $0)) }
                    )
                case .charterDetail(let tripId):
                    DriverCharterRequestDetailView(tripId: tripId) { acceptedTripId in
                        path.append(DriverRoute.driverQr(tripId: acceptedTripId))
                    }
                case .driverApplication:
                    DriverApplicationView()
                case .driverSafety:
                    DriverSafetyView { tripId in
                        path.append(DriverRoute.tripDetails(tripId: tripId))
                    }
                }
            }
            .refreshable {
                await viewModel.load(session: session, silent: true)
            }
            .task {
                viewModel.start(session: session)
            }
            .onDisappear {
                viewModel.stop()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: SafrTheme.Spacing.md) {
            UserAvatarView(
                name: session.user?.fullName ?? "Driver",
                imageURL: session.user?.avatarUrl,
                size: 56
            )

            VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
                Text("Taxi mode")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SafrTheme.Colors.textSecondary)

                Text(session.user?.fullName ?? "Safr driver")
                    .font(.title2.bold())
                    .foregroundStyle(SafrTheme.Colors.textPrimary)

                if let status = viewModel.driverProfile?.status ?? session.user?.approvalStatus {
                    StatusChip(
                        label: status == .approved ? "Verified driver" : status.displayMessage,
                        tone: status == .approved ? .safe : .warning
                    )
                }
            }

            Spacer()
        }
    }

    private var onlineToggleSection: some View {
        InfoCard(title: "Availability") {
            Toggle(isOn: Binding(
                get: { viewModel.preferences.taxiOnline },
                set: { viewModel.updatePreferences(session: session, taxiOnline: $0) }
            )) {
                HStack(spacing: SafrTheme.Spacing.sm) {
                    Circle()
                        .fill(viewModel.preferences.taxiOnline ? SafrTheme.Colors.success : SafrTheme.Colors.textSecondary)
                        .frame(width: 10, height: 10)
                        .scaleEffect(viewModel.preferences.taxiOnline ? 1.2 : 1)
                        .animation(
                            viewModel.preferences.taxiOnline
                                ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                                : .default,
                            value: viewModel.preferences.taxiOnline
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.preferences.taxiOnline ? "Online" : "Offline")
                            .foregroundStyle(SafrTheme.Colors.textPrimary)
                        Text(onlineDurationLabel)
                            .font(.caption)
                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                    }
                }
            }
            .tint(SafrTheme.Colors.accent)

            Toggle(isOn: Binding(
                get: { viewModel.preferences.charterAvailable },
                set: { viewModel.updatePreferences(session: session, charterAvailable: $0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Charter available")
                        .foregroundStyle(SafrTheme.Colors.textPrimary)
                    Text("Receive private charter ride requests.")
                        .font(.caption)
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                }
            }
            .tint(SafrTheme.Colors.accent)

            if viewModel.preferences.charterAvailable {
                SafrSecondaryButton(title: "Charter requests") {
                    path.append(DriverRoute.charterRequests)
                }
            }
        }
    }

    private var onlineDurationLabel: String {
        guard viewModel.preferences.taxiOnline, let since = viewModel.preferences.taxiOnlineSince,
              let date = ISO8601DateFormatter().date(from: since) else {
            return viewModel.preferences.taxiOnline ? "Ready now" : "Not accepting rides"
        }
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 1 { return "Online for under a minute" }
        if minutes < 60 { return "Online for \(minutes) min" }
        return "Online for \(minutes / 60)h \(minutes % 60)m"
    }

    private func activeRideCard(_ trip: Trip) -> some View {
        InfoCard(title: "Active ride") {
            Text(viewModel.tripLabel(trip))
                .foregroundStyle(SafrTheme.Colors.textPrimary)

            StatusChip(label: TripStatusHelpers.badge(for: trip).label, tone: TripStatusHelpers.badge(for: trip).tone)

            if trip.status == .accepted, trip.verifiedAt != nil {
                SafrPrimaryButton(title: "Start trip", isLoading: viewModel.isStartingTrip) {
                    Task {
                        if await viewModel.startTrip(session: session) {
                            path.append(DriverRoute.tripDetails(tripId: trip.id))
                        }
                    }
                }
            }

            if trip.status == .inProgress {
                SafrPrimaryButton(title: "End trip", isLoading: viewModel.isEndingTrip) {
                    Task { _ = await viewModel.endTrip(session: session) }
                }
            }

            SafrSecondaryButton(title: "Open monitor") {
                path.append(DriverRoute.tripDetails(tripId: trip.id))
            }
        }
    }

    private var activePassengersSection: some View {
        InfoCard(title: "Active passengers") {
            ForEach(viewModel.activePassengers) { passenger in
                Button {
                    path.append(DriverRoute.tripDetails(tripId: passenger.tripId))
                } label: {
                    HStack(spacing: SafrTheme.Spacing.md) {
                        UserAvatarView(
                            name: passenger.passenger.fullName,
                            imageURL: passenger.passenger.avatarUrl,
                            size: 44
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(passenger.passenger.fullName)
                                .foregroundStyle(SafrTheme.Colors.textPrimary)
                            Text(passenger.routeSnapshot ?? passenger.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(SafrTheme.Colors.textSecondary)
                        }

                        Spacer()

                        if passenger.sosActive {
                            StatusChip(label: "SOS", tone: .danger)
                        }

                        Image(systemName: "chevron.right")
                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                    }
                }
                .padding(.vertical, SafrTheme.Spacing.xs)
            }
        }
    }

    private var manualStartSection: some View {
        InfoCard(title: "Quick manual start") {
            Text("Start a monitored roadside trip when a rider boards without scanning.")
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textSecondary)

            SafrTextField(title: "Origin (optional)", text: $viewModel.originAddress)
            SafrTextField(title: "Destination (optional)", text: $viewModel.destinationAddress)

            SafrPrimaryButton(title: "Start monitored ride", isLoading: viewModel.isManualStarting) {
                Task {
                    if let trip = await viewModel.manualStart(session: session) {
                        path.append(DriverRoute.driverQr(tripId: trip.id))
                    }
                }
            }
        }
    }
}

#Preview {
    DriverHomeView()
        .environment(SessionManager())
}
