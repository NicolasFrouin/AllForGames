import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'games/game_catalog.dart';
import 'games/klondike/klondike_screen.dart';
import 'hub/hub_screen.dart';
import 'stats/stats_screen.dart';
import 'stats/stats_store.dart';

class AllForGamesApp extends StatefulWidget {
  const AllForGamesApp({
    super.key,
    required this.stats,
    this.initialLocation = '/',
  });

  final StatsStore stats;
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
        builder: (context, state) => HubScreen(stats: widget.stats),
        routes: [
          GoRoute(
            path: 'klondike',
            // Query parameters let a link replay a deal: /klondike?draw=3&seed=42
            builder: (context, state) => KlondikeScreen(
              stats: widget.stats,
              drawCount: state.uri.queryParameters['draw'] == '3' ? 3 : 1,
              seed: int.tryParse(state.uri.queryParameters['seed'] ?? ''),
            ),
          ),
          GoRoute(
            path: 'stats/:gameId',
            redirect: (context, state) =>
                gameById(state.pathParameters['gameId']!) == null ? '/' : null,
            builder: (context, state) => StatsScreen(
              stats: widget.stats,
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
