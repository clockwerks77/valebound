import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/rules/combat.dart';
import 'package:habit_adventure/rules/encounter.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/ui/board/board_screen.dart' show encounterLine;
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';

// Version 0.7 (Amendment v0.3): choosing and changing a class, the day's
// encounter from the board to its chest, and what happens when the
// creature holds. A fresh hero on Saturday 14 November meets an Old
// Yawnstone, a Brute; as a Warden with no quests done the fight goes the
// same way every time (the dice are seeded), so the taps below are a real
// winning line and a real one that does not.

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);
final DateTime sundayEvening = DateTime(2026, 11, 15, 20, 30);

Finder primary(String label) => find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.label == label,
    );

Finder quiet(String label) => find.byWidgetPredicate(
      (w) => w is QuietButton && w.label == label,
    );

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

/// From the board to the first turn of today's fight.
Future<void> meet(WidgetTester tester, TestApp app) async {
  final line = find.text(encounterLine(app.game));
  await reveal(tester, line);
  await tester.tap(line);
  await tester.pumpAndSettle();
  expect(find.text('SCOUT’S REPORT'), findsOneWidget);
  await tester.tap(primary('Meet it'));
  await tester.pumpAndSettle();
}

/// Plays [moves], one action tile a turn.
Future<void> play(
  WidgetTester tester,
  TestApp app,
  List<String> moves,
) async {
  for (final move in moves) {
    await tester.tap(find.text(move));
    await app.settle(tester);
  }
}

const List<String> winningLine = <String>[
  'Strike', 'Strike', 'Defend', 'Stand Firm', 'Strike', //
];
const List<String> strikesOnly = <String>['Strike', 'Strike', 'Strike'];

