//
//  GoogleSignInService.swift
//  Safr
//

import GoogleSignIn
import UIKit

enum GoogleSignInService {
    private static var isConfigured = false

    @MainActor
    static func configureIfNeeded() {
        guard !isConfigured,
              let clientID = GoogleSignInConfiguration.clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        isConfigured = true
    }

    @MainActor
    static func signIn() async throws -> String {
        guard GoogleSignInConfiguration.isConfigured else {
            throw APIError(message: "Google Sign-In is not configured.")
        }

        configureIfNeeded()

        guard let presenting = rootViewController() else {
            throw APIError(message: "Unable to present Google Sign-In.")
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)

        guard let idToken = result.user.idToken?.tokenString else {
            throw APIError(message: "Google did not return an ID token.")
        }

        return idToken
    }

    @MainActor
    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
