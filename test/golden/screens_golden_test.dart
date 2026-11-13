import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/journey.dart';
import 'package:habit_adventure/ui/adaptive.dart';
import 'package:habit_adventure/ui/board/quest_actions.dart';
import 'package:habit_adventure/ui/celebrations.dart';
import 'package:habit_adventure/ui/shell/app_shell.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';

// Renders the Phase 1 screens at the cover-screen and opened-Fold sizes and
// writes them to test/golden/goldens/. CI publishes those PNGs as the phase
// screenshots. The same runs assert that nothing critical sits on the crease.

/// Saturday morning: the weekly and weekend quests are on the board.
final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Future<void> shot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// DESIGN §9.1: never place a primary action, XP bar or dialog button on the
/// display crease. Checks every tappable control, XP bar and text field.
void expectCreaseClear(WidgetTester tester, TestDevice device) {
  final centre = device.size.width / 2;
  final keepOut = Rect.fromLTRB(
    centre - creasePadding + 0.5,
    0,
    centre + creasePadding - 0.5,
    device.size.height,
  );
  var checked = 0;
  for (final finder in <Finder>[
    find.byType(InkWell),
    find.byType(XpBar),
    find.byType(TextField),
    find.byType(CompleteButton),
    find.byType(RoundIconButton),
    find.byType(PrimaryButton),
    find.byType(QuietButton),
  ]) {
    for (final element in finder.evaluate()) {
      final box = element.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      // Only what is actually on screen.
      if (rect.bottom < 0 || rect.top > device.size.height) continue;
      checked++;
      expect(
        rect.overlaps(keepOut),
        isFalse,
        reason: '${element.widget.runtimeType} at $rect sits on the crease '
            '($keepOut)',
      );
    }
  }
  expect(checked, greaterThan(5), reason: 'crease check found controls');
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() => debugDisableShadows = false);
  tearDown(() => debugDisableShadows = true);

  group('Cover screen (compact)', () {
    testWidgets('Board', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withHistory: true);
      expect(find.text('With Babs'), findsOneWidget);
      await shot(tester, '01_board_cover');

      await tester.drag(find.byType(ListView).first, const Offset(0, -330));
      await tester.pumpAndSettle();
      await shot(tester, '02_board_cover_companion_section');

      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      await shot(tester, '03_board_cover_done');
    });

    testWidgets('Party Sheet', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Character');
      await shot(tester, '04_party_cover_hero');
      await tester.drag(find.byType(ListView).last, const Offset(0, -640));
      await tester.pumpAndSettle();
      await shot(tester, '05_party_cover_companion');
    });

    testWidgets('Quest Log and the quest creator', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Log');
      await shot(tester, '06_log_cover');
      await tester.tap(find.text('New quest'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Read a chapter');
      await tester.tap(find.text('Mind'));
      await tester.pumpAndSettle();
      await shot(tester, '07_new_quest_cover');
    });

    testWidgets('Onboarding: companion choice', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withProfile: false);
      await shot(tester, '08_onboarding_cover_hero');
      await tester.enterText(find.byType(TextField).first, 'Adam');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A hound named Babs'));
      await tester.pumpAndSettle();
      await shot(tester, '09_onboarding_cover_companion');
    });

    testWidgets('Level-up and Discovery moments', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, withHistory: true);
      final context = tester.element(find.byType(AppShell));

      showHeroLevelUp(context, hero: app.game.hero!, level: 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      await shot(tester, '10_level_up_cover');
      await tester.tap(find.text('Onward'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      showCompanionLevelUp(
        context,
        companion: app.game.companion!,
        level: 4,
        bondBonus: 3,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await shot(tester, '11_companion_level_up_cover');
      await tester.tap(find.textContaining('Good'));
      await tester.pumpAndSettle();

      showDiscovery(
        context,
        scene: sceneFor(2),
        number: 3,
        companion: app.game.companion,
      );
      await tester.pumpAndSettle();
      await shot(tester, '12_discovery_cover');
      await tester.tap(find.text('Mark it with a lantern'));
      await tester.pumpAndSettle();
    });
  });

  group('Opened Fold (expanded, with crease)', () {
    testWidgets('Board + Vale side by side', (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withHistory: true);
      expect(find.text('With Babs'), findsOneWidget);
      expect(find.text('THE VALE'), findsOneWidget);
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '20_board_open');

      await tester.drag(find.byType(ListView).first, const Offset(0, -380));
      await tester.pumpAndSettle();
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '21_board_open_companion_section');
    });

    testWidgets('Party Sheet: hero on one pane, companion on the other',
        (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Character');
      expect(find.text('HERO'), findsOneWidget);
      expect(find.text('COMPANION · HOUND'), findsOneWidget);

      // Hero entirely left of the crease, companion entirely right of it.
      final crease = TestDevice.foldOpen.size.width / 2;
      final heroBox = tester.getRect(find.text('HERO'));
      final companionBox = tester.getRect(find.text('COMPANION · HOUND'));
      expect(heroBox.right < crease, isTrue);
      expect(companionBox.left > crease, isTrue);

      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '22_party_open');
    });

    testWidgets('Quest Log: list + detail', (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Log');
      await tester.tap(find.text('Walk Babs'));
      await tester.pumpAndSettle();
      expect(find.text('Edit quest'), findsOneWidget);
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '23_log_open');
    });

    testWidgets('Dialogs stay on one side of the crease', (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      final app = await TestApp.start(tester, now: saturday, withHistory: true);
      final context = tester.element(find.byType(AppShell));
      showDiscovery(
        context,
        scene: sceneFor(0),
        number: 1,
        companion: app.game.companion,
      );
      await tester.pumpAndSettle();
      final crease = TestDevice.foldOpen.size.width / 2;
      final button = tester.getRect(find.byType(PrimaryButton).last);
      expect(
        button.right <= crease || button.left >= crease,
        isTrue,
        reason: 'dialog button at $button crosses the crease',
      );
      await shot(tester, '24_discovery_open');
      await tester.tap(find.text('Mark it with a lantern'));
      await tester.pumpAndSettle();
    });

    testWidgets('Onboarding', (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withProfile: false);
      await tester.enterText(find.byType(TextField).first, 'Adam');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '25_onboarding_open_companion');
    });
  });

  group('Compact phone', () {
    testWidgets('Board on a 360dp phone', (tester) async {
      useDevice(tester, TestDevice.compactPhone);
      await TestApp.start(tester, now: saturday, withHistory: true);
      expect(tester.takeException(), isNull);
      await shot(tester, '30_board_phone');
    });
  });
}
