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

/// Short human style: `2h 05m`, `4m 05s` or `12s`.
String formatLongDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${_twoDigits(minutes)}m';
  if (minutes > 0) return '${minutes}m ${_twoDigits(seconds)}s';
  return '${seconds}s';
}

/// Local date and time: `2026-10-05 14:03`.
String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String formatPercent(double ratio) => '${(ratio * 100).round()}%';
