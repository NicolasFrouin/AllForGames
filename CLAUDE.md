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
flutter build web --release --wasm            # release web build in build/web
```

Toolchain: Flutter 3.47.6 / Dart 3.13 (Homebrew cask). CI (`.github/workflows/ci.yml`) runs format, analyze, tests and web e2e.

## Layout

```
lib/
  main.dart, app.dart        loads the stores, routes (go_router): /, /klondike?draw=3&seed=42, /stats/:gameId
  app_stores.dart            AppStores: every store (stats, saves, settings), loaded once, given to the screens
  l10n/                      app_en.arb (template) + app_fr.arb; app_localizations*.dart are generated (git-ignored)
  settings/                  SettingsStore: player settings (language), one storage key per setting
  hub/                       home page: header + language menu, overall stats, game grid (continue line per game)
  saves/                     SavedGame (one game in progress, game-specific JSON in data), GameSaveStore
  stats/                     GameRecord (one finished game), GameStats (aggregates), StatsStore, PlayTimer, stats page
  common/format.dart         duration/date/percent formatting, in the app language
  games/game_catalog.dart    GameInfo list shown on the hub (route, localized title/tagline/variants/stat labels)
  games/klondike/            playing_card, klondike_state (immutable rules), klondike_controller (game session,
                             undo, stat counters), klondike_board (cards + drag and drop), klondike_screen, card_view, suit_icon
test/                        unit (games/, stats/) and widget (widget/) tests; helpers in test/helpers and *_test_helpers.dart
integration_test/            e2e tests (run on web by scripts/e2e_web.sh, or on a device)
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
- **Saved games**: leaving a game (back, app closed, tab closed) saves it; opening it again continues it.
  The controller saves itself after every action, on `pause()` and when the screen closes, and removes the save
  on a win. `toJson()` has a `version`; `restore(json)` throws `FormatException` on bad data, then the screen
  deals a new game. Route params (`/klondike?seed=42`) start that deal and abandon the saved one.
- **Storage** (shared_preferences, `SharedPreferencesAsync`; localStorage on web): one key per item, never a whole
  list (other tabs and unreadable entries must survive). Keys: `stats.game.<gameId>-<startedAt µs>-<seed>` per
  record (`StatsStore.keyOf`), `save.<gameId>` per game in progress (`GameSaveStore.keyOf`), `settings.<name>`
  per setting (`settings.locale`: `en`/`fr`, absent = device language).
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
- **Card suits** are drawn with `SuitIcon` (vector). Text symbols ♥ ♦ render as color emoji on web.
- **Keys for tests**: widgets that tests drive have `ValueKey`s (`game-<id>`, `stats-<id>`, `stock`, `waste`,
  `foundation-<suit>`, `tableau-<i>`, card ids like `hearts-1`, `moves-value`, `undo`, `stat-<id>` like
  `stat-winRate` or `stat-<detailKey>`, `language-menu`, `language-<code>`, ...). Keep them stable.
  Keys never depend on the language (no `ValueKey('stat-$label')`).
- Keep code simple: no extra abstraction or packages unless clearly needed. Match the existing style; comments only for the why.

## Tests

- Write tests for behavior that can break: rules, stats, storage, controller state, navigation, persistence.
  No tests of static text, colors, markup or mocks only.
- Each bug fix gets a regression test (check it fails without the fix).
- Widget tests: `useSurface(tester)` for a desktop-size window; seed data with `seededStores([records], [saves])`
  (or `createTestStores(data)` from `test/helpers/test_stores.dart`; `{SettingsStore.localeKey: 'fr'}` for French).
  They run with an English device; a test that pumps its own `MaterialApp` passes `appLocalizationsDelegates`.
  Drag a card by its visible top strip (`getTopLeft + Offset(10, 6)`), move past the touch slop, then to the target.
- e2e tests use real storage: clear it at the start of each test. `startApp` sets English (the browser may not be).

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
