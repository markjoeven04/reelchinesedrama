import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../data/drama_repository.dart';
import '../../widgets/common.dart';

/// Home: full-bleed featured hero with Discover / For you tabs, then poster rows.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  final _scrolled = ValueNotifier(0.0);

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    final history = ref.read(libraryRepositoryProvider).historyByRecent;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
                _scrolled.value = ((n.metrics.pixels - 160) / 80).clamp(0.0, 1.0);
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                ...catalogSlivers(ref, (repo) {
                  return [
                    SliverToBoxAdapter(
                      child: _Hero(
                        dramas: repo.featured.isEmpty ? repo.all.take(5).toList() : repo.featured,
                        tab: _tab,
                        onTab: (i) => setState(() => _tab = i),
                      ),
                    ),
                    if (_tab == 0) ..._discover(repo, history) else ..._forYou(repo, history),
                  ];
                }),
                SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
              ],
            ),
          ),
          // Keeps scrolled content out from under the status bar.
          IgnorePointer(
            child: ValueListenableBuilder(
              valueListenable: _scrolled,
              builder: (context, v, _) {
                final dark = Theme.of(context).brightness == Brightness.dark;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  // Light icons over the hero; theme-matching icons once the scrim is up.
                  value: v < 0.5 || dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                  child: Container(
                    height: top,
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: v),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _discover(DramaRepository repo, List<LibraryItem> history) => [
    if (history.isNotEmpty) ...[
      SliverToBoxAdapter(
        child: SectionHeader(
          'Continue Watching',
          action: TextAction('See All', onPressed: () => context.go('/library?tab=history')),
        ),
      ),
      SliverToBoxAdapter(child: _ContinueRow(history)),
    ],
    for (final c in repo.catalogs) ...[
      SliverToBoxAdapter(
        child: SectionHeader(
          c.name,
          subtitle: '${c.dramas.length} titles',
          action: TextAction('See All', onPressed: () => context.go('/explore?catalog=${c.id}')),
        ),
      ),
      SliverToBoxAdapter(child: PosterRow(c.dramas)),
    ],
    // One row per genre that has enough titles to scroll.
    for (final g in repo.genres)
      if (repo.browse(genre: g) case final list when list.length >= 2) ...[
        SliverToBoxAdapter(
          child: SectionHeader(g, action: TextAction('See All', onPressed: () => context.go('/explore?genre=$g'))),
        ),
        SliverToBoxAdapter(child: PosterRow(list)),
      ],
  ];

  List<Widget> _forYou(DramaRepository repo, List<LibraryItem> history) {
    final watched = history.map((h) => h.dramaKey).toSet();
    final seeds = history.take(3).map((h) => repo.byKey(h.dramaKey)).whereType<Drama>();
    final fresh = repo.all.where((d) => !watched.contains(d.key)).toList();
    return [
      for (final d in seeds)
        if (repo.related(d) case final related when related.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader('Because you watched ${d.title}')),
          SliverToBoxAdapter(child: PosterRow(related)),
        ],
      SliverToBoxAdapter(
        child: SectionHeader(
          history.isEmpty ? 'Start Watching' : 'Not Watched Yet',
          subtitle: history.isEmpty ? 'Watch something and this tab will learn what you like' : null,
        ),
      ),
      PagedDramaGrid(fresh.isEmpty ? repo.all : fresh),
    ];
  }
}

class _Hero extends StatefulWidget {
  const _Hero({required this.dramas, required this.tab, required this.onTab});

  final List<Drama> dramas;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox(
        height: top + (width * 0.62).clamp(240.0, 420.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.dramas.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final d = widget.dramas[i];
                return GestureDetector(
                  onTap: () => context.push(dramaPath(d.key)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Poster(d.poster, radius: 0),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, 0.28, 0.55, 1],
                            colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xE6050712)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 26,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    d.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.headlineSmall?.copyWith(color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6, children: [for (final g in d.genres.take(3)) _HeroTag(g)]),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Tooltip(
                              message: 'Play ${d.title}',
                              child: GestureDetector(
                                onTap: () => context.push(watchPath(d.key, 1)),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: brandGradient,
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF2F6BFF).withValues(alpha: 0.5), blurRadius: 18),
                                    ],
                                  ),
                                  child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 22),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Discover / For you + search, over the artwork.
            Positioned(
              top: top + 4,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopTab('Discover', selected: widget.tab == 0, onTap: () => widget.onTab(0)),
                          const SizedBox(width: 24),
                          _TopTab('For you', selected: widget.tab == 1, onTap: () => widget.onTab(1)),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: IconBtn(
                        icon: CupertinoIcons.search,
                        tooltip: 'Search',
                        color: Colors.white,
                        onPressed: () => context.push('/search'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.dramas.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 16 : 5,
                        height: 5,
                        decoration: ShapeDecoration(
                          shape: const StadiumBorder(),
                          color: i == _page ? Colors.white : Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab(this.label, {required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 18,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                shadows: const [Shadow(color: Color(0x80000000), blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 18 : 0,
              height: 3,
              decoration: const ShapeDecoration(shape: StadiumBorder(), gradient: brandGradient),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HeroTag extends StatelessWidget {
  const _HeroTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: const Color(0x33FFFFFF),
      border: Border.all(color: const Color(0x4DFFFFFF), width: 0.5),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
    ),
  );
}

class _ContinueRow extends StatelessWidget {
  const _ContinueRow(this.items);

  final List<LibraryItem> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final it = items[i];
          return GestureDetector(
            onTap: () => context.push(watchPath(it.dramaKey, it.episode)),
            child: SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Poster(it.poster, radius: 10),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.play_fill, size: 14, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: it.progress,
                                    minHeight: 4,
                                    color: s.primary,
                                    backgroundColor: Colors.white38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  Text('EP ${it.episode}', style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
