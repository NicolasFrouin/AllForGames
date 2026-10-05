# CLAUDE.md

Guide for AI agents working on this repo. Read it fully before you change code.

## Project

All For Games: one Flutter app with a hub of classic games: Klondike, FreeCell, Spider and Mahjong.
Targets: web and Android first, then iOS and desktop, from one codebase.
Product priorities: rich player statistics, a polished hub, good unit + widget + e2e tests.

## Commands

```sh
flutter pub get                               # also generates lib/l10n/app_localizations*.dart
flutter gen-l10n                              # regenerates them after an ARB change
flutter run -d chrome                         # dev, hot reload
flutter analyze                               # must be clean
dart format lib test integration_test test_driver
flutter test                                  # unit + widget tests (fast)
flutter test test/games/klondike              # one folder or file: prefer narrow runs
scripts/e2e_web.sh                            # e2e in headless Chrome (--no-headless to watch)
dart run tool/generate_klondike_deals.dart    # regenerates klondike_deals.dart (about 1 minute)
dart run tool/generate_freecell_deals.dart    # regenerates freecell_deals.dart (about 1 minute; --stats N)
dart run tool/generate_spider_deals.dart      # regenerates spider_deals.dart (about 3 minutes; --stats N [--level hard])
dart run tool/mahjong_difficulty.dart [deals] # win rates of simulated players per Mahjong level
flutter build web --release --wasm            # release web build in build/web
```

Toolchain: Flutter 3.47.6 / Dart 3.13 (Homebrew cask). CI (`.github/workflows/ci.yml`) runs format, analyze, tests,
the deal test in Chrome with Wasm (the e2e tests check a deal in JS) and web e2e. The e2e tests run in the background
beside the other checks: about 2 minutes. Docs-only changes (`**/*.md`, `.ai/**`) skip CI.

**CI runs only on the self-hosted runner** (Coolify, Linux x64): every job uses `runs-on: [self-hosted, Linux, X64]`.
Never use GitHub-hosted runners (`ubuntu-latest`, ...). The runner is a persistent container (4 CPUs although `nproc`
says 8, 6 GB): the Flutter SDK, pub cache and Chrome stay on its disk, so the workflow restores no cache archives (on
a new container, flutter-action and setup-chrome download them once). The checkout keeps `build/` and `.dart_tool/`
(incremental compiler caches). Flutter commands that run in parallel take `--no-pub`. The workflow passes
`CHROME_EXECUTABLE` and `CHROMEDRIVER` to `scripts/e2e_web.sh`. A new tool needed by CI must be installed by the
workflow too. `scripts/e2e_web.sh` uses the deprecated `--no-web-experimental-hot-reload` (a twice-as-fast debug
build): drop it when a Flutter upgrade removes it.

## Layout

```
lib/
  main.dart, app.dart        loads the stores, routes (go_router): /, /klondike?draw=3&seed=42,
                             /freecell?difficulty=hard&seed=42, /spider?difficulty=hard&seed=42,
                             /mahjong?difficulty=easy&seed=42, /stats/:gameId, /achievements, /card-backs
                             (without params, a game route continues the saved game)
  app_stores.dart            AppStores: every store (stats, saves, settings, achievements), loaded once, given to
                             the screens; its constructor keeps the achievements in sync with the stats
  l10n/                      app_en.arb (template) + app_fr.arb; app_localizations*.dart are generated (git-ignored)
  settings/                  SettingsStore: player settings (language, card back), one storage key per setting
  achievements/              Achievement definitions (goal + progress from records), AchievementStore (unlock dates),
                             achievement_texts (id -> title/description, card back names), achievements page
  skins/                     CardBackSkin list (free or unlocked by an achievement), CardBackView, card backs page
  hub/                       home page: header (achievements, card backs, language), overall stats, game grid
  saves/                     SavedGame (one game in progress, game-specific JSON in data), GameSaveStore
  stats/                     GameRecord (one finished game), GameStats (aggregates), StatsStore, PlayTimer, stats page
  common/format.dart         duration/date/percent formatting, in the app language
  games/game_catalog.dart    GameInfo list shown on the hub (route, localized title/tagline/variants/stat labels)
  cards/                     shared by card games: playing_card (Suit, PlayingCard), deal_random (seeded shuffle, the
                             same on VM/JS/Wasm; Mahjong uses it too), card_view (CardView, compact face below
                             56 px), suit_icon, card_motion (CardMotion: pure motion math), confetti, card_table
                             (CardTable engine: TablePile, TableAction, MotionStyle, CardSlot), moving_card
                             (MovingCard, TurningCardView: per-frame transforms)
  games/klondike/            klondike_state (immutable rules), klondike_controller (game session, undo, stat
                             counters), klondike_board (adapter on CardTable: layout, rules callbacks, MotionStyles),
                             klondike_screen, klondike_deals (generated winnable seeds), deal_picker (pickDealSeed,
                             difficultyOfSeed), klondike_difficulty (enum) + _texts, new_game_sheet,
                             klondike_solver (offline only: the generator and tests)
  games/mahjong/             pure Dart: mahjong_tiles, mahjong_layout, mahjong_state (rules), mahjong_generator
                             (solvable by construction), mahjong_solver (hints), mahjong_difficulty, mahjong_motion,
                             mahjong_players (offline only); Flutter: mahjong_controller, mahjong_board,
                             mahjong_tile_view (vector tile art), mahjong_moving_tile (per-frame transforms),
                             mahjong_screen, mahjong_new_game_sheet, _texts
  games/freecell/            freecell_state (rules), freecell_solver (offline), freecell_deals (generated), deal
                             picker, freecell_controller, freecell_board (adapter on CardTable), screen, sheet, texts
  games/spider/              spider_state (rules, two decks), spider_solver (offline), spider_deals (generated),
                             spider_deal_picker, spider_controller, spider_board (adapter on CardTable), screen, sheet
  games/win_dialog.dart      showWinDialog: the win dialog of every game (extra rows per game)
test/                        unit (games/, stats/) and widget (widget/) tests; helpers in test/helpers and *_test_helpers.dart
integration_test/            e2e tests (run on web by scripts/e2e_web.sh, or on a device)
tool/                        generate_klondike_deals.dart (solves and grades deals, writes klondike_deals.dart),
                             generate_freecell_deals.dart, generate_spider_deals.dart (same idea per game),
                             mahjong_difficulty.dart (simulated win rates per Mahjong level)
```

