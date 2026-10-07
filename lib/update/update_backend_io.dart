import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_release.dart';
import 'app_updater.dart';

/// The update backend of this platform: Android only. Tests run on the
/// desktop VM, where `Platform` is the real system, so they never get one.
UpdateBackend? platformUpdateBackend() =>
    Platform.isAndroid ? AndroidUpdateBackend() : null;

/// The releases of the GitHub repository, the APK in the app's cache folder,
/// and the installer through MainActivity.kt.
class AndroidUpdateBackend implements UpdateBackend {
  static const _channel = MethodChannel('all_for_games/update');

  /// Newest first. /releases/latest skips prereleases, and GitHub marks every
  /// version below 1.0 as one.
  static final _releasesUrl = Uri.parse(
    'https://api.github.com/repos/NicolasFrouin/AllForGames/releases?per_page=20',
  );

  /// GitHub refuses requests without one.
  static const _userAgent = 'AllForGames-Android';

  /// A stalled connection fails instead of waiting forever.
  static const _timeout = Duration(seconds: 30);

  /// Ends the download in progress with an error.
  Completer<Never>? _cancel;

  static HttpClient _client() => HttpClient()
    ..userAgent = _userAgent
    ..connectionTimeout = _timeout;

  @override
  Future<String> installedVersion() async =>
      await _channel.invokeMethod<String>('versionName') ?? '';

  @override
  Future<Object?> fetchReleases() async {
    final client = _client();
    try {
      final request = await client.getUrl(_releasesUrl);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set('X-GitHub-Api-Version', '2022-11-28');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('status ${response.statusCode}', uri: _releasesUrl);
      }
      return jsonDecode(
        await response.transform(utf8.decoder).join().timeout(_timeout),
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<String> download(
    AppRelease release,
    void Function(int received, int total) onProgress,
  ) async {
    final cancel = _cancel = Completer<Never>();
    // Every wait ends at once on a cancel.
    Future<T> unlessCancelled<T>(Future<T> future) =>
        Future.any([future, cancel.future]);
    final client = _client();
    try {
      final folder = await unlessCancelled(_folder());
      final apk = File('${folder.path}/all-for-games-${release.version}.apk');
      // Already downloaded: the player left the installer and taps again.
      final size = release.apkSize;
      if (size != null && await apk.exists() && await apk.length() == size) {
        return apk.path;
      }
      await _clear(folder);
      final part = File('${apk.path}.part');
      // GitHub redirects to its file host: HttpClient follows it (GET).
      final request = await unlessCancelled(client.getUrl(release.apkUrl));
      final response = await unlessCancelled(request.close().timeout(_timeout));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'status ${response.statusCode}',
          uri: release.apkUrl,
        );
      }
      final expected =
          size ?? (response.contentLength > 0 ? response.contentLength : null);
      var received = 0;
      final sink = part.openWrite();
      final subscription = response.timeout(_timeout).listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, expected ?? 0);
      });
      try {
        await unlessCancelled(subscription.asFuture<void>());
      } finally {
        await subscription.cancel();
        await sink.close();
      }
      if (expected != null && received != expected) {
        throw HttpException(
          'got $received bytes of $expected',
          uri: release.apkUrl,
        );
      }
      await part.rename(apk.path);
      return apk.path;
    } finally {
      _cancel = null;
      client.close(force: true);
    }
  }

  @override
  void cancelDownload() {
    if (_cancel case final cancel? when !cancel.isCompleted) {
      cancel.completeError(const HttpException('download cancelled'));
    }
  }

  @override
  Future<void> install(String path) =>
      _channel.invokeMethod<void>('install', {'path': path});

  @override
  Future<void> clearDownloads() async {
    try {
      await _clear(await _folder());
    } on Object catch (error) {
      debugPrint('AndroidUpdateBackend: cannot clear the downloads: $error');
    }
  }

  /// The cache subfolder MainActivity.kt shares with the installer.
  static Future<Directory> _folder() async =>
      Directory((await _channel.invokeMethod<String>('updateFolder'))!);

  static Future<void> _clear(Directory folder) async {
    await for (final entry in folder.list()) {
      await entry.delete(recursive: true);
    }
  }
}
