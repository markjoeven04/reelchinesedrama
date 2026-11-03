import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/layout.dart';
import '../../app/router.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/common.dart';

/// Watch history (with resume progress) and bookmarks, both stored on the device.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.tab});

  final String? tab;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late int _tab = widget.tab == 'bookmarks' ? 1 : 0;

  @override
  void didUpdateWidget(LibraryScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab && widget.tab != null) _tab = widget.tab == 'bookmarks' ? 1 : 0;
  }

  Future<void> _confirmClear(LibraryNotifier notifier) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('Clear Watch History?'),
        content: const Text('Progress and watched episodes will be removed from this device.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) await notifier.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    final repo = ref.read(libraryRepositoryProvider);
    final notifier = ref.read(libraryProvider.notifier);
    return LargeTitlePage(
      title: 'My List',
      trailing: _tab == 0
          ? IconBtn(
              icon: CupertinoIcons.trash,
              tooltip: 'Clear history',
              onPressed: repo.history.isEmpty ? null : () => _confirmClear(notifier),
            )
          : null,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _tab,
              onValueChanged: (v) => setState(() => _tab = v ?? 0),
              children: const {
                0: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('History')),
                1: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Bookmarks')),
              },
            ),
          ),
        ),
        if (_tab == 0)
          ..._history(repo.historyByRecent, notifier.removeHistory)
        else
          ..._bookmarks(repo.bookmarksByRecent, notifier.removeBookmark),
      ],
    );
  }

  List<Widget> _history(List<LibraryItem> items, ValueChanged<String> onRemove) {
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            icon: CupertinoIcons.clock,
            title: 'No watch history yet',
            message: 'Episodes you watch appear here so you can pick up where you left off.',
            action: FilledButton(onPressed: () => context.go('/explore'), child: const Text('Explore')),
          ),
        ),
      ];
    }
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return [
      SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Padding(padding: EdgeInsets.only(left: 152), child: Divider()),
        itemBuilder: (context, i) {
          final it = items[i];
          return Dismissible(
            key: ValueKey(it.dramaKey),
            direction: DismissDirection.endToStart,
            background: Container(
              color: s.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: Text('Delete', style: t.titleMedium?.copyWith(color: s.onErrorContainer)),
            ),
            onDismissed: (_) => onRemove(it.dramaKey),
            child: InkWell(
              onTap: () => context.push(watchPath(it.dramaKey, it.episode)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 124,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Poster(it.poster, radius: 8),
                            Positioned(
                              left: 6,
                              right: 6,
                              bottom: 6,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: it.progress,
                                  minHeight: 3,
                                  color: Colors.white,
                                  backgroundColor: Colors.white38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            'Episode ${it.episode} · ${formatDuration(it.position)}',
                            style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(CupertinoIcons.play_circle, color: s.primary, size: 28),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _bookmarks(List<LibraryItem> items, ValueChanged<String> onRemove) {
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            icon: CupertinoIcons.bookmark,
            title: 'No bookmarks yet',
            message: 'Tap Save on a drama or in the player to keep it here.',
            action: FilledButton(onPressed: () => context.go('/explore'), child: const Text('Explore')),
          ),
        ),
      ];
    }
    final t = Theme.of(context).textTheme;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverLayoutBuilder(
          builder: (context, c) => SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridColumnsFor(c.crossAxisExtent),
              childAspectRatio: 0.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 20,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              return GestureDetector(
                onTap: () => context.push(dramaPath(it.dramaKey)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Poster(it.poster),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Tooltip(
                              message: 'Remove bookmark',
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(44, 44),
                                onPressed: () => onRemove(it.dramaKey),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(CupertinoIcons.bookmark_fill, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ];
  }
}
