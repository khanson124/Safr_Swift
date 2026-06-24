//
//  FeedbackModels.swift
//  Safr
//

import Foundation

enum TripFeedbackTag: String, Codable, CaseIterable {
    case safeDriving = "SAFE_DRIVING"
    case respectful = "RESPECTFUL"
    case cleanVehicle = "CLEAN_VEHICLE"
    case routeIssue = "ROUTE_ISSUE"
    case overcharging = "OVERCHARGING"
    case recklessDriving = "RECKLESS_DRIVING"

    var label: String {
        switch self {
        case .safeDriving: "Safe driving"
        case .respectful: "Respectful"
        case .cleanVehicle: "Clean vehicle"
        case .routeIssue: "Route issue"
        case .overcharging: "Overcharging"
        case .recklessDriving: "Reckless driving"
        }
    }
}

enum SafetyReportCategory: String, Codable, CaseIterable {
    case recklessDriving = "RECKLESS_DRIVING"
    case dangerousBehavior = "DANGEROUS_BEHAVIOR"
    case vehicleMismatch = "VEHICLE_MISMATCH"
    case harassment = "HARASSMENT"
    case routeDeviation = "ROUTE_DEVIATION"
    case overcharging = "OVERCHARGING"
    case other = "OTHER"

    var label: String {
        switch self {
        case .recklessDriving: "Reckless driving"
        case .dangerousBehavior: "Dangerous behavior"
        case .vehicleMismatch: "Vehicle mismatch"
        case .harassment: "Harassment"
        case .routeDeviation: "Route deviation"
        case .overcharging: "Overcharging"
        case .other: "Other"
        }
    }
}

enum SafetyReportOutcome: String, Codable {
    case pendingReview = "PENDING_REVIEW"
    case substantiated = "SUBSTANTIATED"
    case unsubstantiated = "UNSUBSTANTIATED"
    case abusiveFalse = "ABUSIVE_FALSE"
}

struct TripFeedback: Codable, Equatable, Identifiable {
    let id: String
    let tripId: String
    let riderId: String
    var driverProfileId: String?
    let rating: Int
    var comment: String?
    var tags: [TripFeedbackTag]?
    let createdAt: String
}

struct SafetyEvidence: Codable, Equatable, Identifiable {
    let id: String
    let fileUrl: String
    let mimeType: String
    var fileSizeBytes: Int?
    var originalFileName: String?
    let moderationStatus: String
    var moderationReason: String?
    let createdAt: String
}

struct SafetyReport: Codable, Equatable, Identifiable {
    let id: String
    let tripId: String
    let riderId: String
    var driverProfileId: String?
    let category: SafetyReportCategory
    let explanation: String
    let outcome: SafetyReportOutcome
    var adminNotes: String?
    var reviewedAt: String?
    let createdAt: String
    var evidence: [SafetyEvidence]?
}

struct SignedUploadSignature: Codable, Equatable {
    let cloudName: String
    let apiKey: String
    let folder: String
    let timestamp: Int
    let signature: String
}

struct CreateTripRequest: Encodable {
    let pickupLocation: String
    let destination: String
    var tripType: TripType?
    var originLatitude: Double?
    var originLongitude: Double?
    var destinationLatitude: Double?
    var destinationLongitude: Double?
}

struct ManualMonitoringRequest: Encodable {
    var pickupLocation: String?
    var destination: String?
    var driverName: String?
    var plateNumber: String?
    var vehicleDescription: String?
    var routeDetails: String?
    var originLatitude: Double?
    var originLongitude: Double?
    var destinationLatitude: Double?
    var destinationLongitude: Double?
}

struct TripStatusUpdateRequest: Encodable {
    let status: TripStatus
}

struct TripFeedbackRequest: Encodable {
    let rating: Int
    var comment: String?
    var tags: [TripFeedbackTag]?
}

struct SafetyReportEvidenceInput: Encodable {
    let fileUrl: String
    let mimeType: String
    var fileSizeBytes: Int?
    var originalFileName: String?
}

struct TripSafetyReportRequest: Encodable {
    let category: SafetyReportCategory
    let explanation: String
    var evidence: [SafetyReportEvidenceInput]?
}

struct TripFeedbackResponse: Codable {
    let trip: Trip
    let feedback: TripFeedback
}

struct TripSafetyReportResponse: Codable {
    let trip: Trip
    let report: SafetyReport
    let message: String
}

struct RegisterDeviceRequest: Encodable {
    var expoPushToken: String?
    var apnsDeviceToken: String?
    let platform: String
}

struct UnregisterDeviceRequest: Encodable {
    var expoPushToken: String?
    var apnsDeviceToken: String?
}

struct RegisterDeviceResponse: Codable {
    let success: Bool
    let deviceId: String
    var expoPushToken: String?
}

struct UnregisterDeviceResponse: Codable {
    let success: Bool
    var expoPushToken: String?
}

struct CloudinaryUploadResponse: Decodable {
    let secureUrl: String

    enum CodingKeys: String, CodingKey {
        case secureUrl = "secure_url"
    }
}

struct CloudinaryErrorResponse: Decodable {
    struct CloudinaryError: Decodable {
        let message: String?
    }

    let error: CloudinaryError?
}
