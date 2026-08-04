# EastApp v262 platform setup

The SKU edit screen now supports selecting a replacement image from the device gallery through `image_picker`.

For iOS, ensure `ios/Runner/Info.plist` contains a user-facing `NSPhotoLibraryUsageDescription`, for example:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>EastApp needs photo-library access so u can replace an SKU photo.</string>
```

The supplied EastApp package is lib-focused and does not contain the iOS Runner project, so this platform entry cannot be inserted into this ZIP automatically.
