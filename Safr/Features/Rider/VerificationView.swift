//
//  VerificationView.swift
//  Safr
//

import SwiftUI

struct VerificationView: View {
    @Environment(SessionManager.self) private var session

    let routeData: VerificationRouteData
    var onNavigate: (RiderRoute) -> Void
    var onPopToScan: () -> Void

    @State private var routeConfirmation = ""
    @State private var mismatchNotes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                switch routeData.mode {
                case .driverQr:
                    driverQrContent
                case .tripVerification:
                    tripVerificationContent
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(SafrTheme.Colors.danger)
                        .font(.subheadline)
                }

                if let successMessage {
                    Text(successMessage)
                        .foregroundStyle(SafrTheme.Colors.success)
                        .font(.subheadline)
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let driver = routeData.driverVerification {
                routeConfirmation = driver.driver.routeName ?? ""
            }
        }
    }

    @ViewBuilder
    private var driverQrContent: some View {
        if let verification = routeData.driverVerification, let code = routeData.code {
            Text("Confirm this driver before starting your trip.")
                .foregroundStyle(SafrTheme.Colors.textSecondary)

            DriverInfoCard(driver: verification.driver)

            SafrTextField(title: "Route confirmation (optional)", text: $routeConfirmation)

            SafrPrimaryButton(title: "Start trip", isLoading: isSubmitting) {
                Task { await startTrip(code: code) }
            }

            SafrSecondaryButton(title: "Scan another driver") {
                onPopToScan()
            }
        }
    }

    @ViewBuilder
    private var tripVerificationContent: some View {
        if let verification = routeData.tripVerification, let tripId = routeData.tripId {
            Text("Confirm the driver identity for this trip.")
                .foregroundStyle(SafrTheme.Colors.textSecondary)

            DriverInfoCard(verification: verification)

            HStack {
                StatusChip(label: verification.trip.isRiderConfirmed ? "Rider confirmed" : "Rider pending", tone: verification.trip.isRiderConfirmed ? .safe : .warning)
                StatusChip(label: verification.trip.isDriverConfirmed ? "Driver confirmed" : "Driver pending", tone: verification.trip.isDriverConfirmed ? .safe : .warning)
            }

            InfoCard(title: "Trip summary") {
                detail("Type", verification.trip.tripType.rawValue.capitalized)
                detail("Started from", verification.trip.startedFrom?.rawValue.replacingOccurrences(of: "_", with: " ").capitalized ?? "—")
                if let count = verification.trip.passengerCount {
                    detail("Passengers", "\(count)")
                }
                if let notes = verification.trip.notes, !notes.isEmpty {
                    detail("Notes", notes)
                }
            }

            SafrTextField(title: "Mismatch notes (optional)", text: $mismatchNotes)

            SafrPrimaryButton(
                title: "Confirm driver",
                isLoading: isSubmitting,
                isDisabled: verification.trip.verifiedAt != nil
            ) {
                Task { await confirmDriver(tripId: tripId, verifiedAt: verification.trip.verifiedAt) }
            }

            SafrSecondaryButton(title: "Report mismatch", isLoading: isSubmitting) {
                Task { await reportMismatch(tripId: tripId) }
            }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(SafrTheme.Colors.textSecondary)
            Spacer()
            Text(value).foregroundStyle(SafrTheme.Colors.textPrimary)
        }
        .font(.subheadline)
    }

    private func startTrip(code: String) async {
        guard let token = session.accessToken else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let trip = try await APIClient.shared.startTripFromQr(
                token: token,
                code: code,
                routeConfirmation: routeConfirmation.isEmpty ? nil : routeConfirmation
            )
            onNavigate(.tripDetails(tripId: trip.id))
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmDriver(tripId: String, verifiedAt: String?) async {
        guard let token = session.accessToken else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let trip = try await APIClient.shared.confirmDriver(token: token, tripId: tripId)
            if verifiedAt == nil, trip.verifiedAt != nil {
                successMessage = "Driver fully verified."
            }
            onNavigate(.tripDetails(tripId: trip.id))
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reportMismatch(tripId: String) async {
        guard let token = session.accessToken else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let trip = try await APIClient.shared.reportTripIssue(
                token: token,
                tripId: tripId,
                message: mismatchNotes.isEmpty ? nil : mismatchNotes
            )
            successMessage = "Issue reported. Safr will review this trip."
            onNavigate(.tripDetails(tripId: trip.id))
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
