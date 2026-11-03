# TEST_RESULTS (2026-11-03, ReelDrama redesign)

Environment: macOS arm64 · Flutter 3.47.3 / Dart 3.13.3 · Emulator `Pixel_7_Pro` (Android 16, arm64) · Media3 ExoPlayer 1.9.2 (via video_player).

## Automated

| Suite | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found** |
| Unit tests (`test/data_test.dart`, 15) | `flutter test` | **Pass** |
| Widget tests (`test/widget_test.dart`, 10) | `flutter test` | **Pass**. Tab bar vs. sidebar at 5 widths; detail → bookmark → Library → remove; search suggestions/results/empty/recent/category tile; Explore genre filter; Library empty state; Settings autoplay toggle and **Appearance → Dark** switches the theme and persists; not-found route |
| On-device integration (`integration_test/app_test.dart`) | `flutter test integration_test/app_test.dart -d emulator-5554` | **Not passing on this network.** In 5 runs it timed out at a different step each time: EP1 playback, EP2 playback, or resume after restart. The best run passed playback, next episode, HLS server switch and history save. The emulator's link to Wikimedia was slow (480p fell back to 240p; a 240p episode took about 20 s to start). The same flows were confirmed by hand on the release APK (below). The log showed no app exceptions; one HTTP 416 from Wikimedia appeared at teardown. |

## Manual on the emulator (release APK, `screenshots/`)

| Check | Result | Evidence |
|---|---|---|
| Install + launch, label "ReelDrama", id `com.reeldrama.app` | Pass | `aapt2 dump badging`, `rd-home-light.png` |
| Blue home: hero with Discover / For you, poster rows, status-bar scrim (light and dark) | Pass | `rd-home-*.png` |
| Profile tab (dark), detail page (light) | Pass | `rd-profile-dark.png`, `rd-detail-light.png` |
| Reels player: full-bleed portrait playback; swipe up → EP 2 plays (checked before the color change) | Pass | `rd-reel-1.png` |
| Tablet ~960dp | Checked before the blue redesign only; not re-shot | — |
| Slow network → automatic fallback to 240p | Pass (snackbar shown) | — |
| Ad SDKs in APK | None (0 matches for admob/applovin/unity/ironsource/facebook ads) | — |
| minSdk / targetSdk | 26 / 36 | `aapt2 dump badging` |

## Defects found and fixed during testing
1. **480p WebM never started on a slow link.** `initialize()` timed out at 30 s (`debug-webm-480p-timeout.png`). The cause was Wikimedia throughput of ~100–470 KB/s on this network, not the format. Fix: 12 s deadline for higher qualities, then automatic fallback to the lowest quality.
2. **Riverpod `UnmountedRefException`** when the player saved progress during shutdown. Fixed with a `ref.mounted` guard (found by the integration test).
3. **Featured carousel reset** on rebuild (controller recreated) and centered first page on tablets. Fixed.
4. **Unreadable "N EP" badge text.** Fixed.
5. **Action rail overflow** in phone landscape. Fixed (bounded and scrollable).

Redesign fixes: genre pills stretched full width inside `Wrap`; the large-title bar showed a gray band at rest (now transparent until content scrolls under); Settings section headers were oversized; frosted buttons were invisible on black; rail labels were unreadable on bright video (stronger shadow); the sidebar title overflowed with large text.

## Not tested / limitations
- Not re-checked after the redesign: phone landscape, full-screen mode, offline → Retry.
- Android split-screen / freeform windows and physical foldables (width-driven layout was tested by resizing the display instead).
- Physical Android devices (emulator only).
- DASH and MP4 playback (supported in code, but no licensed sources in the demo catalog).
- Importing a remote catalog end to end (validation is unit-tested; no hosted test catalog was used).
- The Share sheet was opened but its target apps were not exercised.
- Performance and battery profiling.
