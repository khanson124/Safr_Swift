//
//  RegisterView.swift
//  Safr
//

import SwiftUI

struct RegisterView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var selectedRole: RegisterRole = .rider
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
                    Text("Create account")
                        .font(.largeTitle.bold())
                        .foregroundStyle(SafrTheme.Colors.textPrimary)

                    Text("Join Safr as a rider or driver")
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                }

                VStack(spacing: SafrTheme.Spacing.md) {
                    SafrTextField(title: "Full name", text: $fullName, textContentType: .name)
                    SafrTextField(
                        title: "Email",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    SafrTextField(
                        title: "Phone number",
                        text: $phoneNumber,
                        keyboardType: .phonePad,
                        textContentType: .telephoneNumber
                    )
                    SafrTextField(
                        title: "Password",
                        text: $password,
                        isSecure: true,
                        textContentType: .newPassword
                    )
                }

                VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
                    Text("I am a")
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.textSecondary)

                    Picker("Role", selection: $selectedRole) {
                        ForEach(RegisterRole.allCases) { role in
                            Text(role.title).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.danger)
                }

                SafrPrimaryButton(
                    title: "Create account",
                    isLoading: isSubmitting,
                    isDisabled: !isFormValid
                ) {
                    Task { await register() }
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isFormValid: Bool {
        !fullName.isEmpty && !email.isEmpty && !phoneNumber.isEmpty && !password.isEmpty
    }

    private func register() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await session.register(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                role: selectedRole
            )
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
        RegisterView()
    }
    .environment(SessionManager())
}
