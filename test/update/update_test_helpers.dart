import 'dart:async';
import 'dart:io';

import 'package:all_for_games/update/app_release.dart';
import 'package:all_for_games/update/app_updater.dart';

/// A release as GitHub's list releases endpoint gives it, with the files of
/// the Release workflow ([apk] false: without the APK).
Map<String, Object?> githubRelease(
  String tag, {
  bool draft = false,
  bool apk = true,
}) {
  final version = tag.substring(1);
  return {
    'tag_name': tag,
    'name': 'All For Games $version',
    'draft': draft,
    'prerelease': version.startsWith('0.') || version.contains('-'),
    'assets': [
      for (final name in [
        if (apk) 'all-for-games-$version.apk',
        'all-for-games-$version.aab',
        'all-for-games-$version-web.zip',
      ])
        {
          'name': name,
          'size': 1000,
          'browser_download_url':
              'https://github.com/NicolasFrouin/AllForGames/releases/download/$tag/$name',
        },
    ],
  };
}

/// The platform side of [AppUpdater], without network or installer: a test
/// ends each download with [finishDownload] or [failDownload].
class FakeUpdateBackend implements UpdateBackend {
  FakeUpdateBackend({this.installed = '0.1.0', this.releases = const []});

  String installed;
  Object? releases;

  /// Thrown by [fetchReleases] when set.
  Object? fetchError;

  final downloads = <AppRelease>[];
  final installs = <String>[];
  var clears = 0;
  Completer<String>? _download;
  void Function(int received, int total)? _onProgress;

  @override
  Future<String> installedVersion() async => installed;

  @override
  Future<Object?> fetchReleases() async {
    if (fetchError case final error?) throw error;
    return releases;
  }

  @override
  Future<String> download(
    AppRelease release,
    void Function(int received, int total) onProgress,
  ) {
    downloads.add(release);
    _onProgress = onProgress;
    return (_download = Completer<String>()).future;
  }

  void progress(int received, int total) => _onProgress!(received, total);

  void finishDownload([String path = '/cache/updates/app.apk']) =>
      _download!.complete(path);

  void failDownload() =>
      _download!.completeError(const SocketException('no network'));

  @override
  void cancelDownload() =>
      _download!.completeError(const HttpException('connection closed'));

  @override
  Future<void> install(String path) async => installs.add(path);

  @override
  Future<void> clearDownloads() async => clears++;
}
