import 'dart:ui' show Locale;

import 'package:all_for_games/common/format.dart';
import 'package:all_for_games/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final en = lookupAppLocalizations(const Locale('en'));
final fr = lookupAppLocalizations(const Locale('fr'));

void main() {
  // The app gets the date formats from its Material localizations.
  setUpAll(initializeDateFormatting);

  group('formatLongDuration', () {
    const durations = [
      Duration(hours: 2, minutes: 5, seconds: 59),
      Duration(minutes: 4, seconds: 5),
      Duration(seconds: 12),
    ];

    test('in English', () {
      expect(
        [for (final d in durations) formatLongDuration(d, en)],
        ['2h 05m', '4m 05s', '12s'],
      );
    });

    test('in French', () {
      expect(
        [for (final d in durations) formatLongDuration(d, fr)],
        ['2 h 05', '4 min 05 s', '12 s'],
      );
    });
  });

  test('formatPercent rounds to a whole percent', () {
    expect(formatPercent(1 / 3, en.localeName), '33%');
    expect(formatPercent(2 / 3, en.localeName), '67%');
    expect(formatPercent(1, en.localeName), '100%');
    expect(formatPercent(1 / 3, fr.localeName), '33 %');
  });

  test('formatDateTime shows the local date and time', () {
    final date = DateTime(2026, 10, 5, 14, 3);
    expect(formatDateTime(date, en.localeName), '10/5/2026 14:03');
    expect(formatDateTime(date, fr.localeName), '05/10/2026 14:03');
    expect(
      formatDateTime(date.toUtc(), en.localeName),
      '10/5/2026 14:03',
      reason: 'records keep UTC times',
    );
  });
}
