import 'package:all_for_games/stats/play_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late PlayTimer timer;

  setUp(() {
    now = DateTime.utc(2026, 1, 1);
    timer = PlayTimer(clock: () => now);
  });

  void wait(int seconds) => now = now.add(Duration(seconds: seconds));

  test('counts nothing before start', () {
    wait(10);
    expect(timer.isRunning, isFalse);
    expect(timer.elapsed, Duration.zero);
  });

  test('pause freezes the time and start continues it', () {
    timer.start();
    wait(5);
    expect(timer.elapsed, const Duration(seconds: 5));

    timer.pause();
    wait(60);
    expect(timer.isRunning, isFalse);
    expect(timer.elapsed, const Duration(seconds: 5));

    timer.start();
    wait(2);
    expect(timer.isRunning, isTrue);
    expect(timer.elapsed, const Duration(seconds: 7));
  });

  test('a second start or pause changes nothing', () {
    timer.start();
    wait(5);
    timer.start();
    wait(5);
    expect(timer.elapsed, const Duration(seconds: 10));

    timer.pause();
    wait(5);
    timer.pause();
    expect(timer.elapsed, const Duration(seconds: 10));
  });
}
