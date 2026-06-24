//
//  ScanQrView.swift
//  Safr
//

import AVFoundation
import SwiftUI

struct ScanQrView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.dismiss) private var dismiss

    var onNavigate: (RiderRoute) -> Void

    @State private var manualCode = ""
    @State private var feedback: ScanFeedback = .idle
    @State private var isScannerLocked = false
    @State private var cameraAuthorized = false
    @State private var showCamera = false

    enum ScanFeedback: Equatable {
        case idle
        case loading
        case error(title: String, detail: String)
        case success(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                Text("Scan Driver QR")
                    .font(.largeTitle.bold())
                    .foregroundStyle(SafrTheme.Colors.textPrimary)

                Text("Verify the taxi before you board. On Simulator, paste a driver code below.")
                    .foregroundStyle(SafrTheme.Colors.textSecondary)

                scannerSection

                feedbackView

                VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
                    Text("Manual code entry")
                        .font(.headline)
                        .foregroundStyle(SafrTheme.Colors.textPrimary)

                    SafrTextField(title: "Driver or trip QR value", text: $manualCode)

                    SafrPrimaryButton(
                        title: "Verify code",
                        isLoading: feedback == .loading,
                        isDisabled: manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        Task { await verifyCode(manualCode, source: .manual) }
                    }
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Scan QR")
        .navigationBarTitleDisplayMode(.inline)
        .safrDismissKeyboardOnTap()
        .task { await prepareCamera() }
    }

    @ViewBuilder
    private var scannerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SafrTheme.Radius.md)
                .fill(SafrTheme.Colors.surface)
                .frame(height: 280)

            if showCamera {
                if #available(iOS 16.0, *) {
                    QRScannerView(onScan: { raw in
                        Task { await verifyCode(raw, source: .camera) }
                    }, isLocked: $isScannerLocked)
                    .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
                    .frame(height: 280)
                }
            } else {
                VStack(spacing: SafrTheme.Spacing.sm) {
                    Image(systemName: cameraAuthorized ? "camera.fill" : "camera.slash")
                        .font(.largeTitle)
                        .foregroundStyle(SafrTheme.Colors.accent)
                    Text(cameraAuthorized ? "Camera unavailable in this environment" : "Camera access required for scanning")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                        .padding(.horizontal)
                }
            }

            RoundedRectangle(cornerRadius: SafrTheme.Radius.sm)
                .stroke(SafrTheme.Colors.accent.opacity(0.8), lineWidth: 2)
                .frame(width: 180, height: 180)
        }
    }

    @ViewBuilder
    private var feedbackView: some View {
        switch feedback {
        case .idle:
            EmptyView()
        case .loading:
            HStack {
                ProgressView().tint(SafrTheme.Colors.accent)
                Text("Verifying…")
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
            }
        case .error(let title, let detail):
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
                Text(title).foregroundStyle(SafrTheme.Colors.danger).fontWeight(.semibold)
                Text(detail).foregroundStyle(SafrTheme.Colors.textSecondary).font(.subheadline)
            }
        case .success(let message):
            Text(message)
                .foregroundStyle(SafrTheme.Colors.success)
                .font(.subheadline)
        }
    }

    private func prepareCamera() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
            showCamera = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
            showCamera = granted
        default:
            cameraAuthorized = false
            showCamera = false
        }
    }

    private func verifyCode(_ rawValue: String, source: ScanSource) async {
        guard let token = session.accessToken else { return }
        feedback = .loading
        isScannerLocked = true

        do {
            if let tripQr = QRCodeParser.parseTripVerificationQr(rawValue) {
                let verification = try await APIClient.shared.verifyTripQr(
                    token: token,
                    tripId: tripQr.tripId,
                    verificationToken: tripQr.verificationToken
                )
                let route = try VerificationRouteData(
                    tripVerification: tripQr.tripId,
                    verification: verification
                )
                onNavigate(.verification(route))
                return
            }

            guard let code = QRCodeParser.normalizeDriverQrCode(rawValue) else {
                let mapped = VerificationErrorMapper.mapParseFailure(source: source)
                feedback = .error(title: mapped.title, detail: mapped.detail)
                unlockScanner()
                return
            }

            let verification = try await APIClient.shared.verifyDriverQr(token: token, code: code)
            let route = try VerificationRouteData(driverQr: code, verification: verification)
            onNavigate(.verification(route))
        } catch {
            let mapped = VerificationErrorMapper.map(error, source: source)
            feedback = .error(title: mapped.title, detail: mapped.detail)
            unlockScanner()
        }
    }

    private func unlockScanner() {
        isScannerLocked = false
    }
}
