import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/export/export_service.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/still.dart';
import 'package:habit_adventure/ui/board/quest_actions.dart';
import 'package:habit_adventure/ui/campfire/campfire_screen.dart';
import 'package:habit_adventure/ui/map/vale_map.dart';
import 'package:habit_adventure/ui/settings/settings_screen.dart';
import 'package:habit_adventure/ui/widgets/common.dart';

import '../support/harness.dart';

final DateTime saturday = DateTime(2026, 11, 14, 9, 12);

Finder completeButton(String questName) => find.byWidgetPredicate(
      (w) => w is CompleteButton && w.label == 'Complete $questName',
    );

Finder roundButton(String semanticLabel) => find.byWidgetPredicate(
      (w) => w is RoundIconButton && w.semanticLabel == semanticLabel,
    );

Finder primary(String label) => find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.label == label,
    );

Finder quiet(String label) => find.byWidgetPredicate(
      (w) => w is QuietButton && w.label == label,
    );

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('Undo', () {
    testWidgets('a tapped quest waits five seconds before anything is awarded',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await reveal(tester, completeButton('Walk Babs'));
      await tester.tap(completeButton('Walk Babs'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(UndoButton), findsOneWidget);
      expect(find.text('Done. Undo if that was a slip.'), findsOneWidget);
      expect(app.game.isPending(app.game.companionQuests.first.quest.id), isTrue);
      expect(app.game.companion!.totalXp, 0, reason: 'nothing awarded yet');
      expect(app.game.doneQuests, isEmpty);

      // The window closes; now it counts.
      await app.settle(tester);
      expect(find.byType(UndoButton), findsNothing);
      expect(app.game.companion!.totalXp, 25);
      expect(app.game.doneQuests.single.quest.name, 'Walk Babs');
    });

    testWidgets('Undo takes it back and leaves no trace', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await reveal(tester, completeButton('Walk Babs'));
      await tester.tap(completeButton('Walk Babs'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(UndoButton));
      await app.settle(tester);

      expect(find.byType(UndoButton), findsNothing);
      expect(completeButton('Walk Babs'), findsOneWidget);
      expect(app.game.companion!.totalXp, 0);
      expect(app.game.hero!.totalXp, 0);
      expect(app.game.world!.journeyPaces, 0);
      expect(app.game.doneQuests, isEmpty);
      expect(await tester.runAsync(app.repo.completionCount), 0);
    });

    testWidgets('leaving the app commits what was tapped', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await reveal(tester, completeButton('Walk Babs'));
      await tester.tap(completeButton('Walk Babs'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(UndoButton), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await app.settle(tester);
      expect(app.game.companion!.totalXp, 25);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await app.settle(tester);
      expect(app.game.companion!.totalXp, 25, reason: 'and only once');
    });
  });

  group('World Map (DESIGN §8.2)', () {
    testWidgets('shows the Vale, the next restoration and the road',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Map');
      expect(find.text('THE VALE'), findsOneWidget);
      expect(find.byType(ValeMap), findsOneWidget);
      final map = tester.widget<ValeMap>(find.byType(ValeMap));
      expect(map.restored, app.game.restored);
      expect(map.restored, greaterThan(0));
      expect(map.paces, app.game.world!.journeyPaces);
      expect(map.discoveries, app.game.discoveries.length);

      await reveal(tester, find.textContaining('WORKING TOWARD'));
      expect(find.text(app.game.target.name), findsWidgets);
      expect(find.text('Restored'), findsOneWidget, reason: 'the map key');
      await reveal(tester, find.text('Places'));
      expect(find.text('Hearthmere'), findsWidgets);
    });

    testWidgets('a fresh Vale is asleep, with the gate lantern first',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday);
      await openTab(tester, 'Map');
      expect(find.text('Asleep, for now'), findsOneWidget);
      await reveal(tester, find.text('WORKING TOWARD · HEARTHMERE'));
      expect(find.text('The Gate Lantern'), findsWidgets);
    });

    testWidgets('a Heroic quest shows its Still creature until it is done',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      final painting = app.game.board
          .firstWhere((b) => b.quest.name == 'Painting / Craft Block');
      expect(app.game.stillQuests.map((b) => b.quest.name), <String>[
        'Painting / Craft Block',
      ]);
      final creature = stillFor(painting.quest.id);
      await reveal(tester, find.text(creature.sits));
      expect(find.text(creature.sits), findsOneWidget);
    });
  });

  group('Inventory (DESIGN §8.4)', () {
    testWidgets('gold, materials, cosmetics, gear and tricks', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, withHistory: true);
      await openTab(tester, 'Character');
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('The stores'), findsOneWidget);
      expect(find.text('HERO'), findsNothing);
      for (final heading in <String>[
        'PORTRAIT FRAMES',
        'BANNER COLOURS',
        'VILLAGE DECORATIONS',
        'GEAR',
        'TRICKS',
      ]) {
        await reveal(tester, find.text(heading));
        expect(find.text(heading), findsOneWidget);
      }
      expect(app.game.cosmeticsUnlocked, contains('dawn'));
    });

    testWidgets('an unlocked banner can be put to use', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, withHistory: true);
      expect(app.game.banner, 'forest');
      await openTab(tester, 'Character');
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Dawn Banner'));
      await tester.tap(find.text('Dawn Banner'));
      await app.settle(tester);
      expect(app.game.banner, 'dawn');
    });
  });

  group('Campfire (DESIGN §4.1, §8.6)', () {
    testWidgets('review, note, close the day, then edit the note',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday);
      await reveal(tester, roundButton('Open the Campfire'));
      await tester.tap(roundButton('Open the Campfire'));
      await tester.pumpAndSettle();
      expect(find.byType(CampfireScreen), findsOneWidget);
      expect(find.text('CAMPFIRE'), findsOneWidget);
      expect(app.game.campfireDone, isFalse);

      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'A calm day.');
      await reveal(tester, primary('Close the day'));
      await tester.tap(primary('Close the day'));
      await app.settle(tester);

      expect(app.game.campfireDone, isTrue);
      expect(app.game.dayNote, 'A calm day.');
      expect(app.game.hero!.totalXp, 10, reason: 'Campfire Review, Minor');
      expect(find.text('The day is closed. Rest well.'), findsOneWidget);

      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'A calm day, and a long walk.');
      await reveal(tester, quiet('Save note'));
      await tester.tap(quiet('Save note'));
      await app.settle(tester);
      expect(app.game.dayNote, 'A calm day, and a long walk.');
      expect(app.game.hero!.totalXp, 10, reason: 'nothing awarded twice');

      await reveal(tester, primary('Back to the board'));
      await tester.tap(primary('Back to the board'));
      await tester.pumpAndSettle();
      expect(find.byType(CampfireScreen), findsNothing);
      await reveal(tester, find.text('The campfire is lit'));
      expect(find.text('The campfire is lit'), findsOneWidget);
    });

    testWidgets('closing the day sends the export to the vault',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final vault = MemoryVault(chosen: true);
      final app = await TestApp.start(tester, now: saturday, vault: vault);
      await reveal(tester, roundButton('Open the Campfire'));
      await tester.tap(roundButton('Open the Campfire'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Written at the fire.');
      await reveal(tester, primary('Close the day'));
      await tester.tap(primary('Close the day'));
      await app.settle(tester);

      final day = vault.files['Daily/2026-11-14.md'];
      expect(day, isNotNull);
      expect(day, contains('| 09:12 | Campfire Review | Hero | Mind | Minor | 10 XP |'));
      expect(day!.endsWith('## Notes\n\nWritten at the fire.\n'), isTrue);
      expect(vault.files.keys, containsAll(<String>['Character Sheet.md', 'Quests.md']));
      expect(app.game.export.state, ExportState.upToDate);
    });
  });

  group('Settings (DESIGN §8.8)', () {
    Future<void> open(WidgetTester tester) async {
      await tester.tap(roundButton('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }

    testWidgets('picking the vault folder starts the export', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final vault = MemoryVault();
      final app = await TestApp.start(tester, now: saturday, vault: vault);
      await open(tester);
      expect(find.text('No vault folder chosen'), findsOneWidget);
      await tester.tap(primary('Choose vault folder'));
      await app.settle(tester);
      expect(vault.chosen, isTrue);
      expect(find.text('Writing to “Quest Log”'), findsOneWidget);
      expect(vault.files.keys, containsAll(<String>['Character Sheet.md', 'Quests.md']));
    });

    testWidgets('a folder that is away shows the calm waiting line',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final vault = MemoryVault(chosen: true, available: false);
      await TestApp.start(tester, now: saturday, vault: vault);
      await open(tester);
      expect(find.text('Export waiting for vault folder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Share… hands over the same files', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final vault = MemoryVault();
      final app = await TestApp.start(tester, now: saturday, vault: vault);
      await open(tester);
      await tester.tap(quiet('Share…'));
      await app.settle(tester);
      expect(vault.shared!.keys.toSet(), <String>{
        'Character Sheet.md',
        'Quests.md',
        'Goals & Habits.md',
        'Daily/2026-11-14.md',
      });
    });

    testWidgets('a new chapter: kind and name change, progress stays',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final app = await TestApp.start(tester, now: saturday, withHistory: true);
      final before = app.game.companion!;
      await open(tester);
      await reveal(tester, quiet('Change'));
      await tester.tap(quiet('Change'));
      await tester.pumpAndSettle();
      expect(find.text('A new chapter'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Ember');
      await tester.tap(find.text('Fox'));
      await tester.pumpAndSettle();
      await tester.tap(primary('Begin the new chapter'));
      await app.settle(tester);

      final after = app.game.companion!;
      expect(after.name, 'Ember');
      expect(after.kind, CompanionKind.fox);
      expect(after.totalXp, before.totalXp);
      expect(after.level, before.level);
      expect(after.bond, before.bond);
      expect(find.text('Ember · Fox'), findsOneWidget);
    });

    testWidgets('backup: save, and a wrong file is turned away kindly',
        (tester) async {
      useDevice(tester, TestDevice.foldCover);
      final vault = MemoryVault()..documentToOpen = 'not a backup';
      final app = await TestApp.start(tester, now: saturday, vault: vault);
      await open(tester);
      await reveal(tester, quiet('Save a backup'));
      await tester.tap(quiet('Save a backup'));
      await app.settle(tester);
      expect(vault.savedName, 'habit-adventure-backup-2026-11-14.json');
      expect(vault.savedDocument, contains('"format": "habit-adventure-backup"'));
      expect(find.text('Backup saved.'), findsOneWidget);

      await tester.tap(quiet('Restore from a backup'));
      await tester.pumpAndSettle();
      expect(find.text('Restore from a backup?'), findsOneWidget);
      await tester.tap(primary('Choose a backup'));
      await app.settle(tester);
      expect(find.text('That file is not a backup from this app.'), findsOneWidget);
      expect(app.game.hero!.name, 'Adam', reason: 'nothing was changed');
    });

    testWidgets('About says the app is offline and original', (tester) async {
      useDevice(tester, TestDevice.foldCover);
      await TestApp.start(tester, now: saturday);
      await open(tester);
      await reveal(tester, find.text('About'));
      expect(find.textContaining('makes no network calls'), findsOneWidget);
      expect(find.textContaining('An original work'), findsOneWidget);
    });
  });
}