## Conventions

- **Material import**: Flutter 3.47 moved Material to a package. Import `package:material_ui/material_ui.dart`,
  never `package:flutter/material.dart` (go_router uses material_ui; mixing them breaks Theme lookups).
- **Rules are pure Dart** (`klondike_state.dart`): immutable state, `move`/`draw` return a new state or null.
  The controller owns the session (undo history, score, timer, counters). Widgets only call the controller.
- **Statistics**: records = finished games only. A game ends when it is won, or abandoned when the player starts
  a new game over it (with at least one move). In-progress games live in `GameSaveStore`, never as records.
  Game-specific counters go in `details` (`Map<String, int>`); keys ending with `Ms` are durations in ms.
  Add a label for each new key in the game's `GameInfo.detailLabels` (a text of the ARB files).
  `GameRecord.difficulty` is optional (null: no levels, an ungraded deal, or an older record); a game with levels
  lists them in `GameInfo.difficulties`, and the stats page filters by variant and difficulty.
- **Saved games**: leaving a game (back, app closed, tab closed) saves it; opening it again continues it.
  The controller saves itself after every action, on `pause()` and when the screen closes, and removes the save
  on a win. `toJson()` has a `version`; `restore(json)` throws `FormatException` on bad data, then the screen
  deals a new game. Route params (`/klondike?seed=42`) start that deal and abandon the saved one.
- **Storage** (shared_preferences, `SharedPreferencesAsync`; localStorage on web): one key per item, never a whole
  list (other tabs and unreadable entries must survive). Keys: `stats.game.<gameId>-<startedAt µs>-<seed>` per
  record (`StatsStore.keyOf`), `save.<gameId>` per game in progress (`GameSaveStore.keyOf`), `settings.<name>`
  per setting (`settings.locale`: `en`/`fr`, absent = device language; `settings.cardBack`: skin id, unknown =
  classic; `settings.klondike.drawCount`: int 1/3, unknown = 1; `settings.<game>.difficulty`:
  `easy`/`medium`/`hard`, unknown = medium), `achievements.<id>` per unlocked achievement (UTC ISO date).
  Catch storage errors (blocked or full storage must not break the app).
- **ChangeNotifier stores** notify *after* an `await`, never synchronously in a mutating call:
  screens call them from `dispose()`, when no widget can rebuild.
- **Translations** (English, French; gen-l10n): every user-facing string goes in `lib/l10n/app_en.arb` (with `@`
  metadata, typed placeholders, ICU plurals for counts) and `lib/l10n/app_fr.arb`. Widgets read
  `AppLocalizations.of(context)`; data like `GameInfo` holds `LocalizedText` (`String Function(AppLocalizations)`).
  Numbers, dates, durations: `common/format.dart` (intl, `l10n.localeName`). French: no-break space before `! ? :`.
  Language names stay in their own language. The generated `app_localizations*.dart` are git-ignored and rebuilt
  by `flutter pub get` / `flutter gen-l10n`. Delegates: `appLocalizationsDelegates` in `app.dart` (material_ui's
  `GlobalMaterialLocalizations`, not the legacy `AppLocalizations.localizationsDelegates`).
