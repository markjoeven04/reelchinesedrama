# UI_COMPONENTS

ReelDrama follows Apple's Human Interface Guidelines, rendered with Flutter's Cupertino widgets on Android.
- **Colors:** Luminark-style palette taken from luminarklabs.com's CSS (`lib/app/theme.dart`). Dark: page `#06070D`, cards `#12162A`. Light: page `#F7F8FD`, white cards, navy text `#0B1430`. Accent blue `#2F6BFF` (light) / `#4D7FFF` (dark); `brandGradient` cyan `#29D3FF` → blue → violet `#6E45F7` for the play button, tab indicator and logo.
- **Type:** Inter (SIL OFL, bundled) on the iOS Dynamic Type scale (34/28/22/20/17/15/13/11).
- **Motion:** Cupertino page transitions with swipe-back, bouncing scroll physics.
- **Appearance:** System / Light / Dark, set in Settings.

Each UI element and the widget that implements it.

| Element | ReelDrama widget | File |
|---|---|---|
| Bottom nav | `AppShell`: `_FloatingTabBar` (frosted capsule, tinted pill + gradient icon for the selected tab) / `_Sidebar` | `lib/app/layout.dart` |
| — | `_Hero` (full-bleed featured pager, Discover / For you, search, gradient play) | `lib/features/home/home_screen.dart` |
| Poster rows | `PosterRow`, `DramaCard` with corner genre tag | `lib/widgets/common.dart` |
| — | Profile card (on-device stats) | `lib/features/settings/settings_screen.dart` |
| Page header | `LargeTitlePage` (collapsing `CupertinoSliverNavigationBar`) | `lib/widgets/common.dart` |
| Drama card | `DramaCard` (EP badge, title, catalog) | `lib/widgets/common.dart` |
| Card grid + Load More | `PagedDramaGrid` | `lib/widgets/common.dart` |
| Catalog chips / filters | `Pill`, `PillRow` (capsules) | `lib/widgets/common.dart` |
| Episode Matrix | `EpisodeMatrix` (20-episode ranges, current/watched) | `lib/widgets/common.dart` |
| History panel | `_ContinueRow` (16:9 cards with progress) | `lib/features/home/home_screen.dart` |
| — | `_FeaturedCarousel` with page dots | `lib/features/home/home_screen.dart` |
| Search input + provider select | `CupertinoSearchTextField` + catalog pills; "Browse Categories" tiles | `lib/features/search/search_screen.dart` |
| Detail page | `_DramaView` (hero art, Play, Save/Share, episodes, More Like This) | `lib/features/drama/drama_screen.dart` |
| Vertical player + right rail | `PlayerView` (vertical episode `PageView`), `_RailButton` / `GlassButton` (frosted) | `lib/features/player/watch_screen.dart` |
| Server / Quality popovers | `CupertinoActionSheet` | same |
| EP / Server badges, progress | `_GlassLabel`, `_Progress` (thin white scrubber) | same |
| Playback failed | `_ErrorPanel` (Retry, Switch server) | same |
| — (tablet) | `_SidePanel` | same |
| Empty / not found | `MessageView` | `lib/app/router.dart` |
| History / Bookmarks | `CupertinoSlidingSegmentedControl`, swipe-to-delete rows | `lib/features/library/library_screen.dart` |
| — | Settings: inset grouped lists, Appearance control, switches, action sheet | `lib/features/settings/settings_screen.dart` |

## Logo
`tools/build_icon.py` generates the mark from one geometry: a white vertical film-strip card with a play cutout on the cyan→blue→violet brand gradient. It writes the adaptive icon (foreground, gradient background, monochrome layer for themed icons) and `reeldrama/assets/brand/logo.svg`. PNGs (`logo.png`, legacy mipmaps) were rendered from the SVG with headless Chrome.
