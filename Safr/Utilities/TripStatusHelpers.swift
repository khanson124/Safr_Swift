//
//  TripStatusHelpers.swift
//  Safr
//

import SwiftUI

struct TripStatusBadge: Equatable {
    let label: String
    let tone: StatusTone
}

struct RiderStateBanner: Equatable {
    let kicker: String
    let title: String
    let tone: StatusTone
}

enum StatusTone {
    case safe
    case info
    case warning
    case danger

    var background: Color {
        switch self {
        case .safe: SafrTheme.Colors.success.opacity(0.15)
        case .info: SafrTheme.Colors.accent.opacity(0.15)
        case .warning: SafrTheme.Colors.accentWarm.opacity(0.18)
        case .danger: SafrTheme.Colors.danger.opacity(0.18)
        }
    }

    var foreground: Color {
        switch self {
        case .safe: SafrTheme.Colors.success
        case .info: SafrTheme.Colors.accent
        case .warning: SafrTheme.Colors.accentWarm
        case .danger: SafrTheme.Colors.danger
        }
    }
}

enum TripStatusHelpers {
    static func badge(for trip: Trip) -> TripStatusBadge {
        if trip.hasActiveSos {
            return TripStatusBadge(label: "SOS Active", tone: .danger)
        }
        if trip.hasOpenIssue || trip.status == .disputed {
            return TripStatusBadge(label: "Issue reported", tone: .danger)
        }
        switch trip.status {
        case .inProgress: return TripStatusBadge(label: "In progress", tone: .info)
        case .accepted:
            if trip.verifiedAt != nil {
                return TripStatusBadge(label: "Waiting to begin", tone: .safe)
            }
            return TripStatusBadge(label: "Awaiting verification", tone: .warning)
        case .driverEnded: return TripStatusBadge(label: "Confirm arrival", tone: .warning)
        case .completed: return TripStatusBadge(label: "Completed", tone: .safe)
        case .cancelled: return TripStatusBadge(label: "Cancelled", tone: .warning)
        case .autoClosed: return TripStatusBadge(label: "Auto-closed", tone: .warning)
        case .disputed: return TripStatusBadge(label: "Disputed", tone: .danger)
        case .requested: return TripStatusBadge(label: "Requested", tone: .info)
        }
    }

    static func riderBanner(for trip: Trip) -> RiderStateBanner {
        if trip.hasActiveSos {
            return RiderStateBanner(kicker: "SOS Active", title: "Emergency alert sent", tone: .danger)
        }
        if trip.status == .disputed || trip.hasOpenIssue {
            return RiderStateBanner(kicker: "Issue Reported", title: "Safr is tracking this issue", tone: .danger)
        }
        switch trip.status {
        case .completed:
            return RiderStateBanner(kicker: "Trip Completed", title: "Thanks for riding with Safr", tone: .safe)
        case .autoClosed:
            return RiderStateBanner(kicker: "Trip auto-closed", title: "This trip was closed automatically", tone: .warning)
        case .driverEnded:
            return RiderStateBanner(kicker: "Driver ended trip", title: "Confirm you arrived safely", tone: .warning)
        case .inProgress:
            return RiderStateBanner(kicker: "Verified trip", title: "You are in an active trip", tone: .info)
        case .accepted:
            if trip.verifiedAt != nil {
                return RiderStateBanner(kicker: "Verified", title: "Waiting for the trip to begin", tone: .safe)
            }
            if trip.isRiderConfirmed == true && trip.isDriverConfirmed != true {
                return RiderStateBanner(kicker: "Almost there", title: "Waiting for driver confirmation", tone: .warning)
            }
            if trip.isDriverConfirmed == true && trip.isRiderConfirmed != true {
                return RiderStateBanner(kicker: "Action needed", title: "Confirm this driver before continuing", tone: .warning)
            }
            return RiderStateBanner(kicker: "Verify driver", title: "Confirm this driver before continuing", tone: .warning)
        default:
            return RiderStateBanner(kicker: "Trip status", title: trip.status.rawValue.capitalized, tone: .info)
        }
    }

    static func driverBanner(for trip: Trip) -> RiderStateBanner {
        if trip.hasActiveSos {
            return RiderStateBanner(kicker: "SOS Active", title: "Passenger emergency alert", tone: .danger)
        }
        if trip.status == .disputed || trip.hasOpenIssue {
            return RiderStateBanner(kicker: "Issue flagged", title: "This trip needs attention", tone: .danger)
        }
        switch trip.status {
        case .completed:
            return RiderStateBanner(kicker: "Trip completed", title: "Passenger confirmed arrival", tone: .safe)
        case .driverEnded:
            return RiderStateBanner(kicker: "Trip ended", title: "Waiting for rider to confirm safe arrival", tone: .warning)
        case .inProgress:
            return RiderStateBanner(kicker: "In progress", title: "Sharing live location with rider", tone: .info)
        case .accepted:
            if trip.verifiedAt != nil {
                return RiderStateBanner(kicker: "Verified", title: "Ready to start the trip", tone: .safe)
            }
            if trip.isDriverConfirmed != true, trip.riderId != nil {
                return RiderStateBanner(kicker: "Action needed", title: "Confirm the passenger before continuing", tone: .warning)
            }
            if trip.isRiderConfirmed != true {
                return RiderStateBanner(kicker: "Waiting", title: "Waiting for rider confirmation", tone: .warning)
            }
            return RiderStateBanner(kicker: "Verify trip", title: "Complete passenger verification", tone: .warning)
        default:
            return RiderStateBanner(kicker: "Trip status", title: trip.status.rawValue.capitalized, tone: .info)
        }
    }
}
