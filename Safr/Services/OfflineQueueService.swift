//
//  OfflineQueueService.swift
//  Safr
//

import Foundation

struct OfflineQueueItem: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case sos = "SOS"
    }

    let id: String
    let kind: Kind
    let userId: String
    let tripId: String
    var message: String?
    var locationLat: Double?
    var locationLng: Double?
    let triggeredAt: String
    var retryCount: Int
    var nextRetryAt: String?
    var lastError: String?
}

struct OfflineSyncResult {
    let item: OfflineQueueItem
    let response: TripSosResponse
}

enum OfflineQueueService {
    private static let storageKey = "safr.offline.queue"
    private static let retryBaseDelay: TimeInterval = 15
    private static let retryMaxDelay: TimeInterval = 300

    static func listQueue() -> [OfflineQueueItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONCoding.decoder.decode([OfflineQueueItem].self, from: data) else {
            return []
        }
        return items
    }

    private static func writeQueue(_ queue: [OfflineQueueItem]) {
        guard let data = try? JSONCoding.encoder.encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    @discardableResult
    static func enqueueSos(
        userId: String,
        tripId: String,
        message: String?,
        lat: Double?,
        lng: Double?,
        triggeredAt: String = JSONCoding.iso8601String()
    ) -> OfflineQueueItem {
        var queue = listQueue()
        let item = OfflineQueueItem(
            id: "offline_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))",
            kind: .sos,
            userId: userId,
            tripId: tripId,
            message: message,
            locationLat: lat,
            locationLng: lng,
            triggeredAt: triggeredAt,
            retryCount: 0,
            nextRetryAt: nil,
            lastError: nil
        )
        queue.insert(item, at: 0)
        writeQueue(queue)
        return item
    }

    static func hasPendingSos(userId: String, tripId: String) -> Bool {
        listQueue().contains { $0.userId == userId && $0.tripId == tripId && $0.kind == .sos }
    }

    static func pendingCount(userId: String) -> Int {
        listQueue().filter { $0.userId == userId }.count
    }

    static func syncQueue(token: String, userId: String) async -> (synced: [OfflineSyncResult], pending: [OfflineQueueItem]) {
        let queue = listQueue()
        var synced: [OfflineSyncResult] = []
        var remaining: [OfflineQueueItem] = []
        let now = Date()

        for var item in queue {
            if item.userId != userId {
                remaining.append(item)
                continue
            }

            if let nextRetryAt = item.nextRetryAt,
               let retryDate = ISO8601DateFormatter().date(from: nextRetryAt),
               retryDate > now {
                remaining.append(item)
                continue
            }

            do {
                let response = try await APIClient.shared.triggerTripSos(
                    token: token,
                    tripId: item.tripId,
                    request: TripSosRequest(
                        message: item.message,
                        locationLat: item.locationLat,
                        locationLng: item.locationLng,
                        triggeredAt: item.triggeredAt,
                        isOfflineTriggered: true
                    )
                )
                synced.append(OfflineSyncResult(item: item, response: response))
            } catch {
                item.retryCount += 1
                let delay = min(retryBaseDelay * pow(2.0, Double(item.retryCount)), retryMaxDelay)
                item.nextRetryAt = JSONCoding.iso8601String(from: now.addingTimeInterval(delay))
                item.lastError = (error as? APIError)?.message ?? error.localizedDescription
                remaining.append(item)
            }
        }

        writeQueue(remaining)
        return (synced, remaining)
    }
}
