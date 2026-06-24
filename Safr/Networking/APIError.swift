//
//  APIError.swift
//  Safr
//

import Foundation

struct APIError: LocalizedError {
    let message: String

    var errorDescription: String? { message }

    static func from(data: Data, statusCode: Int) -> APIError {
        if let payload = try? JSONDecoder().decode(NestErrorResponse.self, from: data) {
            return APIError(message: payload.resolvedMessage)
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return APIError(message: text)
        }

        return APIError(message: "Request failed with status \(statusCode).")
    }

    static func networkFailure(_ error: Error) -> APIError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return APIError(message: "Request timed out. Is the backend running at \(APIConfiguration.baseURL.absoluteString)?")
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return APIError(message: "Cannot reach the backend at \(APIConfiguration.baseURL.absoluteString). Start the server and try again.")
            default:
                break
            }
        }

        return APIError(message: "Network error: \(error.localizedDescription)")
    }
}

private struct NestErrorResponse: Decodable {
    let message: NestMessage?
    let statusCode: Int?

    var resolvedMessage: String {
        switch message {
        case .string(let value):
            return value
        case .array(let values):
            return values.joined(separator: "\n")
        case .none:
            return "Request failed."
        }
    }
}

private enum NestMessage: Decodable {
    case string(String)
    case array([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .array(try container.decode([String].self))
        }
    }
}
