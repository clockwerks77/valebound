import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/ui/board/board_screen.dart' show encounterLine;
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';
import 'screens_golden_test.dart' show expectCreaseClear, screenTest, shot;

// Version 0.7 on the cover screen and the opened Fold: choosing a class,
// the scout's report, a fight in progress (with the crease check), both
// ways it can end, and the class on the Party Sheet.

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder primary(String label) => find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.label == label,
    );

Future<void> classChoice(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final app = await TestApp.start(
    tester,
    now: saturday,
    withHistory: true,
    heroClass: null,
  );
  await app.settle(tester);
  expect(find.text('CHOOSE YOUR CLASS'), findsOneWidget);
  await shot(tester, '110_class_choice_$suffix');
  await tester.tap(find.text('Warden'));
  await tester.pumpAndSettle();
  await shot(tester, '111_class_choice_warden_$suffix');
  await tester.tap(primary('Become a Warden'));
  await app.settle(tester);
}

Future<void> encounter(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final open = device.crease;
  final app = await TestApp.start(tester, now: saturday);
  await shot(tester, '112_board_encounter_$suffix');
  final line = find.text(encounterLine(app.game));
  await reveal(tester, line);
  await tester.tap(line);
  await tester.pumpAndSettle();
  await shot(tester, '113_scout_$suffix');

  await tester.tap(primary('Meet it'));
  await tester.pumpAndSettle();
  await shot(tester, '114_fight_first_turn_$suffix');
  if (open) expectCreaseClear(tester, device);
  for (final move in <String>['Strike', 'Strike']) {
    await tester.tap(find.text(move));
    await app.settle(tester);
  }
  // Turn three: the Brute's big blow is due.
  await shot(tester, '115_fight_big_blow_due_$suffix');
  if (open) expectCreaseClear(tester, device);
  for (final move in <String>['Defend', 'Stand Firm', 'Strike']) {
    await tester.tap(find.text(move));
    await app.settle(tester);
  }
  expect(find.text('The Old Yawnstone wakes'), findsOneWidget);
  await shot(tester, '116_fight_won_$suffix');
  await tester.tap(primary('Back to the board'));
  await app.settle(tester);
  await shot(tester, '117_board_after_win_$suffix');
}

void main() {
  setUpAll(loadAppFonts);
  // Screenshots show the paintings.
  setUpAll(() => TestApp.largeArt = true);

  screenTest('Choosing a class on the cover screen', (tester) async {
    await classChoice(tester, TestDevice.foldCover, 'cover');
  });

  screenTest('Choosing a class on the opened Fold', (tester) async {
    await classChoice(tester, TestDevice.foldOpen, 'open');
  });

  screenTest('An encounter on the cover screen', (tester) async {
    await encounter(tester, TestDevice.foldCover, 'cover');
  });

  screenTest('An encounter on the opened Fold', (tester) async {
    await encounter(tester, TestDevice.foldOpen, 'open');
  });

  screenTest('When the creature holds', (tester) async {
    useDevice(tester, TestDevice.foldCover);
    final app = await TestApp.start(tester, now: saturday);
    final line = find.text(encounterLine(app.game));
    await reveal(tester, line);
    await tester.tap(line);
    await tester.pumpAndSettle();
    await tester.tap(primary('Meet it'));
    await tester.pumpAndSettle();
    for (final move in <String>['Strike', 'Strike', 'Strike']) {
      await tester.tap(find.text(move));
      await app.settle(tester);
    }
    expect(find.text('The Old Yawnstone held'), findsOneWidget);
    await shot(tester, '118_fight_held_cover');
    await tester.tap(primary('Back to the board'));
    await app.settle(tester);
    await shot(tester, '119_board_holding_cover');
  });

  screenTest('The class on the Party Sheet', (tester) async {
    useDevice(tester, TestDevice.foldCover);
    final app = await TestApp.start(tester, now: saturday, withHistory: true);
    await tester.tap(find.text('Character'));
    await app.settle(tester);
    await tester.scrollUntilVisible(
      find.text('HOW TO PLAY IT'),
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pumpAndSettle();
    await shot(tester, '120_party_class_cover');
  });
}