- **Achievements** are evaluated from the records only: `AppStores` checks them at start (silently: games won
  before) and on every stats change (`stats.addListener`), which queues the new ones; the win dialog checks too,
  then shows `takeAnnouncements()`. Unlocks are permanent (clearing stats keeps them; pages show them full).
  A card back is free or names the achievement that unlocks it (`unlockedBy`); the card backs page only selects
  unlocked ones. A new achievement or card back needs its texts in both ARB files and a case in
  `achievement_texts.dart` (a test checks every id has them).
- **Klondike deals**: `KlondikeState.deal(seed)` (`shuffledDeck` with `DealRandom` from `lib/cards/`, the same on VM, JS and Wasm)
  must never change: `klondikeDeals[drawCount][difficulty]` lists seeds proven winnable for these exact deals.
  New games deal `pickDealSeed`: a seed of `klondikeDeals[drawCount][difficulty]`, not yet played in that draw
  mode (records) nor on screen, any seed of that list once all were played. An explicit seed (`/klondike?seed=42`,
  `newGame(seed:)`, for tests and links) deals any seed: only seeds from `klondikeDeals` are guaranteed winnable.
  After a change of the solver or grading, regenerate the lists with `dart run tool/generate_klondike_deals.dart`
  (about 1 minute). `KlondikeDifficulty` stays pure Dart without imports (the tool runs it outside Flutter); its
  texts are in `klondike_difficulty_texts.dart`.
- **Klondike difficulty**: the controller keeps the difficulty of the deal (`difficultyOfSeed`, null for a seed in
  no list), saves it (optional: a save without it looks it up from the seed) and records it. The new game sheet
  (`new-game`) opens with the settings (`klondikeDrawCount`, `klondikeDifficulty`); Deal saves them, and confirms
  the abandon of a game with moves (the sheet says so). A game opened from the hub without a save uses them too
  (`?draw=` overrides the draw count); Play again keeps the draw count and difficulty.
- **Card games build on `CardTable`** (`lib/cards/card_table.dart`). The game gives the piles in paint order
  (`TablePile`: id, cards, top-left offset of each card, rect, drop rect, an optional `CardSlot` with its test
  key), the card width and back, the last action (`TableAction`: serial, moved card ids in stagger order,
  `MotionStyle` with stagger/duration/curve/arc, `dealFrom` pile), callbacks (`canDrag`, `canTap`, `onTap` → false
  shakes, `canDrop`, `onDrop`, `onSlotTap`) and, once won, the `celebration` piles whose top cards hop, plus
  `onCelebrated`. The engine plans a `CardMotion` per changed card (fly on an arc, 3D flip, hop, shake; pure and
  unit-tested); drop glide, snap back on a refused drop, shake, resize glide, confetti and reduced motion are
  built in. Card ids must be unique on a table: with several decks, `PlayingCard.deck` gives them (ids of deck 0
  stay `<suit>-<rank>`). Two-step actions (`TableAction.stops`, `thenIds`, `thenStyle`): cards land somewhere
  first, then fly on (a completed Spider run; FreeCell's automatic moves after the player's move).
- **Animations stay cheap**: one clock (`ValueNotifier<double>`, driven by a `Ticker`) and no `setState` per frame.
  `MovingCard` moves a card by repainting its own layer (fixed-blur shadow, listens only while it moves),
  `TurningCardView` swaps the face once at mid-flip, card faces sit in `RepaintBoundary`s, the card layer
  rebuilds only when the paint order changes (a card takes off or lands), confetti is one `drawVertices` call.
  The `*_board_rebuilds_test.dart` widget tests (Klondike, Spider, Mahjong) guard it with
  `debugOnRebuildDirtyWidget`: keep them passing. The Mahjong board follows the same rules (`MovingTile`).
  A new batch shifts running motions, so moves chain without jumps. Paint order: cards on the table by pile (a
  waiting card keeps its old pile), then cards in the air. Reduced motion (`MediaQuery.disableAnimationsOf`)
  moves cards at once. No endless animation anywhere: tests rely on `pumpAndSettle`.
  A win plays on the same timeline: the cascade (one card after the other), then the top cards of the
  celebration piles hop with confetti bursts (drawn in an `OverlayPortal` above the app bar); the table then calls
  `onCelebrated` and the screen opens the win dialog (at once with reduced motion).
