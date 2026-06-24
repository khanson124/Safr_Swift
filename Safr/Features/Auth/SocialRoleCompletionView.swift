//
//  SocialRoleCompletionView.swift
//  Safr
//

import SwiftUI

struct SocialRoleCompletionView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.dismiss) private var dismiss

    let pending: SocialAuthPendingResponse

    @State private var fullName: String
    @State private var phoneNumber: String
    @State private var selectedRole: RegisterRole = .rider
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(pending: SocialAuthPendingResponse) {
        self.pending = pending
        _fullName = State(initialValue: pending.socialProfile.fullName)
        #if DEBUG
        _phoneNumber = State(initialValue: "+15555550123")
        #else
        _phoneNumber = State(initialValue: "")
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
                        Text("Complete your profile")
                            .font(.title.bold())
                            .foregroundStyle(SafrTheme.Colors.textPrimary)

                        Text("Signed in with \(pending.socialProfile.provider.rawValue.capitalized) as \(pending.socialProfile.email)")
                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                    }

                    VStack(spacing: SafrTheme.Spacing.md) {
                        SafrTextField(title: "Full name", text: $fullName, textContentType: .name)
                        SafrTextField(
                            title: "Phone number",
                            text: $phoneNumber,
                            keyboardType: .phonePad,
                            textContentType: .telephoneNumber
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
                        title: "Continue",
                        isLoading: isSubmitting,
                        isDisabled: fullName.isEmpty || phoneNumber.isEmpty
                    ) {
                        Task { await submit() }
                    }
                }
                .padding(SafrTheme.Spacing.lg)
            }
            .safrScreenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(SafrTheme.Colors.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await session.completeSocialProfile(
                temporaryToken: pending.temporaryToken,
                role: selectedRole,
                phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines)
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
    SocialRoleCompletionView(pending: SocialAuthPendingResponse(
        needsRoleSelection: true,
        socialProfile: SocialProfile(email: "user@example.com", fullName: "Alex Rider", provider: .google),
        temporaryToken: "temp-token"
    ))
    .environment(SessionManager())
}
