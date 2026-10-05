import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app_stores.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AllForGamesApp(stores: await AppStores.load()));
}
