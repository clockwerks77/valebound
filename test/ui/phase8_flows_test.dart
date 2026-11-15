import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/rules/checkin.dart';
import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/first_dawn.dart';
import 'package:habit_adventure/rules/goals.dart';
import 'package:habit_adventure/ui/board/quest_actions.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/first_dawn_run.dart';
import '../support/harness.dart';

// Amendment v0.4 through the screens: First Dawn from the first chapter to
// the board, skipping it, meeting it as a hero who already has a board,
// sizes on a quest card, the Sunday Check-In, and a goal added later.

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder primary(String label) => FirstDawnRun.primary(label);
Finder quiet(String label) => FirstDawnRun.quiet(label);

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

Finder completeButton(String title) => find.byWidgetPredicate(
      (w) => w is CompleteButton && w.label == 'Complete $title',
    );

FirstDawnDraft oneHabit(String habit, {String goal = 'Finish my army'}) =>
    FirstDawnDraft(
      goals: <GoalDraft>[
        GoalDraft(
          domain: LifeDomain.making,
          text: goal,
          plans: <PlanDraft>[PlanDraft(habit: habit, anchor: 'After dinner')],
        ),
      ],
    );

void main() {
  setUpAll(loadAppFonts);

  group('First Dawn (Amendment v0.4 §3)', () {
    testWidgets('a new hero walks all seven chapters and comes out on a board '
        'made from the answers', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: saturday,
        device: FirstDawnRun.device(),
        firstDawn: null,
        heroClass: null,
      );
      await app.settle(tester);
      final run = FirstDawnRun(tester, app);
      await run.storyGoalsHabits();

      // Left now, everything said so far is kept.
      final kept = FirstDawnDraft.decode(app.game.settings.firstDawnDraft);
      expect(kept.goals.map((g) => g.title), <String>[
        'Feel stronger',
        'Finish my army',
      ]);
      expect(kept.goals[0].why, 'Stairs without thinking about them');
      expect(kept.goals[0].plans.single.habit, 'Walk for 20 minutes');
      expect(kept.confirmed, containsAll(<int>[1, 2, 3]));
      expect(app.game.goals, isEmpty, reason: 'not data until the end');

      await run.rhythmAndClass(become: 'Become a Warden');
      await run.calendar();
      await run.firstWeek();
      await app.settle(tester);

      final game = app.game;
      expect(game.firstDawnState, FirstDawnState.done);
      expect(find.text('CHOOSE YOUR CLASS'), findsNothing);
      expect(game.heroClass, HeroClass.warden);
      expect(game.settings.classScore!.recommended, HeroClass.warden);
      expect(game.goals.map((g) => g.text), <String>[
        'Feel stronger',
        'Finish my army',
      ]);
      expect(game.goals[0].horizon, Horizon.season);
      expect(game.goals[0].check, 'I take the stairs');
      expect(game.plans.map((p) => p.target), <String>[
        'Walk for 20 minutes',
        'Paint for 30 minutes',
      ]);
      final paint = game.plans[1];
      expect(paint.frequency, PlanFrequency.weekly);
      expect(paint.weekdays, <int>{6});
      expect(paint.anchor, 'After dinner');
      expect(game.settings.rhythm.restDays, <int>{7});
      expect(game.settings.rhythm.peak, DayWindow.morning);
      expect(game.settings.rhythm.sprints, isFalse);

      // The calendar was asked for in its chapter, and mapped.
      expect(game.settings.calendarOn, isTrue);
      final mappings = game.settings.mappings;
      expect(mappings.map((m) => m.kind), <MappingKind>[
        MappingKind.craft,
        MappingKind.health,
      ]);
      expect(mappings[0].planId, paint.id);
      expect(mappings[1].planId, isNull);

      // The board: the habits, each saying what it is for; the starter
      // quests have stepped back.
      expect(find.text('Walk for 20 minutes'), findsOneWidget);
      expect(find.text('For: Feel stronger · at lunch'), findsOneWidget);
      expect(find.text('Morning Health Check'), findsNothing);
      for (final b in game.board) {
        final line = game.lineFor(b.quest.id)!;
        expect(line.forLine, startsWith('For: '));
        expect(line.kind, anyOf(SourceKind.habit, SourceKind.system));
      }

      // Tuesday has "Painting night" on the calendar, which is the painting
      // habit: one quest, though the habit's own day is Saturday.
      app.now = DateTime(2026, 11, 17, 9);
      await tester.runAsync(() => game.refresh(fromDevice: true));
      await tester.pumpAndSettle();
      final painting = <BoardQuest>[
        for (final b in game.board)
          if (b.quest.planId == paint.id ||
              b.quest.source == QuestSource.calendar)
            b,
      ];
      expect(painting, hasLength(1));
      expect(
        game.lineFor(painting.single.quest.id)!.forLine,
        startsWith('For: Finish my army · on your calendar'),
      );
    });

    testWidgets('skipping every chapter still lands on a working starter '
        'board', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: saturday,
        firstDawn: null,
        heroClass: null,
      );
      await app.settle(tester);
      expect(find.text('FIRST DAWN · CHAPTER 1 OF 7'), findsOneWidget);

      Future<void> skip() async {
        await tester.tap(quiet('Skip chapter'));
        await app.settle(tester);
      }

      Future<void> next(String label) async {
        await tester.tap(primary(label));
        await app.settle(tester);
      }

      await skip(); // Your Story
      // With nothing chosen, Goals and Habit Design are only their mirrors.
      expect(find.text('FIRST DAWN · CHAPTER 2 OF 7'), findsOneWidget);
      await next('That’s right');
      expect(find.text('FIRST DAWN · CHAPTER 3 OF 7'), findsOneWidget);
      await next('That’s right');
      await skip(); // Your Rhythm
      await skip(); // Class & Companion
      expect(find.text('FIRST DAWN · CHAPTER 6 OF 7'), findsOneWidget);
      await skip(); // Calendar
      expect(find.text('Your first week'), findsOneWidget);
      await next('Next');
      await next('Next');
      expect(find.text('The first camp'), findsOneWidget);
      await next('Begin');

      // No class was chosen on the way, so that one question is asked.
      expect(find.text('CHOOSE YOUR CLASS'), findsOneWidget);
      await next('Become a Ranger');

      final game = app.game;
      expect(game.firstDawnState, FirstDawnState.done);
      expect(game.goals, isEmpty);
      expect(game.board, isNotEmpty);
      expect(find.text('Morning Health Check'), findsOneWidget);
      expect(find.text('For: you · not pinned to a goal yet'), findsWidgets);
      for (final b in game.board) {
        expect(game.lineFor(b.quest.id)!.forLine, startsWith('For: '));
      }
      // And it plays.
      await reveal(tester, completeButton('Walk Babs'));
      await tester.tap(completeButton('Walk Babs'));
      await app.settle(tester);
      expect(game.doneQuests.map((b) => b.quest.name), <String>['Walk Babs']);
    });

    testWidgets('left part way, it waits on the board and resumes where it '
        'stopped', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, firstDawn: null);
      await app.settle(tester);
      await tester.tap(find.text('Body & Health'));
      await app.settle(tester);
      await tester.tap(primary('Next'));
      await app.settle(tester);
      expect(find.textContaining('what would better look like?'), findsOneWidget);
      await tester.tap(roundButton('Leave for now'));
      await app.settle(tester);

      expect(app.game.firstDawnState, FirstDawnState.begun);
      expect(find.text('Tell Valebound your goals'), findsOneWidget);
      expect(find.textContaining('You stopped part way'), findsOneWidget);
      await tester.tap(primary('Carry on'));
      await app.settle(tester);
      expect(find.textContaining('what would better look like?'), findsOneWidget);
    });
  });

  group('A hero from before First Dawn (Amendment v0.4 §3, migration)', () {
    testWidgets('is offered it on the board; "Later" leaves it in Settings',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: saturday,
        firstDawn: FirstDawnState.offered,
      );
      expect(find.text('Tell Valebound your goals'), findsOneWidget);
      expect(find.text('FIRST DAWN · CHAPTER 1 OF 7'), findsNothing);
      await tester.tap(quiet('Later'));
      await app.settle(tester);
      expect(find.text('Tell Valebound your goals'), findsNothing);
      expect(app.game.firstDawnState, FirstDawnState.later);

      await tester.tap(roundButton('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Tell Valebound your goals'), findsOneWidget);
      expect(primary('Begin'), findsOneWidget);
    });

    testWidgets('their quests arrive in the review unpinned: pin, keep or '
        'archive, and nothing is deleted', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: saturday,
        firstDawn: FirstDawnState.offered,
      );
      final before = app.game.quests.length;
      await tester.tap(primary('Begin'));
      await app.settle(tester);

      Future<void> tap(Finder f) async {
        await tester.ensureVisible(f);
        await tester.tap(f);
        await app.settle(tester);
      }

      await tap(find.text('Home & Family'));
      await tap(primary('Next'));
      await tester.enterText(
        FirstDawnRun.field('why.0'),
        'More unhurried evenings',
      );
      await tester.pumpAndSettle();
      await tap(primary('Next'));
      await tap(primary('That’s right'));
      for (var chapter = 2; chapter <= 6; chapter++) {
        await tap(quiet('Skip chapter'));
      }
      expect(find.text('Your first week'), findsOneWidget);
      await tap(primary('Next'));

      expect(find.text('The quests you already have'), findsOneWidget);
      expect(find.text('Walk Babs'), findsOneWidget);
      final walk = app.game.quests.firstWhere((q) => q.name == 'Walk Babs');
      final steps = app.game.quests.firstWhere((q) => q.name == '7,000 Steps');
      final wasActive = <String>{
        for (final q in app.game.quests)
          if (q.active) q.id,
      };
      // One card a quest, in the Quest Log's order; the list builds them as
      // they scroll into reach.
      Finder pill(String quest, String label) => find.descendant(
            of: find
                .ancestor(of: find.text(quest), matching: find.byType(Column))
                .first,
            matching: find.text(label),
          );
      await tap(pill('Walk Babs', 'For: More unhurried evenings'));
      await reveal(tester, find.text('7,000 Steps'));
      await tap(pill('7,000 Steps', 'Archive'));
      await tap(primary('Next'));
      await tap(primary('Next'));
      await tap(primary('Begin'));

      final game = app.game;
      expect(game.firstDawnState, FirstDawnState.done);
      expect(game.quests.length, before, reason: 'nothing deleted, none added');
      final goal = game.goals.single;
      expect(goal.text, 'More unhurried evenings');
      expect(game.quests.firstWhere((q) => q.id == walk.id).goalId, goal.id);
      expect(game.quests.firstWhere((q) => q.id == steps.id).active, isFalse);
      for (final q in game.quests) {
        if (q.id != steps.id) {
          expect(q.active, wasActive.contains(q.id), reason: q.name);
        }
      }
      expect(find.text('Tell Valebound your goals'), findsNothing);
      await reveal(tester, find.text('For: More unhurried evenings'));
      expect(find.text('For: More unhurried evenings'), findsOneWidget);
      expect(find.text('For: you · not pinned to a goal yet'), findsWidgets);
    });
  });

  group('Sizes on the board (Amendment v0.4 §4)', () {
    testWidgets('one tap cycles the size; Tiny is worth Minor XP and the '
        'quest is done in full', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tester.runAsync(
        () => app.game.finishFirstDawn(oneHabit('Paint for 30 minutes')),
      );
      await tester.pumpAndSettle();
      final quest = app.game.board
          .firstWhere((b) => b.quest.planId != null)
          .quest;
      final chip = find.byKey(ValueKey<String>('size-${quest.id}'));
      await reveal(tester, chip);
      expect(find.text('Paint for 30 minutes'), findsOneWidget);
      expect(find.text('TARGET'), findsOneWidget);
      expect(find.text('Craft · Standard'), findsOneWidget);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('STRETCH'), findsOneWidget);
      expect(find.text('Paint for 45 minutes'), findsOneWidget);
      // The starter board's own craft block is Heroic too.
      expect(find.text('Craft · Heroic'), findsWidgets);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('TINY'), findsOneWidget);
      expect(find.text('Paint for 5 minutes'), findsOneWidget);
      expect(find.text('Craft · Minor'), findsOneWidget);
      expect(find.text('+10 XP'), findsWidgets);

      final xp = app.game.hero!.totalXp;
      await tester.tap(completeButton('Paint for 5 minutes'));
      await app.settle(tester);
      expect(app.game.hero!.totalXp, xp + Difficulty.minor.xp);
      final done = app.game.doneQuests.single;
      expect(done.quest.id, quest.id);
      expect(sizeOf(done.completion!), QuestSize.tiny);
      expect(app.game.titleFor(done), 'Paint for 5 minutes');
    });
  });

  group('The Sunday Check-In (Amendment v0.4 §6)', () {
    testWidgets('two questions at the Campfire, one proposal, and "no" is '
        'final', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: DateTime(2026, 11, 9, 9));
      await tester.runAsync(() async {
        await app.game.finishFirstDawn(oneHabit('Paint for 30 minutes'));
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
      expect(find.text('This week’s quests felt…'), findsOneWidget);
      expect(
        find.text('Paint for 30 minutes: 3 Tiny · 0 Target · 0 Stretch'),
        findsOneWidget,
      );

      await tester.tap(find.text('About right'));
      await app.settle(tester);
      expect(find.text('This week felt: about right.'), findsOneWidget);
      expect(
        find.textContaining('Shrink the Target to 20 minutes?'),
        findsOneWidget,
      );
      expect(app.game.plans.single.target, 'Paint for 30 minutes');

      await tester.ensureVisible(quiet('No, leave it'));
      await tester.tap(quiet('No, leave it'));
      await app.settle(tester);
      expect(
        find.text('Left as it is. That suggestion will not come up again.'),
        findsOneWidget,
      );
      expect(app.game.plans.single.target, 'Paint for 30 minutes');
      expect(app.game.settings.checkIns.declined, hasLength(1));
      expect(app.game.settings.checkIns.feltOn('2026-11-15'), Felt.right);
    });
  });

  group('A goal added later (Amendment v0.4 §7)', () {
    testWidgets('Settings: New goal runs the short flow and the board gains '
        'its quest', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tester.tap(roundButton('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('No goals yet. The board is the starter quests.'),
          findsOneWidget);
      await tester.tap(primary('New goal'));
      await app.settle(tester);

      Future<void> tap(Finder f) async {
        await tester.ensureVisible(f);
        await tester.tap(f);
        await app.settle(tester);
      }

      expect(find.text('Which part of life is this goal for?'), findsOneWidget);
      await tap(find.text('Mind & Learning'));
      await tap(primary('Next'));
      await tap(find.text('Read more'));
      await tap(primary('Next'));
      await tester.enterText(FirstDawnRun.field('why.0'), 'Fewer screens');
      await tester.pumpAndSettle();
      await tap(primary('Next'));
      await tap(find.text('Read for 20 minutes'));
      await tap(primary('Next'));
      await tap(find.text('Before bed'));
      await tap(primary('Next')); // anchor
      await tap(primary('Next')); // how often
      await tap(primary('Next')); // size
      await tap(primary('Next')); // track
      await tap(primary('Next')); // dread
      expect(find.text('Its first week'), findsOneWidget);
      await tap(primary('Raise the banner'));

      final game = app.game;
      expect(game.goals.single.text, 'Read more');
      expect(game.goals.single.why, 'Fewer screens');
      expect(game.plans.single.target, 'Read for 20 minutes');
      expect(game.plans.single.tiny, 'Read one page');
      expect(game.plans.single.window, DayWindow.evening);
      // Back in Settings, the goal is listed.
      expect(find.text('Read more'), findsOneWidget);
      // The starter quests of someone who already had a board stay.
      expect(game.quests.any((q) => q.name == 'Walk Babs' && q.active), isTrue);
      expect(
        game.board.map(game.titleFor),
        contains('Read for 20 minutes'),
      );
    });
  });
}
