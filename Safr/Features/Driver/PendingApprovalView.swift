//
//  PendingApprovalView.swift
//  Safr
//

import SwiftUI

struct PendingApprovalView: View {
    @Environment(SessionManager.self) private var session

    @State private var driverProfile: DriverProfile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignOutConfirmation = false
    @State private var path = NavigationPath()

    private var user: AuthUser? { session.user }

    private var canEditApplication: Bool {
        user?.approvalStatus != .suspended && user?.approvalStatus != .approved
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: SafrTheme.Spacing.lg) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(SafrTheme.Colors.accentWarm)

                    Text(statusTitle)
                        .font(.title2.bold())
                        .foregroundStyle(SafrTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    if let status = user?.approvalStatus {
                        StatusChip(label: status.displayMessage, tone: statusTone(status))
                    }

                    Text(statusBody)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(SafrTheme.Colors.textSecondary)

                    if let reason = user?.approvalReason, !reason.isEmpty {
                        Text(reason)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                            .padding(SafrTheme.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(SafrTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
                    }

                    if let reviewReason = driverProfile?.reviewReason, !reviewReason.isEmpty {
                        Text(reviewReason)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                            .padding(SafrTheme.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(SafrTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
                    }

                    if let checklist = driverProfile?.reviewSummary?.checklist, !checklist.isEmpty {
                        InfoCard(title: "Application checklist") {
                            ForEach(checklist) { item in
                                HStack {
                                    Image(systemName: item.complete ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.complete ? SafrTheme.Colors.success : SafrTheme.Colors.textSecondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.label)
                                            .foregroundStyle(SafrTheme.Colors.textPrimary)
                                        Text(item.summary)
                                            .font(.caption)
                                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }

                    if user?.avatarUrl == nil {
                        NavigationLink {
                            ProfilePhotoView()
                        } label: {
                            Text("Add profile photo")
                                .fontWeight(.semibold)
                                .foregroundStyle(SafrTheme.Colors.accentWarm)
                        }
                    }

                    if canEditApplication {
                        SafrPrimaryButton(title: "Complete application") {
                            path.append(PendingDriverRoute.driverApplication)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(SafrTheme.Colors.danger)
                    }

                    SafrPrimaryButton(title: "Sign Out") {
                        showSignOutConfirmation = true
                    }
                }
                .padding(SafrTheme.Spacing.lg)
            }
            .safrScreenBackground()
            .navigationTitle("Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title3)
                            .foregroundStyle(SafrTheme.Colors.accent)
                    }
                }
            }
            .navigationDestination(for: PendingDriverRoute.self) { route in
                switch route {
                case .driverApplication:
                    DriverApplicationView()
                case .profilePhoto:
                    ProfilePhotoView()
                }
            }
            .overlay {
                if isLoading {
                    ProgressView().tint(SafrTheme.Colors.accent)
                }
            }
            .refreshable { await loadProfile() }
            .task { await loadProfile() }
        }
        .tint(SafrTheme.Colors.accent)
        .alert("Sign out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                session.logout()
            }
        } message: {
            Text("You will need to sign in again to use Safr.")
        }
    }

    private var statusTitle: String {
        switch user?.approvalStatus {
        case .underReview: "Application under review"
        case .moreInfoRequired: "More information needed"
        case .rejected: "Application needs changes"
        case .suspended: "Driver access suspended"
        case .approved: "Driver account approved"
        default: "Application submitted"
        }
    }

    private var statusBody: String {
        switch user?.approvalStatus {
        case .underReview:
            "Your documents are in the review queue."
        case .moreInfoRequired:
            "Update the requested details so Safr can continue review."
        case .rejected:
            "Review the notes below and resubmit if you want to reapply."
        case .suspended:
            "Trip features are locked while Safr reviews your account."
        case .approved:
            "You can return to the driver dashboard."
        default:
            driverProfile?.reviewSummary?.completionLabel ?? "Complete your application so Safr can begin review."
        }
    }

    private var statusIcon: String {
        switch user?.approvalStatus {
        case .rejected, .suspended: "exclamationmark.triangle.fill"
        case .approved: "checkmark.seal.fill"
        default: "clock.badge.checkmark"
        }
    }

    private func statusTone(_ status: DriverApprovalStatus) -> StatusTone {
        switch status {
        case .approved: .safe
        case .moreInfoRequired: .warning
        case .rejected, .suspended: .danger
        default: .info
        }
    }

    private func loadProfile() async {
        guard let token = session.accessToken else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await session.refreshUser()
            driverProfile = try await APIClient.shared.getMyDriverProfile(token: token)
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    PendingApprovalView()
        .environment(SessionManager())
}
