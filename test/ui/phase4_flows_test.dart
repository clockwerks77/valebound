import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/daily_still.dart';
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
}
