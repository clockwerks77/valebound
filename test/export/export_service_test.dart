import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/export/export_service.dart';
import 'package:habit_adventure/export/markdown.dart';
import 'package:habit_adventure/rules/day_key.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/first_dawn.dart';
import 'package:habit_adventure/rules/goals.dart';

import '../support/harness.dart' show MemoryVault;

// The export end to end: database → Markdown files → the vault folder, with
// the quiet queue of DESIGN §11. Also produces the three sample files.

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late DateTime now;
  late AppDatabase db;
  late GameRepository repo;
  late MemoryVault vault;
  late ExportService export;

  Future<String> id(String name) async =>
      (await repo.allQuests()).firstWhere((q) => q.name == name).id;

  Future<void> at(int day, int hour, int minute) async {
    final next = DateTime(2026, 11, day, hour, minute);
    final newDay = DayKey.of(next) != DayKey.of(now);
    now = next;
    if (newDay) await repo.ensureDawn();
  }

  Future<void> start() async {
    await repo.createProfile(
      heroName: 'Adam',
      portraitId: 'wayfarer',
      companionName: 'Babs',
      companionKind: CompanionKind.hound,
      activateFiveMinuteReset: true,
    );
    await repo.ensureDawn();
  }

  setUp(() {
    now = DateTime(2026, 11, 12, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: () => now);
    vault = MemoryVault();
    export = ExportService(repo, vault);
  });

  tearDown(() => db.close());

  group('The quiet queue (DESIGN §11)', () {
    test('with no folder chosen nothing is written and nothing complains',
        () async {
      await start();
      await repo.completeQuest(await id('Walk Babs'));
      await export.exportPending();
      expect(export.state, ExportState.noFolder);
      expect(vault.files, isEmpty);
    });

    test('a completion writes the sheet, the quest list and today', () async {
      await start();
      vault.chosen = true;
      await repo.completeQuest(await id('Walk Babs'));
      await export.exportPending();
      expect(vault.files.keys.toSet(), <String>{
        'Character Sheet.md',
        'Quests.md',
        'Goals & Habits.md',
        'Daily/2026-11-12.md',
      });
      expect(export.state, ExportState.upToDate);
      expect(export.lastExportAt, now);
      expect((await repo.dayLog('2026-11-12'))!.exportedAt, isNotNull);
    });

    test('today is regenerated on each completion during the day', () async {
      await start();
      vault.chosen = true;
      await repo.completeQuest(await id('Walk Babs'));
      await export.exportPending();
      final first = vault.files['Daily/2026-11-12.md']!;
      expect(first, contains('quests_completed: 1'));

      await at(12, 18, 30);
      await repo.completeQuest(await id('7,000 Steps'));
      await export.exportPending();
      final second = vault.files['Daily/2026-11-12.md']!;
      expect(second, contains('quests_completed: 2'));
      expect(second, contains('| 18:30 | 7,000 Steps | Hero | Vitality | Standard | 25 XP |'));
    });

    test('while the folder is away the export waits, then catches up',
        () async {
      await start();
      vault
        ..chosen = true
        ..available = false;
      await repo.completeQuest(await id('Walk Babs'));
      await export.exportPending();
      expect(export.state, ExportState.waiting);
      expect(vault.files, isEmpty);

      await at(13, 8, 0);
      await repo.completeQuest(await id('Walk Babs'));
      await at(14, 8, 0);
      await repo.completeQuest(await id('Walk Babs'));
      await export.exportPending();
      expect(export.state, ExportState.waiting);
      expect(export.pendingDays, 3);
      expect(vault.files, isEmpty);

      // The vault has synced to the device.
      vault.available = true;
      await export.exportPending();
      expect(export.state, ExportState.upToDate);
      expect(export.pendingDays, 0);
      expect(vault.files.keys.toSet(), <String>{
        'Character Sheet.md',
        'Quests.md',
        'Goals & Habits.md',
        'Daily/2026-11-12.md',
        'Daily/2026-11-13.md',
        'Daily/2026-11-14.md',
      });
    });

    test('days already written are left alone until they change', () async {
      await start();
      vault.chosen = true;
      await repo.completeQuest(await id('Walk Babs'));
      await export.exportPending();
      await at(13, 8, 0);
      await repo.completeQuest(await id('Walk Babs'));
      vault.files.clear();
      await export.exportPending();
      expect(vault.files.keys, isNot(contains('Daily/2026-11-12.md')));
      expect(vault.files.keys, contains('Daily/2026-11-13.md'));
    });

    test('a day with nothing in it makes no file', () async {
      await start();
      vault.chosen = true;
      await at(13, 8, 0);
      await at(14, 8, 0);
      await repo.completeQuest(await id('Walk Babs'));
      await export.exportPending();
      expect(vault.files.keys.where((k) => k.startsWith('Daily/')), <String>[
        'Daily/2026-11-14.md',
      ]);
    });

    test('a past day is exported as it stood at its own evening', () async {
      await start();
      vault.chosen = true;
      await repo.completeQuest(await id('Walk Babs'));
      await at(13, 8, 0);
      await repo.completeQuest(await id('Walk Babs'));
      await repo.completeQuest(await id('7,000 Steps'));
      await export.exportPending();
      final first = vault.files['Daily/2026-11-12.md']!;
      expect(first, contains('xp_earned: 13'));
      expect(first, contains('level: 1'));
      expect(first, contains('- Camp: 1 Pace along the road, in Hearthmere.'));
      final second = vault.files['Daily/2026-11-13.md']!;
      expect(second, contains('xp_earned: 38'));
      expect(second, contains('- Camp: 2 Paces along the road, in Hearthmere.'));
    });

    test('Share… includes today even when everything is written', () async {
      await start();
      vault.chosen = true;
      await repo.completeQuest(await id('Walk Babs'));
      await export.exportPending();
      final files = await export.buildShareFiles('2026-11-12');
      expect(files.keys.toSet(), <String>{
        'Character Sheet.md',
        'Quests.md',
        'Goals & Habits.md',
        'Daily/2026-11-12.md',
      });
    });
  });

  group('What the files say, from real play', () {
    test('restorations, discoveries, health and the note reach the day file',
        () async {
      await start();
      vault.chosen = true;
      // Ten Paces: the first Discovery.
      for (var day = 3; day <= 11; day++) {
        await at(day, 8, 0);
        await repo.completeQuest(await id('Walk Babs'));
      }
      // Two quests this day (the walk and the Campfire), so the day's Still
      // creature sleeps on and brings nothing extra (D-70).
      await at(12, 9, 0);
      await repo.completeQuest(await id('Walk Babs'));
      await repo.setHealthEntry('2026-11-12', 'steps', '8214');
      await repo.setHealthEntry('2026-11-12', 'glucose', '5.8', unit: 'mmol/L');
      await at(12, 21, 0);
      await repo.closeDay(note: 'A long walk.\nBabs slept the whole evening.');
      await export.exportPending();

      final text = vault.files['Daily/2026-11-12.md']!;
      expect(text, contains('steps: 8214'));
      expect(text, contains('paces: 1'));
      expect(text, contains('## Journey\n\n- Paces today: 1\n- Discovery: The Listening Stone\n'));
      expect(text, contains('## Health\n\n- Glucose: 5.8 mmol/L\n- Steps: 8,214\n'));
      // Nothing woke today; the Gate Lantern woke on the 9th, when Babs
      // sniffed out the last Timber it needed.
      expect(text, contains('## World\n\nThe Vale rests.\n'));
      expect(
        vault.files['Daily/2026-11-09.md'],
        contains('## World\n\n- Restored: The Gate Lantern (Hearthmere)\n'),
      );
      expect(
        text.endsWith('## Notes\n\nA long walk.\nBabs slept the whole evening.\n'),
        isTrue,
      );
      expect(text, contains('| 21:00 | Campfire Review | Hero | Mind | Minor | 10 XP |'));

      final sheet = vault.files['Character Sheet.md']!;
      expect(sheet, contains('companion_name: "Babs"'));
      expect(sheet, contains('- Discoveries: 1 (The Listening Stone)'));
      expect(sheet, contains('- Places restored: 1 of 20'));
      expect(sheet, contains('- Hearthmere: The Gate Lantern'));
      expect(sheet, contains('- Working toward: The Village Well'));

      final quests = vault.files['Quests.md']!;
      expect(quests, contains('- **Walk Babs** · Care · Standard · Daily · Tap · Shared track'));
      expect(quests, contains('- **Weekly Injection (Mounjaro)** · Vitality · Minor · Weekly, Saturday · Tap'));
      expect(quests, contains('- **Painting / Craft Block** · Craft · Heroic · Sat, Sun · Timer, 60 min'));
    });

    test('archived quests leave Quests.md; the list explains what is active',
        () async {
      await start();
      vault.chosen = true;
      await repo.setQuestActive(await id('Five-Minute Reset'), active: false);
      await repo.completeQuest(await id('Walk Babs'));
      await export.exportPending();
      final quests = vault.files['Quests.md']!;
      expect(quests, isNot(contains('Five-Minute Reset')));
      expect(quests, contains('active_quests: 7'));
    });
  });

  group('Sample files (Phase 2 deliverable)', () {
    test('a fortnight of realistic play, written to ci_out/samples', () async {
      now = DateTime(2026, 10, 31, 7, 30);
      await start();
      vault.chosen = true;

      Future<void> clock(DateTime day, int hour, int minute) async {
        final next = DateTime(day.year, day.month, day.day, hour, minute);
        final newDay = DayKey.of(next) != DayKey.of(now);
        now = next;
        if (newDay) await repo.ensureDawn();
      }

      const notes = <int, String>{
        0: 'First day in the Vale. Babs approves of the new routine.',
        2: 'Rain all afternoon, so the walk was short. Still counted.',
        4: 'Good energy today. Cleared the desk before dinner.',
        7: 'Painting block ran long in the best way.',
        9: 'Quiet one. Early night.',
        12: 'Babs found the muddiest path in the park. Bath night.',
      };
      // A fortnight: Saturday 31 October to Friday 13 November.
      for (var i = 0; i < 14; i++) {
        final day = DateTime(2026, 10, 31 + i);
        if (i == 5) continue; // A day away. Nothing is recorded, nothing is owed.
        final weekday = day.weekday;
        await clock(day, 7, 35);
        await repo.completeQuest(await id('Morning Health Check'));
        await clock(day, 8, 20);
        await repo.completeQuest(await id('Walk Babs'));
        if (weekday == DateTime.saturday) {
          await clock(day, 9, 10);
          await repo.completeQuest(await id('Weekly Injection (Mounjaro)'));
        }
        await clock(day, 12, 40);
        await repo.completeQuest(await id('Play / Train with Babs'), progress: 600);
        if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
          await clock(day, 14, 5);
          await repo.completeQuest(await id('Painting / Craft Block'), progress: 3900);
        }
        if (i == 2 || i == 9) {
          await clock(day, 17, 15);
          await repo.completeQuest(await id('Five-Minute Reset'), progress: 300);
        }
        await clock(day, 18, 30);
        await repo.completeQuest(await id('7,000 Steps'));
        await repo.setHealthEntry(DayKey.of(day), 'steps', '${7000 + (i * 613) % 2400}');
        if (i != 3 && i != 10) {
          await clock(day, 21, 15);
          await repo.closeDay(note: notes[i] ?? '');
        }
      }

      // Saturday 14 November: the day the samples show. That morning the
      // hero answers First Dawn (Amendment v0.4): two goals, one new habit,
      // and three of the quests already on the board pinned to them.
      final today = DateTime(2026, 11, 14);
      await clock(today, 7, 30);
      await repo.commitFirstDawn(
        FirstDawnDraft(
          goals: <GoalDraft>[
            GoalDraft(
              domain: LifeDomain.body,
              text: 'Feel stronger',
              why: 'Stairs without thinking about them',
              horizon: Horizon.season,
              check: 'I take the stairs',
              plans: <PlanDraft>[
                PlanDraft(
                  habit: 'Stretch for 10 minutes',
                  anchor: 'When I wake up',
                ),
              ],
            ),
            GoalDraft(
              domain: LifeDomain.making,
              text: 'Finish my army',
              why: 'A painted army on the table',
            ),
          ],
          chosenClass: 'warden',
          existing: <String, String>{
            await id('Walk Babs'): 'goal:0',
            await id('7,000 Steps'): 'goal:0',
            await id('Painting / Craft Block'): 'goal:1',
          },
        ),
        fresh: false,
      );
      final stretch = (await repo.settings()).plans.single.questId!;
      await clock(today, 7, 40);
      await repo.completeQuest(await id('Morning Health Check'));
      // A hard morning: the habit at its Tiny size, which counts in full.
      await clock(today, 7, 50);
      await repo.completeQuest(stretch, size: QuestSize.tiny);
      await repo.setHealthEntry('2026-11-14', 'glucose', '5.8', unit: 'mmol/L');
      await repo.setHealthEntry('2026-11-14', 'time_in_range', '86', unit: '%');
      await clock(today, 8, 25);
      await repo.completeQuest(await id('Walk Babs'));
      await clock(today, 9, 5);
      await repo.completeQuest(await id('Weekly Injection (Mounjaro)'));
      await clock(today, 11, 30);
      await repo.completeQuest(await id('Painting / Craft Block'), progress: 4500);
      await clock(today, 16, 10);
      await repo.completeQuest(await id('Play / Train with Babs'), progress: 600);
      await clock(today, 18, 45);
      await repo.completeQuest(await id('7,000 Steps'));
      await repo.setHealthEntry('2026-11-14', 'steps', '8214');
      await clock(today, 21, 30);
      await repo.closeDay(
        note: 'Long walk by the river with Babs before the rain.\n'
            'Two hours on the painting block and the base coats are done.\n\n'
            'Early night.',
      );
      await repo.recordBoardSize('2026-11-14', (await repo.loadBoard('2026-11-14')).length);
      await export.exportPending();

      final samples = <String, String>{
        characterSheetFile: vault.files[characterSheetFile]!,
        dailyFile('2026-11-14'): vault.files[dailyFile('2026-11-14')]!,
        questsFile: vault.files[questsFile]!,
        goalsFile: vault.files[goalsFile]!,
      };

      // Publish what was generated, so it can be read and filed.
      for (final entry in samples.entries) {
        final file = File('ci_out/samples/${entry.key}');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
      }

      // The contract, on real data.
      final day = samples[dailyFile('2026-11-14')]!;
      expect(day, startsWith('---\ntype: valebound-day\ndate: 2026-11-14\n'));
      expect(day, contains('quests_completed: 8'));
      expect(day, contains('| Feel stronger · when I wake up |'));
      expect(day, contains('| Finish my army |'));
      expect(samples[goalsFile], contains('## Feel stronger'));
      expect(samples[goalsFile], contains('- Why: A painted army on the table'));
      expect(day, contains('steps: 8214'));
      for (final heading in <String>[
        '## Quests Completed',
        '## Journey',
        '## Health',
        '## World',
        '## Notes',
      ]) {
        expect(day, contains(heading));
      }
      expect(day.indexOf('## Journey'), lessThan(day.indexOf('## Health')));
      expect(day.indexOf('## Health'), lessThan(day.indexOf('## World')));
      expect(day.indexOf('## World'), lessThan(day.indexOf('## Notes')));
      expect(samples[characterSheetFile], contains('## Companion'));
      expect(vault.files.keys.where((k) => k.startsWith('Daily/')).length, 14);

      // Once the samples are filed in docs/samples they pin the format: any
      // change to what the app writes has to be made there on purpose.
      for (final entry in samples.entries) {
        final filed = File('docs/samples/${entry.key}');
        if (filed.existsSync()) {
          expect(
            entry.value,
            filed.readAsStringSync(),
            reason: 'docs/samples/${entry.key} no longer matches the export',
          );
        }
      }
    });
  });
}
