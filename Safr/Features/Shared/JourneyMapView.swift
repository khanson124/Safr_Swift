//
//  JourneyMapView.swift
//  Safr
//

import MapKit
import SwiftUI

struct JourneyMapView: View {
    var origin: CLLocationCoordinate2D?
    var destination: CLLocationCoordinate2D?
    var driver: CLLocationCoordinate2D?
    var defaultCenter = CLLocationCoordinate2D(latitude: 18.0179, longitude: -76.8099)

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if let origin {
                Marker("Pickup", coordinate: origin)
                    .tint(SafrTheme.Colors.accent)
            }
            if let destination {
                Marker("Destination", coordinate: destination)
                    .tint(SafrTheme.Colors.accentWarm)
            }
            if let driver {
                Marker("Driver", coordinate: driver)
                    .tint(SafrTheme.Colors.success)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .colorScheme(.dark)
        .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: SafrTheme.Radius.md)
                .stroke(SafrTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
        )
        .onAppear { recenter() }
        .onChange(of: driver?.latitude) { _, _ in recenter() }
        .onChange(of: origin?.latitude) { _, _ in recenter() }
    }

    private func recenter() {
        var coords: [CLLocationCoordinate2D] = []
        if let origin { coords.append(origin) }
        if let destination { coords.append(destination) }
        if let driver { coords.append(driver) }

        if coords.isEmpty {
            position = .region(MKCoordinateRegion(center: defaultCenter, span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)))
            return
        }

        if coords.count == 1, let only = coords.first {
            position = .region(MKCoordinateRegion(center: only, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)))
            return
        }

        let latitudes = coords.map(\.latitude)
        let longitudes = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (latitudes.min()! + latitudes.max()!) / 2,
            longitude: (longitudes.min()! + longitudes.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.03, (latitudes.max()! - latitudes.min()!) * 1.6),
            longitudeDelta: max(0.03, (longitudes.max()! - longitudes.min()!) * 1.6)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}
