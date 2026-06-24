//
//  CloudinaryUploadService.swift
//  Safr
//

import Foundation

enum CloudinaryUploadService {
    static func upload(
        signature: SignedUploadSignature,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "https://api.cloudinary.com/v1_1/\(signature.cloudName)/image/upload") else {
            throw APIError(message: "Invalid Cloudinary URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("api_key", signature.apiKey)
        appendField("folder", signature.folder)
        appendField("timestamp", String(signature.timestamp))
        appendField("signature", signature.signature)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid upload response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorPayload = try? JSONDecoder().decode(CloudinaryErrorResponse.self, from: data),
               let message = errorPayload.error?.message {
                throw APIError(message: message)
            }
            throw APIError(message: "Unable to upload image.")
        }

        let payload = try JSONDecoder().decode(CloudinaryUploadResponse.self, from: data)
        return payload.secureUrl
    }
}