- **FreeCell / Spider deals**: like Klondike, `FreeCellState.deal(seed)` and `SpiderState.deal(seed, difficulty)`
  must never change: `freecellDeals[difficulty]` and `spiderDeals[difficulty]` list seeds proven winnable (each
  solution replayed on the rules). FreeCell levels: Easy = a greedy player wins, Medium = solvable with 2 free
  cells, Hard = needs more. Spider levels are suit counts (1, 2, 4): records use variants `suits1/2/4` and no
  difficulty. `test/cards/deals_on_web_test.dart` (run in Wasm by CI) checks every game's seed-1 deal.
- **Mahjong**: deals are built at runtime from the seed (`DealRandom`), solvable by construction (removing pairs
  of free places from the full layout gives a clearing order). A level is a layout plus a trap rate, checked by
  `tool/mahjong_difficulty.dart` and a unit test that keeps the levels ordered. On a tall screen the layout is
  dealt with rows and columns swapped (chosen at deal time, saved with the game). Tile art is vector (no emoji,
  no CJK font).
- **Card suits** are drawn with `SuitIcon` (`lib/cards/`, vector). Text symbols ♥ ♦ render as color emoji on web.
  Face-down cards are drawn with `CardBackView` and the selected skin.
- **Keys for tests**: widgets that tests drive have `ValueKey`s (`game-<id>`, `stats-<id>`, `stock`, `waste`,
  `foundation-<suit>`, `tableau-<i>`, card ids like `hearts-1`, `moves-value`, `difficulty-value`, `undo`,
  `new-game`, `new-game-draw-<n>`, `new-game-difficulty-<name>`, `new-game-deal`, `stat-<id>` like
  `stat-winRate` or `stat-<detailKey>`, `variant-<id>`, `difficulty-<name>` (and `-all`) on the stats page,
  `language-menu`, `language-<code>`, `achievements-button`, `card-backs-button`, `achievement-<id>`,
  `card-back-<id>`, `unlocked-<id>` in the win dialog; Mahjong: `tile-<id>`, `hint`, `shuffle`, `stuck-banner`,
  `tiles-value`, `pairs-value`; FreeCell: `freecell-<i>`, `cascade-<i>`, `foundation-<i>`, `auto-complete`;
  Spider: `stock`, `column-<i>`, `foundation-<i>`, `deals-left`, card ids like `spades-1-7`, ...).
  Keep them stable. Keys never depend on the language (no `ValueKey('stat-$label')`).
- Keep code simple: no extra abstraction or packages unless clearly needed. Match the existing style; comments only for the why.

## Tests

- Write tests for behavior that can break: rules, stats, storage, controller state, navigation, persistence.
  No tests of static text, colors, markup or mocks only.
- Each bug fix gets a regression test (check it fails without the fix).
- Widget tests: `useSurface(tester)` for a desktop-size window; seed data with `seededStores([records], [saves])`
  (or `createTestStores(data)` from `test/helpers/test_stores.dart`; `{SettingsStore.localeKey: 'fr'}` for French,
  `savedUnlockData({id: date})` for unlocked achievements). Seeded records unlock their achievements silently.
  They run with an English device; a test that pumps its own `MaterialApp` passes `appLocalizationsDelegates`.
  Drag a card by its visible top strip (`getTopLeft + Offset(10, 6)`), move past the touch slop, then to the target.
- e2e tests use real storage: clear it at the start of each test. `startApp` sets English (the browser may not be)
  and can seed records first (`records:`, written with `StatsStore`).

## Adding a game

1. Rules (pure Dart) + controller in `lib/games/<game>/` with unit tests. Every deal must be winnable: prove it
   (solver offline + generated seed list, like Klondike, or solvable by construction, like Mahjong).
2. Screen and route in `lib/app.dart`; entry in `game_catalog.dart` (route, variants, difficulties, detail
   labels); its texts in both ARB files. A card game's board is an adapter on `CardTable`.
3. Record finished games with `StatsStore.add`; save the game in progress in `GameSaveStore` (controller
   `toJson`/`restore`, remove on a win). The hub and stats page then work without changes.
4. Widget tests (+ the small screen test pages) + e2e flows in `integration_test/<game>_flows.dart`, called from
   `integration_test/app_test.dart`.

## Workflow

- Small, focused commits (Conventional Commits: `feat(klondike): ...`, `fix(stats): ...`, `test: ...`, `docs: ...`).
- No AI or tool attribution in commits or PRs (no `Co-Authored-By`, no "Generated with").
- `.ai/todo.md` is a local task file (git-ignored). `.ai/lessons.md` holds cross-feature lessons.
- Android build needs the Android SDK command-line tools + licences; iOS/macOS need Xcode (not set up on the dev Mac yet).
