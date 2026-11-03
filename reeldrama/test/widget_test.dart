import 'package:reeldrama/core/providers.dart';
import 'package:reeldrama/data/library_repository.dart';
import 'package:reeldrama/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late LibraryRepository library;

GoRouter router(WidgetTester tester) => tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

Future<void> pumpApp(WidgetTester tester, {double width = 393, double height = 852}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  library = await LibraryRepository.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
  await tester.pumpWidget(
    ProviderScope(overrides: [libraryRepositoryProvider.overrideWithValue(library)], child: ReelDramaApp()),
  );
  // The catalog asset loads on the real event loop; wait until the spinner is gone.
  for (var i = 0; i < 50 && find.byType(CupertinoActivityIndicator).evaluate().isNotEmpty || i == 0; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  sqfliteFfiInit();
  // rootBundle caches futures created inside the previous test's fake-async zone.
  setUp(rootBundle.clear);

  for (final (width, sidebar) in [(360.0, false), (393.0, false), (600.0, false), (840.0, true), (1200.0, true)]) {
    testWidgets('home adapts at ${width.toInt()}dp', (tester) async {
      await pumpApp(tester, width: width, height: width < 600 ? 800 : 900);
      expect(find.byKey(const ValueKey('tabbar')), sidebar ? findsNothing : findsOneWidget);
      expect(find.byKey(const ValueKey('sidebar')), sidebar ? findsOneWidget : findsNothing);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('ReelShort Trending'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('detail page: bookmark shows up in Library, then remove it', (tester) async {
    await pumpApp(tester);
    router(tester).push('/drama/apishort-reelshort/reelshort-6ad72fad13cb3a3d460125d3');
    await tester.pumpAndSettle();

    expect(find.text('Start Episode 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(library.bookmarks.keys, ['apishort-reelshort/reelshort-6ad72fad13cb3a3d460125d3']);
    expect(find.byTooltip('Remove bookmark'), findsOneWidget);

    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('EP 9'), 300, scrollable: page);
    expect(find.text('EP 9'), findsOneWidget);

    router(tester).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('My List'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text("After the Alpha's Cruel Trials"), findsOneWidget);
    await tester.tap(find.byTooltip('Remove bookmark'));
    await tester.pumpAndSettle();
    expect(find.text('No bookmarks yet'), findsOneWidget);
  });

  testWidgets('search: suggestions, results, empty state and recent searches', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoSearchTextField), 'trials');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CupertinoListTile, "After the Alpha's Cruel Trials"), findsOneWidget); // suggestion

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('1 result'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'zzqxjvwk');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No results for "zzqxjvwk"'), findsOneWidget);

    await tester.tap(find.byType(CupertinoSearchTextField)); // the clear button shows while editing
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);
    expect(library.searches, ['zzqxjvwk', 'trials']);

    await tester.tap(find.text('Romance'));
    await tester.pumpAndSettle();
    expect(find.textContaining('results'), findsOneWidget);
  });

  testWidgets('explore filters by genre via the URL', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dragon'));
    await tester.pumpAndSettle();
    expect(find.text('Deny Me, Dragon King'), findsOneWidget);
    expect(find.text("After the Alpha's Cruel Trials"), findsNothing);
  });

  testWidgets('library empty states and profile settings persist', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('My List'));
    await tester.pumpAndSettle();
    expect(find.text('No watch history yet'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autoplay next episode'));
    await tester.pumpAndSettle();
    expect(library.prefs['autoplay_next'], 'false');

    // Appearance: System -> Dark switches the app theme and persists.
    expect(Theme.of(tester.element(find.text('Autoplay next episode'))).brightness, Brightness.light);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(library.prefs['theme'], 'dark');
    expect(Theme.of(tester.element(find.text('Autoplay next episode'))).brightness, Brightness.dark);

    await tester.scrollUntilVisible(find.text('No ads, no tracking'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('No ads, no tracking'), findsOneWidget);
  });

  testWidgets('unknown route shows not-found state', (tester) async {
    await pumpApp(tester);
    router(tester).go('/drama/demo-cc/missing');
    await tester.pumpAndSettle();
    expect(find.text('Not found'), findsOneWidget);
  });
}
