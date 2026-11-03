import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../widgets/common.dart';
import '../../app/router.dart';

/// Category tile colors: deep tones of the Apple system palette so white text stays above 4.5:1.
const _tileColors = [
  Color(0xFF1E5BD8),
  Color(0xFF6D3FC0),
  Color(0xFFC2410C),
  Color(0xFF0F766E),
  Color(0xFF4338CA),
  Color(0xFF15803D),
  Color(0xFFBE185D),
  Color(0xFF8B5E34),
];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _text = TextEditingController(text: widget.initialQuery);
  late String _submitted = widget.initialQuery ?? '';
  String? _catalogId;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit(String q) {
    FocusScope.of(context).unfocus();
    setState(() {
      _text.text = q;
      _submitted = q.trim();
    });
    ref.read(libraryProvider.notifier).addSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(libraryProvider);
    final recent = ref.read(libraryRepositoryProvider).searches;
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return LargeTitlePage(
      title: 'Search',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CupertinoSearchTextField(
              controller: _text,
              placeholder: 'Titles, genres, stories',
              style: t.bodyLarge,
              onChanged: (_) => setState(() {}),
              onSubmitted: _submit,
              onSuffixTap: () => setState(() {
                _text.clear();
                _submitted = '';
              }),
            ),
          ),
        ),
        ...catalogSlivers(ref, (repo) {
          final typing = _text.text.trim();
          final suggestions = typing.isNotEmpty && typing != _submitted ? repo.suggestions(typing) : const <String>[];
          final results = repo.search(_submitted, catalogId: _catalogId);
          return [
            if (repo.catalogs.length > 1)
              SliverToBoxAdapter(
                child: PillRow(
                  children: [
                    Pill('All Catalogs', selected: _catalogId == null, onTap: () => setState(() => _catalogId = null)),
                    for (final c in repo.catalogs)
                      Pill(c.name, selected: _catalogId == c.id, onTap: () => setState(() => _catalogId = c.id)),
                  ],
                ),
              ),
            if (suggestions.isNotEmpty)
              SliverToBoxAdapter(
                child: CupertinoListSection(
                  topMargin: 0,
                  backgroundColor: s.surface,
                  children: [
                    for (final q in suggestions)
                      CupertinoListTile(
                        leading: Icon(CupertinoIcons.search, color: s.onSurfaceVariant),
                        title: Text(q),
                        onTap: () => _submit(q),
                      ),
                  ],
                ),
              ),
            if (_submitted.isEmpty) ...[
              if (recent.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    'Recent searches',
                    action: TextAction('Clear', onPressed: () => ref.read(libraryProvider.notifier).clearSearches()),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      for (final q in recent)
                        CupertinoListTile(
                          leading: Icon(CupertinoIcons.clock, color: s.onSurfaceVariant),
                          title: Text(q),
                          onTap: () => _submit(q),
                        ),
                    ],
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SectionHeader('Browse Categories')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 96,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: repo.genres.length,
                  itemBuilder: (_, i) {
                    final g = repo.genres[i];
                    return Material(
                      color: _tileColors[i % _tileColors.length],
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _submit(g),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              g,
                              style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageView(
                  icon: CupertinoIcons.search,
                  title: 'No results for "$_submitted"',
                  message: 'Check the spelling or try a genre such as Comedy or Fantasy.',
                ),
              )
            else ...[
              SliverToBoxAdapter(child: SectionHeader('${results.length} result${results.length == 1 ? '' : 's'}')),
              PagedDramaGrid(results),
            ],
          ];
        }),
      ],
    );
  }
}
