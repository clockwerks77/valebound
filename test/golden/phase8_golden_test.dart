import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/rules/first_dawn.dart';

import '../support/first_dawn_run.dart';
import '../support/harness.dart';
import 'screens_golden_test.dart' show expectCreaseClear, screenTest, shot;

// Version 0.8: every chapter of First Dawn on the cover screen and on the
// opened Fold, one screenshot a screen, and the board it ends on.

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

/// Screens with enough controls on them for the crease check to mean
/// something.
const Set<String> creaseChecked = <String>{
  'c1_story_domains',
  'c3_habit_track',
  'c5_class_quiz',
  'c5_class_recommended',
  'c6_calendar_series',
};

Future<void> walk(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final app = await TestApp.start(
    tester,
    now: saturday,
    device: FirstDawnRun.device(),
    firstDawn: null,
    heroClass: null,
  );
  await app.settle(tester);
  var n = 130;
  final run = FirstDawnRun(
    tester,
    app,
    at: (name) async {
      await shot(tester, '${n}_${name}_$suffix');
      n++;
      if (device.crease && creaseChecked.contains(name)) {
        expectCreaseClear(tester, device);
      }
    },
  );
  await run.storyGoalsHabits();
  await run.rhythmAndClass(become: 'Become a Warden');
  await run.calendar();
  await run.firstWeek();
  await app.settle(tester);

  expect(app.game.firstDawnState, FirstDawnState.done);
  expect(app.game.heroClass, HeroClass.warden);
  expect(find.text('Walk for 20 minutes'), findsOneWidget);
  await shot(tester, '${n}_board_after_first_dawn_$suffix');
}

void main() {
  setUpAll(loadAppFonts);
  // Screenshots show the paintings.
  setUpAll(() => TestApp.largeArt = true);

  screenTest('First Dawn, every chapter, on the cover screen', (tester) async {
    await walk(tester, TestDevice.foldCover, 'cover');
  });

  screenTest('First Dawn, every chapter, on the opened Fold', (tester) async {
    await walk(tester, TestDevice.foldOpen, 'open');
  });
}
