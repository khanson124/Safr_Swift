//
//  SocialModels.swift
//  Safr
//

import Foundation

enum SocialProvider: String, Codable {
    case google = "GOOGLE"
    case apple = "APPLE"
}

struct SocialProfile: Codable, Equatable {
    let email: String
    let fullName: String
    let provider: SocialProvider
}

struct SocialAuthPendingResponse: Codable, Equatable, Identifiable {
    let needsRoleSelection: Bool
    let socialProfile: SocialProfile
    let temporaryToken: String

    var id: String { temporaryToken }
}

enum SocialAuthResponse {
    case authenticated(AuthResponse)
    case needsRoleSelection(SocialAuthPendingResponse)
}

enum SocialAuthResult: Equatable {
    case authenticated
    case needsRoleSelection(SocialAuthPendingResponse)
}

struct SocialGoogleRequest: Encodable {
    let idToken: String
}

struct SocialAppleRequest: Encodable {
    let identityToken: String
    let fullName: String?
}

struct CompleteSocialProfileRequest: Encodable {
    let temporaryToken: String
    let role: UserRole
    let phoneNumber: String
    let fullName: String
}

struct ResetPasswordRequest: Encodable {
    let token: String
    let password: String
}
