import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/ui/board/quest_actions.dart';
import 'package:habit_adventure/ui/onboarding/onboarding_screen.dart';
import 'package:habit_adventure/ui/shell/app_shell.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder completeButton(String questName) => find.byWidgetPredicate(
      (w) => w is CompleteButton && w.label == 'Complete $questName',
    );

/// A companion kind in the onboarding grid (labels break at spaces).
Finder kindChoice(CompanionKind kind) =>
    find.text(kind.label.replaceAll(' ', '\n'));

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

void main() {
  setUpAll(loadAppFonts);

  group('Onboarding (DESIGN §7A.1)', () {
    testWidgets('offers every kind, free naming and the Babs preset',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: saturday,
        withProfile: false,
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Adam');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // All six kinds in the roster.
      for (final kind in CompanionKind.values) {
        expect(kindChoice(kind), findsOneWidget, reason: kind.label);
      }
      expect(
        find.text('Small, kind, easy-to-drop goals live with your companion. '
            'They level up beside you, on their own track.'),
        findsOneWidget,
      );

      // Free naming with any kind.
      await tester.ensureVisible(kindChoice(CompanionKind.owl));
      await tester.tap(kindChoice(CompanionKind.owl));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Moss');
      await tester.pumpAndSettle();
      expect(find.textContaining('Quiet and night-wise'), findsOneWidget);

      // The one-tap preset overrides it.
      await tester.ensureVisible(find.text('A hound named Babs'));
      await tester.tap(find.text('A hound named Babs'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Babs',
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Add Five-Minute Reset'), findsOneWidget);
      await tester.tap(find.text('Begin at Dawn'));
      await app.settle(tester);

      expect(find.byType(AppShell), findsOneWidget);
      expect(app.game.hero!.name, 'Adam');
      expect(app.game.companion!.name, 'Babs');
      expect(app.game.companion!.kind, CompanionKind.hound);
      await reveal(tester, find.text('With Babs'));
      expect(find.text('With Babs'), findsOneWidget);
    });

    testWidgets('a different kind and name are kept', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: saturday,
        withProfile: false,
      );
      await tester.enterText(find.byType(TextField).first, 'Robin');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(kindChoice(CompanionKind.clockworkSprite));
      await tester.tap(kindChoice(CompanionKind.clockworkSprite));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Tock');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Begin at Dawn'));
      await app.settle(tester);
      expect(app.game.companion!.kind, CompanionKind.clockworkSprite);
      expect(app.game.companion!.name, 'Tock');
      await reveal(tester, find.text('With Tock'));
      expect(find.text('With Tock'), findsOneWidget);
    });
  });

  group('Completing quests on the board', () {
    testWidgets('Tap: Walk Babs awards the Shared split', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await reveal(tester, completeButton('Walk Babs'));
      await tester.tap(completeButton('Walk Babs'));
      await app.settle(tester);

      expect(app.game.companion!.totalXp, 25);
      expect(app.game.hero!.totalXp, 13);
      expect(app.game.companion!.bond, 1);
      expect(app.game.world!.journeyPaces, 1);
      expect(app.game.doneQuests.map((b) => b.quest.name), <String>['Walk Babs']);
      expect(completeButton('Walk Babs'), findsNothing);
    });

    testWidgets('Count: steps up and completes at the target', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, withHistory: true);
      final before = app.game.hero!.totalXp;
      final plus = roundButton('One more for Glasses of water');
      await reveal(tester, plus);
      expect(find.text('3 / 8'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(plus);
        await app.settle(tester);
      }
      expect(find.text('7 / 8'), findsOneWidget);
      expect(app.game.hero!.totalXp, before);
      await tester.tap(plus);
      await app.settle(tester);
      expect(app.game.hero!.totalXp, before + 10);
      expect(
        app.game.doneQuests.map((b) => b.quest.name),
        contains('Glasses of water'),
      );
    });

    testWidgets('Timer: runs, then completes itself at the target',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      final play = roundButton('Start Play / Train with Babs');
      await reveal(tester, play);
      await tester.tap(play);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(roundButton('Pause Play / Train with Babs'), findsOneWidget);
      expect(app.game.companion!.totalXp, 0);

      // Ten minutes later the next tick sees the target reached.
      app.now = app.now.add(const Duration(minutes: 10, seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(app.game.companion!.totalXp, 10);
      expect(
        app.game.doneQuests.map((b) => b.quest.name),
        contains('Play / Train with Babs'),
      );
    });
  });

  group('Quest creator (DESIGN §6.3)', () {
    testWidgets('a new quest takes a name, one tap and save', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tester.tap(find.text('Quest'));
      await tester.pumpAndSettle();
      expect(find.text('New quest'), findsOneWidget);
      // The track picker and its one-sentence explanation are right there.
      expect(find.text('Shared'), findsOneWidget);
      expect(
        find.text('Small, kind, easy-to-drop goals live with your companion.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, 'Read a chapter');
      await tester.tap(find.text('Mind'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add quest'));
      await app.settle(tester);

      final quest =
          app.game.quests.firstWhere((q) => q.name == 'Read a chapter');
      expect(quest.attribute, Attribute.mind);
      expect(quest.difficulty, Difficulty.standard);
      expect(quest.track, Track.hero, reason: 'Hero is the default track');
      expect(quest.completionType, CompletionType.tap);
      expect(app.game.nowQuests.map((b) => b.quest.name), contains('Read a chapter'));
    });

    testWidgets('the track picker moves a quest to the companion',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await tester.tap(find.text('Quest'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Water the fern');
      await tester.tap(find.text('Care'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Babs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add quest'));
      await app.settle(tester);

      final quest =
          app.game.quests.firstWhere((q) => q.name == 'Water the fern');
      expect(quest.track, Track.companion);
      expect(
        app.game.companionQuests.map((b) => b.quest.name),
        contains('Water the fern'),
      );
    });
  });

  group('Navigation', () {
    testWidgets('compact uses bottom navigation: Board, Map, Character, Log',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday);
      for (final label in <String>['Board', 'Map', 'Character', 'Log']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Character'));
      await tester.pumpAndSettle();
      expect(find.text('HERO'), findsOneWidget);
      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();
      expect(find.text('Quest Log'), findsOneWidget);
    });

    testWidgets('one column under 600dp, two panes at 600dp and up',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday);
      expect(find.text('THE VALE'), findsNothing);
      expect(tester.getSize(find.byType(ListView).first).width, 416);
    });
  });
}
