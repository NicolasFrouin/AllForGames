import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_release.dart';

/// What [AppUpdater] needs from the platform (Android: the GitHub releases,
/// the app's cache folder and the system installer).
abstract interface class UpdateBackend {
  /// The version name of the installed app, like 1.2.3.
  Future<String> installedVersion();

  /// The releases of the app, as the JSON of GitHub's list releases
  /// endpoint.
  Future<Object?> fetchReleases();

  /// Downloads the APK of [release] and returns its path. [onProgress] gets
  /// the bytes received so far and the total (0 when unknown).
  Future<String> download(
    AppRelease release,
    void Function(int received, int total) onProgress,
  );

  /// Stops the download in progress: [download] then throws.
  void cancelDownload();

  /// Opens the system installer on the APK at [path].
  Future<void> install(String path);

  /// Deletes the downloaded APKs.
  Future<void> clearDownloads();
}

enum UpdateStatus { idle, downloading, failed }

/// Finds a newer release of the app, asks the player once per version and
/// installs it: downloads its APK, then opens the system installer.
///
/// Without a backend (web, desktop, tests), it never finds one.
class AppUpdater extends ChangeNotifier {
  AppUpdater([this._backend]);

  /// The version the player answered Later to: they are not asked again for
  /// it, only for a newer one.
  static const dismissedKey = 'update.dismissed';

  final UpdateBackend? _backend;
  late final _prefs = SharedPreferencesAsync();
  AppRelease? _available;
  String? _dismissed;
  bool _asked = false;
  UpdateStatus _status = UpdateStatus.idle;
  double _progress = 0;
  bool _cancelled = false;

  /// The newer release, null when the app is up to date (or the check failed
  /// or did not run).
  AppRelease? get available => _available;

  /// Whether to ask the player to install [available]: once per app start,
  /// and never again for a version they answered Later to.
  bool get shouldAsk =>
      !_asked && _available != null && '${_available!.version}' != _dismissed;

  UpdateStatus get status => _status;

  /// From 0 to 1 while [status] is downloading.
  double get progress => _progress;

  /// Looks for a newer release. Errors (no network, GitHub down, bad data)
  /// are only logged: the player sees nothing.
  Future<void> check() async {
    final backend = _backend;
    if (backend == null) return;
    final AppRelease? newer;
    try {
      final installed = await backend.installedVersion();
      newer = pickUpdate(
        await backend.fetchReleases(),
        AppVersion.tryParse(installed) ??
            (throw FormatException('Unknown installed version', installed)),
      );
    } on Object catch (error) {
      debugPrint('AppUpdater: cannot check for updates: $error');
      return;
    }
    if (newer == null) {
      // The APK of the version now installed is no longer needed.
      unawaited(backend.clearDownloads());
      return;
    }
    try {
      _dismissed = await _prefs.getString(dismissedKey);
    } on Object catch (error) {
      debugPrint('AppUpdater: cannot read the dismissed version: $error');
    }
    _available = newer;
    notifyListeners();
  }

  /// The player is being asked: [shouldAsk] is false until the next start.
  void markAsked() => _asked = true;

  /// The player answered Later: they are not asked again for [available].
  Future<void> refuse() async {
    final release = _available;
    if (release == null) return;
    _dismissed = '${release.version}';
    try {
      await _prefs.setString(dismissedKey, _dismissed!);
    } on Object catch (error) {
      debugPrint('AppUpdater: cannot save the dismissed version: $error');
    }
    notifyListeners();
  }

  /// Downloads the APK of [available] and opens the system installer. False
  /// when the download failed ([status] failed) or was cancelled (idle).
  ///
  /// [status] changes at once, but listeners are told only after an await:
  /// the caller rebuilds itself.
  Future<bool> update() async {
    final backend = _backend;
    final release = _available;
    if (backend == null ||
        release == null ||
        _status == UpdateStatus.downloading) {
      return false;
    }
    _status = UpdateStatus.downloading;
    _progress = 0;
    _cancelled = false;
    try {
      final path = await backend.download(release, _onProgress);
      if (!_cancelled) await backend.install(path);
      _status = UpdateStatus.idle;
      notifyListeners();
      return !_cancelled;
    } on Object catch (error) {
      debugPrint('AppUpdater: cannot update: $error');
      _status = _cancelled ? UpdateStatus.idle : UpdateStatus.failed;
      notifyListeners();
      return false;
    }
  }

  /// Stops the download of [update].
  void cancelDownload() {
    if (_status != UpdateStatus.downloading) return;
    _cancelled = true;
    _backend?.cancelDownload();
  }

  void _onProgress(int received, int total) {
    final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
    // One notification per percent, not per chunk.
    final changed = (progress * 100).floor() != (_progress * 100).floor();
    _progress = progress;
    if (changed) notifyListeners();
  }
}
