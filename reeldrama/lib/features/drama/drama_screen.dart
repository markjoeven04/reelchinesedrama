import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/layout.dart';
import '../../app/router.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/common.dart';

void shareDrama(Drama d) => SharePlus.instance.share(
  ShareParams(subject: d.title, text: '${d.title}: ${d.description}${d.sourcePage == null ? '' : '\n${d.sourcePage}'}'),
);

class DramaScreen extends ConsumerWidget {
  const DramaScreen({super.key, required this.dramaKey});

  final String dramaKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dramaProvider(dramaKey))
      .when(
        loading: () => const Scaffold(body: Center(child: CupertinoActivityIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: MessageView(icon: CupertinoIcons.exclamationmark_triangle, title: 'Error', message: '$e'),
        ),
        data: (d) => d == null ? const NotFoundScreen() : _DramaView(d),
      );
}

/// Round frosted button floating over artwork.
class GlassButton extends StatelessWidget {
  const GlassButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 40,
            height: 40,
            color: const Color(0x80303033),
            child: Icon(icon, size: 20, color: color ?? Colors.white),
          ),
        ),
      ),
    ),
  );
}

class _DramaView extends ConsumerWidget {
  const _DramaView(this.drama);

  final Drama drama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);
    final resume = ref.read(libraryRepositoryProvider).history[drama.key];
    final size = MediaQuery.sizeOf(context);
    final wide = windowSizeFor(size.width).index >= WindowSize.expanded.index;
    final related = ref.watch(catalogsProvider).value?.related(drama) ?? const <Drama>[];
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final saved = notifier.isBookmarked(drama.key);

    final hero = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox(
        height: wide ? 360 : (size.width * 0.75).clamp(260.0, 420.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Poster(drama.poster, radius: 0),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.3, 0.75, 1],
                  colors: [const Color(0x66000000), Colors.transparent, s.surface.withValues(alpha: 0.6), s.surface],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          drama.catalogName.toUpperCase(),
          style: t.labelMedium?.copyWith(color: s.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(drama.title, style: t.headlineMedium),
        const SizedBox(height: 4),
        Text(
          ['${drama.episodes.length} Episodes', ...drama.genres].join(' · '),
          style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(CupertinoIcons.play_fill, size: 18),
            label: Text(resume == null ? 'Start Episode 1' : 'Continue EP ${resume.episode}'),
            onPressed: () => context.push(watchPath(drama.key, resume?.episode ?? 1)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SecondaryAction(
                icon: saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                label: saved ? 'Saved' : 'Save',
                tooltip: saved ? 'Remove bookmark' : 'Save',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notifier.toggleBookmark(drama);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SecondaryAction(
                icon: CupertinoIcons.share,
                label: 'Share',
                tooltip: 'Share',
                onPressed: () => shareDrama(drama),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(drama.description, style: t.bodyLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final g in drama.genres) Pill(g, onTap: () => context.go('/explore?genre=$g'))],
        ),
      ],
    );

    final episodes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Episodes', style: t.headlineSmall),
        const SizedBox(height: 12),
        EpisodeMatrix(
          drama: drama,
          current: resume?.episode,
          onSelect: (e) => context.push(watchPath(drama.key, e.number)),
        ),
      ],
    );

    final more = [
      if (related.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
          child: Text('More Like This', style: t.headlineSmall),
        ),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: related.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(width: 124, child: DramaCard(related[i])),
          ),
        ),
      ],
      if (drama.license != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Information', style: t.titleMedium),
              const SizedBox(height: 6),
              Text(
                '${drama.attribution ?? ''} · ${drama.license}',
                style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
              ),
              if (drama.sourcePage != null)
                SelectableText(drama.sourcePage!, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
            ],
          ),
        ),
    ];

    final body = wide
        ? CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: hero),
              SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), child: info),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), child: episodes),
                    ),
                  ],
                ),
              ),
              SliverList.list(children: more),
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 32)),
            ],
          )
        : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: hero),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.list(children: [info, const SizedBox(height: 28), episodes]),
              ),
              SliverList.list(children: more),
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 32)),
            ],
          );

    return Scaffold(
      body: Stack(
        children: [
          body,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            left: 8,
            child: GlassButton(
              icon: CupertinoIcons.chevron_back,
              tooltip: 'Back',
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.icon, required this.label, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: s.surfaceContainer,
          foregroundColor: s.primary,
          minimumSize: const Size(0, 44),
          textStyle: Theme.of(context).textTheme.titleSmall,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
