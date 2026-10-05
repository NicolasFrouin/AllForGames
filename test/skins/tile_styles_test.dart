import 'package:all_for_games/achievements/achievements.dart';
import 'package:all_for_games/app.dart';
import 'package:all_for_games/games/mahjong/mahjong_tile_view.dart';
import 'package:all_for_games/games/mahjong/mahjong_tiles.dart';
import 'package:all_for_games/skins/tile_styles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('classic comes first and is free', () {
    expect(tileStyles.first, same(classicTileStyle));
    expect(classicTileStyle.unlockedBy, isNull);
  });

  test('every unlockedBy names an existing achievement', () {
    final achievementIds = {for (final a in achievements) a.id};
    for (final style in tileStyles) {
      if (style.unlockedBy case final id?) {
        expect(achievementIds, contains(id), reason: style.id);
      }
    }
  });

  test('style ids are unique', () {
    final ids = [for (final style in tileStyles) style.id];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('tileStyleById finds a style, or falls back to classic', () {
    expect(tileStyleById('ebony').id, 'ebony');
    expect(tileStyleById('unknown'), same(classicTileStyle));
    expect(tileStyleById(''), same(classicTileStyle));
  });

  for (final width in [30.0, 80.0]) {
    testWidgets('every style draws every face at ${width.round()} px wide', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(4000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final faceSize = Size(width, width * 1.3);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          home: Wrap(
            children: [
              for (final style in tileStyles) ...[
                TileStylePreview(style: style, width: width),
                for (var code = 0; code < TileFace.count; code++)
                  MahjongTileView(
                    face: TileFace(code),
                    faceSize: faceSize,
                    depth: width * 0.13,
                    style: style,
                    selected: code == 0,
                    dimmed: code.isOdd,
                  ),
              ],
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byType(MahjongTileView),
        findsNWidgets(tileStyles.length * (TileFace.count + 1)),
      );
    });
  }

  testWidgets('a preview needs no app texts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TileStylePreview(style: tileStyles.last, width: 64),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(TileStylePreview)).width, 64);
  });
}
