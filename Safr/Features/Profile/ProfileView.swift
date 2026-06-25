//
//  ProfileView.swift
//  Safr
//

import SwiftUI

struct ProfileView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showSignOutConfirmation = false

    private var user: AuthUser? { session.user }

    var body: some View {
        ScrollView {
            VStack(spacing: SafrTheme.Spacing.lg) {
                if let user {
                    avatarView(for: user)
                        .padding(.top, SafrTheme.Spacing.md)

                    VStack(spacing: SafrTheme.Spacing.xs) {
                        Text(user.fullName)
                            .font(.title2.bold())
                            .foregroundStyle(SafrTheme.Colors.textPrimary)

                        if let email = user.email {
                            Text(email)
                                .foregroundStyle(SafrTheme.Colors.textSecondary)
                        }

                        if let phoneNumber = user.phoneNumber {
                            Text(phoneNumber)
                                .foregroundStyle(SafrTheme.Colors.textSecondary)
                        }

                        RoleBadge(role: user.role)
                            .padding(.top, SafrTheme.Spacing.sm)
                    }

                    if let approvalStatus = user.approvalStatus, user.role == .driver {
                        Text(approvalStatus.displayMessage)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                            .padding(SafrTheme.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(SafrTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.danger)
                }

                VStack(spacing: SafrTheme.Spacing.sm) {
                    NavigationLink {
                        ProfilePhotoView()
                    } label: {
                        profileRow(title: "Profile photo", systemImage: "camera")
                    }

                    NavigationLink {
                        EmergencyContactsView()
                    } label: {
                        profileRow(title: "Emergency contacts", systemImage: "person.2")
                    }
                }

                SafrPrimaryButton(title: "Sign Out") {
                    showSignOutConfirmation = true
                }
                .padding(.top, SafrTheme.Spacing.md)
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isRefreshing {
                ProgressView()
                    .tint(SafrTheme.Colors.accent)
            }
        }
        .task {
            await refreshProfile()
        }
        .alert("Sign out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                session.logout()
                dismiss()
            }
        } message: {
            Text("You will need to sign in again to use Safr.")
        }
    }

    @ViewBuilder
    private func avatarView(for user: AuthUser) -> some View {
        UserAvatarView(name: user.fullName, imageURL: user.avatarUrl, size: 96)
    }

    private func profileRow(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(SafrTheme.Colors.accent)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(SafrTheme.Colors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SafrTheme.Colors.textSecondary)
        }
        .padding(SafrTheme.Spacing.md)
        .background(SafrTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
    }

    private func refreshProfile() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await session.refreshUser()
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(SessionManager())
}
