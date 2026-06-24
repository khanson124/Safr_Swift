//
//  UserAvatarView.swift
//  Safr
//

import SwiftUI

struct UserAvatarView: View {
    let name: String
    var imageURL: String?
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(SafrTheme.Colors.surface)
                .frame(width: size, height: size)

            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
    }

    private var initialsView: some View {
        Text(initials)
            .font(.system(size: size * 0.32, weight: .bold))
            .foregroundStyle(SafrTheme.Colors.accent)
    }

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}
