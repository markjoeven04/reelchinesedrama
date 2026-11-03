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

## Refreshing the catalogs
The bundled catalogs (`reeldrama/assets/dramabox_catalog.json`, `reeldrama/assets/reelshort_catalog.json`) are generated from APIShort by `tools/fetch_apishort_catalog.py`. That script and the `.env` file holding `APISHORT_API_KEY` are kept out of the repository.
```sh
python3 tools/fetch_apishort_catalog.py --platform dramabox --out reeldrama/assets/dramabox_catalog.json
python3 tools/fetch_apishort_catalog.py --platform reelshort --out reeldrama/assets/reelshort_catalog.json
```
DramaBox episode links are signed and expire, so refresh both catalogs and rebuild the APK before each release.

A new owner of the project must use their own APIShort API key; the original key does not transfer (README.md, "Ownership and API access").

## Creative Commons demo catalog (optional, not bundled)
`tools/build_demo_catalog.py` builds a catalog of Blender open movies from Wikimedia Commons, useful for demos without licensed content:
```sh
curl -G 'https://commons.wikimedia.org/w/api.php' --data-urlencode action=query --data-urlencode format=json \
  --data-urlencode prop=videoinfo --data-urlencode 'viprop=url|size|mediatype|extmetadata|derivatives' \
  --data-urlencode viurlwidth=480 --data-urlencode 'titles=File:Big Buck Bunny 4K.webm|…' > tools/commons_videoinfo.json
python3 tools/build_demo_catalog.py tools/commons_videoinfo.json   # writes reeldrama/assets/demo_catalog.json
```
To use it, list `assets/demo_catalog.json` in `pubspec.yaml` and in `CatalogService.bundledAssets` (`lib/data/drama_repository.dart`).
