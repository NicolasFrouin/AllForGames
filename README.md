# All For Games

Classic games in one app: pick a game on the hub, play, and follow detailed statistics.

- **Klondike** solitaire (Draw 1 / Draw 3), with undo, drag and drop, tap-to-move and auto-finish
- **FreeCell**, with multi-card moves and automatic moves to the foundations
- **Spider** with 1, 2 or 4 suits
- **TriPeaks**: clear three peaks with cards one rank above or below the waste (King and Ace wrap around)
- **Mahjong** solitaire (Pyramid and Turtle layouts), with hints, shuffle and undo, and a Tray mode: tapped tiles
  go into 4 places where pairs clear, and a full tray loses
- **Minesweeper** (Beginner, Intermediate, Expert), never a guess: the first tap opens an area and logic alone
  clears every board; flags, chords, hints and a Try again on the same board
- Easy, Medium and Hard levels, and every deal can be won (proven by solvers)
- Games are saved: leave and come back to continue where you were
- Statistics for every game: time, moves, undos, score, streaks, records and more, and an overview of all games
  (daily streaks, activity of the last 30 days, when you play, recent games)
- 45 achievements across the games, each unlocking a skin: 30 card backs, 11 Mahjong tile styles and 7 Minesweeper
  themes (one of each is free)
- English and French
- Fluid animations: dealing, flying and flipping cards, and a celebration for every win

Built with [Flutter](https://flutter.dev): one codebase for Web, Android, iOS, Windows, macOS and Linux.

## Quick start

```sh
flutter pub get
flutter run -d chrome        # run on the web
flutter test                 # unit and widget tests
scripts/e2e_web.sh           # end-to-end tests in headless Chrome
```

Release web build: `flutter build web --release --wasm` (output in `build/web`).

App icon: SVG sources in `assets/icon/`; `scripts/make_icons.sh` regenerates the icons of every platform from them
(needs `brew install librsvg imagemagick`).

## Builds and releases

### Cut a release

```sh
git tag v0.1.0 && git push origin v0.1.0
```

The Release workflow (`.github/workflows/release.yml`, on the self-hosted runner) builds the Android APK, the
Android App Bundle and the web build, then publishes them on a GitHub Release (the repository's Releases page):
`all-for-games-<version>.apk`, `.aab` and `-web.zip`. The tag gives the version (`v1.2.3` → 1.2.3), the run
number the build number (Android `versionCode`). Versions below 1.0 or with a suffix (`v1.0.0-beta.1`) are
prereleases. To build without a release: Actions > Release > Run workflow (pubspec version; the files are
artifacts of the run, kept 14 days).

### Install the APK on an Android phone

- On the phone: open the release page (signed in to GitHub: the repository is private), download the `.apk`,
  open it and allow installs from this source when Android asks.
- Or from a computer, with USB debugging on: `adb install all-for-games-<version>.apk`.

Without the signing secrets (below), builds are signed with the runner's debug key. Android updates an app only
with an APK signed by the same key: after a key change (debug to upload key, local build to CI build), uninstall
the app first (its saved games and statistics go with it).

### Build locally

- **Android**: Android Studio (in its SDK Manager, also add *Android SDK Command-line Tools*, needed for the app
  bundle), or `brew install --cask temurin@17 android-commandlinetools`, then
  `export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools`,
  `sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"` and `flutter doctor --android-licenses`.
  Then `flutter build apk` (`build/app/outputs/flutter-apk/app-release.apk`), `flutter build appbundle`, or
  `flutter run --release` with a phone plugged in.
- **iOS**: a Mac with Xcode and an Apple ID (`flutter run --release` on your own iPhone). TestFlight and the App
  Store need the paid Apple Developer Program (`flutter build ipa`).
- **macOS, Windows, Linux**: build on that system (no cross-compiling): `flutter build macos`,
  `flutter build windows`, `flutter build linux`.
- **Web**: `flutter build web --release --wasm`, then put `build/web` on any static host (at the site root; for a
  sub-folder, add `--base-href /folder/`).

### Android signing key

The Play Store needs every build signed with the same upload key. Create it once (`keytool` comes with any JDK,
e.g. Android Studio's in `/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin`), and keep the file and
its passwords safe (a lost upload key takes a reset request to Google):

```sh
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -storetype JKS -keysize 2048 -validity 10000 -alias upload
```

Local release builds use it through `android/key.properties` (git-ignored; without it, release builds use the
debug key):

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=upload
storeFile=/Users/<you>/upload-keystore.jks
```

The Release workflow uses it through four repository secrets (`gh secret set` asks for each value):

```sh
base64 -i ~/upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS --body upload
gh secret set ANDROID_KEY_PASSWORD
```