void main() {
  setUpAll(loadAppFonts);

  group('Classes (Amendment v0.3 §2)', () {
    testWidgets('a hero with no class chooses one, and nothing earned moves',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: saturday,
        withHistory: true,
        heroClass: null,
      );
      await app.settle(tester);
      expect(find.text('CHOOSE YOUR CLASS'), findsOneWidget);
      expect(app.game.heroClass, isNull);
      final before = app.game.hero!;
      final companion = app.game.companion!;

      // Herald is held in the data and not offered.
      expect(find.text('Herald'), findsNothing);
      await tester.tap(find.text('Sage'));
      await tester.pumpAndSettle();
      await tester.tap(primary('Become a Sage'));
      await app.settle(tester);

      expect(find.text('CHOOSE YOUR CLASS'), findsNothing);
      expect(app.game.heroClass, HeroClass.sage);
      final after = app.game.hero!;
      expect(after.totalXp, before.totalXp);
      expect(after.level, before.level);
      expect(after.gold, before.gold);
      expect(after.materials, before.materials);
      expect(after.attributeXp, before.attributeXp);
      expect(app.game.companion!.totalXp, companion.totalXp);
      expect(app.game.companion!.bond, companion.bond);
    });

    testWidgets('at the weekly Campfire the class can be changed for nothing, '
        'and XP and levels stay', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app =
          await TestApp.start(tester, now: sundayEvening, withHistory: true);
      expect(app.game.respecOpen, isTrue);
      final before = app.game.hero!;
      final companion = app.game.companion!;

      await reveal(tester, roundButton('Open the Campfire'));
      await tester.tap(roundButton('Open the Campfire'));
      await tester.pumpAndSettle();
      await reveal(tester, quiet('Change'));
      await tester.tap(quiet('Change'));
      await tester.pumpAndSettle();
      expect(find.text('CHANGE YOUR CLASS'), findsOneWidget);
      await tester.tap(find.text('Artificer'));
      await tester.pumpAndSettle();
      await tester.tap(primary('Become an Artificer'));
      await app.settle(tester);

      expect(app.game.heroClass, HeroClass.artificer);
      final after = app.game.hero!;
      expect(after.totalXp, before.totalXp);
      expect(after.level, before.level);
      expect(after.attributeXp, before.attributeXp);
      expect(after.gold, before.gold);
      expect(app.game.companion!.level, companion.level);
      expect(app.game.companion!.totalXp, companion.totalXp);
      expect(app.game.companion!.bond, companion.bond);
    });

    testWidgets('on any other day the Campfire does not offer it',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      expect(app.game.respecOpen, isFalse);
    });
  });

  group('Today’s encounter (Amendment v0.3 §§3, 5)', () {
    testWidgets('the board names it, the scout reports, a good plan wakes '
        'it, and the chest comes home', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final vault = MemoryVault(chosen: true);
      final app = await TestApp.start(tester, now: saturday, vault: vault);
      expect(app.game.enemyToday.key, 'old_yawnstone');
      expect(app.game.encounterStatus, EncounterStatus.ready);
      expect(
        find.text('Today’s encounter: an Old Yawnstone (Brute)'),
        findsOneWidget,
      );
      expect(app.game.resourceNow, baseResource, reason: 'no quests yet');

      await meet(tester, app);
      await play(tester, app, winningLine);
      expect(find.text('The Old Yawnstone wakes'), findsOneWidget);
      expect(find.text('+8 gold'), findsOneWidget);
      expect(find.text('+2 Timber'), findsOneWidget);
      await tester.tap(primary('Back to the board'));
      await app.settle(tester);

      final record = app.game.encounterToday!;
      expect(record.won, isTrue);
      expect(record.attempts, 1);
      expect(record.turns, 5);
      expect(record.classId, 'warden');
      expect(app.game.encounterStatus, EncounterStatus.won);
      expect(app.game.hero!.gold, 8);
      expect(app.game.materials[MaterialKind.timber], 2);
      expect(app.game.hero!.totalXp, 10);
      expect(app.game.companion!.totalXp, 10);
      expect(app.game.pouch[ItemKind.smoke], 1);
      expect(app.game.bossState.marks, 1);
      expect(
        find.text('The Old Yawnstone woke. The road is clear'),
        findsOneWidget,
      );

      // The day's note carries it (Amendment v0.3 §6).
      await tester.runAsync(() => app.game.exportNow());
      expect(
        vault.files['Daily/2026-11-14.md'],
        contains('## Encounter\n\n- Creature: Old Yawnstone (Brute)\n'
            '- Result: woke it in 5 turns\n- Class: Warden\n'),
      );
    });

    testWidgets('when the creature holds, nothing earned is touched; any '
        'quest brings a Salve and another try', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      // Something to have, so there is something that could be taken.
      final check = app.game.quests
          .firstWhere((q) => q.name == 'Morning Health Check');
      await tester.runAsync(() async {
        await app.repo.completeQuest(check.id);
        await app.game.refresh();
      });
      await tester.pumpAndSettle();
      final hero = app.game.hero!.toJson();
      final companion = app.game.companion!.toJson();
      final world = app.game.world!.toJson();
      expect(app.game.hero!.totalXp, greaterThan(0));

      // Ignoring its wind-up: three strikes, and the big blow lands.
      await meet(tester, app);
      await play(tester, app, strikesOnly);
      expect(find.text('The Old Yawnstone held'), findsOneWidget);
      // The words are about the fight and what to try, nothing else.
      expect(find.textContaining('Finish any quest for a Salve'), findsOneWidget);
      await tester.tap(primary('Back to the board'));
      await app.settle(tester);

      expect(app.game.hero!.toJson(), hero);
      expect(app.game.companion!.toJson(), companion);
      expect(app.game.world!.toJson(), world);
      expect(app.game.encounterToday!.won, isFalse);
      expect(app.game.encounterStatus, EncounterStatus.holding);
      expect(app.game.pouch, isEmpty);
      expect(app.game.bossState.marks, 0);

      // Any quest opens another try, with a Salve for it.
      final walk = app.game.quests.firstWhere((q) => q.name == 'Walk Babs');
      await tester.runAsync(() async {
        await app.repo.completeQuest(walk.id);
        await app.game.refresh();
      });
      await tester.pumpAndSettle();
      expect(app.game.encounterStatus, EncounterStatus.retry);
      expect(app.game.pouch[ItemKind.salve], 1);
      expect(find.text('Try again'), findsOneWidget);

      await meet(tester, app);
      await play(tester, app, winningLine);
      expect(find.text('The Old Yawnstone wakes'), findsOneWidget);
      await tester.tap(primary('Back to the board'));
      await app.settle(tester);
      expect(app.game.encounterToday!.won, isTrue);
      expect(app.game.encounterToday!.attempts, 2);
      expect(app.game.pouch[ItemKind.salve], 1, reason: 'not used');
    });

    testWidgets('tomorrow there is a new creature, whatever happened today',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await meet(tester, app);
      await play(tester, app, strikesOnly);
      await tester.tap(primary('Back to the board'));
      await app.settle(tester);
      expect(app.game.encounterStatus, EncounterStatus.holding);

      app.now = DateTime(2026, 11, 15, 8, 0);
      await tester.runAsync(() => app.game.refresh());
      await tester.pumpAndSettle();
      expect(app.game.enemyToday.key, 'hushmoths');
      expect(app.game.encounterStatus, EncounterStatus.ready);
    });
  });

  group('The weekly boss (Amendment v0.3 §5)', () {
    testWidgets('an attempt that does not finish it still wears it down, '
        'for good, and takes nothing', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app =
          await TestApp.start(tester, now: sundayEvening, withHistory: true);
      await tester.runAsync(() async {
        await app.game.closeDay(note: '');
        await app.game.refresh();
      });
      await tester.pumpAndSettle();
      expect(app.game.delve, isNotNull);
      final hero = app.game.hero!.toJson();
      final companion = app.game.companion!.toJson();

      final setup = app.game.bossSetup()!;
      expect(setup.boss, isTrue);
      expect(setup.bossHp, isNull, reason: 'not met yet');
      final fight = Fight(setup);
      final full = fight.enemyMax;
      // Seven turns of plain strikes.
      while (!fight.over) {
        fight.act(CombatAction.strike, companion: fight.companionReady);
      }
      expect(fight.outcome, FightOutcome.held);
      final left = fight.enemyHp;
      expect(left, lessThan(full));
      expect(left, greaterThan(0));

      final outcome = (await tester.runAsync(
        () => app.game.finishBoss(fight, spentMarks: false),
      ))!;
      await tester.pumpAndSettle();
      expect(outcome.woken, isFalse);
      expect(outcome.left, left);
      expect(app.game.bossState.hpLeft, left);
      expect(app.game.bossState.boss.key, 'long_doze');
      expect(app.game.delve, isNull, reason: 'one attempt a week');
      expect(app.game.hero!.toJson(), hero);
      expect(app.game.companion!.toJson(), companion);

      // A week on, it is exactly as it was left.
      app.now = DateTime(2026, 11, 22, 20, 30);
      await tester.runAsync(() async {
        await app.game.refresh();
        await app.game.closeDay(note: '');
        await app.game.refresh();
      });
      await tester.pumpAndSettle();
      final again = app.game.bossSetup()!;
      expect(again.bossHp, left);
      final second = Fight(again);
      expect(second.enemyHp, left);
      expect(second.enemyMax, greaterThanOrEqualTo(left));
    });
  });
}
