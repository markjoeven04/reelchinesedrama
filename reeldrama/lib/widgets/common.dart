import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/layout.dart';
import '../app/router.dart';
import '../core/models.dart';
import '../core/providers.dart';
import '../data/drama_repository.dart';

/// Scaffold with an iOS collapsing large title. Adds bottom space for the translucent tab bar.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({super.key, required this.title, required this.slivers, this.trailing, this.background});

  final String title;
  final List<Widget> slivers;
  final Widget? trailing;
  final Color? background;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    // CupertinoPageScaffold lets the bar stay transparent until content scrolls under it (iOS 15+ behaviour).
    body: CupertinoPageScaffold(
      backgroundColor: background ?? Theme.of(context).colorScheme.surface,
      child: CustomScrollView(
        slivers: [
          // Route hero transitions are off: the shell keeps several of these bars alive at once.
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            trailing: trailing,
            transitionBetweenRoutes: false,
            backgroundColor: (background ?? Theme.of(context).colorScheme.surface).withValues(alpha: 0.88),
            border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
          ),
          ...slivers,
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
        ],
      ),
    ),
  );
}

/// [catalogsProvider] as slivers: a spinner while loading, an error with Retry, else [build].
List<Widget> catalogSlivers(WidgetRef ref, List<Widget> Function(DramaRepository repo) build) => ref
    .watch(catalogsProvider)
    .when(
      data: build,
      loading: () => const [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator())),
      ],
      error: (e, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'Could not load catalogs',
            message: '$e',
            action: FilledButton(onPressed: () => ref.invalidate(catalogsProvider), child: const Text('Retry')),
          ),
        ),
      ],
    );

/// 44pt icon button with an accessible name (Tooltip doubles as the semantics label).
class IconBtn extends StatelessWidget {
  const IconBtn({super.key, required this.icon, required this.tooltip, required this.onPressed, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Icon(icon, size: 24, color: onPressed == null ? null : color ?? Theme.of(context).colorScheme.primary),
    ),
  );
}

/// Capsule filter/tag in the style of Apple Music and the TV app.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.selected = false, this.icon, required this.onTap});

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final fg = selected ? s.onPrimary : s.onSurface;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? s.primary : s.surfaceContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of [Pill]s with page gutters.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) => children[i],
    ),
  );
}

class Poster extends StatelessWidget {
  const Poster(this.url, {super.key, this.radius = 12});

  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        httpHeaders: const {'User-Agent': userAgent},
        fit: BoxFit.cover,
        placeholder: (_, _) => ColoredBox(color: s.surfaceContainerHigh),
        errorWidget: (_, _, _) => ColoredBox(
          color: s.surfaceContainerHigh,
          child: Center(child: Icon(CupertinoIcons.film, color: s.outline)),
        ),
      ),
    );
  }
}

/// Small translucent capsule laid over artwork (episode counts, server labels).
class OverlayBadge extends StatelessWidget {
  const OverlayBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(color: Color(0x99000000), shape: StadiumBorder()),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Portrait poster card: genre tag, episode count, title.
class DramaCard extends StatelessWidget {
  const DramaCard(this.drama, {super.key});

  final Drama drama;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => context.push(dramaPath(drama.key)),
      child: Semantics(
        button: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Poster(drama.poster, radius: 10),
                  if (drama.genres.isNotEmpty) Positioned(right: 0, top: 0, child: _CornerTag(drama.genres.first)),
                  Positioned(left: 6, bottom: 6, child: OverlayBadge('${drama.episodes.length} EP')),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              drama.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleSmall?.copyWith(height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerTag extends StatelessWidget {
  const _CornerTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: const BoxDecoration(
      color: Color(0xB3000000),
      borderRadius: BorderRadius.only(topRight: Radius.circular(10), bottomLeft: Radius.circular(10)),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
    ),
  );
}

/// Horizontally scrolling row of poster cards.
class PosterRow extends StatelessWidget {
  const PosterRow(this.dramas, {super.key});

  final List<Drama> dramas;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 218,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: dramas.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, i) => SizedBox(width: 118, child: DramaCard(dramas[i])),
    ),
  );
}

/// Sliver grid that reveals [pageSize] more items each time "Load more" is pressed.
class PagedDramaGrid extends StatefulWidget {
  const PagedDramaGrid(this.dramas, {super.key, this.pageSize = 12});

  final List<Drama> dramas;
  final int pageSize;

  @override
  State<PagedDramaGrid> createState() => _PagedDramaGridState();
}

class _PagedDramaGridState extends State<PagedDramaGrid> {
  late int _shown = widget.pageSize;

  @override
  void didUpdateWidget(PagedDramaGrid old) {
    super.didUpdateWidget(old);
    if (old.dramas != widget.dramas) _shown = widget.pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.dramas.take(_shown).toList();
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, c) => SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridColumnsFor(c.crossAxisExtent),
                childAspectRatio: 0.55,
                crossAxisSpacing: 12,
                mainAxisSpacing: 20,
              ),
              itemCount: visible.length,
              itemBuilder: (_, i) => DramaCard(visible[i]),
            ),
          ),
        ),
        if (_shown < widget.dramas.length)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CupertinoButton.tinted(
                  onPressed: () => setState(() => _shown += widget.pageSize),
                  child: const Text('Load More'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Episode grid split into ranges of 20 ("1-20", "21-40" ...). Watched episodes are dimmed with a check.
class EpisodeMatrix extends ConsumerStatefulWidget {
  const EpisodeMatrix({super.key, required this.drama, required this.onSelect, this.current});

  final Drama drama;
  final int? current;
  final ValueChanged<Episode> onSelect;

  @override
  ConsumerState<EpisodeMatrix> createState() => _EpisodeMatrixState();
}

class _EpisodeMatrixState extends ConsumerState<EpisodeMatrix> {
  static const rangeSize = 20;
  late int _range = ((widget.current ?? 1) - 1) ~/ rangeSize;

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    final watched = ref.read(libraryRepositoryProvider).watched[widget.drama.key] ?? const {};
    final eps = widget.drama.episodes;
    final ranges = (eps.length / rangeSize).ceil();
    final shown = eps.skip(_range * rangeSize).take(rangeSize).toList();
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ranges > 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var r = 0; r < ranges; r++)
                Pill(
                  '${r * rangeSize + 1}-${((r + 1) * rangeSize).clamp(1, eps.length)}',
                  selected: r == _range,
                  onTap: () => setState(() => _range = r),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 96,
            mainAxisExtent: 44,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: shown.length,
          itemBuilder: (_, i) {
            final e = shown[i];
            final isCurrent = e.number == widget.current;
            final isWatched = watched.contains(e.number);
            final fg = isCurrent ? s.onPrimary : (isWatched ? s.onSurfaceVariant : s.onSurface);
            return Material(
              color: isCurrent ? s.primary : s.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                key: ValueKey('ep-${e.number}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => widget.onSelect(e),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'EP ${e.number}',
                      style: t.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                    ),
                    if (isWatched) ...[
                      const SizedBox(width: 3),
                      Icon(CupertinoIcons.checkmark_alt, size: 14, color: fg),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Section title with an optional subtitle and trailing action such as "See All".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Accent text button used for "See All" / "Clear" next to section titles.
class TextAction extends StatelessWidget {
  const TextAction(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    minimumSize: const Size(44, 44),
    onPressed: onPressed,
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
