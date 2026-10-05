# CLAUDE.md

Guide for AI agents working on this repo. Read it fully before you change code.

## Project

All For Games: one Flutter app with a hub of classic games (Klondike now; FreeCell, Spider, Mahjong later).
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
flutter build web --release --wasm            # release web build in build/web
```

Toolchain: Flutter 3.47.6 / Dart 3.13 (Homebrew cask). CI (`.github/workflows/ci.yml`) runs format, analyze, tests,
the deal tests in Chrome (JS and Wasm) and web e2e.

**CI runs only on the self-hosted runner** (Coolify, Linux x64): every job uses `runs-on: [self-hosted, Linux, X64]`.
Never use GitHub-hosted runners (`ubuntu-latest`, ...). The runner has no preinstalled Chrome or Flutter: the
workflow installs them (`subosito/flutter-action`, `browser-actions/setup-chrome`) and passes `CHROME_EXECUTABLE`
and `CHROMEDRIVER` to `scripts/e2e_web.sh`. A new tool needed by CI must be installed by the workflow too.

## Layout

```
lib/
  main.dart, app.dart        loads the stores, routes (go_router): /, /klondike?draw=3&seed=42, /stats/:gameId,
                             /achievements, /card-backs
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
  games/klondike/            playing_card, klondike_state (immutable rules), klondike_controller (game session,
                             undo, stat counters), klondike_board (cards + drag and drop), klondike_screen, card_view, suit_icon,
                             deal_random (seeded shuffle), klondike_deals (generated winnable seeds), deal_picker
                             (pickDealSeed, difficultyOfSeed), klondike_difficulty (enum) + _texts, new_game_sheet,
                             klondike_solver (offline only: the generator and tests)
test/                        unit (games/, stats/) and widget (widget/) tests; helpers in test/helpers and *_test_helpers.dart
integration_test/            e2e tests (run on web by scripts/e2e_web.sh, or on a device)
tool/                        generate_klondike_deals.dart (solves and grades deals, writes klondike_deals.dart)
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
  classic; `settings.klondike.drawCount`: int 1/3, unknown = 1; `settings.klondike.difficulty`:
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
- **Klondike deals**: `KlondikeState.deal(seed)` (`shuffledDeck` with `DealRandom`, the same on VM, JS and Wasm)
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
- **Card suits** are drawn with `SuitIcon` (vector). Text symbols ♥ ♦ render as color emoji on web.
  Face-down cards are drawn with `CardBackView` and the selected skin.
- **Keys for tests**: widgets that tests drive have `ValueKey`s (`game-<id>`, `stats-<id>`, `stock`, `waste`,
  `foundation-<suit>`, `tableau-<i>`, card ids like `hearts-1`, `moves-value`, `difficulty-value`, `undo`,
  `new-game`, `new-game-draw-<n>`, `new-game-difficulty-<name>`, `new-game-deal`, `stat-<id>` like
  `stat-winRate` or `stat-<detailKey>`, `variant-<id>`, `difficulty-<name>` (and `-all`) on the stats page,
  `language-menu`, `language-<code>`, `achievements-button`, `card-backs-button`, `achievement-<id>`,
  `card-back-<id>`, `unlocked-<id>` in the win dialog, ...).
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

1. Rules + controller in `lib/games/<game>/` with unit tests.
2. Screen and route in `lib/app.dart`; entry in `game_catalog.dart` (route, variants, detail labels); its texts
   in both ARB files.
3. Record finished games with `StatsStore.add`; save the game in progress in `GameSaveStore` (controller
   `toJson`/`restore`, remove on a win). The hub and stats page then work without changes.
4. Widget tests + one e2e flow.

## Workflow

- Small, focused commits (Conventional Commits: `feat(klondike): ...`, `fix(stats): ...`, `test: ...`, `docs: ...`).
- No AI or tool attribution in commits or PRs (no `Co-Authored-By`, no "Generated with").
- `.ai/todo.md` is a local task file (git-ignored). `.ai/lessons.md` holds cross-feature lessons.
- Android build needs the Android SDK command-line tools + licences; iOS/macOS need Xcode (not set up on the dev Mac yet).
