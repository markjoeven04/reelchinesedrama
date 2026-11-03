import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// Breakpoints on the actual available width.
enum WindowSize { compact, medium, expanded, large }

WindowSize windowSizeFor(double width) => width < 600
    ? WindowSize.compact
    : width < 840
    ? WindowSize.medium
    : width < 1200
    ? WindowSize.expanded
    : WindowSize.large;

/// Grid columns for poster cards: 2 on phones up to 6 on large tablets.
int gridColumnsFor(double width) => (width / 170).floor().clamp(2, 6);

const _destinations = [
  (icon: CupertinoIcons.house, selected: CupertinoIcons.house_fill, label: 'Home'),
  (icon: CupertinoIcons.square_grid_2x2, selected: CupertinoIcons.square_grid_2x2_fill, label: 'Explore'),
  (icon: CupertinoIcons.bookmark, selected: CupertinoIcons.bookmark_fill, label: 'My List'),
  (icon: CupertinoIcons.person_crop_circle, selected: CupertinoIcons.person_crop_circle_fill, label: 'Profile'),
];

/// Floating glass tab bar below 840dp; an iPadOS-style sidebar on wider windows.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int i) {
    if (i != shell.currentIndex) HapticFeedback.selectionClick();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final size = windowSizeFor(MediaQuery.sizeOf(context).width);
    if (size.index < WindowSize.expanded.index) {
      return Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: _FloatingTabBar(current: shell.currentIndex, onSelect: _go),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(width: size == WindowSize.large ? 280 : 240, current: shell.currentIndex, onSelect: _go),
          const VerticalDivider(width: 0.5),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.width, required this.current, required this.onSelect});

  final double width;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('sidebar'),
      width: width,
      color: scheme.surfaceContainer,
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/brand/logo.png', width: 34, height: 34),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'ReelDrama',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, d) in _destinations.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: i == current ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(i),
                    child: Semantics(
                      selected: i == current,
                      button: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Row(
                          children: [
                            Icon(
                              i == current ? d.selected : d.icon,
                              size: 22,
                              color: i == current ? scheme.onPrimary : scheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              d.label,
                              style: t.bodyLarge?.copyWith(
                                color: i == current ? scheme.onPrimary : scheme.onSurface,
                                fontWeight: i == current ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Floating frosted capsule; the selected tab sits in a tinted pill with a gradient icon.
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final dark = s.brightness == Brightness.dark;
    return SafeArea(
      key: const ValueKey('tabbar'),
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: (dark ? Colors.black : const Color(0xFF17213F)).withValues(alpha: dark ? 0.5 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 64,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: (dark ? const Color(0xFF151A2E) : Colors.white).withValues(alpha: dark ? 0.78 : 0.85),
                  border: Border.all(color: dark ? const Color(0x1FFFFFFF) : s.outlineVariant, width: 0.5),
                ),
                child: Row(
                  children: [
                    for (final (i, d) in _destinations.indexed)
                      Expanded(
                        child: _TabItem(
                          icon: i == current ? d.selected : d.icon,
                          label: d.label,
                          selected: i == current,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final fg = selected ? s.primary : s.onSurfaceVariant;
    final glyph = Icon(icon, size: 22, color: selected ? Colors.white : fg);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: selected ? s.primary.withValues(alpha: 0.14) : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              selected ? ShaderMask(shaderCallback: brandGradient.createShader, child: glyph) : glyph,
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
