//
//  TripCacheService.swift
//  Safr
//

import Foundation

enum TripCacheService {
    private static func tripKey(userId: String, tripId: String) -> String {
        "safr.trip.cache.\(userId).\(tripId)"
    }

    private static func locationKey(userId: String, tripId: String) -> String {
        "safr.trip.location.\(userId).\(tripId)"
    }

    static func saveTrip(_ trip: Trip, userId: String) {
        guard let data = try? JSONCoding.encoder.encode(trip) else { return }
        UserDefaults.standard.set(data, forKey: tripKey(userId: userId, tripId: trip.id))
    }

    static func loadTrip(userId: String, tripId: String) -> Trip? {
        guard let data = UserDefaults.standard.data(forKey: tripKey(userId: userId, tripId: tripId)) else {
            return nil
        }
        return try? JSONCoding.decoder.decode(Trip.self, from: data)
    }

    static func saveLocation(_ location: DriverLocationSnapshot, userId: String, tripId: String) {
        guard let data = try? JSONCoding.encoder.encode(location) else { return }
        UserDefaults.standard.set(data, forKey: locationKey(userId: userId, tripId: tripId))
    }

    static func loadLocation(userId: String, tripId: String) -> DriverLocationSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: locationKey(userId: userId, tripId: tripId)) else {
            return nil
        }
        return try? JSONCoding.decoder.decode(DriverLocationSnapshot.self, from: data)
    }
}
