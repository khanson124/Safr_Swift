//
//  DriverQrView.swift
//  Safr
//

import SwiftUI

struct DriverQrView: View {
    @Environment(SessionManager.self) private var session

    let tripId: String?

    @State private var driverPayload: DriverQrPayload?
    @State private var tripPayload: TripVerificationQrPayload?
    @State private var trip: Trip?
    @State private var isLoading = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var copiedNotice = false

    private var qrValue: String? {
        tripPayload?.qrValue ?? driverPayload?.qrCode.qrValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                if isLoading && qrValue == nil {
                    ProgressView()
                        .tint(SafrTheme.Colors.accent)
                        .frame(maxWidth: .infinity)
                } else if let qrValue {
                    qrSection(qrValue)

                    if let driverPayload {
                        DriverInfoCard(driver: driverPayload.driver)
                    }

                    if let trip {
                        tripSummary(trip)
                    }

                    actionButtons(qrValue: qrValue)
                } else {
                    emptyState
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
        .navigationTitle(tripId == nil ? "Driver QR" : "Trip verification QR")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if copiedNotice {
                Text("Copied to clipboard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SafrTheme.Colors.background)
                    .padding(.horizontal, SafrTheme.Spacing.md)
                    .padding(.vertical, SafrTheme.Spacing.sm)
                    .background(SafrTheme.Colors.accent)
                    .clipShape(Capsule())
                    .padding(.top, SafrTheme.Spacing.sm)
            }
        }
        .task {
            await load()
        }
    }

    @ViewBuilder
    private func qrSection(_ value: String) -> some View {
        VStack(spacing: SafrTheme.Spacing.md) {
            Text(tripId == nil ? "Riders scan this code to verify you." : "Rider scans this to confirm the trip.")
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            QRCodeImageView(value: value)
                .frame(maxWidth: .infinity)
        }
        .padding(SafrTheme.Spacing.md)
        .background(SafrTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
    }

    private func tripSummary(_ trip: Trip) -> some View {
        InfoCard(title: "Trip") {
            detailRow("Type", trip.tripType == .charter ? "Charter" : "Shared")
            detailRow("Route", trip.routeSnapshot ?? "\(trip.originAddress) → \(trip.destinationAddress)")
            detailRow("Status", trip.status.rawValue.capitalized)
        }
    }

    private var emptyState: some View {
        VStack(spacing: SafrTheme.Spacing.md) {
            Text("No QR available yet")
                .font(.headline)
                .foregroundStyle(SafrTheme.Colors.textPrimary)

            Text(errorMessage ?? "Generate a QR code to display for boarding.")
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            SafrPrimaryButton(title: "Generate QR", isLoading: isGenerating) {
                Task { await regenerate() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SafrTheme.Spacing.xl)
    }

    private func actionButtons(qrValue: String) -> some View {
        VStack(spacing: SafrTheme.Spacing.sm) {
            SafrSecondaryButton(title: "Copy code for testing", isLoading: false) {
                UIPasteboard.general.string = qrValue
                copiedNotice = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copiedNotice = false
                }
            }

            SafrPrimaryButton(title: tripId == nil ? "Regenerate QR" : "Refresh verification QR", isLoading: isGenerating) {
                Task { await regenerate() }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
            Text(label).font(.caption).foregroundStyle(SafrTheme.Colors.textSecondary)
            Text(value).foregroundStyle(SafrTheme.Colors.textPrimary)
        }
    }

    private func load() async {
        guard let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            if let tripId {
                async let tripTask = APIClient.shared.getTrip(token: token, tripId: tripId)
                async let qrTask = APIClient.shared.getTripVerificationQr(token: token, tripId: tripId)
                let (loadedTrip, loadedQr) = try await (tripTask, qrTask)
                trip = loadedTrip
                tripPayload = loadedQr
                driverPayload = nil
            } else {
                let payload = try await APIClient.shared.getMyDriverQr(token: token)
                driverPayload = payload
                tripPayload = nil
                trip = nil
            }
        } catch let error as APIError {
            errorMessage = error.message
            driverPayload = nil
            tripPayload = nil
            trip = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func regenerate() async {
        guard let token = session.accessToken else { return }
        isGenerating = true
        defer { isGenerating = false }

        do {
            if let tripId {
                tripPayload = try await APIClient.shared.getTripVerificationQr(token: token, tripId: tripId)
            } else {
                driverPayload = try await APIClient.shared.generateMyDriverQr(token: token)
            }
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        DriverQrView(tripId: nil)
    }
    .environment(SessionManager())
}
