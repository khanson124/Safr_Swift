//
//  VerificationModels.swift
//  Safr
//

import Foundation

struct DriverVerificationDriver: Codable, Equatable, Hashable {
    let id: String
    let displayName: String
    var avatarUrl: String?
    var vehicleMake: String?
    var vehicleModel: String?
    var vehicleColor: String?
    var plateNumber: String?
    var routeName: String?
    var originArea: String?
    var destinationArea: String?
    let approvalStatus: DriverApprovalStatus
    let badgeNumber: String
}

struct DriverVerificationPayload: Codable, Equatable, Hashable {
    let driver: DriverVerificationDriver
}

struct TripVerificationDriver: Codable, Equatable, Hashable {
    let fullName: String
    var photoUrl: String?
    var vehicleMake: String?
    var vehicleModel: String?
    var vehicleColor: String?
    var plateNumber: String?
    let isApproved: Bool
}

struct TripVerificationTrip: Codable, Equatable, Hashable {
    let id: String
    let status: TripStatus
    let tripType: TripType
    let initiatedBy: TripInitiatedBy
    var startedFrom: TripStartedFrom?
    var passengerCount: Int?
    var notes: String?
    var riderId: String?
    let isRiderConfirmed: Bool
    let isDriverConfirmed: Bool
    var verifiedAt: String?
}

struct TripVerificationPayload: Codable, Equatable, Hashable {
    let driver: TripVerificationDriver
    let trip: TripVerificationTrip
}

enum VerificationMode: Hashable {
    case driverQr(code: String, verification: DriverVerificationPayload)
    case tripVerification(tripId: String, verification: TripVerificationPayload)
}

struct VerificationRouteData: Hashable {
    let mode: Mode
    let code: String?
    let tripId: String?
    private let payloadData: Data

    enum Mode: String, Hashable, Codable {
        case driverQr
        case tripVerification
    }

    init(driverQr code: String, verification: DriverVerificationPayload) throws {
        mode = .driverQr
        self.code = code
        tripId = nil
        payloadData = try JSONCoding.encoder.encode(verification)
    }

    init(tripVerification tripId: String, verification: TripVerificationPayload) throws {
        mode = .tripVerification
        code = nil
        self.tripId = tripId
        payloadData = try JSONCoding.encoder.encode(verification)
    }

    var driverVerification: DriverVerificationPayload? {
        guard mode == .driverQr else { return nil }
        return try? JSONCoding.decoder.decode(DriverVerificationPayload.self, from: payloadData)
    }

    var tripVerification: TripVerificationPayload? {
        guard mode == .tripVerification else { return nil }
        return try? JSONCoding.decoder.decode(TripVerificationPayload.self, from: payloadData)
    }
}

enum RiderRoute: Hashable {
    case scanQr
    case verification(VerificationRouteData)
    case tripDetails(tripId: String?)
    case charter
}

enum VerificationErrorMapper {
    static func map(_ error: Error, source: ScanSource) -> (title: String, detail: String) {
        let message = (error as? APIError)?.message.lowercased() ?? error.localizedDescription.lowercased()

        if message.contains("not valid") || message.contains("invalid") {
            return ("Invalid or expired code", "Ask the driver to refresh their QR code and try again.")
        }
        if message.contains("not approved") {
            return ("Driver not approved", "This driver is not approved for verification yet.")
        }
        if message.contains("network") || message.contains("unable to reach") || message.contains("cannot reach") {
            return ("Network issue", "Check your connection and try again.")
        }
        if message.contains("current trip") || message.contains("active trip") {
            return ("Trip already active", "Finish or leave your current trip before starting another.")
        }

        switch source {
        case .camera:
            return ("Unable to verify driver", "Scan failed. Try again or enter the code manually.")
        case .manual:
            return ("Unable to verify driver", "Check the code and try again.")
        }
    }

    static func mapParseFailure(source: ScanSource) -> (title: String, detail: String) {
        switch source {
        case .camera:
            return ("Invalid or expired code", "This QR code is not a valid Safr driver or trip verification code.")
        case .manual:
            return ("Invalid or expired code", "Paste a valid driver code or trip verification link.")
        }
    }
}

enum ScanSource {
    case camera
    case manual
}
