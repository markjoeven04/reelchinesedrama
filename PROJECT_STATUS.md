# PROJECT_STATUS

Last updated: 2026-11-03. Rebuilt as **ReelDrama** with an Apple-style light/dark UI, a new logo and a Reels-style portrait player.

| Phase | Status | Notes |
|---|---|---|
| 1. Environment | DONE | macOS arm64 (M3 Pro), Flutter 3.47.3 / Dart 3.13.3, JDK 17, Android SDK 36, AVD `Pixel_7_Pro` |
| 4. Licensed content | DONE | 14 CC films → 57 episodes, `reeldrama/assets/demo_catalog.json` |
| 5. Flutter app | DONE | `reeldrama/` |
| 6. Tests | PARTIAL | analyze clean; 25 unit/widget tests pass; the on-device integration test times out on the emulator's slow link (flows checked by hand, TEST_RESULTS.md) |
| 7. APK/AAB + emulator verification | DONE | `dist/`; release APK checked on a phone (light/dark) and at tablet width |
| 9. ReelDrama redesign | DONE | rename, `com.reeldrama.app`, logo, Apple-style theme, reels player |
| 10. Blue short-drama home | DONE | Luminark palette, Discover/For you hero, poster rows, Profile tab, blue logo |
| 8. Docs | DONE | README and 6 documents |

## Needs your decision
1. **Production signing.** The APK uses the debug key. Provide or create an upload keystore (BUILD_INSTRUCTIONS.md).
2. **Content.** For real short dramas, supply a catalog JSON for media you hold rights to.
3. **Publishing.** Not done; needs separate authorization.

## Resume commands
- Emulator: `~/Library/Android/sdk/emulator/emulator -avd Pixel_7_Pro`
- Dev run: `cd reeldrama && flutter run`
- Tests: `flutter test && flutter test integration_test/app_test.dart -d emulator-5554`
