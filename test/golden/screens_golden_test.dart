import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/journey.dart';
import 'package:habit_adventure/rules/world.dart';
import 'package:habit_adventure/ui/adaptive.dart';
import 'package:habit_adventure/ui/board/quest_actions.dart';
import 'package:habit_adventure/ui/campfire/campfire_screen.dart';
import 'package:habit_adventure/ui/celebrations.dart';
import 'package:habit_adventure/ui/map/vale_map.dart';
import 'package:habit_adventure/ui/settings/settings_screen.dart';
import 'package:habit_adventure/ui/shell/app_shell.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';

// Renders every screen at the cover-screen and opened-Fold sizes and
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
    find.byType(UndoButton),
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

/// A screenshot test with real shadows. The flag has to be put back before
/// the test body returns, or the framework reports a changed debug variable.
void screenTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  setUpAll(loadAppFonts);
  // Screenshots show the paintings.
  setUpAll(() => TestApp.largeArt = true);

  group('Cover screen (compact)', () {
    screenTest('Board', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await shot(tester, '01_board_cover');

      await reveal(tester, find.text('With Babs'));
      await shot(tester, '02_board_cover_companion_section');

      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      await shot(tester, '03_board_cover_done');
    });

    screenTest('Party Sheet', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Character');
      await shot(tester, '04_party_cover_hero');
      await tester.drag(find.byType(ListView).last, const Offset(0, -640));
      await tester.pumpAndSettle();
      await shot(tester, '05_party_cover_companion');
    });

    screenTest('Quest Log and the quest creator', (tester) async {
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

    screenTest('Onboarding: companion choice', (tester) async {
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

    screenTest('Level-up and Discovery moments', (tester) async {
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
    screenTest('Board + Vale side by side', (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withHistory: true);
      expect(find.text('THE VALE'), findsOneWidget);
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '20_board_open');

      await reveal(tester, find.text('With Babs'));
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '21_board_open_companion_section');
    });

    screenTest('Party Sheet: hero on one pane, companion on the other',
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

    screenTest('Quest Log: list + detail', (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Log');
      await tester.tap(find.text('Walk Babs'));
      await tester.pumpAndSettle();
      expect(find.text('Edit quest'), findsOneWidget);
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '23_log_open');
    });

    screenTest('Dialogs stay on one side of the crease', (tester) async {
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

      // The quest detail (a bottom sheet on the cover screen) becomes a
      // dialog inside one pane.
      await tester.tap(find.text('7,000 Steps'));
      await tester.pumpAndSettle();
      expect(find.text('Mark done'), findsOneWidget);
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '26_quest_detail_open');
      await tester.tapAt(const Offset(700, 20));
      await tester.pumpAndSettle();

      // So does the quest creator.
      await tester.tap(find.text('Quest'));
      await tester.pumpAndSettle();
      expect(find.text('New quest'), findsOneWidget);
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '27_new_quest_open');
    });

    screenTest('Onboarding', (tester) async {
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

  group('Phase 2 on the cover screen', () {
    screenTest('World Map', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Map');
      expect(find.byType(ValeMap), findsOneWidget);
      await shot(tester, '40_map_cover');
      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pumpAndSettle();
      await shot(tester, '41_map_cover_target_and_road');
      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pumpAndSettle();
      await shot(tester, '42_map_cover_places');
    });

    screenTest('Inventory', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Character');
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      await shot(tester, '43_inventory_cover_hero');
      await reveal(tester, find.text('GEAR'));
      await shot(tester, '44_inventory_cover_companion');
    });

    screenTest('Campfire', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await reveal(tester, find.text('Campfire Review'));
      await tester.tap(find.text('Campfire Review'));
      await tester.pumpAndSettle();
      expect(find.byType(CampfireScreen), findsOneWidget);
      await shot(tester, '45_campfire_cover_scene');
      await tester.drag(find.byType(ListView).first, const Offset(0, -420));
      await tester.pumpAndSettle();
      await shot(tester, '46_campfire_cover_review');
      await reveal(tester, find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'Long walk by the river with Babs before the rain.',
      );
      await tester.pumpAndSettle();
      await shot(tester, '47_campfire_cover_note');
    });

    screenTest('Settings', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(
        tester,
        now: saturday,
        withHistory: true,
        vault: MemoryVault(chosen: true),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RoundIconButton && w.semanticLabel == 'Settings',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await shot(tester, '48_settings_cover');
      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pumpAndSettle();
      await shot(tester, '49_settings_cover_more');
    });

    screenTest('A place is restored; a quest waits to be undone',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday, withHistory: true);
      final context = tester.element(find.byType(AppShell));
      showRestoration(context, target: restorationTargets[2]);
      await tester.pumpAndSettle();
      await shot(tester, '50_restoration_cover');
      await tester.tap(find.text('The Vale wakes'));
      await tester.pumpAndSettle();

      final steps = find.byWidgetPredicate(
        (w) => w is CompleteButton && w.label == 'Complete 7,000 Steps',
      );
      await reveal(tester, steps);
      await tester.tap(steps);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(UndoButton), findsOneWidget);
      await shot(tester, '51_board_cover_undo');
      await tester.tap(find.byType(UndoButton));
      await tester.pumpAndSettle();
      expect(find.byType(UndoButton), findsNothing);
    });
  });

  group('Phase 2 on the opened Fold', () {
    screenTest('World Map: the map on one pane, the details on the other',
        (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Map');
      final crease = TestDevice.foldOpen.size.width / 2;
      expect(tester.getRect(find.byType(ValeMap)).right < crease, isTrue);
      expect(
        tester.getRect(find.textContaining('WORKING TOWARD')).left > crease,
        isTrue,
      );
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '60_map_open');
    });

    screenTest('Inventory: the hero’s things and the companion’s',
        (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Character');
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      final crease = TestDevice.foldOpen.size.width / 2;
      expect(tester.getRect(find.text('The stores')).right < crease, isTrue);
      expect(tester.getRect(find.text('GEAR AND TRICKS')).left > crease, isTrue);
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '61_inventory_open');
    });

    screenTest('Campfire: the camp on one pane, the review on the other',
        (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withHistory: true);
      await reveal(tester, find.text('Campfire Review'));
      await tester.tap(find.text('Campfire Review'));
      await tester.pumpAndSettle();
      final crease = TestDevice.foldOpen.size.width / 2;
      expect(tester.getRect(find.text('CAMPFIRE')).right < crease, isTrue);
      expect(tester.getRect(find.text('TODAY')).left > crease, isTrue);
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '62_campfire_open');
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '63_campfire_open_note');
    });

    screenTest('Settings', (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(
        tester,
        now: saturday,
        withHistory: true,
        vault: MemoryVault(chosen: true),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expectCreaseClear(tester, TestDevice.foldOpen);
      await shot(tester, '64_settings_open');
    });

    screenTest('The restoration moment stays on one side of the crease',
        (tester) async {
      useDevice(tester, TestDevice.foldOpen);
      await TestApp.start(tester, now: saturday, withHistory: true);
      final context = tester.element(find.byType(AppShell));
      showRestoration(context, target: restorationTargets[2]);
      await tester.pumpAndSettle();
      final crease = TestDevice.foldOpen.size.width / 2;
      final button = tester.getRect(find.byType(PrimaryButton).last);
      expect(button.right <= crease || button.left >= crease, isTrue);
      await shot(tester, '65_restoration_open');
      await tester.tap(find.text('The Vale wakes'));
      await tester.pumpAndSettle();
    });
  });

  group('Compact phone', () {
    screenTest('Board on a 360dp phone', (tester) async {
      useDevice(tester, TestDevice.compactPhone);
      await TestApp.start(tester, now: saturday, withHistory: true);
      expect(tester.takeException(), isNull);
      await shot(tester, '30_board_phone');
    });
  });
}
