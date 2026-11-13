import 'package:flutter/material.dart';

import 'app_info.dart';
import 'state/game_controller.dart';
import 'theme/app_theme.dart';
import 'theme/palette.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/shell/app_shell.dart';

class HabitAdventureApp extends StatelessWidget {
  const HabitAdventureApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    // The scope sits above the navigator so dialogs and sheets can reach it.
    return GameScope(
      controller: controller,
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final Widget child;
    if (game.loading) {
      child = const Scaffold(
        key: ValueKey<String>('loading'),
        backgroundColor: Palette.forestDeep,
        body: SizedBox.expand(),
      );
    } else if (!game.hasProfile) {
      child = const OnboardingScreen(key: ValueKey<String>('onboarding'));
    } else {
      child = const AppShell(key: ValueKey<String>('shell'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: child,
    );
  }
}
