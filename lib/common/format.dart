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

/// `33%` in English, `33 %` in French.
String formatPercent(double ratio, String localeName) =>
    NumberFormat.percentPattern(localeName).format(ratio);
