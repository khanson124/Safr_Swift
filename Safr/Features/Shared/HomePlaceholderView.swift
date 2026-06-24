//
//  HomePlaceholderView.swift
//  Safr
//

import SwiftUI

struct HomePlaceholderView: View {
    @Environment(SessionManager.self) private var session

    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: SafrTheme.Spacing.lg) {
            Spacer()

            if let user = session.user {
                Text("Hello, \(user.fullName)")
                    .font(.title2.bold())
                    .foregroundStyle(SafrTheme.Colors.textPrimary)

                RoleBadge(role: user.role)
            }

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(SafrTheme.Colors.textPrimary)

            Text(subtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(SafrTheme.Colors.textSecondary)

            SafrPrimaryButton(title: "Sign Out") {
                session.logout()
            }
            .padding(.top, SafrTheme.Spacing.md)

            Spacer()
        }
        .padding(SafrTheme.Spacing.lg)
        .safrScreenBackground()
    }
}
