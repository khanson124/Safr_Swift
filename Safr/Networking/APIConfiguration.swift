//
//  APIConfiguration.swift
//  Safr
//

import Foundation
import os

enum APIConfiguration {
    private static let logger = Logger(subsystem: "com.kylehanson.safr", category: "API")

  /// Override via Info.plist `SAFR_API_BASE_URL` (Debug xcconfig, device LAN IP, or staging).
    static var baseURL: URL {
        if let override = Bundle.main.object(forInfoDictionaryKey: "SAFR_API_BASE_URL") as? String {
            let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = URL(string: trimmed) {
                return url
            }
        }

        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:4000/api/v1")!
        #else
        // Device: set SAFR_API_BASE_URL in Info.plist to http://<Mac-LAN-IP>:4000/api/v1
        // Production placeholder: https://api.safr.app/api/v1
        return URL(string: "http://localhost:4000/api/v1")!
        #endif
    }

    static var trackingSocketURL: URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = ""
        components.query = nil
        if components.port == nil {
            components.port = 4000
        }
        return components.url
    }

    static func logResolvedURL() {
        #if DEBUG
        logger.debug("API base URL: \(baseURL.absoluteString, privacy: .public)")
        if let trackingSocketURL {
            logger.debug("WS URL: \(trackingSocketURL.absoluteString, privacy: .public)/tracking")
        }
        #endif
    }
}
