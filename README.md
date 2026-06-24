# Safr iOS

Native SwiftUI client for the Safr safety-first taxi platform.

## Requirements

- Xcode 16+ (iOS 17+ deployment target)
- Running Safr backend (`npm run dev:backend` from monorepo root)
- For physical device testing: Mac and device on the same LAN

## API configuration

| Environment | Configuration |
|-------------|---------------|
| Simulator (default) | `http://localhost:4000/api/v1` |
| Physical device | Set `SAFR_API_BASE_URL` in `Safr/Info.plist` to `http://<Mac-LAN-IP>:4000/api/v1` |
| Staging / production | Set `SAFR_API_BASE_URL` to your deployed API base (e.g. `https://api.safr.app/api/v1`) |

Debug builds log the resolved API and WebSocket URLs to the console.

## Versioning

- **Marketing version:** `1.0.0` (`MARKETING_VERSION` in Xcode)
- **Build number:** increment `CURRENT_PROJECT_VERSION` for each TestFlight upload

## TestFlight release checklist

1. **Signing** — Select your Team under Signing & Capabilities → enable Automatic Signing.
2. **Push Notifications** — In Xcode: Signing & Capabilities → **+ Capability** → Push Notifications. This updates your provisioning profile with `aps-environment` (required for device/archive builds).
3. **Scheme debugger** — In the Safr scheme → Run → Diagnostics, disable **Enable backtrace recording** (avoids iOS 27 debugger crash).
4. **Device API URL** — Set `SAFR_API_BASE_URL` in Info.plist for non-simulator builds, or use a staging server reachable from testers' devices.
5. **Backend** — Ensure Cloudinary env vars are set for photo uploads; APNs env vars optional until native push delivery is configured:
   - `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_PATH`, `APNS_BUNDLE_ID`
6. **Archive** — Product → Archive (Release configuration).
7. **Validate** — Window → Organizer → Validate App.
8. **Distribute** — Upload to App Store Connect → TestFlight.

## Deep links

| URL | Behavior |
|-----|----------|
| `safr://reset-password?token=…` | Opens Reset Password screen |
| `safr://login` | Opens Login (when logged out) |

## Privacy

`PrivacyInfo.xcprivacy` declares UserDefaults usage (driver preferences, offline queue) and collected data types for App Store review.

## Smoke test

1. Rider: login → scan QR → trip → SOS → driver ends → confirm → feedback
2. Rider: manual monitoring + charter request
3. Driver: QR → charter accept → start/end trip
4. Pending driver: application + doc upload
5. Profile: emergency contact + photo
6. Offline SOS → reconnect → sync banner
