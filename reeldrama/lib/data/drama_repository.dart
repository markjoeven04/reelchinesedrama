import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/models.dart';

const userAgent = 'ReelDrama/1.0 (Android; ad-free open-movie player)';

/// Loads catalogs: the bundled Creative Commons demo catalog plus any
/// user-imported JSON catalogs (fetched over HTTPS with Dio).
class CatalogService {
  CatalogService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'User-Agent': userAgent},
              responseType: ResponseType.plain,
            ),
          );

  final Dio _dio;

  static const bundledAssets = [
    'assets/dramabox_catalog.json',
    'assets/reelshort_catalog.json',
  ];
  static const maxCatalogBytes = 5 * 1024 * 1024;

  Future<List<Catalog>> loadAllBundled() async {
    final list = <Catalog>[];
    for (final asset in bundledAssets) {
      try {
        final body = await rootBundle.loadString(asset);
        list.add(parse(body));
      } catch (_) {
        // Fallback gracefully if an asset is not found
      }
    }
    return list;
  }

  /// Fetches a catalog and returns it with its raw body (cached for offline use).
  Future<(Catalog, String)> fetch(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) {
      throw const FormatException('Catalog URL must start with https://');
    }
    final res = await _dio.getUri<String>(uri);
    final body = res.data ?? '';
    if (body.length > maxCatalogBytes) throw const FormatException('Catalog is larger than 5 MB');
    return (parse(body, sourceUrl: uri.toString()), body);
  }

  static Catalog parse(String body, {String? sourceUrl}) {
    final json = jsonDecode(body);
    if (json is! Map) throw const FormatException('Catalog must be a JSON object');
    return Catalog.fromJson(json.cast<String, dynamic>(), sourceUrl: sourceUrl);
  }
}

/// Read-only queries over the loaded catalogs: browsing, details, episodes,
/// search and related titles.
class DramaRepository {
  DramaRepository(this.catalogs) : all = [for (final c in catalogs) ...c.dramas];

  final List<Catalog> catalogs;
  final List<Drama> all;

  List<String> get genres => {for (final d in all) ...d.genres}.toList()..sort();

  List<Drama> get featured => all.where((d) => d.featured).toList();

  Drama? byKey(String key) {
    for (final d in all) {
      if (d.key == key) return d;
    }
    return null;
  }

  List<Drama> browse({String? catalogId, String? genre}) => all
      .where((d) => (catalogId == null || d.catalogId == catalogId) && (genre == null || d.genres.contains(genre)))
      .toList();

  /// Case-insensitive match on title (ranked first), then genre and description.
  List<Drama> search(String query, {String? catalogId}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final pool = browse(catalogId: catalogId);
    final byTitle = pool.where((d) => d.title.toLowerCase().contains(q));
    final other = pool.where(
      (d) =>
          !d.title.toLowerCase().contains(q) &&
          (d.genres.any((g) => g.toLowerCase().contains(q)) || d.description.toLowerCase().contains(q)),
    );
    return [...byTitle, ...other];
  }

  List<String> suggestions(String query) =>
      search(query)
          .where((d) => d.title.toLowerCase().contains(query.trim().toLowerCase()))
          .map((d) => d.title)
          .take(5)
          .toList();

  /// Other dramas sharing the most genres with [drama].
  List<Drama> related(Drama drama, {int limit = 8}) {
    int shared(Drama d) => d.genres.where(drama.genres.contains).length;
    final others = all.where((d) => d.key != drama.key && shared(d) > 0).toList()
      ..sort((a, b) => shared(b).compareTo(shared(a)));
    return others.take(limit).toList();
  }
}
