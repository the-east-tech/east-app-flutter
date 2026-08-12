# EastApp v274 platform setup

This package is the lib-focused EastApp source package. It does not contain the full `android/` or `ios/` projects.

## Current Android baseline

The full local project has been verified with:

- Android Gradle Plugin: 9.3.1
- Gradle wrapper: 9.5.0

Keep `android/gradle/wrapper/gradle-wrapper.properties` on Gradle 9.5.0 while AGP 9.3.1 is used.

## iOS photo-library permission

The SKU edit screen supports selecting a replacement image from the device gallery through `image_picker`.

Ensure `ios/Runner/Info.plist` contains a user-facing `NSPhotoLibraryUsageDescription`, for example:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>EastApp needs photo-library access so u can replace an SKU photo.</string>
```

## Dependency notes

`flutter_secure_storage` is upgraded to 11.0.0 in v274. EastApp v272/v273 already used v10.3.1, whose Android migration is enabled by default, so current installations that have run v10 are on the supported migration path. Do not let an installation jump directly from a pre-v10 EastApp build to v274; run a v10-based build first so legacy secure-storage data is migrated.

`google_mlkit_face_detection` remains on 0.14.0, the current stable release. Its current Android plugin still triggers Flutter's Built-in Kotlin migration warning. That warning is upstream of EastApp and should not be hidden or worked around by patching generated plugin files.

After replacing the v274 files in the full project, run:

```bash
flutter clean
flutter pub get
flutter pub upgrade
flutter analyze
flutter build apk --debug
```
