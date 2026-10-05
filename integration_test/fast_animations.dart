import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `testWidgets` whose animations play 5 times faster: the e2e flows check
/// what the player can do, the widget tests check the timings.
void testFlow(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    timeDilation = 0.2;
    try {
      await body(tester);
    } finally {
      // Before the end of the test: flutter_test checks it right after.
      timeDilation = 1;
    }
  });
}
