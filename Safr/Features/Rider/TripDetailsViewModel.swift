//
//  TripDetailsViewModel.swift
//  Safr
//

import Foundation

@Observable
@MainActor
final class TripDetailsViewModel {
    var trip: Trip?
    var driverLocation: DriverLocationSnapshot?
    var liveNotice: String?
    var isLoading = false
    var errorMessage: String?
    var sosMessage = ""
    var issueMessage = ""
    var showSosConfirm = false
    var alertTitle: String?
    var alertMessage: String?

    var feedbackRating = 0
    var feedbackComment = ""
    var feedbackTags: Set<TripFeedbackTag> = []
    var reportCategory: SafetyReportCategory = .recklessDriving
    var reportExplanation = ""
    var isSubmittingFeedback = false
    var isSubmittingSafetyReport = false

    private let tripId: String?
    private let isRider: Bool
    private let realtime = RealtimeService()
    private var pollTask: Task<Void, Never>?
    private var locationPollTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?

    private var connectivity: ConnectivityMonitor?

    init(tripId: String?, isRider: Bool) {
        self.tripId = tripId
        self.isRider = isRider
    }

    func start(session: SessionManager, connectivity: ConnectivityMonitor) {
        self.connectivity = connectivity
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.loadTrip(session: session, connectivity: connectivity, silent: false)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, let trip, !trip.status.isTerminal else { continue }
                await loadTrip(session: session, connectivity: connectivity, silent: true)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        locationPollTask?.cancel()
        noticeTask?.cancel()
        realtime.disconnect()
        if !isRider {
            LocationTrackingService.shared.stop()
        }
    }

    func refresh(session: SessionManager, connectivity: ConnectivityMonitor) async {
        await loadTrip(session: session, connectivity: connectivity, silent: false)
    }

    func loadTrip(session: SessionManager, connectivity: ConnectivityMonitor, silent: Bool) async {
        guard let token = session.accessToken, let userId = session.user?.id else { return }

        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }

        do {
            let loaded: Trip?
            if let tripId {
                loaded = try await APIClient.shared.getTrip(token: token, tripId: tripId)
            } else if isRider {
                loaded = try await APIClient.shared.getMyActiveTrip(token: token)
            } else {
                let trips = try await APIClient.shared.listTrips(token: token)
                loaded = trips.first { trip in
                    trip.tripType != .charter &&
                    [.accepted, .inProgress, .driverEnded, .disputed].contains(trip.status)
                }
            }

            if let loaded {
                trip = loaded
                TripCacheService.saveTrip(loaded, userId: userId)
                configureRealtime(session: session, trip: loaded)
                if isRider {
                    startLocationPolling(session: session, tripId: loaded.id)
                } else {
                    locationPollTask?.cancel()
                    updateLocationTracking(session: session, trip: loaded)
                }
            } else if !isRider {
                LocationTrackingService.shared.stop()
            }
            errorMessage = nil
        } catch {
            if let tripId, let cached = TripCacheService.loadTrip(userId: userId, tripId: tripId) {
                trip = cached
            } else if let active = trip?.id, let cached = TripCacheService.loadTrip(userId: userId, tripId: active) {
                trip = cached
            }
            if !silent {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
        }

        if let notice = connectivity.lastSyncNotice {
            showNotice(notice)
            connectivity.clearLastSyncNotice()
        }
    }

