import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(libraryProvider);
    final lib = ref.read(libraryProvider.notifier);
    final catalogs = ref.watch(catalogsProvider).value?.catalogs ?? const [];
    final s = Theme.of(context).colorScheme;
    final theme = lib.repo.prefs['theme'] ?? 'system';
    return LargeTitlePage(
      title: 'Profile',
      slivers: [
        SliverList.list(
          children: [
            const _ProfileCard(),
            _section(
              context,
              header: _caption(context, 'APPEARANCE'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: theme,
                      onValueChanged: (v) => lib.setPref('theme', v ?? 'system'),
                      children: const {
                        'system': Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('System')),
                        'light': Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Light')),
                        'dark': Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Dark')),
                      },
                    ),
                  ),
                ),
              ],
            ),
            _section(
              context,
              header: _caption(context, 'PLAYBACK'),
              children: [
                CupertinoListTile(
                  leading: const _SettingsIcon(CupertinoIcons.forward_end_fill, Color(0xFFFF9500)),
                  title: const Text('Autoplay next episode'),
                  trailing: CupertinoSwitch(
                    value: lib.autoplayNext,
                    activeTrackColor: CupertinoColors.systemGreen,
                    onChanged: (v) => lib.setPref('autoplay_next', '$v'),
                  ),
                  onTap: () => lib.setPref('autoplay_next', '${!lib.autoplayNext}'),
                ),
                CupertinoListTile(
                  leading: const _SettingsIcon(CupertinoIcons.fullscreen, Color(0xFF5856D6)),
                  title: const Text('Fill screen'),
                  subtitle: const Text('Crop video instead of letterboxing'),
                  trailing: CupertinoSwitch(
                    value: lib.fillScreen,
                    activeTrackColor: CupertinoColors.systemGreen,
                    onChanged: (v) => lib.setPref('video_fit', v ? 'cover' : 'contain'),
                  ),
                  onTap: () => lib.setPref('video_fit', lib.fillScreen ? 'contain' : 'cover'),
                ),
                CupertinoListTile(
                  leading: const _SettingsIcon(CupertinoIcons.sparkles, Color(0xFF007AFF)),
                  title: const Text('Preferred quality'),
                  additionalInfo: Text(lib.preferredQuality),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => showCupertinoModalPopup<void>(
                    context: context,
                    builder: (c) => CupertinoActionSheet(
                      title: const Text('Preferred Quality'),
                      actions: [
                        for (final q in ['240p', '480p', '1080p'])
                          CupertinoActionSheetAction(
                            isDefaultAction: q == lib.preferredQuality,
                            onPressed: () {
                              Navigator.pop(c);
                              lib.setPref('quality', q);
                            },
                            child: Text(q),
                          ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _section(
              context,
              header: _caption(context, 'CATALOGS'),
              footer: _caption(context, 'A JSON catalog of media you are authorized to stream.'),
              children: [
                for (final c in catalogs)
                  CupertinoListTile(
                    leading: const _SettingsIcon(CupertinoIcons.film_fill, Color(0xFFFF2D55)),
                    title: Text(c.name),
                    subtitle: Text(c.sourceUrl ?? 'Built-in · ${c.dramas.length} titles'),
                    trailing: c.sourceUrl == null
                        ? null
                        : IconBtn(
                            icon: CupertinoIcons.minus_circle_fill,
                            tooltip: 'Remove catalog',
                            color: CupertinoColors.systemRed,
                            onPressed: () => ref.read(catalogsProvider.notifier).remove(c.sourceUrl!),
                          ),
                  ),
                CupertinoListTile(
                  leading: const _SettingsIcon(CupertinoIcons.link, Color(0xFF34C759)),
                  title: Text('Add catalog from URL', style: TextStyle(color: s.primary)),
                  onTap: () => showCupertinoDialog<void>(context: context, builder: (_) => const _AddCatalogDialog()),
                ),
              ],
            ),
            _section(
              context,
              header: _caption(context, 'PRIVACY & DATA'),
              children: [
                CupertinoListTile(
                  title: Text('Clear watch history', style: TextStyle(color: s.error)),
                  onTap: () async {
                    await lib.clearHistory();
                    if (context.mounted) _toast(context, 'Watch history cleared');
                  },
                ),
                CupertinoListTile(
                  title: Text('Clear recent searches', style: TextStyle(color: s.error)),
                  onTap: () async {
                    await lib.clearSearches();
                    if (context.mounted) _toast(context, 'Recent searches cleared');
                  },
                ),
              ],
            ),
            _section(
              context,
              header: _caption(context, 'ABOUT'),
              children: [
                const CupertinoListTile(
                  leading: _SettingsIcon(CupertinoIcons.hand_raised_fill, Color(0xFF007AFF)),
                  title: Text('No ads, no tracking'),
                  subtitle: Text('Your library stays on this device.'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Inset grouped section using the app palette (navy cells in dark, white in light).
Widget _section(BuildContext context, {Widget? header, Widget? footer, required List<Widget> children}) {
  final s = Theme.of(context).colorScheme;
  return CupertinoListSection.insetGrouped(
    header: header,
    footer: footer,
    backgroundColor: s.surface,
    separatorColor: s.outlineVariant,
    decoration: BoxDecoration(
      color: s.brightness == Brightness.dark ? s.surfaceContainer : s.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
    ),
    children: children,
  );
}

/// Footnote-style section header/footer text, as in iOS Settings.
Widget _caption(BuildContext context, String text) => Text(
  text,
  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
);

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// Brand card: there are no accounts, so it states what the app keeps on the device.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(libraryProvider);
    final repo = ref.read(libraryRepositoryProvider);
    final t = Theme.of(context).textTheme;
    Widget stat(int n, String label) => Expanded(
      child: Column(
        children: [
          Text(
            '$n',
            style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          Text(label, style: t.bodySmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const RadialGradient(
          center: Alignment(0.6, -0.8),
          radius: 1.4,
          colors: [Color(0xFF3B4FD8), Color(0xFF17213F), Color(0xFF0A1232)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F6BFF).withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/brand/logo.png', width: 56, height: 56),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ReelDrama',
                      style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    Text('No account needed · no ads', style: t.bodySmall?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 0.5, color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(repo.history.length, 'Watched'),
              stat(repo.bookmarks.length, 'Saved'),
              stat(repo.likes.length, 'Liked'),
            ],
          ),
        ],
      ),
    );
  }
}

/// White SF-style glyph on a colored rounded square, as in iOS Settings.
class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 29,
    height: 29,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
    child: Icon(icon, size: 18, color: Colors.white),
  );
}

class _AddCatalogDialog extends ConsumerStatefulWidget {
  const _AddCatalogDialog();

  @override
  ConsumerState<_AddCatalogDialog> createState() => _AddCatalogDialogState();
}

class _AddCatalogDialogState extends ConsumerState<_AddCatalogDialog> {
  final _url = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await ref.read(catalogsProvider.notifier).add(_url.text);
      if (!mounted) return;
      Navigator.pop(context);
      _toast(context, 'Added "${c.name}" (${c.dramas.length} titles)');
    } on Object catch (e) {
      setState(() {
        _busy = false;
        _error = e is FormatException ? e.message : 'Could not load catalog: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: const Text('Add Catalog'),
    content: Column(
      children: [
        const Text('Enter the HTTPS address of a JSON catalog.'),
        const SizedBox(height: 12),
        CupertinoTextField(
          controller: _url,
          autofocus: true,
          keyboardType: TextInputType.url,
          placeholder: 'https://example.com/catalog.json',
          onSubmitted: (_) => _add(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
        ],
      ],
    ),
    actions: [
      CupertinoDialogAction(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: _busy ? null : _add,
        child: _busy ? const CupertinoActivityIndicator() : const Text('Add'),
      ),
    ],
  );
}
