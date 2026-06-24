//
//  SafrComponents.swift
//  Safr
//

import SwiftUI

struct SafrTextField: View {
    let title: String
    @Binding var text: String
    var isSecure = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?

    var body: some View {
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textSecondary)

            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .padding(SafrTheme.Spacing.md)
            .background(SafrTheme.Colors.surface)
            .foregroundStyle(SafrTheme.Colors.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: SafrTheme.Radius.sm)
                    .stroke(SafrTheme.Colors.textSecondary.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

struct SafrPrimaryButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SafrTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(SafrTheme.Colors.background)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SafrTheme.Spacing.md)
            .background(isDisabled ? SafrTheme.Colors.accent.opacity(0.4) : SafrTheme.Colors.accent)
            .foregroundStyle(SafrTheme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
        }
        .disabled(isDisabled || isLoading)
    }
}

struct SafrSecondaryButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SafrTheme.Spacing.sm) {
                if isLoading {
                    ProgressView().tint(SafrTheme.Colors.accent)
                }
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SafrTheme.Spacing.md)
            .background(SafrTheme.Colors.surface)
            .foregroundStyle(SafrTheme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: SafrTheme.Radius.md)
                    .stroke(SafrTheme.Colors.accent.opacity(0.5), lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

struct RoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, SafrTheme.Spacing.md)
            .padding(.vertical, SafrTheme.Spacing.xs)
            .background(SafrTheme.Colors.accent.opacity(0.15))
            .foregroundStyle(SafrTheme.Colors.accent)
            .clipShape(Capsule())
    }
}
