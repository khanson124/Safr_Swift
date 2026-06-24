//
//  AuthModels.swift
//  Safr
//

import Foundation

struct AuthResponse: Codable {
    let accessToken: String
    let user: AuthUser
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let fullName: String
    let phoneNumber: String
}

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct MessageResponse: Codable {
    let message: String
}

enum RegisterRole: String, CaseIterable, Identifiable {
    case rider
    case driver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rider: "Rider"
        case .driver: "Driver"
        }
    }
}
