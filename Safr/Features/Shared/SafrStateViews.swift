//
//  SafrStateViews.swift
//  Safr
//

import SwiftUI

struct SafrLoadingStateView: View {
    var message = "Loading…"

    var body: some View {
        VStack(spacing: SafrTheme.Spacing.md) {
            ProgressView()
                .tint(SafrTheme.Colors.accent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SafrTheme.Spacing.xl)
    }
}

struct SafrEmptyStateView: View {
    let title: String
    var message: String?
    var systemImage = "tray"

    var body: some View {
        VStack(spacing: SafrTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(SafrTheme.Colors.textSecondary)

            Text(title)
                .font(.headline)
                .foregroundStyle(SafrTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SafrTheme.Spacing.lg)
    }
}

struct SafrErrorStateView: View {
    let message: String
    var retryTitle = "Try again"
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: SafrTheme.Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(SafrTheme.Colors.danger)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            SafrSecondaryButton(title: retryTitle, action: onRetry)
        }
        .frame(maxWidth: .infinity)
        .padding(SafrTheme.Spacing.lg)
    }
}
