import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Luminark-style palette (deep navy, electric blue, cyan-to-violet glow) on Apple-style structure.
/// surface = page, surfaceContainer* = cards and fills, onSurfaceVariant = secondary text (>= 4.5:1 on surface).
ColorScheme _scheme(Brightness b) {
  final dark = b == Brightness.dark;
  final accent = dark ? const Color(0xFF4D7FFF) : const Color(0xFF2F6BFF);
  return ColorScheme(
    brightness: b,
    primary: accent,
    onPrimary: Colors.white,
    primaryContainer: accent.withValues(alpha: 0.16),
    onPrimaryContainer: accent,
    secondary: const Color(0xFF6E45F7),
    onSecondary: Colors.white,
    tertiary: const Color(0xFF29D3FF),
    onTertiary: const Color(0xFF06070D),
    error: dark ? const Color(0xFFFF453A) : const Color(0xFFD70015),
    onError: Colors.white,
    errorContainer: dark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
    onErrorContainer: Colors.white,
    surface: dark ? const Color(0xFF06070D) : const Color(0xFFF7F8FD),
    onSurface: dark ? const Color(0xFFF4F6FF) : const Color(0xFF0B1430),
    onSurfaceVariant: dark ? const Color(0xFFA3AED0) : const Color(0xFF52617F),
    surfaceContainerLowest: dark ? const Color(0xFF06070D) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF0D1020) : Colors.white,
    surfaceContainer: dark ? const Color(0xFF12162A) : const Color(0xFFEEF1FA),
    surfaceContainerHigh: dark ? const Color(0xFF1B2140) : const Color(0xFFE2E7F5),
    surfaceContainerHighest: dark ? const Color(0xFF283157) : const Color(0xFFCBD3EA),
    outline: dark ? const Color(0xFF6B7698) : const Color(0xFF7A86A6),
    outlineVariant: dark ? const Color(0xFF232A45) : const Color(0xFFD5DCEE),
    inverseSurface: dark ? const Color(0xFFF4F6FF) : const Color(0xFF17213F),
    onInverseSurface: dark ? const Color(0xFF06070D) : Colors.white,
  );
}

/// Brand glow: cyan -> blue -> violet.
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF29D3FF), Color(0xFF2F6BFF), Color(0xFF6E45F7)],
);

const _font = 'Inter';

/// iOS Dynamic Type sizes (Large): largeTitle 34, title1 28, title2 22, title3 20,
/// headline 17 semibold, body 17, callout 16, subheadline 15, footnote 13, caption 12/11.
TextTheme _text(Color label) {
  TextStyle s(double size, FontWeight w, double tracking) =>
      TextStyle(fontFamily: _font, fontSize: size, fontWeight: w, letterSpacing: tracking, color: label);
  return TextTheme(
    displaySmall: s(34, FontWeight.w700, -0.4),
    headlineMedium: s(28, FontWeight.w700, -0.38),
    headlineSmall: s(22, FontWeight.w700, -0.26),
    titleLarge: s(20, FontWeight.w600, -0.45),
    titleMedium: s(17, FontWeight.w600, -0.43),
    titleSmall: s(15, FontWeight.w600, -0.23),
    bodyLarge: s(17, FontWeight.w400, -0.43),
    bodyMedium: s(15, FontWeight.w400, -0.23),
    bodySmall: s(13, FontWeight.w400, -0.08),
    labelLarge: s(17, FontWeight.w600, -0.43),
    labelMedium: s(13, FontWeight.w500, -0.08),
    labelSmall: s(11, FontWeight.w500, 0.06),
  );
}

ThemeData buildTheme(Brightness b) {
  final scheme = _scheme(b);
  final text = _text(scheme.onSurface);
  const radius12 = BorderRadius.all(Radius.circular(12));
  final cupertinoText = CupertinoTextThemeData(
    primaryColor: scheme.primary,
    textStyle: text.bodyLarge,
    actionTextStyle: text.bodyLarge!.copyWith(color: scheme.primary),
    navTitleTextStyle: text.titleMedium,
    navLargeTitleTextStyle: text.displaySmall,
    navActionTextStyle: text.bodyLarge!.copyWith(color: scheme.primary),
    tabLabelTextStyle: text.labelSmall!.copyWith(fontSize: 10, letterSpacing: 0.1),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    fontFamily: _font,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: NoSplash.splashFactory,
    highlightColor: scheme.onSurface.withValues(alpha: 0.06),
    cupertinoOverrideTheme: CupertinoThemeData(brightness: b, primaryColor: scheme.primary, textTheme: cupertinoText),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: const RoundedRectangleBorder(borderRadius: radius12),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary, textStyle: text.bodyLarge),
    ),
    iconTheme: IconThemeData(color: scheme.onSurface),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 0.5, space: 0.5),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium!.copyWith(color: scheme.onInverseSurface),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: b == Brightness.dark ? scheme.surfaceContainer : scheme.surface,
      showDragHandle: true,
      dragHandleColor: scheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 600),
      textStyle: text.labelMedium?.copyWith(color: scheme.onInverseSurface),
    ),
  );
}

final lightTheme = buildTheme(Brightness.light);
final darkTheme = buildTheme(Brightness.dark);

/// iOS-style rubber-band scrolling without the Android stretch/glow.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
