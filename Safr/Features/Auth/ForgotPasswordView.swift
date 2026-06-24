//
//  ForgotPasswordView.swift
//  Safr
//

import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
                    Text("Reset password")
                        .font(.largeTitle.bold())
                        .foregroundStyle(SafrTheme.Colors.textPrimary)

                    Text("Enter your email and we'll send reset instructions.")
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                }

                SafrTextField(
                    title: "Email",
                    text: $email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.danger)
                }

                if let successMessage {
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.success)
                }

                SafrPrimaryButton(
                    title: "Send reset link",
                    isLoading: isSubmitting,
                    isDisabled: email.isEmpty
                ) {
                    Task { await submit() }
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Forgot password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        errorMessage = nil
        successMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response = try await APIClient.shared.forgotPassword(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            successMessage = response.message
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
}
