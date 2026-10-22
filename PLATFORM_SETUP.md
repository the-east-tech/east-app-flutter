# Flow platform setup

The authoritative source is the complete Flutter Git repository.

## Current Android baseline

The full local project previously used:

- Android Gradle Plugin: 9.3.1
- Gradle wrapper: 9.5.0

Keep the full project aligned with that baseline unless u intentionally migrate it.

## Attendance change in v275

Attendance face capture/detection has been removed from the active Flutter implementation and `google_mlkit_face_detection` has been removed from `pubspec.yaml`.

Attendance now uses:

- `mobile_scanner` for scanning attendance QR codes
- `qr_flutter` for rendering generated attendance QR codes
- `geolocator` for mandatory GPS capture

The QR scanner still requires camera access. Keep the full platform project's existing camera permission configuration. On iOS, ensure `ios/Runner/Info.plist` contains a user-facing `NSCameraUsageDescription`.

Example:

```xml
<key>NSCameraUsageDescription</key>
<string>Flow needs camera access to scan attendance QR codes.</string>
```

GPS remains required for Attendance. Keep the existing Android/iOS location permissions used by Flow.

## iOS photo-library permission

The SKU edit screen supports selecting a replacement image from the device gallery through `image_picker`.

Ensure `ios/Runner/Info.plist` contains a user-facing `NSPhotoLibraryUsageDescription`, for example:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Flow needs photo-library access so u can replace an SKU photo.</string>
```

## Native notifications

Create Android and iOS apps in one Firebase project using these current identifiers:

- Android application ID: `com.sequosal.flow`
- iOS production bundle ID: `com.sequosal.flow`

The project is configured for paid Apple Developer Team `24MJ8NMULJ` across iOS Debug, Profile and Release. The production Bundle ID is `com.sequosal.flow` for all three configurations. The original identifier must be released by Apple and registered under this paid team before signing, TestFlight or App Store distribution succeeds.

Push-capable entitlements are selected for Debug/Profile (`Runner/PushDebugProfile.entitlements`) and Release (`Runner/PushRelease.entitlements`). After Apple releases the identifier, enable Push Notifications on that App ID, create or refresh signing profiles as necessary and upload the APNs authentication key to Firebase. Do not use the old Personal Team or create a temporary production Bundle ID.

The Firebase client values for project `sequosal-flow` are included in
`lib/firebase_options.dart`. Run Flow normally:

```bash
flutter run
```

No Firebase `--dart-define` parameters are required.

## Dependency notes

`flutter_secure_storage` remains on 11.0.0. Flow v272/v273 already used v10.3.1, whose Android migration is enabled by default, so current installations that have run v10 are on the supported migration path. Do not let an installation jump directly from a pre-v10 Flow build to v277; run a v10-based build first so legacy secure-storage data is migrated.

From the project root, run normally:

```bash
flutter run
```

## Project identity

- Flutter/Dart package: `flow_app`
- Android application ID: `com.sequosal.flow`
- iOS production Bundle ID: `com.sequosal.flow`
- Apple paid Team ID: `24MJ8NMULJ`
- Existing secure-storage keys remain unchanged for existing sessions. Release builds use only the `FLOW_API_BASE_URL` Dart define.
