//
//  APIClient.swift
//  Safr
//

import Foundation

struct APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 12
        self.session = session ?? URLSession(configuration: configuration)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await post("/auth/login", body: LoginRequest(email: email, password: password))
    }

    func registerRider(
        email: String,
        password: String,
        fullName: String,
        phoneNumber: String
    ) async throws -> AuthResponse {
        try await post(
            "/auth/register/rider",
            body: RegisterRequest(
                email: email,
                password: password,
                fullName: fullName,
                phoneNumber: phoneNumber
            )
        )
    }

    func registerDriver(
        email: String,
        password: String,
        fullName: String,
        phoneNumber: String
    ) async throws -> AuthResponse {
        try await post(
            "/auth/register/driver",
            body: RegisterRequest(
                email: email,
                password: password,
                fullName: fullName,
                phoneNumber: phoneNumber
            )
        )
    }

    func forgotPassword(email: String) async throws -> MessageResponse {
        try await post("/auth/forgot-password", body: ForgotPasswordRequest(email: email))
    }

    func resetPassword(token: String, password: String) async throws -> MessageResponse {
        try await post("/auth/reset-password", body: ResetPasswordRequest(token: token, password: password))
    }

    func socialGoogle(idToken: String) async throws -> SocialAuthResponse {
        let data = try await rawPost("/auth/social/google", body: SocialGoogleRequest(idToken: idToken))
        return try decodeSocialAuthResponse(from: data)
    }

    func socialApple(identityToken: String, fullName: String?) async throws -> SocialAuthResponse {
        let data = try await rawPost(
            "/auth/social/apple",
            body: SocialAppleRequest(identityToken: identityToken, fullName: fullName)
        )
        return try decodeSocialAuthResponse(from: data)
    }

    func completeSocialProfile(
        temporaryToken: String,
        role: UserRole,
        phoneNumber: String,
        fullName: String
    ) async throws -> AuthResponse {
        try await post(
            "/auth/social/complete-profile",
            body: CompleteSocialProfileRequest(
                temporaryToken: temporaryToken,
                role: role,
                phoneNumber: phoneNumber,
                fullName: fullName
            )
        )
    }

    func fetchMe(token: String) async throws -> AuthUser {
        try await get("/auth/me", token: token)
    }

    func updateMe(token: String, body: UpdateUserRequest) async throws -> AuthUser {
        try await patch("/users/me", body: body, token: token)
    }

    // MARK: - Trips & QR

    func verifyDriverQr(token: String, code: String) async throws -> DriverVerificationPayload {
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
        return try await get("/qr/\(encoded)", token: token, decoder: JSONCoding.decoder)
    }

    func verifyTripQr(token: String, tripId: String, verificationToken: String) async throws -> TripVerificationPayload {
        try await post(
            "/trips/verify",
            body: TripVerifyRequest(tripId: tripId, verificationToken: verificationToken),
            token: token,
            decoder: JSONCoding.decoder
        )
    }

    func startTripFromQr(token: String, code: String, routeConfirmation: String?) async throws -> Trip {
        try await post(
            "/trips/start-from-qr",
            body: StartTripFromQrRequest(code: code, routeConfirmation: routeConfirmation),
            token: token,
            decoder: JSONCoding.decoder
        )
    }

    func confirmDriver(token: String, tripId: String) async throws -> Trip {
        try await post(
            "/trips/confirm-driver",
            body: ConfirmDriverRequest(tripId: tripId),
            token: token,
            decoder: JSONCoding.decoder
        )
    }

    func reportTripIssue(token: String, tripId: String, message: String?) async throws -> Trip {
        try await patch(
            "/trips/\(tripId)/report-issue",
            body: ReportIssueRequest(message: message),
            token: token,
            decoder: JSONCoding.decoder
        )
    }

    func getTrip(token: String, tripId: String) async throws -> Trip {
        try await get("/trips/\(tripId)", token: token, decoder: JSONCoding.decoder)
    }

    func getMyActiveTrip(token: String) async throws -> Trip? {
        let data = try await requestData(path: "/trips/my/active", method: "GET", body: Optional<String>.none, token: token)
        if data.isEmpty || String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
            return nil
        }
        return try JSONCoding.decoder.decode(Trip.self, from: data)
    }

    func listMyTrips(token: String) async throws -> [Trip] {
        try await get("/trips/my", token: token, decoder: JSONCoding.decoder)
    }

    func getTripLocation(token: String, tripId: String) async throws -> DriverLocationSnapshot? {
        let data = try await requestData(path: "/tracking/trip/\(tripId)", method: "GET", body: Optional<String>.none, token: token)
        if data.isEmpty || String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
            return nil
        }
        return try JSONCoding.decoder.decode(DriverLocationSnapshot.self, from: data)
    }

    func triggerTripSos(token: String, tripId: String, request: TripSosRequest) async throws -> TripSosResponse {
        try await post("/trips/\(tripId)/sos", body: request, token: token, decoder: JSONCoding.decoder)
    }

    func confirmTripComplete(token: String, tripId: String) async throws -> Trip {
        try await patch(
            "/trips/\(tripId)/confirm-complete",
            body: EmptyBody(),
            token: token,
            decoder: JSONCoding.decoder
        )
    }

    // MARK: - Driver

    func getMyDriverProfile(token: String) async throws -> DriverProfile {
        try await get("/drivers/me", token: token, decoder: JSONCoding.decoder)
    }

    func getMyDriverQr(token: String) async throws -> DriverQrPayload {
        try await get("/drivers/me/qr", token: token, decoder: JSONCoding.decoder)
    }

    func generateMyDriverQr(token: String) async throws -> DriverQrPayload {
        try await post("/drivers/me/qr/generate", body: EmptyBody(), token: token, decoder: JSONCoding.decoder)
    }

    func listActivePassengers(token: String) async throws -> [ActivePassengerSession] {
        try await get("/drivers/me/active-passengers", token: token, decoder: JSONCoding.decoder)
    }

    func listTrips(token: String) async throws -> [Trip] {
        try await get("/trips", token: token, decoder: JSONCoding.decoder)
    }

    func manualStartTrip(token: String, request: ManualStartTripRequest) async throws -> Trip {
        try await post("/trips/manual-start", body: request, token: token, decoder: JSONCoding.decoder)
    }

    func confirmRider(token: String, tripId: String) async throws -> Trip {
        try await post(
            "/trips/confirm-rider",
            body: ConfirmRiderRequest(tripId: tripId),
            token: token,
            decoder: JSONCoding.decoder
        )
    }

    func startTrip(token: String, tripId: String) async throws -> Trip {
        try await patch("/trips/\(tripId)/start", body: EmptyBody(), token: token, decoder: JSONCoding.decoder)
    }

    func endTripByDriver(token: String, tripId: String) async throws -> Trip {
        try await patch("/trips/\(tripId)/end-by-driver", body: EmptyBody(), token: token, decoder: JSONCoding.decoder)
    }

    func getTripVerificationQr(token: String, tripId: String) async throws -> TripVerificationQrPayload {
        try await get("/trips/\(tripId)/qr", token: token, decoder: JSONCoding.decoder)
    }

    func sendDriverLocation(token: String, request: DriverLocationPost) async throws -> DriverLocationSnapshot {
        try await post("/tracking/location", body: request, token: token, decoder: JSONCoding.decoder)
    }

    // MARK: - Emergency contacts

    func listEmergencyContacts(token: String) async throws -> [EmergencyContact] {
        try await get("/emergency-contacts", token: token, decoder: JSONCoding.decoder)
    }

    func addEmergencyContact(token: String, request: AddEmergencyContactRequest) async throws -> EmergencyContact {
        try await post("/emergency-contacts", body: request, token: token, decoder: JSONCoding.decoder)
    }

    func deleteEmergencyContact(token: String, contactId: String) async throws -> DeleteEmergencyContactResponse {
        try await delete("/emergency-contacts/\(contactId)", token: token, decoder: JSONCoding.decoder)
    }

    // MARK: - Profile photo

    func uploadProfilePhoto(token: String, imageData: Data, filename: String, mimeType: String) async throws -> AuthUser {
        try await uploadMultipart(
            path: "/users/me/photo",
            method: "PATCH",
            token: token,
            fieldName: "photo",
            filename: filename,
            mimeType: mimeType,
            data: imageData
        )
    }

    // MARK: - Charter & monitoring

    func createTrip(token: String, request: CreateTripRequest) async throws -> Trip {
        try await post("/trips", body: request, token: token, decoder: JSONCoding.decoder)
    }

    func startManualMonitoring(token: String, request: ManualMonitoringRequest) async throws -> Trip {
        try await post("/trips/manual-monitor", body: request, token: token, decoder: JSONCoding.decoder)
    }

    func listAvailableTrips(token: String) async throws -> [Trip] {
        try await get("/trips/available", token: token, decoder: JSONCoding.decoder)
    }

    func acceptTrip(token: String, tripId: String) async throws -> Trip {
        try await patch("/trips/\(tripId)/accept", body: EmptyBody(), token: token, decoder: JSONCoding.decoder)
    }

    func cancelTrip(token: String, tripId: String) async throws -> Trip {
        try await patch(
            "/trips/\(tripId)/status",
            body: TripStatusUpdateRequest(status: .cancelled),
            token: token,
            decoder: JSONCoding.decoder
        )
    }

    // MARK: - Driver onboarding

    func getDriverDocumentUploadSignature(token: String) async throws -> SignedUploadSignature {
        try await get("/drivers/me/upload-signature", token: token, decoder: JSONCoding.decoder)
    }

    func updateMyDriverProfile(token: String, request: UpdateDriverProfileRequest) async throws -> DriverProfile {
        try await patch("/drivers/me", body: request, token: token, decoder: JSONCoding.decoder)
    }

    // MARK: - Feedback & safety reports

    func submitTripFeedback(token: String, tripId: String, request: TripFeedbackRequest) async throws -> TripFeedbackResponse {
        try await post("/trips/\(tripId)/feedback", body: request, token: token, decoder: JSONCoding.decoder)
    }

    func getTripReportUploadSignature(token: String, tripId: String) async throws -> SignedUploadSignature {
        try await get("/trips/\(tripId)/report-upload-signature", token: token, decoder: JSONCoding.decoder)
    }

    func submitTripSafetyReport(token: String, tripId: String, request: TripSafetyReportRequest) async throws -> TripSafetyReportResponse {
        try await post("/trips/\(tripId)/safety-report", body: request, token: token, decoder: JSONCoding.decoder)
    }

    // MARK: - Push notifications

    func registerDevice(token: String, apnsDeviceToken: String, platform: String) async throws -> RegisterDeviceResponse {
        try await post(
            "/notifications/register-device",
            body: RegisterDeviceRequest(apnsDeviceToken: apnsDeviceToken, platform: platform),
            token: token
        )
    }

    func unregisterDevice(token: String, apnsDeviceToken: String) async throws -> UnregisterDeviceResponse {
        try await delete(
            "/notifications/register-device",
            body: UnregisterDeviceRequest(apnsDeviceToken: apnsDeviceToken),
            token: token
        )
    }

    // MARK: - Private

    private struct EmptyBody: Encodable {}

    private func get<T: Decodable>(_ path: String, token: String? = nil, decoder: JSONDecoder? = nil) async throws -> T {
        try await request(path: path, method: "GET", body: Optional<String>.none, token: token, decoder: decoder)
    }

    private func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        token: String? = nil,
        decoder: JSONDecoder? = nil
    ) async throws -> Response {
        try await request(path: path, method: "POST", body: body, token: token, decoder: decoder)
    }

    private func patch<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        token: String,
        decoder: JSONDecoder? = nil
    ) async throws -> Response {
        try await request(path: path, method: "PATCH", body: body, token: token, decoder: decoder)
    }

    private func delete<Response: Decodable>(
        _ path: String,
        token: String,
        decoder: JSONDecoder? = nil
    ) async throws -> Response {
        try await request(path: path, method: "DELETE", body: Optional<String>.none, token: token, decoder: decoder)
    }

    private func delete<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        token: String,
        decoder: JSONDecoder? = nil
    ) async throws -> Response {
        try await request(path: path, method: "DELETE", body: body, token: token, decoder: decoder)
    }

    private func uploadMultipart<Response: Decodable>(
        path: String,
        method: String,
        token: String,
        fieldName: String,
        filename: String,
        mimeType: String,
        data: Data,
        decoder: JSONDecoder? = nil
    ) async throws -> Response {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: path, relativeTo: APIConfiguration.baseURL) else {
            throw APIError(message: "Invalid API path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkFailure(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid server response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.from(data: responseData, statusCode: httpResponse.statusCode)
        }

        let activeDecoder = decoder ?? self.decoder
        do {
            return try activeDecoder.decode(Response.self, from: responseData)
        } catch {
            throw APIError(message: "Could not parse server response.")
        }
    }

    private func rawPost<Body: Encodable>(_ path: String, body: Body, token: String? = nil) async throws -> Data {
        try await requestData(path: path, method: "POST", body: body, token: token)
    }

    private func decodeSocialAuthResponse(from data: Data) throws -> SocialAuthResponse {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let needsRoleSelection = json["needsRoleSelection"] as? Bool,
           needsRoleSelection {
            let pending = try decoder.decode(SocialAuthPendingResponse.self, from: data)
            return .needsRoleSelection(pending)
        }

        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        return .authenticated(authResponse)
    }

    private func request<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body?,
        token: String?,
        decoder: JSONDecoder? = nil
    ) async throws -> Response {
        let data = try await requestData(path: path, method: method, body: body, token: token)
        let activeDecoder = decoder ?? self.decoder

        do {
            return try activeDecoder.decode(Response.self, from: data)
        } catch {
            throw APIError(message: "Could not parse server response.")
        }
    }

    private func requestData<Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        token: String?
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: APIConfiguration.baseURL) else {
            throw APIError(message: "Invalid API path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkFailure(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid server response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.from(data: data, statusCode: httpResponse.statusCode)
        }

        return data
    }
}

struct UpdateUserRequest: Encodable {
    var fullName: String?
    var phoneNumber: String?
}
