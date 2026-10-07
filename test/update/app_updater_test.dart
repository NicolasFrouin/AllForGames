import 'package:all_for_games/update/app_updater.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/test_stores.dart';
import 'update_test_helpers.dart';

/// An updater on 0.1.0 whose check found [releases] (0.2.0 by default).
Future<(AppUpdater, FakeUpdateBackend)> checked([
  List<String> releases = const ['v0.2.0'],
]) async {
  final backend = FakeUpdateBackend(
    releases: [for (final tag in releases) githubRelease(tag)],
  );
  final updater = AppUpdater(backend);
  await updater.check();
  return (updater, backend);
}

void main() {
  setUp(useTestStorage);

  test('finds a newer version and asks once', () async {
    final (updater, _) = await checked();

    expect('${updater.available!.version}', '0.2.0');
    expect(updater.shouldAsk, isTrue);
    updater.markAsked();
    expect(updater.shouldAsk, isFalse);
  });

  test('without a backend, it never finds one', () async {
    final updater = AppUpdater();
    await updater.check();

    expect(updater.available, isNull);
    expect(updater.shouldAsk, isFalse);
    expect(await updater.update(), isFalse);
  });

  test('up to date, it removes the downloaded APKs', () async {
    final (updater, backend) = await checked(['v0.1.0']);

    expect(updater.available, isNull);
    expect(updater.shouldAsk, isFalse);
    expect(backend.clears, 1);
  });

  test('a failed check offers nothing and throws nothing', () async {
    final failures = <void Function(FakeUpdateBackend)>[
      (backend) => backend.fetchError = const FormatException('bad JSON'),
      (backend) => backend.releases = {'message': 'Not Found'},
      (backend) => backend.installed = '',
    ];
    for (final fail in failures) {
      final backend = FakeUpdateBackend(releases: [githubRelease('v0.2.0')]);
      fail(backend);
      final updater = AppUpdater(backend);
      await updater.check();

      expect(updater.available, isNull);
      expect(backend.clears, 0);
    }
  });

  test(
    'Later is kept: no question for that version, the update stays',
    () async {
      final (updater, _) = await checked();
      await updater.refuse();
      expect(updater.shouldAsk, isFalse);
      expect(
        await SharedPreferencesAsync().getString(AppUpdater.dismissedKey),
        '0.2.0',
      );

      // The next start.
      final (again, _) = await checked();
      expect('${again.available!.version}', '0.2.0');
      expect(again.shouldAsk, isFalse);
    },
  );

  test('a version newer than the refused one is asked again', () async {
    final (updater, _) = await checked();
    await updater.refuse();

    final (later, _) = await checked(['v0.2.0', 'v0.3.0']);
    expect('${later.available!.version}', '0.3.0');
    expect(later.shouldAsk, isTrue);
  });

  test('blocked storage still asks, and Later still works', () async {
    SharedPreferencesAsyncPlatform.instance = BrokenPrefs();
    final (updater, _) = await checked();
    expect(updater.shouldAsk, isTrue);

    await updater.refuse();
    expect(updater.shouldAsk, isFalse);
  });

  test('downloads with progress, then opens the installer', () async {
    final (updater, backend) = await checked();
    var notified = 0;
    updater.addListener(() => notified++);

    final updated = updater.update();
    expect(updater.status, UpdateStatus.downloading);
    expect('${backend.downloads.single.apkUrl}', endsWith('0.2.0.apk'));

    backend.progress(500, 1000);
    expect(updater.progress, 0.5);
    backend.progress(501, 1000);
    expect(notified, 1, reason: 'one notification per percent');

    backend.finishDownload('/cache/updates/a.apk');
    expect(await updated, isTrue);
    expect(backend.installs, ['/cache/updates/a.apk']);
    expect(updater.status, UpdateStatus.idle);
  });

  test('a failed download can be tried again', () async {
    final (updater, backend) = await checked();

    final failed = updater.update();
    backend.failDownload();
    expect(await failed, isFalse);
    expect(updater.status, UpdateStatus.failed);
    expect(backend.installs, isEmpty);

    final retried = updater.update();
    expect(updater.status, UpdateStatus.downloading);
    expect(updater.progress, 0);
    backend.finishDownload();
    expect(await retried, isTrue);
    expect(backend.installs, hasLength(1));
    expect(backend.downloads, hasLength(2));
  });

  test('a cancelled download is no failure and installs nothing', () async {
    final (updater, backend) = await checked();

    final cancelled = updater.update();
    updater.cancelDownload();
    expect(await cancelled, isFalse);
    expect(updater.status, UpdateStatus.idle);
    expect(backend.installs, isEmpty);
  });

  test('one download at a time', () async {
    final (updater, backend) = await checked();

    final first = updater.update();
    expect(await updater.update(), isFalse);
    backend.finishDownload();
    expect(await first, isTrue);
    expect(backend.downloads, hasLength(1));
  });
}
