import 'package:all_for_games/app.dart';
import 'package:all_for_games/app_stores.dart';
import 'package:all_for_games/games/klondike/klondike_screen.dart';
import 'package:all_for_games/update/app_updater.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_stores.dart';
import '../update/update_test_helpers.dart';
import 'widget_test_helpers.dart';

Finder byKey(String key) => find.byKey(ValueKey(key));

/// Starts the app (0.1.0) on the current storage, with [tags] released on
/// GitHub. The check of the start has not run yet: see [check].
Future<(AppStores, FakeUpdateBackend)> startApp(
  WidgetTester tester, {
  List<String> tags = const ['v0.2.0'],
}) async {
  final backend = FakeUpdateBackend(
    releases: [for (final tag in tags) githubRelease(tag)],
  );
  final stores = await AppStores.load(updateBackend: backend);
  useSurface(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(AllForGamesApp(stores: stores));
  await tester.pumpAndSettle();
  return (stores, backend);
}

Future<void> check(WidgetTester tester, AppStores stores) async {
  await stores.updater.check();
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  setUp(useTestStorage);

  testWidgets('up to date, the hub shows no update', (tester) async {
    final (stores, _) = await startApp(tester, tags: ['v0.1.0']);
    await check(tester, stores);

    expect(byKey('update-dialog'), findsNothing);
    expect(byKey('update-button'), findsNothing);
  });

  testWidgets('a new version is asked once; after Later, the button stays', (
    tester,
  ) async {
    final (stores, _) = await startApp(tester);
    expect(byKey('update-button'), findsNothing);

    await check(tester, stores);
    expect(byKey('update-dialog'), findsOneWidget);
    expect(
      find.text('Version 0.2.0 is available. Update now?'),
      findsOneWidget,
    );
    await tapKey(tester, 'update-later');
    expect(byKey('update-dialog'), findsNothing);
    expect(
      find.descendant(
        of: byKey('update-button'),
        matching: find.text('Update to 0.2.0'),
      ),
      findsOneWidget,
    );

    // Back on the hub from a game: not asked again.
    await tapKey(tester, 'game-klondike');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(byKey('update-dialog'), findsNothing);

    // The next start: still not asked for 0.2.0, the button is there.
    final (again, _) = await startApp(tester);
    await check(tester, again);
    expect(byKey('update-dialog'), findsNothing);
    expect(byKey('update-button'), findsOneWidget);

    // A newer version is asked.
    final (newer, _) = await startApp(tester, tags: ['v0.2.0', 'v0.3.0']);
    await check(tester, newer);
    expect(
      find.text('Version 0.3.0 is available. Update now?'),
      findsOneWidget,
    );
  });

  testWidgets('the question waits for the hub to be on top', (tester) async {
    final (stores, _) = await startApp(tester);
    await tapKey(tester, 'game-klondike');

    await check(tester, stores);
    expect(find.byType(KlondikeScreen), findsOneWidget);
    expect(byKey('update-dialog'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(byKey('update-dialog'), findsOneWidget);
  });

  testWidgets('Update downloads with progress, then opens the installer', (
    tester,
  ) async {
    final (stores, backend) = await startApp(tester);
    await check(tester, stores);

    await tapKey(tester, 'update-now');
    expect(byKey('update-dialog'), findsNothing);
    expect(byKey('update-progress'), findsOneWidget);
    expect(textOf('update-percent'), 'Downloading… 0%');

    backend.progress(500, 1000);
    await tester.pumpAndSettle();
    expect(textOf('update-percent'), 'Downloading… 50%');
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);

    backend.finishDownload('/cache/updates/all-for-games-0.2.0.apk');
    await tester.pumpAndSettle();
    expect(byKey('update-progress'), findsNothing);
    expect(backend.installs, ['/cache/updates/all-for-games-0.2.0.apk']);
    // The app stays on 0.1.0 until Android replaces it; not asked again.
    expect(byKey('update-button'), findsOneWidget);
    expect(byKey('update-dialog'), findsNothing);
  });

  testWidgets('the button downloads again after a failure', (tester) async {
    final (stores, backend) = await startApp(tester);
    await check(tester, stores);
    await tapKey(tester, 'update-later');

    await tapKey(tester, 'update-button');
    expect(byKey('update-progress'), findsOneWidget);
    backend.failDownload();
    await tester.pumpAndSettle();
    expect(byKey('update-error'), findsOneWidget);

    await tapKey(tester, 'update-retry');
    expect(byKey('update-error'), findsNothing);
    expect(textOf('update-percent'), 'Downloading… 0%');
    expect(backend.downloads, hasLength(2));

    backend.finishDownload();
    await tester.pumpAndSettle();
    expect(byKey('update-progress'), findsNothing);
    expect(backend.installs, hasLength(1));
  });

  testWidgets('Cancel stops the download', (tester) async {
    final (stores, backend) = await startApp(tester);
    await check(tester, stores);
    await tapKey(tester, 'update-later');
    await tapKey(tester, 'update-button');

    await tapKey(tester, 'update-cancel');
    expect(byKey('update-progress'), findsNothing);
    expect(stores.updater.status, UpdateStatus.idle);
    expect(backend.installs, isEmpty);
  });
}
