//
//  AppRouter.swift
//  Safr
//

import SwiftUI

private enum UnauthRoute: Hashable {
    case resetPassword(String?)
    case login
}

struct AppRouter: View {
    @State private var session = SessionManager()
    @State private var connectivity = ConnectivityMonitor()
    @State private var resetPasswordToken: String?
    @State private var deepLinkTrigger = 0
    @State private var pendingDeepLink: UnauthRoute?
    @State private var loginSuccessMessage: String?
    @State private var unauthPath = NavigationPath()

    var body: some View {
        VStack(spacing: 0) {
            connectivityBanner
            Group {
                if session.isLoading {
                    loadingView
                } else if session.isAuthenticated, let user = session.user {
                    authenticatedView(for: user)
                } else {
                    unauthenticatedView
                }
            }
        }
        .environment(session)
        .environment(connectivity)
        .preferredColorScheme(.dark)
        .task {
            APIConfiguration.logResolvedURL()
            await session.bootstrap()
            connectivity.start(session: session)
            if session.isAuthenticated {
                await PushNotificationService.shared.registerIfNeeded(session: session)
            }
        }
        .onDisappear {
            connectivity.stop()
        }
        .onChange(of: session.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                connectivity.refreshPendingCount(session: session)
                Task { await PushNotificationService.shared.registerIfNeeded(session: session) }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    @ViewBuilder
    private var connectivityBanner: some View {
        if session.isAuthenticated {
            if connectivity.isSyncing {
                banner(text: "Syncing offline safety events…", color: SafrTheme.Colors.accent)
            } else if !connectivity.isOnline {
                banner(text: "You're offline — safety events will sync when connection returns.", color: SafrTheme.Colors.accentWarm)
            } else if connectivity.pendingQueueCount > 0 {
                banner(text: "\(connectivity.pendingQueueCount) offline safety event(s) pending sync.", color: SafrTheme.Colors.accentWarm)
            }
        }
    }

    private func banner(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SafrTheme.Colors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SafrTheme.Spacing.sm)
            .background(color)
    }

    private var loadingView: some View {
        SafrLoadingStateView(message: "Loading Safr…")
            .safrScreenBackground()
    }

    private var unauthenticatedView: some View {
        NavigationStack(path: $unauthPath) {
            LoginView(successMessage: $loginSuccessMessage)
                .navigationDestination(for: UnauthRoute.self) { route in
                    switch route {
                    case .resetPassword(let token):
                        ResetPasswordView(token: token) { message in
                            loginSuccessMessage = message
                            unauthPath = NavigationPath()
                        }
                    case .login:
                        LoginView(successMessage: $loginSuccessMessage)
                    }
                }
        }
        .tint(SafrTheme.Colors.accent)
        .onChange(of: deepLinkTrigger) { _, _ in
            guard let pendingDeepLink else { return }
            unauthPath.append(pendingDeepLink)
            self.pendingDeepLink = nil
        }
    }

    @ViewBuilder
    private func authenticatedView(for user: AuthUser) -> some View {
        switch user.role {
        case .admin:
            UnsupportedRoleView()
        case .driver:
            if user.approvalStatus != .approved {
                PendingApprovalView()
            } else {
                DriverHomeView()
            }
        case .rider:
            RiderHomeView()
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "safr" else { return }

        switch url.host {
        case "reset-password":
            let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "token" })?
                .value

            if session.isAuthenticated {
                Task {
                    await PushNotificationService.shared.unregister(session: session)
                    session.logout()
                    resetPasswordToken = token
                    pendingDeepLink = .resetPassword(token)
                    deepLinkTrigger += 1
                }
            } else {
                resetPasswordToken = token
                pendingDeepLink = .resetPassword(token)
                deepLinkTrigger += 1
            }

        case "login":
            guard !session.isAuthenticated else { return }
            pendingDeepLink = .login
            unauthPath = NavigationPath()
            deepLinkTrigger += 1

        default:
            break
        }
    }
}

#Preview {
    AppRouter()
}