    func triggerSos(session: SessionManager, connectivity: ConnectivityMonitor) async {
        guard var currentTrip = trip else { return }
        let lat = driverLocation?.latitude ?? currentTrip.lastLatitude
        let lng = driverLocation?.longitude ?? currentTrip.lastLongitude
        let triggeredAt = JSONCoding.iso8601String()

        if !connectivity.isOnline {
            connectivity.queueOfflineSos(
                session: session,
                tripId: currentTrip.id,
                message: sosMessage.isEmpty ? nil : sosMessage,
                lat: lat,
                lng: lng
            )
            currentTrip.emergencyTriggeredAt = triggeredAt
            if !currentTrip.status.isTerminal {
                currentTrip.status = .disputed
            }
            trip = currentTrip
            alertTitle = "Emergency recorded"
            alertMessage = "You're offline. Safr will send this SOS when connection returns."
            return
        }

        guard let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.triggerTripSos(
                token: token,
                tripId: currentTrip.id,
                request: TripSosRequest(
                    message: sosMessage.isEmpty ? nil : sosMessage,
                    locationLat: lat,
                    locationLng: lng,
                    triggeredAt: triggeredAt,
                    isOfflineTriggered: false
                )
            )
            trip = response.trip
            alertTitle = "SOS sent"
            alertMessage = response.emergencyContactCount == 0
                ? "Emergency alert sent. Add emergency contacts in Profile for faster notifications."
                : response.message
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmSafeArrival(session: SessionManager) async {
        guard isRider, let trip, trip.status == .driverEnded, let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            self.trip = try await APIClient.shared.confirmTripComplete(token: token, tripId: trip.id)
            alertTitle = "Trip confirmed"
            alertMessage = "Thanks for confirming you arrived safely."
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reportIssue(session: SessionManager) async {
        guard isRider, let trip, let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            self.trip = try await APIClient.shared.reportTripIssue(
                token: token,
                tripId: trip.id,
                message: issueMessage.isEmpty ? nil : issueMessage
            )
            alertTitle = "Issue reported"
            alertMessage = "Safr recorded your report for this trip."
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startTrip(session: SessionManager) async {
        guard !isRider, let trip, trip.status == .accepted, trip.verifiedAt != nil,
              let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await APIClient.shared.startTrip(token: token, tripId: trip.id)
            self.trip = updated
            updateLocationTracking(session: session, trip: updated)
            alertTitle = "Trip started"
            alertMessage = "Live location sharing is active."
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func endTrip(session: SessionManager) async {
        guard !isRider, let trip, trip.status == .inProgress, let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await APIClient.shared.endTripByDriver(token: token, tripId: trip.id)
            self.trip = updated
            LocationTrackingService.shared.stop()
            alertTitle = "Trip ended"
            alertMessage = "Waiting for the rider to confirm safe arrival."
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmRider(session: SessionManager) async {
        guard !isRider, let trip, trip.status == .accepted, let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let updated = try await APIClient.shared.confirmRider(token: token, tripId: trip.id)
            self.trip = updated
            if updated.verifiedAt != nil {
                alertTitle = "Trip verified"
                alertMessage = "Both rider and driver have confirmed each other."
                SafrHaptics.success()
            }
            updateLocationTracking(session: session, trip: updated)
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func riderFeedback(for userId: String) -> TripFeedback? {
        trip?.feedbacks?.first { $0.riderId == userId }
    }

    func riderSafetyReport(for userId: String) -> SafetyReport? {
        trip?.safetyReports?.first { $0.riderId == userId }
    }

    func submitFeedback(session: SessionManager) async {
        guard isRider, let trip, trip.status == .completed, let token = session.accessToken else { return }
        guard feedbackRating >= 1 else { return }

        isSubmittingFeedback = true
        defer { isSubmittingFeedback = false }

        do {
            let response = try await APIClient.shared.submitTripFeedback(
                token: token,
                tripId: trip.id,
                request: TripFeedbackRequest(
                    rating: feedbackRating,
                    comment: feedbackComment.isEmpty ? nil : feedbackComment,
                    tags: feedbackTags.isEmpty ? nil : Array(feedbackTags)
                )
            )
            self.trip = response.trip
            alertTitle = "Feedback submitted"
            alertMessage = "Thanks for helping Safr improve rider safety."
            SafrHaptics.success()
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitSafetyReport(
        session: SessionManager,
        evidenceData: Data?,
        fileName: String,
        mimeType: String
    ) async {
        guard isRider, let trip, trip.status != .cancelled, let token = session.accessToken else { return }
        let explanation = reportExplanation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !explanation.isEmpty else {
            errorMessage = "Explain what happened before submitting a safety report."
            return
        }

        isSubmittingSafetyReport = true
        defer { isSubmittingSafetyReport = false }

        do {
            var evidence: [SafetyReportEvidenceInput]?
            if let evidenceData {
                let signature = try await APIClient.shared.getTripReportUploadSignature(token: token, tripId: trip.id)
                let secureURL = try await CloudinaryUploadService.upload(
                    signature: signature,
                    imageData: evidenceData,
                    fileName: fileName,
                    mimeType: mimeType
                )
                evidence = [
                    SafetyReportEvidenceInput(
                        fileUrl: secureURL,
                        mimeType: mimeType,
                        fileSizeBytes: evidenceData.count,
                        originalFileName: fileName
                    )
                ]
            }

            let response = try await APIClient.shared.submitTripSafetyReport(
                token: token,
                tripId: trip.id,
                request: TripSafetyReportRequest(
                    category: reportCategory,
                    explanation: explanation,
                    evidence: evidence
                )
            )
            self.trip = response.trip
            reportExplanation = ""
            alertTitle = "Report submitted"
            alertMessage = response.message
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateLocationTracking(session: SessionManager, trip: Trip) {
        guard !isRider, let token = session.accessToken else {
            LocationTrackingService.shared.stop()
            return
        }

        if [.accepted, .inProgress].contains(trip.status), !trip.status.isTerminal {
            Task {
                try? await LocationTrackingService.shared.start(token: token, tripId: trip.id)
            }
        } else {
            LocationTrackingService.shared.stop()
        }
    }

    private func configureRealtime(session: SessionManager, trip: Trip) {
        guard !trip.status.isTerminal, let token = session.accessToken else {
            realtime.disconnect()
            return
        }

        realtime.connect(token: token, tripId: trip.id) { [weak self] snapshot in
            guard let self else { return }
            self.driverLocation = snapshot
            if var current = self.trip {
                current.lastLatitude = snapshot.latitude
                current.lastLongitude = snapshot.longitude
                current.lastLocationUpdatedAt = snapshot.updatedAt
                self.trip = current
            }
            if let userId = session.user?.id {
                TripCacheService.saveLocation(snapshot, userId: userId, tripId: trip.id)
            }
        } onTripEvent: { [weak self] event in
            guard let self, event.tripId == trip.id else { return }
            if let body = event.body, !body.isEmpty {
                self.showNotice(body)
            }
            guard let connectivity = self.connectivity else { return }
            Task { await self.loadTrip(session: session, connectivity: connectivity, silent: true) }
        }
    }

    private func startLocationPolling(session: SessionManager, tripId: String) {
        locationPollTask?.cancel()
        locationPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self, let token = session.accessToken, let trip = self.trip,
                      [.accepted, .inProgress].contains(trip.status) else { continue }
                if let snapshot = try? await APIClient.shared.getTripLocation(token: token, tripId: tripId) {
                    self.driverLocation = snapshot
                }
            }
        }
    }

    private func showNotice(_ message: String) {
        liveNotice = message
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            self?.liveNotice = nil
        }
    }
}
