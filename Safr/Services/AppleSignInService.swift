//
//  AppleSignInService.swift
//  Safr
//

import AuthenticationServices
import UIKit

struct AppleSignInCredential {
    let identityToken: String
    let fullName: String?
}

enum AppleSignInError: Error {
    case cancelled
    case missingIdentityToken
    case failed(String)
}

@MainActor
final class AppleSignInService: NSObject {
    static let shared = AppleSignInService()

    private var continuation: CheckedContinuation<Result<AppleSignInCredential, AppleSignInError>, Never>?

    func signIn() async -> Result<AppleSignInCredential, AppleSignInError> {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(returning: .failure(.missingIdentityToken))
            continuation = nil
            return
        }

        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        continuation?.resume(returning: .success(AppleSignInCredential(
            identityToken: identityToken,
            fullName: fullName.isEmpty ? nil : fullName
        )))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(returning: .failure(.cancelled))
        } else {
            continuation?.resume(returning: .failure(.failed(error.localizedDescription)))
        }
        continuation = nil
    }
}

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: \.isKeyWindow) else {
            return UIWindow()
        }
        return window
    }
}
