//
//  TripModels.swift
//  Safr
//

import Foundation

enum TripStatus: String, Codable, CaseIterable {
    case requested = "REQUESTED"
    case accepted = "ACCEPTED"
    case inProgress = "IN_PROGRESS"
    case driverEnded = "DRIVER_ENDED"
    case disputed = "DISPUTED"
    case autoClosed = "AUTO_CLOSED"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"

    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .autoClosed: true
        default: false
        }
    }

    var isActiveMonitoring: Bool {
        switch self {
        case .accepted, .inProgress, .driverEnded, .disputed: true
        default: false
        }
    }
}

enum TripType: String, Codable {
    case shared = "SHARED"
    case charter = "CHARTER"
}

enum TripInitiatedBy: String, Codable {
    case driver = "DRIVER"
    case rider = "RIDER"
    case system = "SYSTEM"
}

enum TripStartedFrom: String, Codable {
    case taxiStand = "TAXI_STAND"
    case roadside = "ROADSIDE"
    case charter = "CHARTER"
    case other = "OTHER"
}

enum IncidentType: String, Codable {
    case sos = "SOS"
    case report = "REPORT"
    case harassment = "HARASSMENT"
    case accident = "ACCIDENT"
    case other = "OTHER"
}

enum IncidentStatus: String, Codable {
    case active = "ACTIVE"
    case acknowledged = "ACKNOWLEDGED"
    case escalated = "ESCALATED"
    case resolved = "RESOLVED"
}

enum TripRealtimeEventName: String, Codable {
    case tripCreated = "trip.created"
    case tripInitiated = "trip.initiated"
    case tripUpdated = "trip.updated"
    case tripConfirmedRider = "trip.confirmed.rider"
    case tripConfirmedDriver = "trip.confirmed.driver"
    case tripVerified = "trip.verified"
    case tripStarted = "trip.started"
    case tripDriverEnded = "trip.driverEnded"
    case tripCompleted = "trip.completed"
    case tripCancelled = "trip.cancelled"
    case safetyIssueReported = "safety.issueReported"
    case safetySos = "safety.sos"

    static let allSubscribed: [TripRealtimeEventName] = [
        .tripCreated, .tripInitiated, .tripUpdated, .tripConfirmedRider,
        .tripConfirmedDriver, .tripVerified, .tripStarted, .tripDriverEnded,
        .tripCompleted, .tripCancelled, .safetyIssueReported, .safetySos
    ]
}

struct TripIncidentSummary: Codable, Equatable {
    let id: String
    let type: IncidentType
    let status: IncidentStatus
}

struct DriverProfileSummary: Codable, Equatable {
    let id: String
    let status: DriverApprovalStatus?
    let vehicleMake: String?
    let vehicleModel: String?
    let vehicleColor: String?
    let plateNumber: String?
    let serviceRoute: String?
    let originArea: String?
    let destinationArea: String?
    let user: AuthUser?
}

struct VehicleSummary: Codable, Equatable {
    let id: String
    let make: String
    let model: String
    let color: String
    let plateNumber: String
}

struct Trip: Codable, Equatable, Identifiable {
    let id: String
    var riderId: String?
    let shareCode: String
    var status: TripStatus
    let tripType: TripType
    let initiatedBy: TripInitiatedBy
    var startedFrom: TripStartedFrom?
    var passengerCount: Int?
    var notes: String?
    var isActive: Bool?
    var startedFromQr: Bool?
    var routeSnapshot: String?
    var vehicleMakeSnapshot: String?
    var vehicleModelSnapshot: String?
    var vehicleColorSnapshot: String?
    var plateNumberSnapshot: String?
    let originAddress: String
    let destinationAddress: String
    var originLatitude: Double?
    var originLongitude: Double?
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var lastLatitude: Double?
    var lastLongitude: Double?
    var lastLocationUpdatedAt: String?
    let requestedAt: String
    var acceptedAt: String?
    var startedAt: String?
    var isRiderConfirmed: Bool?
    var isDriverConfirmed: Bool?
    var verifiedAt: String?
    var verificationToken: String?
    var verificationTokenExpiresAt: String?
    var endedByDriverAt: String?
    var endedByRiderAt: String?
    var autoClosedAt: String?
    var driverEndedLatitude: Double?
    var driverEndedLongitude: Double?
    var driverEndedAccuracy: Double?
    var riderConfirmedSafe: Bool?
    var completionTimeoutAt: String?
    var completedAt: String?
    var endedAt: String?
    var emergencyTriggeredAt: String?
    var rider: AuthUser?
    var driverProfile: DriverProfileSummary?
    var vehicle: VehicleSummary?
    var incidents: [TripIncidentSummary]?
    var feedbacks: [TripFeedback]?
    var safetyReports: [SafetyReport]?

    var hasActiveSos: Bool {
        incidents?.contains { $0.type == .sos && $0.status == .active } == true
    }

    var hasOpenIssue: Bool {
        incidents?.contains {
            $0.type != .sos && [.active, .acknowledged, .escalated].contains($0.status)
        } == true
    }
}

struct DriverLocationSnapshot: Codable, Equatable, Hashable {
    let driverId: String?
    let tripId: String?
    let latitude: Double
    let longitude: Double
    var accuracy: Double?
    var speed: Double?
    var heading: Double?
    let updatedAt: String
}

struct TripRealtimeEvent: Codable {
    let event: TripRealtimeEventName
    let tripId: String
    var status: TripStatus?
    var isRiderConfirmed: Bool?
    var isDriverConfirmed: Bool?
    var verifiedAt: String?
    var emergencyTriggeredAt: String?
    var incidentId: String?
    var incidentType: IncidentType?
    var title: String?
    var body: String?
    let timestamp: String
}

struct TripSosRequest: Encodable {
    var message: String?
    var locationLat: Double?
    var locationLng: Double?
    var triggeredAt: String?
    var isOfflineTriggered: Bool?
}

struct TripSosResponse: Codable {
    let success: Bool
    let incidentId: String
    let emergencyContactCount: Int
    var contactsNotifiedCount: Int?
    var trackingUrl: String?
    let message: String
    let trip: Trip
}

struct StartTripFromQrRequest: Encodable {
    let code: String
    var routeConfirmation: String?
}

struct TripVerifyRequest: Encodable {
    let tripId: String
    let verificationToken: String
}

struct ConfirmDriverRequest: Encodable {
    let tripId: String
}

struct ReportIssueRequest: Encodable {
    var message: String?
}

extension Trip {
    static func isRoadsideMonitoring(_ trip: Trip) -> Bool {
        trip.tripType != .charter && trip.status.isActiveMonitoring
    }
}
