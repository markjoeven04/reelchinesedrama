import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/drama/drama_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/player/watch_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import 'layout.dart';

/// Routes mirror the reference site's shape: /drama/{catalog}/{id} and /watch/{catalog}/{id}?ep=N.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => const NotFoundScreen(),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (_, s) =>
                  ExploreScreen(catalogId: s.uri.queryParameters['catalog'], genre: s.uri.queryParameters['genre']),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (_, s) => LibraryScreen(tab: s.uri.queryParameters['tab']),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())],
        ),
      ],
    ),
    GoRoute(
      path: '/search',
      builder: (_, s) => SearchScreen(initialQuery: s.uri.queryParameters['q']),
    ),
    GoRoute(
      path: '/drama/:catalog/:id',
      builder: (_, s) => DramaScreen(dramaKey: '${s.pathParameters['catalog']}/${s.pathParameters['id']}'),
    ),
    GoRoute(
      path: '/watch/:catalog/:id',
      builder: (_, s) => WatchScreen(
        dramaKey: '${s.pathParameters['catalog']}/${s.pathParameters['id']}',
        episode: int.tryParse(s.uri.queryParameters['ep'] ?? ''),
      ),
    ),
  ],
);

String dramaPath(String key) => '/drama/$key';
String watchPath(String key, int episode) => '/watch/$key?ep=$episode';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Not Found'), transitionBetweenRoutes: false),
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            icon: CupertinoIcons.search,
            title: 'Not found',
            message: 'That drama or episode is not available in your catalogs.',
            action: FilledButton(onPressed: () => context.go('/'), child: const Text('Back to Home')),
          ),
        ),
      ],
    ),
  );
}

/// Centered symbol + title + message (like iOS ContentUnavailableView), for empty, error and not-found states.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: s.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}
