import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../widgets/common.dart';

/// Browse every catalog, filtered by catalog and genre (state lives in the URL query).
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key, this.catalogId, this.genre});

  final String? catalogId;
  final String? genre;

  void _go(BuildContext context, {String? catalog, String? genre}) {
    final q = {'catalog': ?catalog, 'genre': ?genre};
    context.go(Uri(path: '/explore', queryParameters: q.isEmpty ? null : q).toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => LargeTitlePage(
    title: 'Explore',
    slivers: catalogSlivers(ref, (repo) {
      final catalog = repo.catalogs.where((c) => c.id == catalogId).firstOrNull;
      final dramas = repo.browse(catalogId: catalog?.id, genre: genre);
      return [
        SliverToBoxAdapter(
          child: PillRow(
            children: [
              Pill(
                'All Catalogs',
                selected: catalog == null,
                onTap: () => _go(context, genre: genre),
              ),
              for (final c in repo.catalogs)
                Pill(
                  c.name,
                  selected: catalog?.id == c.id,
                  onTap: () => _go(context, catalog: c.id, genre: genre),
                ),
            ],
          ),
        ),
        if (catalog != null && catalog.description.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                catalog.description,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in [null, ...repo.genres])
                  Pill(
                    g ?? 'All Genres',
                    selected: genre == g,
                    onTap: () => _go(context, catalog: catalog?.id, genre: g),
                  ),
              ],
            ),
          ),
        ),
        if (dramas.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: MessageView(
              icon: CupertinoIcons.film,
              title: 'Nothing here yet',
              message: 'Try another catalog or genre.',
            ),
          )
        else
          PagedDramaGrid(dramas),
      ];
    }),
  );
}
