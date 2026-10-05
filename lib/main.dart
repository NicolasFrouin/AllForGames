import 'package:flutter/widgets.dart';

import 'app.dart';
import 'stats/stats_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stats = await StatsStore.load();
  runApp(AllForGamesApp(stats: stats));
}
