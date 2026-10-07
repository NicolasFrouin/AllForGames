import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app_stores.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stores = await AppStores.load();
  runApp(AllForGamesApp(stores: stores));
  // After the first frame, so the start does not wait for the network.
  unawaited(
    WidgetsBinding.instance.endOfFrame.then((_) => stores.updater.check()),
  );
}
