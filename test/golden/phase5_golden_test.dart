import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/narrator.dart';
import 'package:habit_adventure/ui/adaptive.dart';
import 'package:habit_adventure/ui/shell/app_shell.dart';
import 'package:habit_adventure/ui/story/story.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';
import 'screens_golden_test.dart' show expectCreaseClear, screenTest, shot;

// The narrator, at the cover-screen and opened-Fold sizes: the prologue, a
// chapter closing and the next one opening, and the Chronicle. The opened
// Fold runs also assert that the words and the buttons keep to one side of
// the crease.

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder primary(String label) => find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.label == label,
    );

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

/// A story page has only a button or two, so the crease is checked for the
/// words as well as the controls.
void expectStoryClearOfCrease(WidgetTester tester, TestDevice device) {
  final centre = device.size.width / 2;
  final keepOut = Rect.fromLTRB(
    centre - creasePadding + 0.5,
    0,
    centre + creasePadding - 0.5,
    device.size.height,
  );
  var checked = 0;
  for (final finder in <Finder>[
    find.byType(PrimaryButton),
    find.byType(QuietButton),
    find.byType(Text),
  ]) {
    for (final element in finder.evaluate()) {
      final box = element.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      checked++;
      expect(
        rect.overlaps(keepOut),
        isFalse,
        reason: '${element.widget} at $rect sits on the crease ($keepOut)',
      );
    }
  }
  expect(checked, greaterThan(2), reason: 'crease check found the page');
}

Future<void> prologue(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final open = device.crease;
  final app = await TestApp.start(
    tester,
    now: saturday,
    withHistory: true,
    prologue: true,
  );
  await app.settle(tester);
  expect(find.text('PROLOGUE'), findsOneWidget);
  if (open) expectStoryClearOfCrease(tester, device);
  await shot(tester, '91_prologue_hill_$suffix');

  await tester.tap(primary('Continue'));
  await tester.pumpAndSettle();
  if (open) expectStoryClearOfCrease(tester, device);
  await shot(tester, '92_prologue_vale_$suffix');

  await tester.tap(primary('Continue'));
  await tester.pumpAndSettle();
  await shot(tester, '93_prologue_lantern_$suffix');

  for (var i = 0; i < 2; i++) {
    await tester.tap(primary('Continue'));
    await tester.pumpAndSettle();
    if (open) expectStoryClearOfCrease(tester, device);
  }
  await shot(tester, '94_prologue_road_$suffix');

  await tester.tap(primary('Continue'));
  await tester.pumpAndSettle();
  expect(find.text('CHAPTER ONE'), findsOneWidget);
  if (open) expectStoryClearOfCrease(tester, device);
  await shot(tester, '95_prologue_chapter_one_$suffix');

  await tester.tap(primary('Begin'));
  await app.settle(tester);
  expect(app.game.settings.prologueSeen, isTrue);
}

Future<void> chapterTurn(
  WidgetTester tester,
  TestDevice device,
  String suffix,
) async {
  useDevice(tester, device);
  final open = device.crease;
  final app = await TestApp.start(tester, now: saturday, withHistory: true);
  final context = tester.element(find.byType(AppShell));
  showChapterTurn(context, chapters.first);
  await tester.pumpAndSettle();
  expect(find.text('Hearthmere wakes'), findsOneWidget);
  if (open) expectStoryClearOfCrease(tester, device);
  await shot(tester, '96_chapter_wakes_$suffix');

  await tester.tap(primary('Continue'));
  await tester.pumpAndSettle();
  expect(find.text('CHAPTER TWO'), findsOneWidget);
  if (open) expectStoryClearOfCrease(tester, device);
  await shot(tester, '97_chapter_opens_$suffix');
  await tester.tap(primary('Onward'));
  await app.settle(tester);
}

void main() {
  setUpAll(loadAppFonts);

  screenTest('The prologue on the cover screen', (tester) async {
    await prologue(tester, TestDevice.foldCover, 'cover');
  });

  screenTest('The prologue on the opened Fold', (tester) async {
    await prologue(tester, TestDevice.foldOpen, 'open');
  });

  screenTest('A chapter turns on the cover screen', (tester) async {
    await chapterTurn(tester, TestDevice.foldCover, 'cover');
  });

  screenTest('A chapter turns on the opened Fold', (tester) async {
    await chapterTurn(tester, TestDevice.foldOpen, 'open');
  });

  screenTest('The last chapter closes with the Vale awake', (tester) async {
    useDevice(tester, TestDevice.foldCover);
    final app = await TestApp.start(tester, now: saturday, withHistory: true);
    final context = tester.element(find.byType(AppShell));
    showChapterTurn(context, chapters.last);
    await tester.pumpAndSettle();
    expect(find.text('The Vale wakes'), findsOneWidget);
    expect(primary('Continue'), findsNothing, reason: 'one page, no next');
    await shot(tester, '98_vale_awake_cover');
    await tester.tap(primary('The Vale is awake'));
    await app.settle(tester);
  });

  screenTest('The sky over the board keeps the hours', (tester) async {
    for (final (hour, name) in <(int, String)>[
      (14, 'afternoon'),
      (19, 'evening'),
      (23, 'night'),
    ]) {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(
        tester,
        now: DateTime(2026, 11, 14, hour, 20),
        withHistory: true,
      );
      expect(
        app.game.narration.setting.toLowerCase(),
        startsWith(name),
      );
      await shot(tester, '100_board_${name}_cover');
      // Start again from nothing for the next hour.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => app.db.close());
    }
  });

  screenTest('The Chronicle on the cover screen', (tester) async {
    useDevice(tester, TestDevice.foldCover);
    final app = await TestApp.start(tester, now: saturday, withHistory: true);
    await tester.tap(find.text(app.game.narration.line));
    await tester.pumpAndSettle();
    expect(find.text('WHERE THINGS STAND'), findsOneWidget);
    await shot(tester, '99_chronicle_cover');
    await tester.drag(find.byType(ListView).first, const Offset(0, -470));
    await tester.pumpAndSettle();
    await shot(tester, '99b_chronicle_story_cover');
    await tester.tap(roundButton('Close the Chronicle'));
    await tester.pumpAndSettle();
  });

  screenTest('The Chronicle on the opened Fold', (tester) async {
    useDevice(tester, TestDevice.foldOpen);
    final app = await TestApp.start(tester, now: saturday, withHistory: true);
    await tester.tap(find.text(app.game.narration.line));
    await tester.pumpAndSettle();
    expect(find.text('WHERE THINGS STAND'), findsOneWidget);
    expectCreaseClear(tester, TestDevice.foldOpen);
    await shot(tester, '99_chronicle_open');
  });
}
