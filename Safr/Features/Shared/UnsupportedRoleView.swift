//
//  UnsupportedRoleView.swift
//  Safr
//

import SwiftUI

struct UnsupportedRoleView: View {
    @Environment(SessionManager.self) private var session

    var body: some View {
        VStack(spacing: SafrTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "desktopcomputer")
                .font(.system(size: 48))
                .foregroundStyle(SafrTheme.Colors.accent)

            Text("Use Admin Dashboard")
                .font(.title2.bold())
                .foregroundStyle(SafrTheme.Colors.textPrimary)

            Text("Admin features are on the web. Sign out to use a rider or driver account.")
                .multilineTextAlignment(.center)
                .foregroundStyle(SafrTheme.Colors.textSecondary)

            SafrPrimaryButton(title: "Sign Out") {
                session.logout()
            }

            Spacer()
        }
        .padding(SafrTheme.Spacing.lg)
        .safrScreenBackground()
    }
}

#Preview {
    UnsupportedRoleView()
        .environment(SessionManager())
}
