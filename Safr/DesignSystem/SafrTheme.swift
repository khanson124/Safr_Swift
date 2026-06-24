//
//  SafrTheme.swift
//  Safr
//

import SwiftUI

enum SafrTheme {
    enum Colors {
        static let background = Color(hex: "#07101b")
        static let surface = Color(hex: "#101c2d")
        static let textPrimary = Color(hex: "#f5f7fb")
        static let textSecondary = Color(hex: "#b1bfd3")
        static let accent = Color(hex: "#6dd6ff")
        static let accentWarm = Color(hex: "#ffb36a")
        static let success = Color(hex: "#7ef0be")
        static let danger = Color(hex: "#ff7b8d")
    }

    enum Radius {
        static let sm: CGFloat = 14
        static let md: CGFloat = 18
        static let lg: CGFloat = 24
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
}
