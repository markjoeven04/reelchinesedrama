# BUILD_INSTRUCTIONS

## Prerequisites
- Flutter 3.47+ (Dart 3.13+), JDK 17, Android SDK 36 (`flutter doctor` clean for Android)
- An emulator or a USB-debugging device for on-device tests

## Build
```sh
cd reeldrama
flutter pub get
flutter analyze
flutter test                                   # 25 unit + widget tests
flutter test integration_test/app_test.dart -d <device-id>   # needs network
flutter build apk --release                    # → build/app/outputs/flutter-apk/app-release.apk (universal)
flutter build appbundle --release              # → build/app/outputs/bundle/release/app-release.aab
```
Prebuilt outputs are in `dist/` with `SHA256SUMS.txt`.

Install: `adb install -r dist/ReelDrama-1.0.0-universal-release.apk`

Smaller per-ABI APKs: `flutter build apk --release --split-per-abi`.

## Signing (important)
The release build is currently signed with the **Android debug key** (the Flutter template default). It installs and runs, but **cannot be published** to Google Play, and anyone holding the debug key could sign an "update". For production:

1. Create an upload key (keep it out of git; `.gitignore` already excludes `*.jks` and `key.properties`):
   `keytool -genkey -v -keystore ~/reeldrama-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Create `reeldrama/android/key.properties` containing `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
3. In `android/app/build.gradle.kts`, add a `signingConfigs { create("release") { … } }` block that reads `key.properties`, and point `buildTypes.release.signingConfig` at it (see flutter.dev/deployment/android).
4. Enroll in Play App Signing and upload the `.aab`.

Also change `applicationId` (`com.reeldrama.app`) if you publish under a different identity.

## Regenerating the demo catalog
```sh
curl -G 'https://commons.wikimedia.org/w/api.php' --data-urlencode action=query --data-urlencode format=json \
  --data-urlencode prop=videoinfo --data-urlencode 'viprop=url|size|mediatype|extmetadata|derivatives' \
  --data-urlencode viurlwidth=480 --data-urlencode 'titles=File:Big Buck Bunny 4K.webm|…' > tools/commons_videoinfo.json
python3 tools/build_demo_catalog.py tools/commons_videoinfo.json   # writes reeldrama/assets/demo_catalog.json
```
The title list and original descriptions are in `tools/build_demo_catalog.py` (`META`).
