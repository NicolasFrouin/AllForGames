import 'dart:async';
import 'dart:io';

import 'package:all_for_games/update/app_release.dart';
import 'package:all_for_games/update/update_backend_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const channel = MethodChannel('all_for_games/update');

/// The bytes of the APK the local server sends.
final apkBytes = [for (var i = 0; i < 200000; i++) i % 251];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late Uri server;
  late List<String> requests;
  late Completer<void> stalled;

  setUp(() async {
    // flutter_test answers every HttpClient request with 400: this test talks
    // to a local server.
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);

    folder = await Directory.systemTemp.createTemp('afg-update-');
    addTearDown(() => folder.delete(recursive: true));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'updateFolder' ? folder.path : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    requests = [];
    stalled = Completer();
    addTearDown(() => stalled.complete());
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    server = Uri.parse('http://${http.address.host}:${http.port}');
    http.listen((request) async {
      final response = request.response;
      requests.add(request.uri.path);
      switch (request.uri.path) {
        case '/releases/app.apk':
          // Like GitHub, which sends the file from another host.
          await response.redirect(server.resolve('/files/app.apk'));
        case '/files/app.apk':
          response.contentLength = apkBytes.length;
          response.add(apkBytes);
          await response.close();
        case '/files/stalled.apk':
          // Sends its first bytes at once, then waits.
          response.bufferOutput = false;
          response.contentLength = apkBytes.length;
          response.add(apkBytes.sublist(0, 1000));
          await response.flush();
          await stalled.future;
        default:
          response.statusCode = HttpStatus.notFound;
          await response.close();
      }
    });
  });

  AppRelease release(String path, {int? size}) => AppRelease(
    version: AppVersion.tryParse('0.2.0')!,
    apkUrl: server.resolve(path),
    apkSize: size,
  );

  List<String> files() => [
    for (final file in folder.listSync()) file.uri.pathSegments.last,
  ];

  test('downloads the APK behind the redirect, with progress', () async {
    final progress = <(int, int)>[];
    final path = await AndroidUpdateBackend().download(
      release('/releases/app.apk', size: apkBytes.length),
      (received, total) => progress.add((received, total)),
    );

    expect(path, '${folder.path}/all-for-games-0.2.0.apk');
    expect(await File(path).readAsBytes(), apkBytes);
    expect(files(), ['all-for-games-0.2.0.apk']);
    expect(progress.last, (apkBytes.length, apkBytes.length));
    expect(requests, ['/releases/app.apk', '/files/app.apk']);
  });

  test('a complete APK is not downloaded again; others are removed', () async {
    File('${folder.path}/all-for-games-0.1.0.apk').writeAsStringSync('old');
    final backend = AndroidUpdateBackend();
    final apk = release('/files/app.apk', size: apkBytes.length);

    await backend.download(apk, (_, _) {});
    expect(files(), ['all-for-games-0.2.0.apk']);
    await backend.download(apk, (_, _) {});
    expect(requests, ['/files/app.apk']);

    await backend.clearDownloads();
    expect(files(), isEmpty);
  });

  test('a download of the wrong size fails and keeps no APK', () async {
    await expectLater(
      AndroidUpdateBackend().download(
        release('/files/app.apk', size: 1234),
        (_, _) {},
      ),
      throwsA(isA<HttpException>()),
    );
    expect(files(), isNot(contains('all-for-games-0.2.0.apk')));
  });

  test('a missing file fails', () async {
    await expectLater(
      AndroidUpdateBackend().download(release('/files/none.apk'), (_, _) {}),
      throwsA(isA<HttpException>()),
    );
  });

  test('cancelling stops a download in progress', () async {
    final backend = AndroidUpdateBackend();
    await expectLater(
      backend.download(
        release('/files/stalled.apk'),
        (received, total) => backend.cancelDownload(),
      ),
      throwsA(anything),
    );
    expect(files(), isNot(contains('all-for-games-0.2.0.apk')));
  });
}
