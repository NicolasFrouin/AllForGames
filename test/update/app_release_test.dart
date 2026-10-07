import 'package:all_for_games/update/app_release.dart';
import 'package:flutter_test/flutter_test.dart';

import 'update_test_helpers.dart';

AppVersion version(String text) => AppVersion.tryParse(text)!;

/// The version of the release [pickUpdate] chooses, or null.
String? picked(List<Object?> releases, {String installed = '0.1.0'}) =>
    pickUpdate(releases, version(installed))?.version.toString();

void main() {
  group('AppVersion', () {
    test('reads versions and tags, with or without a suffix', () {
      expect('${version('1.2.3')}', '1.2.3');
      expect('${version('v0.10.0')}', '0.10.0');
      expect(version('1.2.3-beta.1').suffix, 'beta.1');
      expect(version(' 2.0.0 ').major, 2);
      for (final text in [
        '',
        '1.2',
        'v1.2.3.4',
        '1.2.x',
        'x1.2.3',
        '1.2.3+4',
      ]) {
        expect(AppVersion.tryParse(text), isNull, reason: text);
      }
    });

    test('compares numbers, not text', () {
      expect(version('0.10.0') > version('0.9.0'), isTrue);
      expect(version('1.0.0') > version('0.99.99'), isTrue);
      expect(version('0.2.1') > version('0.2.0'), isTrue);
      expect(version('0.2.0') > version('0.2.1'), isFalse);
      expect(version('v1.2.3').compareTo(version('1.2.3')), 0);
    });

    test('a prerelease comes before its release', () {
      expect(version('1.2.3') > version('1.2.3-beta.1'), isTrue);
      expect(version('1.2.3-beta.1') > version('1.2.3'), isFalse);
      expect(version('1.2.3-beta.1') > version('1.2.2'), isTrue);
    });
  });

  group('pickUpdate', () {
    test('takes the highest version above the installed one', () {
      final releases = [
        githubRelease('v0.2.0'),
        githubRelease('v0.3.0'),
        githubRelease('v0.1.0'),
      ];
      expect(picked(releases), '0.3.0');
      expect(picked(releases, installed: '0.2.5'), '0.3.0');
    });

    test('skips drafts, suffixed tags and releases without an APK', () {
      final releases = [
        githubRelease('v0.5.0', draft: true),
        githubRelease('v0.4.0-beta.1'),
        githubRelease('v0.3.0', apk: false),
        githubRelease('v0.2.0'),
      ];
      expect(picked(releases), '0.2.0');
    });

    test('offers nothing for the same or older versions', () {
      final releases = [githubRelease('v0.2.0'), githubRelease('v0.1.0')];
      expect(picked(releases, installed: '0.2.0'), isNull);
      expect(picked(releases, installed: '0.3.0'), isNull);
      expect(picked([]), isNull);
    });

    test('offers the release of an installed prerelease', () {
      expect(
        picked([githubRelease('v0.2.0')], installed: '0.2.0-beta.1'),
        '0.2.0',
      );
    });

    test('gives the APK file of the release', () {
      final release = pickUpdate([githubRelease('v0.2.0')], version('0.1.0'))!;

      expect(
        '${release.apkUrl}',
        'https://github.com/NicolasFrouin/AllForGames/releases/download/'
            'v0.2.0/all-for-games-0.2.0.apk',
      );
      expect(release.apkSize, 1000);
    });

    test('skips entries it cannot read', () {
      final insecure = githubRelease('v0.4.0');
      final asset = (insecure['assets']! as List).first as Map;
      asset['browser_download_url'] = 'http://example.com/app.apk';
      final releases = [
        'not a release',
        {'tag_name': 'v0.6.0'},
        {...githubRelease('v0.5.0'), 'draft': null},
        insecure,
        {...githubRelease('v0.3.0'), 'tag_name': 'latest'},
        githubRelease('v0.2.0'),
      ];
      expect(picked(releases), '0.2.0');
    });

    test('fails on anything but a list', () {
      expect(
        () => pickUpdate({'message': 'Not Found'}, version('0.1.0')),
        throwsFormatException,
      );
    });
  });
}
