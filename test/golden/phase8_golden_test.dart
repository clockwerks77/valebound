import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/rules/first_dawn.dart';
import 'package:habit_adventure/rules/goals.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

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

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

FirstDawnDraft paintingHabit() => FirstDawnDraft(
      goals: <GoalDraft>[
        GoalDraft(
          domain: LifeDomain.making,
          text: 'Finish my army',
          why: 'A painted army on the table',
          plans: <PlanDraft>[
            PlanDraft(habit: 'Paint for 30 minutes', anchor: 'After dinner'),
          ],
        ),
      ],
    );

/// A hero from before 0.8: the offer on the board, and their own quests in
/// Chapter 7's review.
Future<void> existingHero(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final app = await TestApp.start(
    tester,
    now: saturday,
    firstDawn: FirstDawnState.offered,
  );
  await reveal(tester, find.text('Tell Valebound your goals'));
  await shot(tester, '165_offer_on_board_$suffix');

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await app.settle(tester);
  }

  await tap(FirstDawnRun.primary('Begin'));
  await tap(find.text('Home & Family'));
  await tap(FirstDawnRun.primary('Next'));
  await tester.enterText(
    FirstDawnRun.field('why.0'),
    'More unhurried evenings',
  );
  await tester.pumpAndSettle();
  await tap(FirstDawnRun.primary('Next'));
  await tap(FirstDawnRun.primary('That’s right'));
  for (var chapter = 2; chapter <= 6; chapter++) {
    await tap(FirstDawnRun.quiet('Skip chapter'));
  }
  await tap(FirstDawnRun.primary('Next'));
  expect(find.text('The quests you already have'), findsOneWidget);
  await shot(tester, '166_existing_quests_review_$suffix');
}

/// The Sunday Check-In at the Campfire: the question, then the one
/// proposal.
Future<void> checkIn(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final app = await TestApp.start(tester, now: DateTime(2026, 11, 9, 9));
  await tester.runAsync(() async {
    await app.game.finishFirstDawn(paintingHabit());
    final id = app.game.plans.single.questId!;
    for (final day in <int>[9, 10, 11]) {
      app.now = DateTime(2026, 11, day, 10);
      await app.game.refresh();
      await app.repo.completeQuest(id, size: QuestSize.tiny);
    }
    app.now = DateTime(2026, 11, 15, 20);
    await app.game.refresh();
  });
  await tester.pumpAndSettle();
  await reveal(tester, roundButton('Open the Campfire'));
  await tester.tap(roundButton('Open the Campfire'));
  await app.settle(tester);
  await reveal(tester, find.text('This week’s quests felt…'));
  await shot(tester, '167_checkin_$suffix');
  await tester.tap(find.text('About right'));
  await app.settle(tester);
  // The whole card: what was said, the counts, the proposal, its answers.
  await Scrollable.ensureVisible(
    tester.element(find.text('THE WEEK')),
    alignment: 0.05,
  );
  await tester.pumpAndSettle();
  expect(FirstDawnRun.quiet('No, leave it'), findsOneWidget);
  await shot(tester, '168_checkin_proposal_$suffix');
}

/// Goals & habits in Settings, once there is a goal.
Future<void> goalsInSettings(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final app = await TestApp.start(tester, now: saturday);
  await tester.runAsync(() => app.game.finishFirstDawn(paintingHabit()));
  await tester.pumpAndSettle();
  await tester.tap(
    device == TestDevice.foldOpen
        ? find.text('Settings')
        : roundButton('Settings'),
  );
  await tester.pumpAndSettle();
  expect(find.text('Goals & habits'), findsOneWidget);
  expect(find.text('Finish my army'), findsOneWidget);
  await shot(tester, '169_settings_goals_$suffix');
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

  for (final (device, suffix) in <(TestDevice, String)>[
    (TestDevice.foldCover, 'cover'),
    (TestDevice.foldOpen, 'open'),
  ]) {
    screenTest('A hero from before 0.8 is offered First Dawn ($suffix)',
        (tester) async {
      await existingHero(tester, device, suffix);
    });
    screenTest('The Sunday Check-In at the Campfire ($suffix)', (tester) async {
      await checkIn(tester, device, suffix);
    });
    screenTest('Goals & habits in Settings ($suffix)', (tester) async {
      await goalsInSettings(tester, device, suffix);
    });
  }
}
