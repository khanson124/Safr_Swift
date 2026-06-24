//
//  SafrApp.swift
//  Safr
//

import GoogleSignIn
import SwiftUI

@main
struct SafrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .onOpenURL { url in
                    if handleGoogleSignIn(url) { return }
                    // safr:// deep links are handled in AppRouter
                }
        }
    }

    private func handleGoogleSignIn(_ url: URL) -> Bool {
        guard GoogleSignInConfiguration.isConfigured,
              let scheme = GoogleSignInConfiguration.reversedClientIDURLScheme,
              url.scheme == scheme else {
            return false
        }
        GoogleSignInService.configureIfNeeded()
        return GIDSignIn.sharedInstance.handle(url)
    }
}
