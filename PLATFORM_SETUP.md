# EastApp v277 platform setup

This package is the lib-focused EastApp source package. It does not contain the full `android/` or `ios/` projects.

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

## Dependency notes

`flutter_secure_storage` remains on 11.0.0. EastApp v272/v273 already used v10.3.1, whose Android migration is enabled by default, so current installations that have run v10 are on the supported migration path. Do not let an installation jump directly from a pre-v10 EastApp build to v277; run a v10-based build first so legacy secure-storage data is migrated.

After replacing the v277 files in the full project, run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
```
