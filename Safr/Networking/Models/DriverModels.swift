//
//  DriverModels.swift
//  Safr
//

import Foundation

struct DriverProfile: Codable, Equatable {
    let id: String
    var status: DriverApprovalStatus?
    var licenseNumber: String?
    var licenseImageUrl: String?
    var licenseExpiryDate: String?
    var governmentIdImageUrl: String?
    var vehicleMake: String?
    var vehicleModel: String?
    var vehicleColor: String?
    var plateNumber: String?
    var vehiclePhotoUrl: String?
    var serviceArea: String?
    var taxiType: DriverTaxiType?
    var serviceRoute: String?
    var originArea: String?
    var destinationArea: String?
    var verificationNotes: String?
    var reviewReason: String?
    var user: AuthUser?
    var vehicles: [VehicleSummary]?
    var reviewSummary: DriverReviewSummary?
}

enum DriverTaxiType: String, Codable, CaseIterable {
    case route = "ROUTE"
    case charter = "CHARTER"
    case both = "BOTH"

    var label: String {
        switch self {
        case .route: "Route taxi"
        case .charter: "Charter only"
        case .both: "Both"
        }
    }
}

struct DriverReviewSummary: Codable, Equatable {
    var missingFields: [String]?
    var isComplete: Bool?
    var completionLabel: String?
    var checklist: [DriverReviewChecklistItem]?
}

struct DriverReviewChecklistItem: Codable, Equatable, Identifiable {
    let key: String
    let label: String
    let complete: Bool
    let summary: String

    var id: String { key }
}

struct UpdateDriverProfileRequest: Encodable {
    var licenseNumber: String?
    var licenseImageUrl: String?
    var licenseExpiryDate: String?
    var governmentIdImageUrl: String?
    var vehicleMake: String?
    var vehicleModel: String?
    var vehicleColor: String?
    var plateNumber: String?
    var vehiclePhotoUrl: String?
    var serviceArea: String?
    var taxiType: DriverTaxiType?
    var serviceRoute: String?
    var originArea: String?
    var destinationArea: String?
}

struct DriverQrCode: Codable, Equatable {
    let code: String
    let qrValue: String
    let updatedAt: String
}

struct DriverQrPayload: Codable, Equatable {
    let qrCode: DriverQrCode
    let driver: DriverVerificationDriver
}

struct TripVerificationQrPayload: Codable, Equatable {
    let tripId: String
    let verificationToken: String
    var verificationTokenExpiresAt: String?
    let qrValue: String
}

struct ActivePassengerSession: Codable, Equatable, Identifiable {
    let tripId: String
    let tripSessionId: String
    let status: TripStatus
    var startedAt: String?
    let requestedAt: String
    var routeSnapshot: String?
    let startedFromQr: Bool
    let sosActive: Bool
    let passenger: ActivePassenger

    var id: String { tripSessionId }
}

struct ActivePassenger: Codable, Equatable {
    let id: String
    let firstName: String
    let fullName: String
    var avatarUrl: String?
}

struct EmergencyContact: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let phoneNumber: String
    var relationship: String?
    var isPrimary: Bool?
    var createdAt: String?
    var updatedAt: String?
}

struct AddEmergencyContactRequest: Encodable {
    let name: String
    let phoneNumber: String
    var relationship: String?
    var isPrimary: Bool?
}

struct DeleteEmergencyContactResponse: Codable {
    let success: Bool
    let deletedContactId: String
}

struct ManualStartTripRequest: Encodable {
    let tripType: TripType
    let startedFrom: TripStartedFrom
    var passengerCount: Int?
    var notes: String?
}

struct ConfirmRiderRequest: Encodable {
    let tripId: String
}

struct DriverLocationPost: Encodable {
    let tripId: String
    let latitude: Double
    let longitude: Double
    var accuracy: Double?
    var speed: Double?
    var heading: Double?
}

enum DriverRoute: Hashable {
    case driverQr(tripId: String?)
    case tripDetails(tripId: String?)
    case charterRequests
    case charterDetail(tripId: String)
    case driverApplication
    case driverSafety
}

enum PendingDriverRoute: Hashable {
    case driverApplication
    case profilePhoto
}
