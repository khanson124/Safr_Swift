//
//  AuthenticatedHomeContainer.swift
//  Safr
//

import SwiftUI

struct AuthenticatedHomeContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
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
        }
        .tint(SafrTheme.Colors.accent)
    }
}
