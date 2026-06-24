//
//  SessionManager.swift
//  Safr
//

import Foundation

@Observable
final class SessionManager {
    private enum KeychainKey {
        static let token = "safr.token"
        static let user = "safr.user"
    }

    private let apiClient: APIClient
    private let encoder = JSONEncoder()

    private(set) var user: AuthUser?
    private(set) var isLoading = true
    private(set) var accessToken: String?

    var isAuthenticated: Bool {
        accessToken != nil && user != nil
    }

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }

        guard let token = KeychainHelper.load(for: KeychainKey.token) else {
            clearSessionState()
            return
        }

        do {
            let freshUser = try await apiClient.fetchMe(token: token)
            accessToken = token
            user = freshUser
            persistUser(freshUser)
        } catch {
            clearKeychain()
            clearSessionState()
        }
    }

    func login(email: String, password: String) async throws {
        let response = try await apiClient.login(email: email, password: password)
        applyAuthResponse(response)
    }

    func register(
        email: String,
        password: String,
        fullName: String,
        phoneNumber: String,
        role: RegisterRole
    ) async throws {
        let response: AuthResponse
        switch role {
        case .rider:
            response = try await apiClient.registerRider(
                email: email,
                password: password,
                fullName: fullName,
                phoneNumber: phoneNumber
            )
        case .driver:
            response = try await apiClient.registerDriver(
                email: email,
                password: password,
                fullName: fullName,
                phoneNumber: phoneNumber
            )
        }
        applyAuthResponse(response)
    }

    func socialGoogle(idToken: String) async throws -> SocialAuthResult {
        try await handleSocialResponse(try await apiClient.socialGoogle(idToken: idToken))
    }

    func socialApple(identityToken: String, fullName: String?) async throws -> SocialAuthResult {
        try await handleSocialResponse(
            try await apiClient.socialApple(identityToken: identityToken, fullName: fullName)
        )
    }

    func completeSocialProfile(
        temporaryToken: String,
        role: RegisterRole,
        phoneNumber: String,
        fullName: String
    ) async throws {
        let userRole: UserRole = role == .rider ? .rider : .driver
        let response = try await apiClient.completeSocialProfile(
            temporaryToken: temporaryToken,
            role: userRole,
            phoneNumber: phoneNumber,
            fullName: fullName
        )
        applyAuthResponse(response)
    }

    func refreshUser() async throws {
        guard let token = accessToken else {
            throw APIError(message: "Not signed in.")
        }

        let freshUser = try await apiClient.fetchMe(token: token)
        user = freshUser
        persistUser(freshUser)
    }

    func logout() {
        let authToken = accessToken
        if let authToken {
            Task {
                await PushNotificationService.shared.unregister(authToken: authToken)
            }
        }
        clearKeychain()
        clearSessionState()
    }

    // MARK: - Private

    private func handleSocialResponse(_ response: SocialAuthResponse) throws -> SocialAuthResult {
        switch response {
        case .authenticated(let authResponse):
            applyAuthResponse(authResponse)
            return .authenticated
        case .needsRoleSelection(let pending):
            return .needsRoleSelection(pending)
        }
    }

    private func applyAuthResponse(_ response: AuthResponse) {
        accessToken = response.accessToken
        user = response.user
        KeychainHelper.save(response.accessToken, for: KeychainKey.token)
        persistUser(response.user)
    }

    private func persistUser(_ user: AuthUser) {
        guard let data = try? encoder.encode(user) else { return }
        KeychainHelper.saveData(data, for: KeychainKey.user)
    }

    private func clearKeychain() {
        KeychainHelper.delete(for: KeychainKey.token)
        KeychainHelper.delete(for: KeychainKey.user)
    }

    private func clearSessionState() {
        accessToken = nil
        user = nil
    }
}
