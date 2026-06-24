//
//  DriverInfoCard.swift
//  Safr
//

import SwiftUI

struct DriverInfoCard: View {
    let name: String
    var avatarURL: String?
    var plateNumber: String?
    var vehicleMake: String?
    var vehicleModel: String?
    var vehicleColor: String?
    var routeName: String?
    var badgeNumber: String?
    var isApproved: Bool = true

    var body: some View {
        InfoCard(title: "Driver") {
            HStack(alignment: .top, spacing: SafrTheme.Spacing.md) {
                UserAvatarView(name: name, imageURL: avatarURL)

                VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
                    Text(name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SafrTheme.Colors.textPrimary)

                    if let badgeNumber, !badgeNumber.isEmpty {
                        Text("Badge #\(badgeNumber)")
                            .font(.subheadline)
                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                    }

                    StatusChip(
                        label: isApproved ? "Verified driver" : "Pending approval",
                        tone: isApproved ? .safe : .warning
                    )
                }
            }

            VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
                if let plate = plateNumber, !plate.isEmpty {
                    detailRow("Plate", plate)
                }
                if let vehicleLine = vehicleLine, !vehicleLine.isEmpty {
                    detailRow("Vehicle", vehicleLine)
                }
                if let routeName, !routeName.isEmpty {
                    detailRow("Route", routeName)
                }
            }
        }
    }

    private var vehicleLine: String? {
        let parts = [vehicleColor, vehicleMake, vehicleModel].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textSecondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(SafrTheme.Colors.textPrimary)
        }
    }
}

extension DriverInfoCard {
    init(driver: DriverVerificationDriver) {
        self.init(
            name: driver.displayName,
            avatarURL: driver.avatarUrl,
            plateNumber: driver.plateNumber,
            vehicleMake: driver.vehicleMake,
            vehicleModel: driver.vehicleModel,
            vehicleColor: driver.vehicleColor,
            routeName: driver.routeName,
            badgeNumber: driver.badgeNumber,
            isApproved: driver.approvalStatus == .approved
        )
    }

    init(trip: Trip) {
        let profile = trip.driverProfile
        self.init(
            name: profile?.user?.fullName ?? "Driver",
            avatarURL: profile?.user?.avatarUrl,
            plateNumber: trip.plateNumberSnapshot ?? profile?.plateNumber ?? trip.vehicle?.plateNumber,
            vehicleMake: trip.vehicleMakeSnapshot ?? profile?.vehicleMake ?? trip.vehicle?.make,
            vehicleModel: trip.vehicleModelSnapshot ?? profile?.vehicleModel ?? trip.vehicle?.model,
            vehicleColor: trip.vehicleColorSnapshot ?? profile?.vehicleColor ?? trip.vehicle?.color,
            routeName: trip.routeSnapshot ?? profile?.serviceRoute,
            badgeNumber: nil,
            isApproved: profile?.status == .approved
        )
    }

    init(verification: TripVerificationPayload) {
        self.init(
            name: verification.driver.fullName,
            avatarURL: verification.driver.photoUrl,
            plateNumber: verification.driver.plateNumber,
            vehicleMake: verification.driver.vehicleMake,
            vehicleModel: verification.driver.vehicleModel,
            vehicleColor: verification.driver.vehicleColor,
            routeName: nil,
            badgeNumber: nil,
            isApproved: verification.driver.isApproved
        )
    }
}
