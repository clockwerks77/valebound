import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'state/game_controller.dart';
import 'theme/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Palette.forestNight,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // Everything is on the device: one local SQLite file, no network.
  final database = AppDatabase();
  final controller = GameController(GameRepository(database));
  runApp(HabitAdventureApp(controller: controller));
  await controller.start();
}
