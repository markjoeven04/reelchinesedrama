import 'dart:convert';
import 'dart:io';

import 'package:reeldrama/app/layout.dart';
import 'package:reeldrama/core/models.dart';
import 'package:reeldrama/data/drama_repository.dart';
import 'package:reeldrama/data/library_repository.dart';
import 'package:reeldrama/features/player/watch_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Catalog reelshort() => CatalogService.parse(File('assets/reelshort_catalog.json').readAsStringSync());
Catalog dramabox() => CatalogService.parse(File('assets/dramabox_catalog.json').readAsStringSync());

Map<String, dynamic> drama(String id, {List<String> genres = const ['Comedy'], String title = 'T'}) => {
  'id': id,
  'title': title,
  'poster': 'https://example.com/$id.jpg',
  'genres': genres,
  'episodes': [
    {
      'number': 1,
      'sources': [
        {'url': 'https://example.com/$id.m3u8'},
      ],
    },
  ],
};

void main() {
  group('bundled catalogs', () {
    final rs = reelshort();
    final db = dramabox();

    test('parses ReelShort catalog with 3 dramas and valid HLS sources', () {
      expect(rs.dramas, hasLength(3));
      for (final d in rs.dramas) {
        expect(d.episodes, isNotEmpty);
        expect(d.episodes.first.sources.first.isHls, isTrue);
      }
    });

    test('parses DramaBox catalog with 3 dramas and valid episodes', () {
      expect(db.dramas, hasLength(3));
      for (final d in db.dramas) {
        expect(d.episodes, isNotEmpty);
      }
    });
  });

  group('catalog validation (untrusted input)', () {
    test('infers format from the URL and defaults server/quality', () {
      final s = VideoSource.fromJson({'url': 'https://x.org/a/master.m3u8'});
      expect((s.format, s.server, s.quality), ('hls', 'Server 1', 'Auto'));
    });

    test('rejects non-http URLs, bad ids and inverted episode windows', () {
      expect(() => VideoSource.fromJson({'url': 'javascript:alert(1)'}), throwsFormatException);
      expect(() => VideoSource.fromJson({'url': 'file:///sdcard/x.mp4'}), throwsFormatException);
      expect(() => Drama.fromJson(drama('../etc'), catalogId: 'c', catalogName: 'C'), throwsFormatException);
      expect(
        () => Episode.fromJson({
          'number': 1,
          'start': 10,
          'end': 5,
          'sources': [
            {'url': 'https://x.org/a.mp4'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('skips malformed dramas but rejects a catalog with none valid', () {
      final ok = Catalog.fromJson({
        'id': 'mine',
        'name': 'Mine',
        'dramas': [
          drama('good'),
          {'id': 'bad', 'title': 'No episodes', 'poster': 'https://x.org/p.jpg'},
        ],
      });
      expect(ok.dramas.single.key, 'mine/good');
      expect(() => Catalog.fromJson({'id': 'x', 'name': 'X', 'dramas': []}), throwsFormatException);
      expect(() => CatalogService.parse('[1,2]'), throwsFormatException);
    });

    test('remote catalogs must be https', () async {
      await expectLater(CatalogService().fetch('http://example.com/c.json'), throwsFormatException);
    });
  });

  group('DramaRepository', () {
    final repo = DramaRepository([
      Catalog.fromJson({
        'id': 'a',
        'name': 'A',
        'dramas': [
          drama('x', title: 'Comedy Club', genres: ['Drama']),
          drama('y', title: 'Space', genres: ['Comedy', 'Sci-Fi']),
          drama('z', title: 'Night', genres: ['Horror']),
        ],
      }),
      Catalog.fromJson({
        'id': 'b',
        'name': 'B',
        'dramas': [
          drama('x', title: 'Other comedy', genres: ['Comedy']),
        ],
      }),
    ]);

    test('search ranks title matches before genre matches and filters by catalog', () {
      expect(repo.search('comedy').map((d) => d.key), ['a/x', 'b/x', 'a/y']);
      expect(repo.search('comedy', catalogId: 'b').map((d) => d.key), ['b/x']);
      expect(repo.search('   '), isEmpty);
      expect(repo.suggestions('COM'), ['Comedy Club', 'Other comedy']);
    });

    test('same id in two catalogs stays distinct', () {
      expect(repo.byKey('a/x')!.title, 'Comedy Club');
      expect(repo.byKey('b/x')!.title, 'Other comedy');
    });

    test('browse, genres and related', () {
      expect(repo.browse(genre: 'Comedy').map((d) => d.key), ['a/y', 'b/x']);
      expect(repo.genres, ['Comedy', 'Drama', 'Horror', 'Sci-Fi']);
      expect(repo.related(repo.byKey('a/y')!).map((d) => d.key), ['b/x']);
    });
  });

  group('player source selection', () {
    final ep = Episode.fromJson({
      'number': 1,
      'sources': [
        {'server': 'S1', 'quality': '480p', 'url': 'https://x.org/480.webm'},
        {'server': 'S1', 'quality': '240p', 'url': 'https://x.org/240.webm'},
        {'server': 'S1', 'quality': '1080p', 'url': 'https://x.org/1080.webm'},
        {'server': 'S2', 'quality': 'Auto', 'url': 'https://x.org/a.m3u8'},
      ],
    });

    test('honours server and quality, falls back to preference then first', () {
      expect(pickSource(ep).quality, '480p');
      expect(pickSource(ep, quality: '1080p').quality, '1080p');
      expect(pickSource(ep, server: 'S2', quality: '480p').quality, 'Auto');
      expect(pickSource(ep, server: 'gone', preferredQuality: '240p').url, 'https://x.org/240.webm');
    });

    test('lowest quality used for slow-connection fallback', () {
      expect(lowestQuality(ep, 'S1'), '240p');
      expect(lowestQuality(ep, 'S2'), 'Auto');
    });
  });

  test('responsive breakpoints at the reference widths', () {
    expect(
      [
        for (final w in [360.0, 393.0, 600.0, 840.0, 1200.0]) windowSizeFor(w),
      ],
      [WindowSize.compact, WindowSize.compact, WindowSize.medium, WindowSize.expanded, WindowSize.large],
    );
    expect(
      [
        for (final w in [360.0, 393.0, 520.0, 760.0, 944.0, 2000.0]) gridColumnsFor(w),
      ],
      [2, 2, 3, 4, 5, 6],
    );
  });

  group('LibraryRepository (SQLite)', () {
    sqfliteFfiInit();
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('reeldrama'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<LibraryRepository> open() => LibraryRepository.open('${dir.path}/t.db', factory: databaseFactoryFfi);

    LibraryItem item(String key, {int ep = 1, int ms = 0, DateTime? at}) => LibraryItem(
      dramaKey: key,
      title: key,
      poster: 'https://x.org/p.jpg',
      episode: ep,
      position: Duration(milliseconds: ms),
      length: const Duration(seconds: 100),
      updatedAt: at ?? DateTime.now(),
    );

    test('everything survives an app restart (reopen)', () async {
      final a = await open();
      await a.setBookmark(item('c/a'), true);
      await a.saveProgress(item('c/a', ep: 3, ms: 42000));
      await a.markWatched('c/a', 1);
      await a.markWatched('c/a', 3);
      await a.setLiked('c/a', true);
      await a.addSearch('love');
      await a.setPref('quality', '240p');
      await a.saveCatalog('https://x.org/c.json', jsonEncode({'id': 'c'}));
      await a.close();

      final b = await open();
      expect(b.bookmarks.keys, ['c/a']);
      expect(b.history['c/a']!.episode, 3);
      expect(b.history['c/a']!.position, const Duration(seconds: 42));
      expect(b.history['c/a']!.progress, closeTo(0.42, 1e-9));
      expect(b.watched['c/a'], {1, 3});
      expect(b.likes, {'c/a'});
      expect(b.searches, ['love']);
      expect(b.prefs['quality'], '240p');
      expect(b.catalogs.keys, ['https://x.org/c.json']);
      await b.close();
    });

    test('recent searches are de-duplicated, newest first and capped', () async {
      final r = await open();
      for (var i = 0; i < 12; i++) {
        await r.addSearch('q$i');
      }
      await r.addSearch('q5');
      await r.addSearch('  ');
      expect(r.searches.first, 'q5');
      expect(r.searches, hasLength(LibraryRepository.maxSearches));
      await r.close();
      expect((await open()).searches, hasLength(LibraryRepository.maxSearches));
    });

    test('history is ordered by recency; removing clears watched episodes', () async {
      final r = await open();
      await r.saveProgress(item('c/old', at: DateTime(2020)));
      await r.saveProgress(item('c/new', at: DateTime(2024)));
      await r.markWatched('c/old', 1);
      expect(r.historyByRecent.map((i) => i.dramaKey), ['c/new', 'c/old']);
      await r.removeHistory('c/old');
      expect(r.watched['c/old'], isNull);
      await r.clearHistory();
      expect(r.history, isEmpty);
      await r.close();
    });
  });
}
