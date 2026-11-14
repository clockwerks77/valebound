import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/device/device_port.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';
import 'screens_golden_test.dart' show expectCreaseClear, screenTest, shot;

// What came after the first run on the Fold, at the cover-screen and
// opened-Fold sizes: the tour's bubbles, the day's Still creature, and the
// glucose average. The opened-Fold run also asserts that no bubble's
// buttons sit on the crease.

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder primary(String label) => find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.label == label,
    );

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

/// Walks the whole tour, taking a picture of the bubbles worth seeing.
Future<void> tour(WidgetTester tester, TestDevice device, String suffix) async {
  useDevice(tester, device);
  final open = device.crease;
  final app = await TestApp.start(
    tester,
    now: saturday,
    withHistory: true,
    tour: true,
  );
  await app.settle(tester);
  expect(find.text('Welcome to the Vale'), findsOneWidget);
  await shot(tester, '80_tour_welcome_$suffix');
  if (open) expectCreaseClear(tester, device);

  const pictured = <int, String>{
    2: '90_tour_story',
    3: '81_tour_party',
    6: '82_tour_sleeper',
    7: '83_tour_quest',
    9: '84_tour_campfire',
    12: '85_tour_nav',
  };
  await tester.tap(primary('Show me'));
  await tester.pumpAndSettle();
  for (var step = 2; step <= 12; step++) {
    expect(find.text('$step OF 12'), findsOneWidget);
    if (open) expectCreaseClear(tester, device);
    final name = pictured[step];
    if (name != null) await shot(tester, '${name}_$suffix');
    await tester.tap(primary(step == 12 ? 'Done' : 'Next'));
    await tester.pumpAndSettle();
  }
  await app.settle(tester);
  expect(app.game.settings.tourDone, isTrue);
}

void main() {
  setUpAll(loadAppFonts);
  // Screenshots show the paintings.
  setUpAll(() => TestApp.largeArt = true);

  screenTest('The tour on the cover screen', (tester) async {
    await tour(tester, TestDevice.foldCover, 'cover');
  });

  screenTest('The tour on the opened Fold', (tester) async {
    await tour(tester, TestDevice.foldOpen, 'open');
  });

  screenTest('The day’s creature awake, and glucose from Health Connect',
      (tester) async {
    useDevice(tester, TestDevice.foldCover);
    final device = MemoryDevice(
      stepCount: 4630,
      glucoseToday: const GlucoseSpan(average: 7.44, readings: 212),
    );
    final app = await TestApp.start(
      tester,
      now: saturday,
      withHistory: true,
      device: device,
    );
    await tester.runAsync(() async {
      await app.game.connectSteps();
      await app.game.connectGlucose();
      // The morning's two quests are done; a third wakes the creature.
      final play = app.game.quests
          .firstWhere((q) => q.name == 'Play / Train with Babs');
      await app.repo.completeQuest(play.id);
      await app.game.refresh();
    });
    await app.settle(tester);
    expect(app.game.dailyStillToday!.still.awake, isTrue);
    await shot(tester, '86_board_creature_awake_cover');

    await tester.tap(roundButton('Health Log'));
    // Opening the log reads Health Connect again.
    await app.settle(tester);
    await shot(tester, '87_health_log_glucose_cover');
    await tester.tap(roundButton('Close the Health Log'));
    await tester.pumpAndSettle();

    await tester.tap(roundButton('Settings'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('GLUCOSE'));
    await shot(tester, '88_settings_glucose_cover');
  });

  screenTest('A screen’s one-time hint', (tester) async {
    useDevice(tester, TestDevice.foldCover);
    final app = await TestApp.start(
      tester,
      now: saturday,
      withHistory: true,
      hints: true,
    );
    await app.settle(tester);
    await tester.tap(find.text('Map').last);
    await app.settle(tester);
    expect(primary('Got it'), findsOneWidget);
    await shot(tester, '89_hint_map_cover');
  });
}
