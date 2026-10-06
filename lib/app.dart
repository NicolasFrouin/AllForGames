import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'achievements/achievements_screen.dart';
import 'app_stores.dart';
import 'games/freecell/freecell_difficulty.dart';
import 'games/freecell/freecell_screen.dart';
import 'games/game_catalog.dart';
import 'games/klondike/klondike_screen.dart';
import 'games/mahjong/mahjong_difficulty.dart';
import 'games/mahjong/mahjong_screen.dart';
import 'games/spider/spider_difficulty.dart';
import 'games/spider/spider_screen.dart';
import 'hub/hub_screen.dart';
import 'l10n/app_localizations.dart';
import 'skins/skins_screen.dart';
import 'stats/overview_screen.dart';
import 'stats/stats_screen.dart';

/// The texts of the app, then the Material, Cupertino and widgets texts.
/// These come from material_ui: the flutter_localizations ones (in
/// `AppLocalizations.localizationsDelegates`) do not serve material_ui widgets.
const appLocalizationsDelegates = <LocalizationsDelegate<Object?>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

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
            path: 'freecell',
            // Query parameters start a given deal: /freecell?difficulty=hard&
            // seed=42. Without them, the saved game continues.
            builder: (context, state) {
              final query = state.uri.queryParameters;
              return FreeCellScreen(
                stores: widget.stores,
                difficulty: FreeCellDifficulty.values
                    .asNameMap()[query['difficulty']],
                seed: int.tryParse(query['seed'] ?? ''),
              );
            },
          ),
          GoRoute(
            path: 'mahjong',
            // Query parameters start a given deal: /mahjong?mode=tray&
            // difficulty=hard&seed=42. Without them, the saved game
            // continues.
            builder: (context, state) {
              final query = state.uri.queryParameters;
              return MahjongScreen(
                stores: widget.stores,
                mode: MahjongMode.values.asNameMap()[query['mode']],
                difficulty: MahjongDifficulty.values
                    .asNameMap()[query['difficulty']],
                seed: int.tryParse(query['seed'] ?? ''),
              );
            },
          ),
          GoRoute(
            path: 'spider',
            // Query parameters start a given deal: /spider?difficulty=hard&
            // seed=42. Without them, the saved game continues.
            builder: (context, state) {
              final query = state.uri.queryParameters;
              return SpiderScreen(
                stores: widget.stores,
                difficulty: SpiderDifficulty.values
                    .asNameMap()[query['difficulty']],
                seed: int.tryParse(query['seed'] ?? ''),
              );
            },
          ),
          GoRoute(
            path: 'stats',
            builder: (context, state) => OverviewScreen(stores: widget.stores),
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
          GoRoute(
            path: 'achievements',
            builder: (context, state) =>
                AchievementsScreen(stores: widget.stores),
          ),
          GoRoute(
            path: 'skins',
            builder: (context, state) => SkinsScreen(stores: widget.stores),
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
    final settings = widget.stores.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
            brightness: Brightness.dark,
          ),
        ),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Null follows the device language.
        locale: settings.locale,
        routerConfig: _router,
      ),
    );
  }
}
