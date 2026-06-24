//
//  StatusChip.swift
//  Safr
//

import SwiftUI

struct StatusChip: View {
    let label: String
    var tone: StatusTone = .info

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, SafrTheme.Spacing.md)
            .padding(.vertical, SafrTheme.Spacing.xs)
            .background(tone.background)
            .foregroundStyle(tone.foreground)
            .clipShape(Capsule())
    }
}
