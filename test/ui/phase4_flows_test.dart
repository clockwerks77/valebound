import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/rules/daily_still.dart';
import 'package:habit_adventure/rules/health_fields.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';

// What came after the first run on the Fold: the day's Still creature, the
// glucose average from Health Connect, and the tour.

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

/// Finishes a quest straight in storage and lets the screen catch up.
Future<void> finish(WidgetTester tester, TestApp app, String name) async {
  final quest = app.game.quests.firstWhere((q) => q.name == name);
  await tester.runAsync(() async {
    await app.repo.completeQuest(quest.id);
    await app.game.refresh();
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('The day’s Still creature (DECISIONS D-70)', () {
    testWidgets('dozes on the board, stirs with each quest, wakes on the third',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      final creature = dailyStillFor('2026-11-14');
      final dozing = find.text('A ${creature.name} dozes by The Gate Lantern');
      expect(dozing, findsOneWidget);
      expect(app.game.dailyStillToday!.still.stirs, 0);

      await finish(tester, app, 'Morning Health Check');
      await finish(tester, app, '7,000 Steps');
      expect(app.game.dailyStillToday!.still.stirs, 2);
      expect(app.game.dailyStillToday!.still.awake, isFalse);
      expect(dozing, findsOneWidget);

      await finish(tester, app, 'Walk Babs');
      expect(app.game.dailyStillToday!.still.awake, isTrue);
      expect(dozing, findsNothing);
      expect(
        find.text('The ${creature.name} woke: +$dailyStillGold gold, +1 Timber'),
        findsOneWidget,
      );
    });

    testWidgets('the Campfire names it once it has woken', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      final creature = dailyStillFor('2026-11-14');
      await finish(tester, app, 'Morning Health Check');
      await finish(tester, app, '7,000 Steps');
      await finish(tester, app, 'Walk Babs');

      await reveal(tester, roundButton('Open the Campfire'));
      await tester.tap(roundButton('Open the Campfire'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Woke: the ${creature.name}.'));
      expect(find.text('Woke: the ${creature.name}.'), findsOneWidget);
    });
  });

  group('Glucose from Health Connect (DECISIONS D-71)', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(roundButton('Settings'));
      await tester.pumpAndSettle();
    }

    testWidgets('connected in Settings, the day’s average shows as a number',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(
        glucoseToday: const GlucoseSpan(average: 7.44, readings: 212),
      );
      final app = await TestApp.start(tester, now: saturday, device: device);
      // Nothing is read until it is turned on.
      expect(app.game.glucoseConnected, isFalse);
      expect(app.game.glucoseAverageToday, isNull);

      await openSettings(tester);
      await reveal(tester, find.text('Glucose is not connected'));
      await reveal(tester, primary('Connect glucose'));
      await tester.tap(primary('Connect glucose'));
      await app.settle(tester);

      expect(app.game.glucoseConnected, isTrue);
      expect(app.game.glucoseAverageToday!.value, '7.4');
      expect(app.game.glucoseAverageToday!.unit, glucoseAverageUnit);
      await reveal(tester, find.text('Today’s average: 7.4 mmol/L'));
      expect(find.text('Today’s average: 7.4 mmol/L'), findsOneWidget);
      expect(quiet('Disconnect glucose'), findsOneWidget);

      // The Health Log shows the same figure, read only.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(roundButton('Health Log'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Average glucose today: 7.4 mmol/L, from 212 readings in Health '
          'Connect.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('refused, nothing is read and nothing is kept', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(
        grantGlucose: false,
        glucoseToday: const GlucoseSpan(average: 7.44, readings: 212),
      );
      final app = await TestApp.start(tester, now: saturday, device: device);
      await openSettings(tester);
      await reveal(tester, primary('Connect glucose'));
      await tester.tap(primary('Connect glucose'));
      await app.settle(tester);
      expect(app.game.glucoseConnected, isFalse);
      expect(app.game.glucoseAverageToday, isNull);
      expect(find.text('Glucose is not connected'), findsOneWidget);
    });

    testWidgets('connected with no readings yet, it says so and keeps nothing',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice();
      final app = await TestApp.start(tester, now: saturday, device: device);
      await tester.runAsync(() => app.game.connectGlucose());
      await tester.pumpAndSettle();
      expect(app.game.glucoseConnected, isTrue);
      expect(app.game.glucoseAverageToday, isNull);

      await tester.tap(roundButton('Health Log'));
      await tester.pumpAndSettle();
      expect(
        find.text('Average glucose: nothing from Health Connect yet today.'),
        findsOneWidget,
      );
    });

    testWidgets('disconnecting stops the reading and keeps what was written',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(
        glucoseToday: const GlucoseSpan(average: 6.02, readings: 40),
      );
      final app = await TestApp.start(tester, now: saturday, device: device);
      await tester.runAsync(() => app.game.connectGlucose());
      await tester.pumpAndSettle();
      expect(app.game.glucoseAverageToday!.value, '6.0');

      device.glucoseToday = const GlucoseSpan(average: 9.5, readings: 80);
      await tester.runAsync(() => app.game.disconnectGlucose());
      await tester.pumpAndSettle();
      expect(app.game.glucoseConnected, isFalse);
      // What was already in the Health Log is the user's, and stays.
      expect(app.game.glucoseAverageToday!.value, '6.0');
    });

    testWidgets('yesterday’s whole-day figures are written back next morning',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final device = MemoryDevice(
        steps: StepsAccess.connected,
        glucose: StepsAccess.connected,
        stepCount: 310,
        stepCountYesterday: 8340,
        glucoseToday: const GlucoseSpan(average: 6.8, readings: 30),
        glucoseYesterday: const GlucoseSpan(average: 7.26, readings: 288),
      );
      // A party that was in the Vale yesterday too.
      final app = await TestApp.start(
        tester,
        now: saturday,
        withHistory: true,
        device: device,
      );
      await tester.runAsync(() async {
        await app.game.connectSteps();
        await app.game.connectGlucose();
      });
      await tester.pumpAndSettle();

      final friday = (await tester.runAsync(
        () => app.repo.healthEntriesByKey('2026-11-13'),
      ))!;
      expect(friday[stepsFieldKey]!.value, '8340');
      expect(friday[glucoseAverageFieldKey]!.value, '7.3');
      expect(app.game.stepsToday, 310);
      expect(app.game.glucoseAverageToday!.value, '6.8');
    });
  });

  group('The tour (DECISIONS D-72)', () {
    const titles = <String>[
      'You and Babs',
      'A place to wake',
      'The road',
      'Today’s sleeper',
      'A quest',
      'With Babs',
      'The Campfire',
      'Anything else',
      'Health Log and Settings',
      'Getting around',
    ];

    testWidgets('on the first run it walks the board, one bubble at a time',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, tour: true);
      await app.settle(tester);
      expect(find.text('Welcome to the Vale'), findsOneWidget);
      expect(find.text('1 OF 11'), findsOneWidget);
      expect(app.game.settings.tourDone, isFalse);

      await tester.tap(primary('Show me'));
      await tester.pumpAndSettle();
      for (var i = 0; i < titles.length; i++) {
        expect(find.text('${i + 2} OF 11'), findsOneWidget, reason: titles[i]);
        expect(find.text(titles[i]), findsWidgets, reason: titles[i]);
        final last = i == titles.length - 1;
        expect(quiet('Back'), findsOneWidget);
        expect(quiet('Skip the tour'), last ? findsNothing : findsOneWidget);
        await tester.tap(primary(last ? 'Done' : 'Next'));
        await tester.pumpAndSettle();
      }
      await app.settle(tester);
      expect(find.text('Getting around'), findsNothing);
      expect(app.game.settings.tourDone, isTrue);
    });

    testWidgets('Back returns to the bubble before', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, tour: true);
      await app.settle(tester);
      await tester.tap(primary('Show me'));
      await tester.pumpAndSettle();
      // On to the Campfire, well down the board, then back up it.
      for (var i = 0; i < 6; i++) {
        await tester.tap(primary('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('8 OF 11'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.tap(quiet('Back'));
        await tester.pumpAndSettle();
      }
      expect(find.text('2 OF 11'), findsOneWidget);
      expect(find.text('You and Babs'), findsOneWidget);
    });

    testWidgets('it can be left at once, and does not come back',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, tour: true);
      await app.settle(tester);
      await tester.tap(quiet('Skip the tour'));
      await app.settle(tester);
      expect(find.text('Welcome to the Vale'), findsNothing);
      expect(app.game.settings.tourDone, isTrue);

      // The board underneath is untouched and usable.
      await finish(tester, app, 'Morning Health Check');
      expect(app.game.doneQuests.length, 1);
      expect(find.text('Welcome to the Vale'), findsNothing);
    });

    testWidgets('nothing underneath can be pressed while a bubble is up',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, tour: true);
      await app.settle(tester);
      // The Settings button sits top right, under the dimmed screen.
      final settings = tester.getCenter(roundButton('Settings'));
      await tester.tapAt(settings);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Welcome to the Vale'), findsOneWidget);
      expect(app.game.settings.tourDone, isFalse);
    });

    testWidgets('a quest that is not on the board today is passed over',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, tour: true);
      await app.settle(tester);
      // Everything of the hero's is done, so "Now" is empty.
      for (final b in List.of(app.game.nowQuests)) {
        await tester.runAsync(() => app.repo.completeQuest(b.quest.id));
      }
      await tester.runAsync(() => app.game.refresh());
      await tester.pumpAndSettle();
      expect(app.game.nowQuests, isEmpty);

      await tester.tap(primary('Show me'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(primary('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Today’s sleeper'), findsOneWidget);
      await tester.tap(primary('Next'));
      await tester.pumpAndSettle();
      // Straight on to the companion: there is no quest card to point at.
      expect(find.text('A quest'), findsNothing);
      expect(find.text('7 OF 11'), findsOneWidget);
    });

    testWidgets('Settings can show it again', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await app.settle(tester);
      expect(find.text('Welcome to the Vale'), findsNothing);

      await tester.tap(roundButton('Settings'));
      await tester.pumpAndSettle();
      await reveal(tester, quiet('Show the tour again'));
      await tester.tap(quiet('Show the tour again'));
      await app.settle(tester);
      expect(find.text('Welcome to the Vale'), findsOneWidget);
      expect(app.game.settings.hintsSeen, isEmpty);
    });

    testWidgets('each other screen explains itself once', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, hints: true);
      await app.settle(tester);

      await tester.tap(find.text('Map').last);
      await app.settle(tester);
      expect(primary('Got it'), findsOneWidget);
      expect(find.text('The Vale'), findsWidgets);
      expect(primary('Next'), findsNothing, reason: 'one bubble, no tour');
      await tester.tap(primary('Got it'));
      await app.settle(tester);
      expect(primary('Got it'), findsNothing);
      expect(app.game.settings.hintsSeen, contains('map'));

      // Coming back to it later says nothing.
      await tester.tap(find.text('Board').last);
      await app.settle(tester);
      await tester.tap(find.text('Map').last);
      await app.settle(tester);
      expect(primary('Got it'), findsNothing);

      await tester.tap(find.text('Log').last);
      await app.settle(tester);
      expect(primary('Got it'), findsOneWidget);
      expect(find.text('The Quest Log'), findsWidgets);
      await tester.tap(primary('Got it'));
      await app.settle(tester);
      expect(app.game.settings.hintsSeen, containsAll(<String>['map', 'log']));
    });
  });
}
