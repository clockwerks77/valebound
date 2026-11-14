import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/state/game_controller.dart';
import 'package:habit_adventure/ui/board/quest_actions.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';

// 0.5.0: Health Connect read again while the app stays open, and the
// narrator who tells the player where they are.

/// 2026-11-14 is a Saturday.
final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

Finder primary(String label) => find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.label == label,
    );

Finder quiet(String label) => find.byWidgetPredicate(
      (w) => w is QuietButton && w.label == label,
    );

Finder completeButton(String questName) => find.byWidgetPredicate(
      (w) => w is CompleteButton && w.label == 'Complete $questName',
    );

/// Sets what the hero has gathered, as if earned on earlier days.
Future<void> gather(
  WidgetTester tester,
  TestApp app, {
  required int timber,
  required int stone,
  required int shards,
}) async {
  await tester.runAsync(() async {
    final hero = (await app.repo.hero())!;
    await (app.db.update(app.db.characters)
          ..where((c) => c.id.equals(hero.id)))
        .write(
      CharactersCompanion(
        materials: Value(
          encodeMaterials(<MaterialKind, int>{
            MaterialKind.timber: timber,
            MaterialKind.stone: stone,
            MaterialKind.starShard: shards,
          }),
        ),
      ),
    );
    await app.game.refresh();
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('Health Connect while the app stays open (DECISIONS D-74)', () {
    testWidgets('steps walked with the app open arrive within a few minutes',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(
        steps: StepsAccess.connected,
        stepCount: 3120,
      );
      final app = await TestApp.start(tester, now: saturday, device: device);
      expect(app.game.stepsToday, 3120);
      expect(app.game.doneQuests, isEmpty);

      // A walk, with the app left open on the table.
      device.stepCount = 7420;
      app.now = saturday.add(const Duration(minutes: 3));
      await tester.pump(GameController.healthRefreshEvery);
      await app.settle(tester);

      expect(app.game.stepsToday, 7420);
      expect(app.game.doneQuests.single.quest.name, '7,000 Steps');
    });

    testWidgets('glucose readings that arrive meanwhile move the average',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(
        glucose: StepsAccess.connected,
        glucoseToday: const GlucoseSpan(average: 7.44, readings: 212),
      );
      final app = await TestApp.start(tester, now: saturday, device: device);
      expect(app.game.glucoseAverageToday!.value, '7.4');

      device.glucoseToday = const GlucoseSpan(average: 6.91, readings: 215);
      await tester.pump(GameController.healthRefreshEvery);
      await app.settle(tester);

      expect(app.game.glucoseAverageToday!.value, '6.9');
      expect(app.game.glucoseToday!.readings, 215);
    });

    testWidgets('opening the Health Log reads at once', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(
        glucose: StepsAccess.connected,
        glucoseToday: const GlucoseSpan(average: 7.44, readings: 212),
      );
      final app = await TestApp.start(tester, now: saturday, device: device);

      device.glucoseToday = const GlucoseSpan(average: 6.12, readings: 214);
      await tester.tap(roundButton('Health Log'));
      await app.settle(tester);

      expect(
        find.text(
          'Average glucose today: 6.1 mmol/L, from 214 readings in Health '
          'Connect.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('nothing is asked while the app is out of sight',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(
        steps: StepsAccess.connected,
        stepCount: 900,
      );
      final app = await TestApp.start(tester, now: saturday, device: device);
      final atLaunch = device.stepReads;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await app.settle(tester);
      device.stepCount = 1500;
      await tester.pump(const Duration(minutes: 20));
      await app.settle(tester);
      expect(device.stepReads, atLaunch, reason: 'no reads while away');
      expect(app.game.stepsToday, 900);

      // Back in front: read at once, and the few-minute rhythm starts over.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await app.settle(tester);
      expect(app.game.stepsToday, 1500);
      final afterReturn = device.stepReads;
      device.stepCount = 1800;
      await tester.pump(GameController.healthRefreshEvery);
      await app.settle(tester);
      expect(device.stepReads, greaterThan(afterReturn));
      expect(app.game.stepsToday, 1800);
    });

    testWidgets('with nothing connected, the timer reads nothing',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(stepCount: 5000);
      final app = await TestApp.start(tester, now: saturday, device: device);

      await tester.pump(const Duration(minutes: 10));
      await app.settle(tester);
      expect(device.stepReads, 0);
      expect(app.game.stepsToday, isNull);
    });

    testWidgets('midnight with the app open turns the day over',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(
        steps: StepsAccess.connected,
        stepCount: 6100,
        stepCountYesterday: 6400,
      );
      final app = await TestApp.start(tester, now: saturday, device: device);
      expect(app.game.day, '2026-11-14');

      app.now = DateTime(2026, 11, 15, 0, 2);
      device.stepCount = 12;
      await tester.pump(GameController.healthRefreshEvery);
      await app.settle(tester);

      expect(app.game.day, '2026-11-15');
      expect(app.game.stepsToday, 12);
    });
  });

  group('The prologue (DECISIONS D-76)', () {
    testWidgets('is told on the first run, one page at a time, then the tour',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: saturday,
        prologue: true,
        tour: true,
      );
      await app.settle(tester);
      expect(find.text('PROLOGUE'), findsOneWidget);
      expect(
        find.text('You come over the last hill at first light, and Babs is '
            'already ahead of you.'),
        findsOneWidget,
      );
      expect(find.text('Welcome to the Vale'), findsNothing);
      expect(app.game.settings.prologueSeen, isFalse);

      await tester.tap(primary('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Below lies the Vale. It should be full of lantern light. '
            'It is grey, and very quiet.'),
        findsOneWidget,
      );
      await tester.tap(primary('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('One lantern still burns, at the gate.'), findsOneWidget);
      await tester.tap(primary('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(primary('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Begin at the gate.'), findsOneWidget);
      expect(quiet('Skip'), findsOneWidget);

      // The last page opens Chapter One.
      await tester.tap(primary('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('CHAPTER ONE'), findsOneWidget);
      expect(find.text('Hearthmere'), findsOneWidget);
      expect(quiet('Skip'), findsNothing);
      await tester.tap(primary('Begin'));
      await app.settle(tester);

      expect(find.text('PROLOGUE'), findsNothing);
      expect(app.game.settings.prologueSeen, isTrue);
      // And only then the tour of the board.
      expect(find.text('Welcome to the Vale'), findsOneWidget);
    });

    testWidgets('can be skipped, and is not told twice', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, prologue: true);
      await app.settle(tester);
      expect(find.text('PROLOGUE'), findsOneWidget);
      await tester.tap(quiet('Skip'));
      await app.settle(tester);
      expect(find.text('PROLOGUE'), findsNothing);
      expect(app.game.settings.prologueSeen, isTrue);
      expect(find.text('Welcome to the Vale'), findsNothing);

      // Coming back to the app does not start it again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await app.settle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await app.settle(tester);
      expect(find.text('PROLOGUE'), findsNothing);
    });

    testWidgets('someone already in the Vale is told it once, without the tour',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      // A party with two weeks behind it, opening the build that has a
      // narrator for the first time.
      final app = await TestApp.start(
        tester,
        now: saturday,
        withHistory: true,
        prologue: true,
      );
      await app.settle(tester);
      expect(find.text('PROLOGUE'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.tap(primary('Continue'));
        await tester.pumpAndSettle();
      }
      await tester.tap(primary('Begin'));
      await app.settle(tester);
      expect(find.text('Welcome to the Vale'), findsNothing);
      expect(app.game.settings.prologueSeen, isTrue);
      expect(app.game.settings.tourDone, isTrue);
    });

    testWidgets('the Chronicle can tell it again', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tester.tap(find.text(app.game.narration.line));
      await tester.pumpAndSettle();
      await reveal(tester, quiet('Read the prologue again'));
      await tester.tap(quiet('Read the prologue again'));
      await tester.pumpAndSettle();
      expect(find.text('PROLOGUE'), findsOneWidget);
      await tester.tap(quiet('Skip'));
      await app.settle(tester);
      expect(find.text('PROLOGUE'), findsNothing);
      expect(find.text('WHERE THINGS STAND'), findsOneWidget);
    });
  });

  group('The narrator on the board and at the Campfire (DECISIONS D-76)', () {
    testWidgets('says when and where it is, and what is waiting',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      // A new arrival: nothing awake, camp at the village gate.
      expect(app.game.narration.setting, 'Morning in Hearthmere');
      expect(find.textContaining('MORNING IN HEARTHMERE · 0 OF'), findsOneWidget);
      expect(
        find.text('Every door is shut. The Gate Lantern burns low, and waits.'),
        findsOneWidget,
      );
    });

    testWidgets('turns with the clock', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: DateTime(2026, 11, 14, 18, 40),
      );
      expect(app.game.narration.setting, 'Evening in Hearthmere');
      expect(find.textContaining('EVENING IN HEARTHMERE'), findsOneWidget);
    });

    testWidgets('names what woke last and what is next', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      // Enough for the Gate Lantern, and no more.
      await gather(tester, app, timber: 2, stone: 1, shards: 0);
      expect(app.game.restored, 1);
      expect(
        find.text('The Gate Lantern is burning. The well is waiting.'),
        findsOneWidget,
      );
    });

    testWidgets('after days away it says only that the Vale has kept',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      app.now = DateTime(2026, 11, 18, 8, 5);
      await tester.runAsync(() => app.game.refresh());
      await tester.pumpAndSettle();
      expect(app.game.comebackQuest, isNotNull);
      expect(
        find.textContaining('The Vale has kept, just as you left it.'),
        findsOneWidget,
      );
    });

    testWidgets('the Campfire is closed in the narrator’s words',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      expect(
        app.game.campfireStory,
        'The fire is lit all the same. The Vale keeps, and so does the '
        'road. It is quiet in the Vale tonight, the good kind of quiet.',
      );
      await tester.runAsync(() async {
        final check = app.game.quests
            .firstWhere((q) => q.name == 'Morning Health Check');
        await app.repo.completeQuest(check.id);
        await app.game.refresh();
      });
      await tester.pumpAndSettle();
      expect(
        app.game.campfireStory,
        startsWith('One quest done, and the fire is warm.'),
      );

      await reveal(tester, find.text('Campfire Review'));
      await tester.tap(find.text('Campfire Review'));
      await app.settle(tester);
      expect(find.text(app.game.campfireStory), findsOneWidget);
    });
  });

  group('Chapters (DECISIONS D-76)', () {
    testWidgets('the last place of a region closes its chapter and opens '
        'the next', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      // One Timber short of the Moot Hall, the last place in Hearthmere.
      await gather(tester, app, timber: 14, stone: 14, shards: 4);
      expect(app.game.restored, 3);
      expect(app.game.storyTitle, 'Chapter One · Hearthmere');

      await reveal(tester, completeButton('Morning Health Check'));
      await tester.tap(completeButton('Morning Health Check'));
      await app.settle(tester);

      // First the place wakes...
      expect(find.text('The Moot Hall'), findsWidgets);
      await tester.tap(find.text('The Vale wakes'));
      await app.settle(tester);
      // ...then its chapter closes...
      expect(find.text('CHAPTER ONE'), findsOneWidget);
      expect(find.text('Hearthmere wakes'), findsOneWidget);
      expect(find.textContaining('Hearthmere is awake.'), findsOneWidget);
      await tester.tap(primary('Continue'));
      await tester.pumpAndSettle();
      // ...and the next one opens.
      expect(find.text('CHAPTER TWO'), findsOneWidget);
      expect(find.text('Larkdown'), findsOneWidget);
      await tester.tap(primary('Onward'));
      await app.settle(tester);

      expect(find.text('CHAPTER TWO'), findsNothing);
      expect(app.game.restored, 4);
      expect(app.game.storyTitle, 'Chapter Two · Larkdown');
    });

    testWidgets('a place in the middle of a region wakes without one',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      // One Timber short of the Gate Lantern.
      await gather(tester, app, timber: 1, stone: 1, shards: 0);
      await reveal(tester, completeButton('Morning Health Check'));
      await tester.tap(completeButton('Morning Health Check'));
      await app.settle(tester);
      expect(find.text('The Gate Lantern'), findsWidgets);
      await tester.tap(find.text('The Vale wakes'));
      await app.settle(tester);
      expect(find.text('CHAPTER ONE'), findsNothing);
      expect(app.game.restored, 1);
    });
  });

  group('The Chronicle (DECISIONS D-76)', () {
    testWidgets('opens from the storyteller’s line and reads back the story',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await gather(tester, app, timber: 4, stone: 5, shards: 1);
      expect(app.game.restored, 2);

      await tester.tap(find.text(app.game.narration.line));
      await tester.pumpAndSettle();
      expect(find.text('Chronicle'), findsOneWidget);
      expect(find.text('Chapter One · Hearthmere'), findsOneWidget);
      expect(find.text('WHERE THINGS STAND'), findsOneWidget);
      expect(find.text(app.game.narration.full), findsOneWidget);
      expect(
        find.text('2 of the Vale’s 20 places are awake, and 2 villagers '
            'are home.'),
        findsOneWidget,
      );
      expect(
        find.text('Chapter One · Hearthmere: 2 of 4 places awake.'),
        findsOneWidget,
      );
      expect(find.text('Camp is at the village gate, in Hearthmere.'),
          findsOneWidget);

      await reveal(tester, find.text('THE STORY SO FAR'));
      await reveal(tester, find.text('The last hill'));
      expect(find.text('The last hill'), findsOneWidget);
      await reveal(tester, find.text('The Village Well'));
      expect(
        find.text('Clear water rises again, and Marla draws the first '
            'bucket. Marla the well-keeper has come home.'),
        findsOneWidget,
      );

      await tester.tap(roundButton('Close the Chronicle'));
      await tester.pumpAndSettle();
      expect(find.text('WHERE THINGS STAND'), findsNothing);
    });

    testWidgets('opens from the Map as well', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday);
      await tester.tap(find.text('Map').last);
      await tester.pumpAndSettle();
      expect(find.text('Chapter One · Hearthmere'), findsOneWidget);
      await tester.tap(roundButton('Chronicle'));
      await tester.pumpAndSettle();
      expect(find.text('WHERE THINGS STAND'), findsOneWidget);
      expect(
        find.text('The whole Vale is asleep: 20 places, waiting.'),
        findsOneWidget,
      );
    });

    testWidgets('on the opened Fold the story sits beside where things stand',
        (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      final app = await TestApp.start(tester, now: saturday);
      await gather(tester, app, timber: 4, stone: 5, shards: 1);
      await tester.tap(find.text(app.game.narration.line));
      await tester.pumpAndSettle();
      final crease = TestDevice.foldOpen.size.width / 2;
      expect(
        tester.getRect(find.text('WHERE THINGS STAND')).right,
        lessThan(crease),
      );
      expect(
        tester.getRect(find.text('THE STORY SO FAR')).left,
        greaterThan(crease),
      );
    });
  });
}
