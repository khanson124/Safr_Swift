//
//  ConnectivityMonitor.swift
//  Safr
//

import Foundation
import Network

@Observable
@MainActor
final class ConnectivityMonitor {
    private(set) var isOnline = true
    private(set) var isSyncing = false
    private(set) var pendingQueueCount = 0
    private(set) var lastSyncNotice: String?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "safr.connectivity")

    func start(session: SessionManager) {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = online
                self.refreshPendingCount(session: session)
                if online, wasOffline {
                    await self.syncIfNeeded(session: session)
                }
            }
        }
        monitor.start(queue: queue)
        refreshPendingCount(session: session)
    }

    func stop() {
        monitor.cancel()
    }

    func refreshPendingCount(session: SessionManager) {
        guard let userId = session.user?.id else {
            pendingQueueCount = 0
            return
        }
        pendingQueueCount = OfflineQueueService.pendingCount(userId: userId)
    }

    func queueOfflineSos(
        session: SessionManager,
        tripId: String,
        message: String?,
        lat: Double?,
        lng: Double?
    ) {
        guard let userId = session.user?.id else { return }
        OfflineQueueService.enqueueSos(
            userId: userId,
            tripId: tripId,
            message: message,
            lat: lat,
            lng: lng
        )
        refreshPendingCount(session: session)
    }

    func hasPendingSos(session: SessionManager, tripId: String) -> Bool {
        guard let userId = session.user?.id else { return false }
        return OfflineQueueService.hasPendingSos(userId: userId, tripId: tripId)
    }

    func clearLastSyncNotice() {
        lastSyncNotice = nil
    }

    func syncIfNeeded(session: SessionManager) async {
        guard isOnline, let token = session.accessToken, let userId = session.user?.id else { return }
        guard pendingQueueCount > 0 else { return }

        isSyncing = true
        defer {
            isSyncing = false
            refreshPendingCount(session: session)
        }

        let result = await OfflineQueueService.syncQueue(token: token, userId: userId)
        if let latest = result.synced.last {
            lastSyncNotice = latest.response.message.isEmpty
                ? "Emergency successfully sent after reconnecting."
                : latest.response.message
        }
    }
}
