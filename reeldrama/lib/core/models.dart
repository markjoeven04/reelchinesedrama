/// Typed models for catalogs, dramas, episodes and playable sources.
///
/// The JSON shape parsed here is also the import format for user-supplied
/// catalogs (see DATA_MODELS.md), so parsing validates untrusted input.
library;

class VideoSource {
  const VideoSource({required this.server, required this.quality, required this.format, required this.url});

  final String server;
  final String quality;
  final String format; // hls | dash | mp4 | webm
  final String url;

  bool get isHls => format == 'hls';

  factory VideoSource.fromJson(Map<String, dynamic> j) {
    final url = _httpUrl(j['url']);
    return VideoSource(
      server: (j['server'] as String?) ?? 'Server 1',
      quality: (j['quality'] as String?) ?? 'Auto',
      format: (j['format'] as String?) ?? _formatFromUrl(url),
      url: url,
    );
  }
}

class Episode {
  const Episode({required this.number, required this.sources, this.start = Duration.zero, this.end, this.thumbnail});

  final int number;
  final Duration start;

  /// End of this episode inside the source media; null means "until the media ends".
  final Duration? end;
  final String? thumbnail;
  final List<VideoSource> sources;

  Duration? get length => end == null ? null : end! - start;

  List<String> get servers => sources.map((s) => s.server).toSet().toList();

  factory Episode.fromJson(Map<String, dynamic> j) {
    final sources = [for (final s in (j['sources'] as List? ?? const [])) VideoSource.fromJson(_map(s))];
    if (sources.isEmpty) throw const FormatException('episode has no sources');
    final start = _seconds(j['start']) ?? Duration.zero;
    final end = _seconds(j['end']);
    if (end != null && end <= start) throw const FormatException('episode end must be after start');
    return Episode(
      number: (j['number'] as num).toInt(),
      start: start,
      end: end,
      thumbnail: j['thumbnail'] == null ? null : _httpUrl(j['thumbnail']),
      sources: sources,
    );
  }
}

class Drama {
  const Drama({
    required this.id,
    required this.catalogId,
    required this.catalogName,
    required this.title,
    required this.description,
    required this.poster,
    required this.genres,
    required this.episodes,
    this.featured = false,
    this.license,
    this.attribution,
    this.sourcePage,
  });

  final String id;
  final String catalogId;
  final String catalogName;
  final String title;
  final String description;
  final String poster;
  final List<String> genres;
  final List<Episode> episodes;
  final bool featured;
  final String? license;
  final String? attribution;
  final String? sourcePage;

  /// Unique across catalogs; used in routes and persistence.
  String get key => '$catalogId/$id';

  Episode? episode(int number) {
    for (final e in episodes) {
      if (e.number == number) return e;
    }
    return null;
  }

  factory Drama.fromJson(Map<String, dynamic> j, {required String catalogId, required String catalogName}) {
    final episodes = [for (final e in (j['episodes'] as List? ?? const [])) Episode.fromJson(_map(e))]
      ..sort((a, b) => a.number.compareTo(b.number));
    if (episodes.isEmpty) throw const FormatException('drama has no episodes');
    return Drama(
      id: _id(j['id']),
      catalogId: catalogId,
      catalogName: catalogName,
      title: j['title'] as String,
      description: (j['description'] as String?) ?? '',
      poster: _httpUrl(j['poster']),
      genres: [for (final g in (j['genres'] as List? ?? const [])) g as String],
      featured: j['featured'] == true,
      license: j['license'] as String?,
      attribution: j['attribution'] as String?,
      sourcePage: j['sourcePage'] as String?,
      episodes: episodes,
    );
  }
}

class Catalog {
  const Catalog({
    required this.id,
    required this.name,
    required this.description,
    required this.dramas,
    this.sourceUrl,
  });

  final String id;
  final String name;
  final String description;
  final List<Drama> dramas;

  /// Where a user-imported catalog was fetched from; null for the bundled demo catalog.
  final String? sourceUrl;

  /// Parses a catalog. Invalid dramas are skipped; a catalog with none left is rejected.
  factory Catalog.fromJson(Map<String, dynamic> j, {String? sourceUrl}) {
    final id = _id(j['id']);
    final name = (j['name'] as String?)?.trim();
    if (name == null || name.isEmpty) throw const FormatException('catalog needs a name');
    final dramas = <Drama>[];
    for (final d in (j['dramas'] as List? ?? const [])) {
      try {
        dramas.add(Drama.fromJson(_map(d), catalogId: id, catalogName: name));
      } on Object {
        // Skip malformed entries rather than rejecting a whole user catalog.
      }
    }
    if (dramas.isEmpty) throw const FormatException('catalog contains no valid dramas');
    return Catalog(
      id: id,
      name: name,
      description: (j['description'] as String?) ?? '',
      dramas: dramas,
      sourceUrl: sourceUrl,
    );
  }
}

/// Snapshot of a drama kept in bookmarks/history so they render even if a catalog disappears.
class LibraryItem {
  const LibraryItem({
    required this.dramaKey,
    required this.title,
    required this.poster,
    required this.updatedAt,
    this.episode = 1,
    this.position = Duration.zero,
    this.length,
  });

  final String dramaKey;
  final String title;
  final String poster;
  final DateTime updatedAt;
  final int episode;
  final Duration position;
  final Duration? length;

  double get progress {
    final l = length;
    if (l == null || l.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / l.inMilliseconds).clamp(0.0, 1.0);
  }

  Map<String, Object?> toRow() => {
    'drama_key': dramaKey,
    'title': title,
    'poster': poster,
    'episode': episode,
    'position_ms': position.inMilliseconds,
    'length_ms': length?.inMilliseconds,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory LibraryItem.fromRow(Map<String, Object?> r) => LibraryItem(
    dramaKey: r['drama_key']! as String,
    title: r['title']! as String,
    poster: r['poster']! as String,
    episode: (r['episode'] as int?) ?? 1,
    position: Duration(milliseconds: (r['position_ms'] as int?) ?? 0),
    length: r['length_ms'] == null ? null : Duration(milliseconds: r['length_ms']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at']! as int),
  );
}

Map<String, dynamic> _map(Object? o) =>
    o is Map ? o.cast<String, dynamic>() : throw const FormatException('expected an object');

String _id(Object? o) {
  final s = o?.toString().trim() ?? '';
  if (!RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(s)) throw FormatException('invalid id: $s');
  return s;
}

String _httpUrl(Object? o) {
  final uri = Uri.tryParse(o is String ? o : '');
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
    throw FormatException('expected an http(s) URL: $o');
  }
  return uri.toString();
}

Duration? _seconds(Object? o) => o is num ? Duration(milliseconds: (o * 1000).round()) : null;

String _formatFromUrl(String url) {
  final path = Uri.parse(url).path.toLowerCase();
  if (path.endsWith('.m3u8')) return 'hls';
  if (path.endsWith('.mpd')) return 'dash';
  if (path.endsWith('.webm')) return 'webm';
  return 'mp4';
}
