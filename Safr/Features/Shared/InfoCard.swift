//
//  InfoCard.swift
//  Safr
//

import SwiftUI

struct InfoCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(SafrTheme.Colors.textPrimary)

            content()
        }
        .padding(SafrTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SafrTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
    }
}
