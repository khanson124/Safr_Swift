//
//  LoginView.swift
//  Safr
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(SessionManager.self) private var session

    @Binding var successMessage: String?

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var isSocialLoading = false
    @State private var errorMessage: String?
    @State private var pendingSocial: SocialAuthPendingResponse?

    init(successMessage: Binding<String?> = .constant(nil)) {
        _successMessage = successMessage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
                    Text("Welcome back")
                        .font(.largeTitle.bold())
                        .foregroundStyle(SafrTheme.Colors.textPrimary)

                    Text("Sign in to continue with Safr")
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                }

                socialButtons

                HStack {
                    Rectangle().fill(SafrTheme.Colors.textSecondary.opacity(0.25)).frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                    Rectangle().fill(SafrTheme.Colors.textSecondary.opacity(0.25)).frame(height: 1)
                }

                VStack(spacing: SafrTheme.Spacing.md) {
                    SafrTextField(
                        title: "Email",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )

                    SafrTextField(
                        title: "Password",
                        text: $password,
                        isSecure: true,
                        textContentType: .password
                    )
                }

                if let successMessage {
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.success)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.danger)
                }

                SafrPrimaryButton(
                    title: "Sign In",
                    isLoading: isSubmitting,
                    isDisabled: email.isEmpty || password.isEmpty || isSocialLoading
                ) {
                    Task { await signIn() }
                }

                HStack {
                    NavigationLink("Create account") {
                        RegisterView()
                    }
                    Spacer()
                    NavigationLink("Forgot password?") {
                        ForgotPasswordView()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.accent)
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isSocialLoading)
        .sheet(item: $pendingSocial) { pending in
            SocialRoleCompletionView(pending: pending)
        }
        .onChange(of: successMessage) { _, newValue in
            if newValue != nil {
                errorMessage = nil
            }
        }
    }

    private var socialButtons: some View {
        VStack(spacing: SafrTheme.Spacing.sm) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await handleAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
            .disabled(isSubmitting || isSocialLoading)

            if GoogleSignInConfiguration.isConfigured {
                SafrSecondaryButton(title: isSocialLoading ? "Signing in…" : "Continue with Google") {
                    Task { await signInWithGoogle() }
                }
                .disabled(isSubmitting || isSocialLoading)
            } else {
                SafrSecondaryButton(title: "Continue with Google") {}
                    .disabled(true)
                    .opacity(0.5)

                #if DEBUG
                Text("Set GIDClientID in Info.plist to enable Google Sign-In")
                    .font(.caption)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                #endif
            }
        }
    }

    private func signIn() async {
        errorMessage = nil
        successMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await session.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signInWithGoogle() async {
        errorMessage = nil
        successMessage = nil
        isSocialLoading = true
        defer { isSocialLoading = false }

        do {
            let idToken = try await GoogleSignInService.signIn()
            try await handleSocialResult(try await session.socialGoogle(idToken: idToken))
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        successMessage = nil

        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple Sign-In did not return an identity token."
                return
            }

            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            isSocialLoading = true
            defer { isSocialLoading = false }

            do {
                try await handleSocialResult(try await session.socialApple(
                    identityToken: identityToken,
                    fullName: fullName.isEmpty ? nil : fullName
                ))
            } catch let error as APIError {
                errorMessage = error.message
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleSocialResult(_ result: SocialAuthResult) async throws {
        switch result {
        case .authenticated:
            break
        case .needsRoleSelection(let pending):
            pendingSocial = pending
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environment(SessionManager())
}
