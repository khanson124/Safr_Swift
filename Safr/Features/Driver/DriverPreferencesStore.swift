//
//  DriverPreferencesStore.swift
//  Safr
//

import Foundation

struct DriverPreferences: Codable, Equatable {
    var taxiOnline: Bool
    var charterAvailable: Bool
    var taxiOnlineSince: String?

    static let defaults = DriverPreferences(
        taxiOnline: true,
        charterAvailable: false,
        taxiOnlineSince: JSONCoding.iso8601String()
    )
}

enum DriverPreferencesStore {
    private static func key(for userId: String) -> String {
        "safr:driver-preferences:\(userId)"
    }

    static func load(userId: String) -> DriverPreferences {
        guard let data = UserDefaults.standard.data(forKey: key(for: userId)),
              let preferences = try? JSONCoding.decoder.decode(DriverPreferences.self, from: data) else {
            return .defaults
        }
        return preferences
    }

    static func save(_ preferences: DriverPreferences, userId: String) {
        guard let data = try? JSONCoding.encoder.encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: key(for: userId))
    }
}
