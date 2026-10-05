import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_stores.dart';
import 'games/game_catalog.dart';
import 'games/klondike/klondike_screen.dart';
import 'hub/hub_screen.dart';
import 'stats/stats_screen.dart';

class AllForGamesApp extends StatefulWidget {
  const AllForGamesApp({
    super.key,
    required this.stores,
    this.initialLocation = '/',
  });

  final AppStores stores;
  final String initialLocation;

  @override
  State<AllForGamesApp> createState() => _AllForGamesAppState();
}

class _AllForGamesAppState extends State<AllForGamesApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HubScreen(stores: widget.stores),
        routes: [
          GoRoute(
            path: 'klondike',
            // Query parameters start a given deal: /klondike?draw=3&seed=42.
            // Without them, the saved game continues.
            builder: (context, state) {
              final query = state.uri.queryParameters;
              return KlondikeScreen(
                stores: widget.stores,
                drawCount: switch (query['draw']) {
                  null => null,
                  '3' => 3,
                  _ => 1,
                },
                seed: int.tryParse(query['seed'] ?? ''),
              );
            },
          ),
          GoRoute(
            path: 'stats/:gameId',
            redirect: (context, state) =>
                gameById(state.pathParameters['gameId']!) == null ? '/' : null,
            builder: (context, state) => StatsScreen(
              stores: widget.stores,
              game: gameById(state.pathParameters['gameId']!)!,
            ),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'All For Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: _router,
    );
  }
}
