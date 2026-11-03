import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/providers.dart';
import 'data/library_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Inter'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final library = await LibraryRepository.open(p.join(await getDatabasesPath(), 'reeldrama.db'));
  runApp(ProviderScope(overrides: [libraryRepositoryProvider.overrideWithValue(library)], child: ReelDramaApp()));
}

class ReelDramaApp extends ConsumerWidget {
  ReelDramaApp({super.key});

  final _router = buildRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'ReelDrama',
    debugShowCheckedModeBanner: false,
    theme: lightTheme,
    darkTheme: darkTheme,
    themeMode: ref.watch(themeModeProvider),
    scrollBehavior: const AppScrollBehavior(),
    routerConfig: _router,
  );
}
