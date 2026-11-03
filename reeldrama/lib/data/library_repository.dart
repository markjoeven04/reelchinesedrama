import 'package:sqflite/sqflite.dart';

import '../core/models.dart';

/// Local persistence (SQLite) for everything the user owns: bookmarks, watch
/// history, watched episodes, likes, recent searches, imported catalogs and
/// preferences. Data is small, so it is loaded into memory once and every
/// write goes straight through to the database.
class LibraryRepository {
  LibraryRepository._(this._db);

  final Database _db;

  final Map<String, LibraryItem> bookmarks = {};
  final Map<String, LibraryItem> history = {};
  final Map<String, Set<int>> watched = {};
  final Set<String> likes = {};
  final List<String> searches = [];
  final Map<String, String> prefs = {};

  /// url -> cached JSON body of a user-imported catalog.
  final Map<String, String> catalogs = {};

  static const _schema = [
    'CREATE TABLE bookmarks(drama_key TEXT PRIMARY KEY, title TEXT, poster TEXT, episode INTEGER, position_ms INTEGER, length_ms INTEGER, updated_at INTEGER)',
    'CREATE TABLE history(drama_key TEXT PRIMARY KEY, title TEXT, poster TEXT, episode INTEGER, position_ms INTEGER, length_ms INTEGER, updated_at INTEGER)',
    'CREATE TABLE watched(drama_key TEXT, episode INTEGER, PRIMARY KEY(drama_key, episode))',
    'CREATE TABLE likes(drama_key TEXT PRIMARY KEY)',
    'CREATE TABLE searches(query TEXT PRIMARY KEY, at INTEGER)',
    'CREATE TABLE catalogs(url TEXT PRIMARY KEY, body TEXT, added_at INTEGER)',
    'CREATE TABLE prefs(key TEXT PRIMARY KEY, value TEXT)',
  ];

  static const maxHistory = 100;
  static const maxSearches = 10;

  static Future<LibraryRepository> open(String path, {DatabaseFactory? factory}) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final s in _schema) {
            await db.execute(s);
          }
        },
      ),
    );
    return LibraryRepository._(db).._load(await _readAll(db));
  }

  static Future<Map<String, List<Map<String, Object?>>>> _readAll(Database db) async => {
    for (final t in ['bookmarks', 'history', 'watched', 'likes', 'searches', 'catalogs', 'prefs']) t: await db.query(t),
  };

  void _load(Map<String, List<Map<String, Object?>>> t) {
    for (final r in t['bookmarks']!) {
      final i = LibraryItem.fromRow(r);
      bookmarks[i.dramaKey] = i;
    }
    for (final r in t['history']!) {
      final i = LibraryItem.fromRow(r);
      history[i.dramaKey] = i;
    }
    for (final r in t['watched']!) {
      watched.putIfAbsent(r['drama_key']! as String, () => {}).add(r['episode']! as int);
    }
    likes.addAll(t['likes']!.map((r) => r['drama_key']! as String));
    final s = [...t['searches']!]..sort((a, b) => (b['at']! as int).compareTo(a['at']! as int));
    searches.addAll(s.map((r) => r['query']! as String));
    for (final r in t['catalogs']!) {
      catalogs[r['url']! as String] = r['body']! as String;
    }
    for (final r in t['prefs']!) {
      prefs[r['key']! as String] = r['value']! as String;
    }
  }

  List<LibraryItem> get historyByRecent => history.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  List<LibraryItem> get bookmarksByRecent =>
      bookmarks.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> setBookmark(LibraryItem item, bool on) async {
    if (on) {
      bookmarks[item.dramaKey] = item;
      await _db.insert('bookmarks', item.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      bookmarks.remove(item.dramaKey);
      await _db.delete('bookmarks', where: 'drama_key = ?', whereArgs: [item.dramaKey]);
    }
  }

  Future<void> saveProgress(LibraryItem item) async {
    history[item.dramaKey] = item;
    await _db.insert('history', item.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    if (history.length > maxHistory) {
      final oldest = historyByRecent.last.dramaKey;
      await removeHistory(oldest);
    }
  }

  Future<void> removeHistory(String dramaKey) async {
    history.remove(dramaKey);
    watched.remove(dramaKey);
    await _db.delete('history', where: 'drama_key = ?', whereArgs: [dramaKey]);
    await _db.delete('watched', where: 'drama_key = ?', whereArgs: [dramaKey]);
  }

  Future<void> clearHistory() async {
    history.clear();
    watched.clear();
    await _db.delete('history');
    await _db.delete('watched');
  }

  Future<void> markWatched(String dramaKey, int episode) async {
    if (!watched.putIfAbsent(dramaKey, () => {}).add(episode)) return;
    await _db.insert('watched', {
      'drama_key': dramaKey,
      'episode': episode,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> setLiked(String dramaKey, bool on) async {
    if (on) {
      likes.add(dramaKey);
      await _db.insert('likes', {'drama_key': dramaKey}, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      likes.remove(dramaKey);
      await _db.delete('likes', where: 'drama_key = ?', whereArgs: [dramaKey]);
    }
  }

  Future<void> addSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    searches
      ..remove(q)
      ..insert(0, q);
    await _db.insert('searches', {
      'query': q,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    while (searches.length > maxSearches) {
      await _db.delete('searches', where: 'query = ?', whereArgs: [searches.removeLast()]);
    }
  }

  Future<void> clearSearches() async {
    searches.clear();
    await _db.delete('searches');
  }

  Future<void> saveCatalog(String url, String body) async {
    catalogs[url] = body;
    await _db.insert('catalogs', {
      'url': url,
      'body': body,
      'added_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeCatalog(String url) async {
    catalogs.remove(url);
    await _db.delete('catalogs', where: 'url = ?', whereArgs: [url]);
  }

  Future<void> setPref(String key, String value) async {
    prefs[key] = value;
    await _db.insert('prefs', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => _db.close();
}
