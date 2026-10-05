# All For Games

Classic games in one app: pick a game on the hub, play, and follow detailed statistics.

- **Klondike** solitaire (Draw 1 / Draw 3), with undo, drag and drop, tap-to-move and auto-finish
- Games are saved: leave and come back to continue where you were
- Statistics for every game: time, moves, undos, score, streaks, records and more
- Achievements, with progress, that unlock new card backs to pick for the games
- English and French
- FreeCell, Spider and Mahjong are coming

Built with [Flutter](https://flutter.dev): one codebase for Web, Android, iOS, Windows, macOS and Linux.

## Quick start

```sh
flutter pub get
flutter run -d chrome        # run on the web
flutter test                 # unit and widget tests
scripts/e2e_web.sh           # end-to-end tests in headless Chrome
```

Release web build: `flutter build web --release --wasm` (output in `build/web`).
