//
//  RealtimeService.swift
//  Safr
//

import Foundation
import SocketIO

@MainActor
final class RealtimeService {
    typealias LocationHandler = (DriverLocationSnapshot) -> Void
    typealias TripEventHandler = (TripRealtimeEvent) -> Void

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var subscribedTripId: String?

    func connect(
        token: String,
        tripId: String,
        onLocation: @escaping LocationHandler,
        onTripEvent: @escaping TripEventHandler
    ) {
        disconnect()

        guard let socketURL = APIConfiguration.trackingSocketURL else { return }

        let manager = SocketManager(
            socketURL: socketURL,
            config: [
                .log(false),
                .compress,
                .forceWebsockets(true),
                .connectParams(["token": token])
            ]
        )
        let socket = manager.socket(forNamespace: "/tracking")

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self else { return }
            socket.emit("subscribe:trip", tripId)
            self.subscribedTripId = tripId
        }

        socket.on("trip:location") { data, _ in
            guard let dict = data.first as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                  let snapshot = try? JSONCoding.decoder.decode(DriverLocationSnapshot.self, from: jsonData) else {
                return
            }
            Task { @MainActor in onLocation(snapshot) }
        }

        for eventName in TripRealtimeEventName.allSubscribed {
            socket.on(eventName.rawValue) { data, _ in
                guard let dict = data.first as? [String: Any],
                      let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                      let event = try? JSONCoding.decoder.decode(TripRealtimeEvent.self, from: jsonData) else {
                    return
                }
                Task { @MainActor in onTripEvent(event) }
            }
        }

        self.manager = manager
        self.socket = socket
        socket.connect()
    }

    func disconnect() {
        socket?.disconnect()
        socket?.removeAllHandlers()
        socket = nil
        manager = nil
        subscribedTripId = nil
    }

    var isConnected: Bool {
        socket?.status == .connected
    }
}
