import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Clock style: `4:05` or `1:04:05`.
String formatClock(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = _twoDigits(duration.inSeconds.remainder(60));
  return hours > 0
      ? '$hours:${_twoDigits(minutes)}:$seconds'
      : '$minutes:$seconds';
}

/// Short human style: `2h 05m`, `4m 05s` or `12s` in English.
String formatLongDuration(Duration duration, AppLocalizations l10n) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return l10n.durationHoursMinutes(hours, _twoDigits(minutes));
  if (minutes > 0) {
    return l10n.durationMinutesSeconds(minutes, _twoDigits(seconds));
  }
  return l10n.durationSeconds(seconds);
}

/// Local date and time in the style of [localeName]: `10/5/2026 14:03` in
/// English.
String formatDateTime(DateTime dateTime, String localeName) =>
    DateFormat.yMd(localeName).add_Hm().format(dateTime.toLocal());

/// Local date in the style of [localeName]: `10/5/2026` in English.
String formatDate(DateTime dateTime, String localeName) =>
    DateFormat.yMd(localeName).format(dateTime.toLocal());

/// Day and month: `Oct 5` in English, `5 oct.` in French.
String formatShortDate(DateTime dateTime, String localeName) =>
    DateFormat.MMMd(localeName).format(dateTime.toLocal());

/// An hour of the day: `6 AM` in English, `06 h` in French.
String formatHour(int hour, String localeName) =>
    DateFormat.j(localeName).format(DateTime(2000, 1, 1, hour));

/// Short name of [weekday] (`DateTime.monday` to `DateTime.sunday`): `Mon`
/// in English.
String formatWeekday(int weekday, String localeName) =>
    // January 1, 2024 is a Monday.
    DateFormat.E(localeName).format(DateTime(2024, 1, weekday));

/// The weekdays (`DateTime.monday` to `DateTime.sunday`) in the order of a
/// week in [localeName]: Sunday first in English, Monday first in French.
List<int> weekdaysInOrder(String localeName) {
  final first = DateFormat.E(localeName).dateSymbols.FIRSTDAYOFWEEK;
  // FIRSTDAYOFWEEK counts from Monday = 0.
  return [for (var i = 0; i < 7; i++) (first + i) % 7 + DateTime.monday];
}

/// `12,345` in English, `12 345` in French.
String formatCount(int value, String localeName) =>
    NumberFormat.decimalPattern(localeName).format(value);

/// `33%` in English, `33 %` in French.
String formatPercent(double ratio, String localeName) =>
    NumberFormat.percentPattern(localeName).format(ratio);
