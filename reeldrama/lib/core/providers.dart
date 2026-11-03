import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/drama_repository.dart';
import '../data/library_repository.dart';
import 'models.dart';

/// Opened in main() and injected with an override.
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) => throw UnimplementedError('override in main'));

final catalogServiceProvider = Provider<CatalogService>((ref) => CatalogService());

/// All catalogs (bundled + imported) wrapped in a query repository.
final catalogsProvider = AsyncNotifierProvider<CatalogsNotifier, DramaRepository>(CatalogsNotifier.new);

class CatalogsNotifier extends AsyncNotifier<DramaRepository> {
  @override
  Future<DramaRepository> build() async {
    final service = ref.read(catalogServiceProvider);
    final library = ref.read(libraryRepositoryProvider);
    final catalogs = await service.loadAllBundled();
    for (final MapEntry(key: url, value: body) in library.catalogs.entries) {
      try {
        catalogs.add(CatalogService.parse(body, sourceUrl: url));
      } on Object {
        // A cached catalog that no longer parses is ignored; the user can remove it in Settings.
      }
    }
    return DramaRepository(catalogs);
  }

  /// Fetches, validates and stores a user catalog. Throws with a readable message on failure.
  Future<Catalog> add(String url) async {
    final (catalog, body) = await ref.read(catalogServiceProvider).fetch(url);
    final current = await future;
    if (current.catalogs.any((c) => c.id == catalog.id && c.sourceUrl != catalog.sourceUrl)) {
      throw FormatException('A catalog with id "${catalog.id}" is already installed');
    }
    await ref.read(libraryRepositoryProvider).saveCatalog(catalog.sourceUrl!, body);
    ref.invalidateSelf();
    return catalog;
  }

  Future<void> remove(String url) async {
    await ref.read(libraryRepositoryProvider).removeCatalog(url);
    ref.invalidateSelf();
  }
}

final dramaProvider = FutureProvider.family<Drama?, String>((ref, key) async {
  return (await ref.watch(catalogsProvider.future)).byKey(key);
});

/// Revision counter: widgets watch it, mutations bump it.
final libraryProvider = NotifierProvider<LibraryNotifier, int>(LibraryNotifier.new);

class LibraryNotifier extends Notifier<int> {
  LibraryRepository get repo => ref.read(libraryRepositoryProvider);

  @override
  int build() => 0;

  Future<void> _run(Future<void> f) async {
    await f;
    // The write may finish after the scope is gone (e.g. player disposed on shutdown).
    if (ref.mounted) state++;
  }

  static LibraryItem snapshot(Drama d, {int episode = 1, Duration position = Duration.zero, Duration? length}) =>
      LibraryItem(
        dramaKey: d.key,
        title: d.title,
        poster: d.poster,
        episode: episode,
        position: position,
        length: length,
        updatedAt: DateTime.now(),
      );

  bool isBookmarked(String key) => repo.bookmarks.containsKey(key);
  Future<void> toggleBookmark(Drama d) => _run(repo.setBookmark(snapshot(d), !isBookmarked(d.key)));
  Future<void> removeBookmark(String key) => _run(repo.setBookmark(repo.bookmarks[key]!, false));

  bool isLiked(String key) => repo.likes.contains(key);
  Future<void> toggleLike(String key) => _run(repo.setLiked(key, !isLiked(key)));

  Future<void> saveProgress(Drama d, int episode, Duration position, Duration? length) =>
      _run(repo.saveProgress(snapshot(d, episode: episode, position: position, length: length)));
  Future<void> markWatched(String key, int episode) => _run(repo.markWatched(key, episode));
  Future<void> removeHistory(String key) => _run(repo.removeHistory(key));
  Future<void> clearHistory() => _run(repo.clearHistory());

  Future<void> addSearch(String q) => _run(repo.addSearch(q));
  Future<void> clearSearches() => _run(repo.clearSearches());

  // Preferences
  bool get autoplayNext => repo.prefs['autoplay_next'] != 'false';

  /// Reels-style crop-to-fill is the default; "contain" letterboxes instead.
  bool get fillScreen => repo.prefs['video_fit'] != 'contain';
  String get preferredQuality => repo.prefs['quality'] ?? '480p';
  Future<void> setPref(String key, String value) => _run(repo.setPref(key, value));
}

/// Appearance preference ("system" | "light" | "dark"); only notifies when the mode changes.
final themeModeProvider = Provider<ThemeMode>((ref) {
  ref.watch(libraryProvider);
  return switch (ref.read(libraryRepositoryProvider).prefs['theme']) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});
