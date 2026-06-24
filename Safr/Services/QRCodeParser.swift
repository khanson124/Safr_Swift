//
//  QRCodeParser.swift
//  Safr
//

import Foundation

enum QRCodeParser {
    struct TripVerificationQr: Equatable {
        let tripId: String
        let verificationToken: String
    }

    static func normalizeDriverQrCode(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let match = firstCapture(in: trimmed, pattern: "[?&]code=([^&]+)", options: .caseInsensitive) {
            return match.removingPercentEncoding ?? match
        }

        if let match = firstCapture(in: trimmed, pattern: "^safr://driver/(.+)$", options: .caseInsensitive) {
            return match
        }

        return trimmed
    }

    static func parseTripVerificationQr(_ rawValue: String) -> TripVerificationQr? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let querySource: String?
        if let match = firstCapture(in: trimmed, pattern: "^safr://trip-verify\\?(.+)$", options: .caseInsensitive) {
            querySource = match
        } else {
            querySource = trimmed.split(separator: "?", maxSplits: 1).dropFirst().first.map(String.init)
        }

        guard let querySource,
              let components = URLComponents(string: "?\(querySource)"),
              let items = components.queryItems,
              let tripId = items.first(where: { $0.name == "tripId" })?.value,
              let token = items.first(where: { $0.name == "token" })?.value else {
            return nil
        }

        return TripVerificationQr(tripId: tripId, verificationToken: token)
    }

    private static func firstCapture(in text: String, pattern: String, options: NSRegularExpression.Options) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
}
