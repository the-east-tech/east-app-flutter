# EastApp v309 platform setup

This release package contains the complete changed `lib/` folder and the
changed root files only.

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
<string>EastApp needs camera access to scan attendance QR codes.</string>
```

GPS remains required for Attendance. Keep the existing Android/iOS location permissions used by EastApp.

## iOS photo-library permission

The SKU edit screen supports selecting a replacement image from the device gallery through `image_picker`.

Ensure `ios/Runner/Info.plist` contains a user-facing `NSPhotoLibraryUsageDescription`, for example:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>EastApp needs photo-library access so u can replace an SKU photo.</string>
```

## Native notifications

Create Android and iOS apps in one Firebase project using these current identifiers:

- Android application ID: `com.jenssen.eastapp.east_app`
- iOS bundle ID: `com.jenssen.eastapp.test`

For iPhone, enable Push Notifications for the App ID and upload the Apple APNs authentication key to Firebase. The checked-in entitlements already select development APNs for debug/profile and production APNs for release builds.

The Firebase client values for project `theeast-888` are included in
`lib/firebase_options.dart`. Run EastApp normally:

```bash
flutter run
```

No Firebase `--dart-define` parameters are required.

## Dependency notes

`flutter_secure_storage` remains on 11.0.0. EastApp v272/v273 already used v10.3.1, whose Android migration is enabled by default, so current installations that have run v10 are on the supported migration path. Do not let an installation jump directly from a pre-v10 EastApp build to v277; run a v10-based build first so legacy secure-storage data is migrated.

After replacing the v309 files in the full project, run normally:

```bash
flutter run
```
