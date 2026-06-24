//
//  PushNotificationService.swift
//  Safr
//

import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()

    private enum KeychainKey {
        static let apnsToken = "safr.apns.token"
    }

    private var authToken: String?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermissionAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func registerIfNeeded(session: SessionManager) async {
        guard let token = session.accessToken else { return }
        authToken = token
        await requestPermissionAndRegister()
    }

    func handleDeviceToken(_ deviceToken: Data) async {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard let token = authToken else { return }

        let previous = KeychainHelper.load(for: KeychainKey.apnsToken)

        do {
            if let previous, previous != hex {
                _ = try? await APIClient.shared.unregisterDevice(token: token, apnsDeviceToken: previous)
            }

            _ = try await APIClient.shared.registerDevice(
                token: token,
                apnsDeviceToken: hex,
                platform: "ios"
            )
            KeychainHelper.save(hex, for: KeychainKey.apnsToken)
        } catch {
            #if DEBUG
            print("[Safr] APNs registration failed: \(error.localizedDescription)")
            #endif
        }
    }

    func unregister(session: SessionManager) async {
        guard let token = session.accessToken else { return }
        await unregister(authToken: token)
    }

    func unregister(authToken: String) async {
        guard let apnsToken = KeychainHelper.load(for: KeychainKey.apnsToken) else { return }
        _ = try? await APIClient.shared.unregisterDevice(token: authToken, apnsDeviceToken: apnsToken)
        KeychainHelper.delete(for: KeychainKey.apnsToken)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
