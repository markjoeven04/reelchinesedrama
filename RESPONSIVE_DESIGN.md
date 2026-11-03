# RESPONSIVE_DESIGN

Layout is chosen from the **actual available width** (`MediaQuery.sizeOf`, `LayoutBuilder`), never from device names. See `lib/app/layout.dart`.

| Window class | Width | Navigation | Grid columns (`width/170`, clamped 2–6) | Detail page | Player |
|---|---|---|---|---|---|
| compact | < 600dp | Translucent iOS tab bar (`CupertinoTabBar`) | 2 | single column | full-bleed portrait reel |
| medium | 600–839dp | Tab bar | 3–4 | single column | full-bleed portrait reel |
| expanded | 840–1199dp | iPadOS-style sidebar (240dp) | 4–5 | hero + two columns (info / episodes) | reel + 360dp side panel |
| large | ≥ 1200dp | Sidebar (280dp) | 5–6 | hero + two columns | reel + side panel |

Player (Reels-style):
- A vertical `PageView` with one page per episode. Swipe up/down changes episode. Previous/next buttons and the episode sheet do the same, for users who can't swipe.
- Video **fills** the reel by default (crop to fill; `video_fit=contain` letterboxes). The demo films are landscape, so the sides are cropped in portrait.
- When the window is wider than 9:16 (landscape phones, wide tablets), the reel is a centered 9:16 column.
- Full screen: immersive, locked to landscape for landscape video, shows the whole frame (fit). Paging is disabled in full screen.

## Verification (release APK, Pixel 7 Pro emulator)
| Target | Screens |
|---|---|
| Phone 412dp, light / dark | `screenshots/rd-home-*.png`, `rd-profile-dark.png`, `rd-detail-light.png`, `rd-reel-1.png` |
| Tablet ~960dp (`wm density 240`) | Checked before the blue redesign; widget tests still cover 840 and 1200dp |

Widget tests check the navigation type at 360, 393, 600, 840 and 1200dp.

**Not re-tested after the redesign:** phone landscape, split-screen / freeform multi-window, physical foldables.
