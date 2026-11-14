import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/app.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/state/game_controller.dart';
import 'package:habit_adventure/ui/board/quest_actions.dart';
import 'package:habit_adventure/ui/shell/app_shell.dart';
import 'package:integration_test/integration_test.dart';

// Runs on a real Android runtime (the CI emulator, or a connected phone):
//   flutter test integration_test -d <device>
//
// It uses the app's real on-device SQLite file, so it proves what the unit
// tests cannot: that storage opens on Android, and that what was saved is
// still there after the database is closed and opened again.

Future<void> reveal(WidgetTester tester, Finder target) async {
  final list = find.byType(ListView).first;
  for (var i = 0; i < 14 && target.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.4);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run, one completed quest, then reopen', (tester) async {
    void step(String what) => debugPrint('DEVICE-TEST STEP: $what');

    step('open storage');
    var db = AppDatabase();
    var game = GameController(GameRepository(db));
    await game.init();
    expect(game.hasProfile, isFalse, reason: 'a fresh install starts empty');

    step('show the app');
    await tester.pumpWidget(HabitAdventureApp(controller: game));
    await tester.pumpAndSettle();

    // Onboarding: name the hero, take the Babs preset, begin.
    step('onboarding');
    await tester.enterText(find.byType(TextField).first, 'Adam');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('A hound named Babs'));
    await tester.tap(find.text('A hound named Babs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    step('create the profile');
    await tester.tap(find.text('Begin at Dawn'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    step('board is up');

    expect(find.byType(AppShell), findsOneWidget);
    expect(game.companion!.kind, CompanionKind.hound);

    // Complete the flagship Shared quest on the board.
    final walk = find.byWidgetPredicate(
      (w) => w is CompleteButton && w.label == 'Complete Walk Babs',
    );
    step('find Walk Babs');
    await reveal(tester, walk);
    step('complete Walk Babs');
    await tester.tap(walk);
    // A tapped completion waits five seconds so it can be undone.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    step('completed');
    expect(game.companion!.totalXp, 25);
    expect(game.hero!.totalXp, 13);

    // "Restart": drop the app, close storage, open it all again.
    step('close everything');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();

    step('reopen storage');
    db = AppDatabase();
    game = GameController(GameRepository(db));
    await game.init();
    expect(game.hasProfile, isTrue);
    expect(game.hero!.name, 'Adam');
    expect(game.hero!.totalXp, 13);
    expect(game.companion!.name, 'Babs');
    expect(game.companion!.totalXp, 25);
    expect(game.companion!.bond, 1);
    expect(game.world!.journeyPaces, 1);
    expect(game.doneQuests.map((b) => b.quest.name), contains('Walk Babs'));

    step('show the app again');
    await tester.pumpWidget(HabitAdventureApp(controller: game));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
    step('done');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });
}
