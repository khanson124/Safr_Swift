//
//  ResetPasswordView.swift
//  Safr
//

import SwiftUI

struct ResetPasswordView: View {
    let token: String?
    var onSuccess: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var missingToken: Bool {
        guard let token else { return true }
        return token.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
                    Text("Set new password")
                        .font(.largeTitle.bold())
                        .foregroundStyle(SafrTheme.Colors.textPrimary)

                    Text("Choose a strong password for your Safr account.")
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                }

                if missingToken {
                    Text("This reset link is missing a token.")
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.danger)
                } else {
                    VStack(spacing: SafrTheme.Spacing.md) {
                        SafrTextField(
                            title: "New password",
                            text: $password,
                            isSecure: true,
                            textContentType: .newPassword
                        )

                        SafrTextField(
                            title: "Confirm password",
                            text: $confirmPassword,
                            isSecure: true,
                            textContentType: .newPassword
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(SafrTheme.Colors.danger)
                    }

                    SafrPrimaryButton(
                        title: "Update password",
                        isLoading: isSubmitting,
                        isDisabled: !canSubmit
                    ) {
                        Task { await submit() }
                    }
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Reset password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        !missingToken && !password.isEmpty && !confirmPassword.isEmpty
    }

    private func submit() async {
        errorMessage = nil

        if let validationError = PasswordValidator.validationMessage(for: password) {
            errorMessage = validationError
            return
        }

        guard PasswordValidator.passwordsMatch(password, confirmPassword) else {
            errorMessage = "Passwords do not match."
            return
        }

        guard let token, !token.isEmpty else {
            errorMessage = "This reset link is missing a token."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response = try await APIClient.shared.resetPassword(token: token, password: password)
            onSuccess(response.message)
            dismiss()
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ResetPasswordView(token: "preview-token", onSuccess: { _ in })
    }
}
