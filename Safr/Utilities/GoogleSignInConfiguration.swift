//
//  GoogleSignInConfiguration.swift
//  Safr
//

import Foundation

enum GoogleSignInConfiguration {
    static var clientID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("YOUR_") else { return nil }
        return trimmed
    }

    static var isConfigured: Bool {
        clientID != nil
    }

    /// Reversed client ID used as the Google Sign-In URL scheme.
    static var reversedClientIDURLScheme: String? {
        guard let clientID else { return nil }
        return clientID
            .split(separator: ".")
            .reversed()
            .joined(separator: ".")
    }
}
