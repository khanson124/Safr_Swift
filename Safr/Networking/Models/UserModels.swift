//
//  UserModels.swift
//  Safr
//

import Foundation

enum UserRole: String, Codable, CaseIterable {
    case rider = "RIDER"
    case driver = "DRIVER"
    case admin = "ADMIN"

    var displayName: String {
        switch self {
        case .rider: "Rider"
        case .driver: "Driver"
        case .admin: "Admin"
        }
    }
}

enum DriverApprovalStatus: String, Codable {
    case pending = "PENDING"
    case underReview = "UNDER_REVIEW"
    case moreInfoRequired = "MORE_INFO_REQUIRED"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    case suspended = "SUSPENDED"

    var displayMessage: String {
        switch self {
        case .pending:
            "Your driver application is pending review."
        case .underReview:
            "Your application is under review."
        case .moreInfoRequired:
            "We need more information to approve your application."
        case .approved:
            "Your application has been approved."
        case .rejected:
            "Your driver application was not approved."
        case .suspended:
            "Your driver account has been suspended."
        }
    }
}

struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
    let fullName: String
    let phoneNumber: String
    let role: UserRole
    var avatarUrl: String?
    var approvalStatus: DriverApprovalStatus?
    var approvalReason: String?
}
