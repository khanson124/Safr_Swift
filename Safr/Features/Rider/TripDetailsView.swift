//
//  TripDetailsView.swift
//  Safr
//

import CoreLocation
import SwiftUI
import UIKit

struct TripDetailsView: View {
    @Environment(SessionManager.self) private var session
    @Environment(ConnectivityMonitor.self) private var connectivity

    let tripId: String?
    var isRider: Bool = true

    @State private var viewModel: TripDetailsViewModel
    @State private var reportEvidenceImage: UIImage?
    @State private var imagePickerSource: ImagePickerView.Source?

    init(tripId: String?, isRider: Bool = true) {
        self.tripId = tripId
        self.isRider = isRider
        _viewModel = State(initialValue: TripDetailsViewModel(tripId: tripId, isRider: isRider))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                if let trip = viewModel.trip {
                    banner(for: trip)
                    statusSection(for: trip)
                    mapSection(for: trip)
                    DriverInfoCard(trip: trip)
                    tripInfoSection(for: trip)
                    if isRider {
                        riderActions(for: trip)
                        riderPostTripSections(for: trip)
                    } else {
                        driverActions(for: trip)
                    }
                } else if viewModel.isLoading {
                    SafrLoadingStateView(message: "Loading trip…")
                } else {
                    Text("No trip found.")
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(SafrTheme.Colors.danger).font(.subheadline)
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let notice = viewModel.liveNotice {
                Text(notice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SafrTheme.Colors.background)
                    .padding(.horizontal, SafrTheme.Spacing.md)
                    .padding(.vertical, SafrTheme.Spacing.sm)
                    .background(SafrTheme.Colors.accent)
                    .clipShape(Capsule())
                    .padding(.top, SafrTheme.Spacing.sm)
            }
        }
        .refreshable {
            await viewModel.refresh(session: session, connectivity: connectivity)
        }
        .task {
            viewModel.start(session: session, connectivity: connectivity)
        }
        .onDisappear {
            viewModel.stop()
        }
        .alert(viewModel.alertTitle ?? "", isPresented: alertBinding) {
            Button("OK", role: .cancel) {
                viewModel.alertTitle = nil
                viewModel.alertMessage = nil
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert("Send SOS?", isPresented: $viewModel.showSosConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Send SOS", role: .destructive) {
                SafrHaptics.warning()
                Task { await viewModel.triggerSos(session: session, connectivity: connectivity) }
            }
        } message: {
            Text("This alerts Safr and your emergency contacts if configured.")
        }
        .sheet(isPresented: Binding(
            get: { imagePickerSource != nil },
            set: { isPresented in
                if !isPresented { imagePickerSource = nil }
            }
        )) {
            if let source = imagePickerSource {
                ImagePickerView(source: source) { image in
                    reportEvidenceImage = image
                }
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.alertTitle != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.alertTitle = nil
                    viewModel.alertMessage = nil
                }
            }
        )
    }

