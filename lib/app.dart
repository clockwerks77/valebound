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
    } else if (game.startupTrouble != null) {
      child = _StartupTrouble(
        key: const ValueKey<String>('trouble'),
        detail: game.startupTrouble!,
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

/// Shown only if the local database cannot be opened. Calm, and specific
/// enough to act on; nothing has been changed or removed.
class _StartupTrouble extends StatelessWidget {
  const _StartupTrouble({super.key, required this.detail});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.forestDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'The Vale could not open your saved data',
                    style: AppText.heading.copyWith(color: Palette.onDark),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nothing has been changed. Close $appName fully and open '
                    'it again. If you see this twice, send the detail below '
                    'to whoever builds the app.',
                    style: AppText.body.copyWith(color: Palette.onDarkSoft),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    detail,
                    style: AppText.small.copyWith(color: Palette.onDarkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
