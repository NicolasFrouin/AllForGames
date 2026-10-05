/// Measures active play time. It can pause, for example when the app goes to
/// the background.
class PlayTimer {
  PlayTimer({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;

  bool get isRunning => _runningSince != null;

  Duration get elapsed => switch (_runningSince) {
    final since? => _accumulated + _clock().difference(since),
    null => _accumulated,
  };

  void start() => _runningSince ??= _clock();

  void pause() {
    if (_runningSince case final since?) {
      _accumulated += _clock().difference(since);
      _runningSince = null;
    }
  }
}