    @ViewBuilder
    private func banner(for trip: Trip) -> some View {
        let banner = isRider ? TripStatusHelpers.riderBanner(for: trip) : TripStatusHelpers.driverBanner(for: trip)
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
            Text(banner.kicker.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(banner.tone.foreground)
            Text(banner.title)
                .font(.headline)
                .foregroundStyle(SafrTheme.Colors.textPrimary)
        }
        .padding(SafrTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(banner.tone.background)
        .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
    }

    private func statusSection(for trip: Trip) -> some View {
        let badge = TripStatusHelpers.badge(for: trip)
        return StatusChip(label: badge.label, tone: badge.tone)
    }

    private func mapSection(for trip: Trip) -> some View {
        JourneyMapView(
            origin: coordinate(lat: trip.originLatitude, lng: trip.originLongitude),
            destination: coordinate(lat: trip.destinationLatitude, lng: trip.destinationLongitude),
            driver: coordinate(
                lat: viewModel.driverLocation?.latitude ?? trip.lastLatitude,
                lng: viewModel.driverLocation?.longitude ?? trip.lastLongitude
            )
        )
        .frame(height: 240)
    }

    private func tripInfoSection(for trip: Trip) -> some View {
        InfoCard(title: "Journey") {
            detailRow("From", trip.originAddress)
            detailRow("To", trip.destinationAddress)
            detailRow("Share code", trip.shareCode)
        }
    }

    @ViewBuilder
    private func riderActions(for trip: Trip) -> some View {
        if !trip.status.isTerminal {
            InfoCard(title: "Safety") {
                SafrTextField(title: "SOS message (optional)", text: $viewModel.sosMessage)
                Button {
                    viewModel.showSosConfirm = true
                } label: {
                    Text("Send SOS")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SafrTheme.Spacing.md)
                        .background(SafrTheme.Colors.danger)
                        .foregroundStyle(SafrTheme.Colors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
                }
                .accessibilityLabel("Send emergency SOS alert")

                SafrTextField(title: "Issue details (optional)", text: $viewModel.issueMessage)
                SafrSecondaryButton(title: "Report issue") {
                    Task { await viewModel.reportIssue(session: session) }
                }
            }
        }

        if trip.status == .driverEnded {
            SafrPrimaryButton(title: "Confirm safe arrival", isLoading: viewModel.isLoading) {
                Task { await viewModel.confirmSafeArrival(session: session) }
            }
        }
    }

    @ViewBuilder
    private func riderPostTripSections(for trip: Trip) -> some View {
        if trip.status == .completed,
           let userId = session.user?.id {
            TripFeedbackSection(
                existingFeedback: viewModel.riderFeedback(for: userId),
                rating: $viewModel.feedbackRating,
                comment: $viewModel.feedbackComment,
                selectedTags: $viewModel.feedbackTags,
                isSubmitting: viewModel.isSubmittingFeedback
            ) {
                Task { await viewModel.submitFeedback(session: session) }
            }
        }

        if canFileSafetyReport(trip), let userId = session.user?.id {
            safetyReportSection(existingReport: viewModel.riderSafetyReport(for: userId))
        }
    }

    private func canFileSafetyReport(_ trip: Trip) -> Bool {
        trip.status != .cancelled &&
        [.accepted, .inProgress, .driverEnded, .autoClosed, .completed, .disputed].contains(trip.status)
    }

    @ViewBuilder
    private func safetyReportSection(existingReport: SafetyReport?) -> some View {
        InfoCard(title: "Private safety report") {
            if let existingReport {
                Text("Report submitted: \(existingReport.category.label)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SafrTheme.Colors.textPrimary)
                Text(existingReport.explanation)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
            } else {
                Text("Trip-related evidence only. False reports may be reviewed.")
                    .font(.caption)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)

                Picker("Category", selection: $viewModel.reportCategory) {
                    ForEach(SafetyReportCategory.allCases, id: \.self) { category in
                        Text(category.label).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .tint(SafrTheme.Colors.accent)

                SafrTextField(title: "Explanation (required)", text: $viewModel.reportExplanation)

                DocumentUploadField(
                    label: "Evidence photo (optional)",
                    helper: "One image, up to 8 MB.",
                    previewImage: reportEvidenceImage,
                    fileLabel: reportEvidenceImage == nil ? nil : "Selected evidence",
                    isUploading: viewModel.isSubmittingSafetyReport,
                    onTakePhoto: { imagePickerSource = .camera },
                    onChooseFromLibrary: { imagePickerSource = .photoLibrary },
                    onRemove: { reportEvidenceImage = nil }
                )

                SafrSecondaryButton(
                    title: "Send private report",
                    isLoading: viewModel.isSubmittingSafetyReport
                ) {
                    Task {
                        let data = reportEvidenceImage?.jpegData(compressionQuality: 0.75)
                        await viewModel.submitSafetyReport(
                            session: session,
                            evidenceData: data,
                            fileName: "safety-evidence.jpg",
                            mimeType: "image/jpeg"
                        )
                        if viewModel.riderSafetyReport(for: session.user?.id ?? "") != nil {
                            reportEvidenceImage = nil
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func driverActions(for trip: Trip) -> some View {
        if trip.status == .accepted, trip.verifiedAt != nil {
            SafrPrimaryButton(title: "Start trip", isLoading: viewModel.isLoading) {
                Task { await viewModel.startTrip(session: session) }
            }
        }

        if trip.status == .accepted, trip.verifiedAt == nil {
            if trip.isRiderConfirmed != true {
                Text("Waiting for rider confirmation")
                    .font(.subheadline)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
            }

            if trip.isDriverConfirmed != true, trip.riderId != nil {
                SafrPrimaryButton(title: "Confirm rider", isLoading: viewModel.isLoading) {
                    Task { await viewModel.confirmRider(session: session) }
                }
            }
        }

        if trip.status == .inProgress {
            SafrPrimaryButton(title: "End trip", isLoading: viewModel.isLoading) {
                Task { await viewModel.endTrip(session: session) }
            }
        }

        if !trip.status.isTerminal {
            InfoCard(title: "Safety") {
                SafrTextField(title: "SOS message (optional)", text: $viewModel.sosMessage)
                Button {
                    viewModel.showSosConfirm = true
                } label: {
                    Text("Send SOS")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SafrTheme.Spacing.md)
                        .background(SafrTheme.Colors.danger)
                        .foregroundStyle(SafrTheme.Colors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
                }
                .accessibilityLabel("Send emergency SOS alert")
            }
        }

        if trip.status == .driverEnded {
            Text("Trip ended — waiting for rider to confirm safe arrival.")
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textSecondary)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
            Text(label).font(.caption).foregroundStyle(SafrTheme.Colors.textSecondary)
            Text(value).foregroundStyle(SafrTheme.Colors.textPrimary)
        }
    }

    private func coordinate(lat: Double?, lng: Double?) -> CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
