// On-device test: real network playback through Media3/ExoPlayer.
// Run: flutter test integration_test/app_test.dart -d <device>
import 'dart:io';

import 'package:reeldrama/core/providers.dart';
import 'package:reeldrama/data/library_repository.dart';
import 'package:reeldrama/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

Future<void> waitFor(WidgetTester tester, bool Function() ok, {int seconds = 90, String? what}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for ${what ?? 'condition'}');
    await tester.pump(const Duration(milliseconds: 500));
  }
}

double progress(WidgetTester tester) {
  final f = find.byKey(const ValueKey('progress'));
  return f.evaluate().isEmpty ? -1 : tester.widget<Slider>(f).value;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('play, switch episode and server, persist and resume', (tester) async {
    final dbPath = '${Directory.systemTemp.path}/it_${DateTime.now().millisecondsSinceEpoch}.db';
    final library = await LibraryRepository.open(dbPath);
    await library.setPref('quality', '240p'); // keep the emulator's slow link happy
    await tester.pumpWidget(
      ProviderScope(overrides: [libraryRepositoryProvider.overrideWithValue(library)], child: ReelDramaApp()),
    );
    await waitFor(tester, () => find.text('Discover').evaluate().isNotEmpty, what: 'home');
    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

    // 1. WebM/VP9 playback starts and the position advances.
    router.push('/watch/demo-cc/big-buck-bunny?ep=1');
    await waitFor(tester, () => progress(tester) > 0.03, what: 'EP1 playback (webm)');
    expect(find.text('Server 1 · 240p'), findsOneWidget);

    // 2. Next episode: same file, seek into the next window.
    await tester.tap(find.byTooltip('Next episode'));
    await waitFor(tester, () => find.text('Big Buck Bunny · EP 2/6').evaluate().isNotEmpty, what: 'EP2 title');
    await waitFor(tester, () => progress(tester) > 0.02 && progress(tester) < 0.5, what: 'EP2 playback');

    // 3. Switch to the HLS server; playback resumes in the same episode.
    await tester.tap(find.byTooltip('Server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Server 2 (HLS)'));
    await waitFor(tester, () => find.text('Server 2 (HLS) · Auto').evaluate().isNotEmpty, what: 'server switch');
    await waitFor(tester, () => progress(tester) > 0.05, what: 'HLS playback');

    // 4. Leaving saves history; Home shows Continue watching.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await waitFor(tester, () => library.history.containsKey('demo-cc/big-buck-bunny'), what: 'history saved');
    final saved = library.history['demo-cc/big-buck-bunny']!;
    expect(saved.episode, 2);
    expect(saved.position.inSeconds, greaterThan(3));
    expect(library.watched['demo-cc/big-buck-bunny'], containsAll([1, 2]));
    await waitFor(tester, () => find.text('Continue Watching').evaluate().isNotEmpty, what: 'continue row');

    // 5. Restart persistence: reopen the database and resume from the saved spot.
    await library.close();
    final reopened = await LibraryRepository.open(dbPath);
    expect(reopened.history['demo-cc/big-buck-bunny']!.episode, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(overrides: [libraryRepositoryProvider.overrideWithValue(reopened)], child: ReelDramaApp()),
    );
    await waitFor(tester, () => find.text('Continue Watching').evaluate().isNotEmpty, what: 'home after restart');
    await tester.tap(find.text('EP 2').first);
    await waitFor(tester, () => find.text('Big Buck Bunny · EP 2/6').evaluate().isNotEmpty, what: 'resume EP2');
    await waitFor(tester, () => progress(tester) > 0, what: 'resumed playback');
    // Resumed near the saved position rather than at 0.
    expect(progress(tester) * 105.76, greaterThan(saved.position.inSeconds - 3));
    await tester.pumpWidget(const SizedBox());
    await reopened.close();
  });
}
