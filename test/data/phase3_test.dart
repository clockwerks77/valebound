import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/data/seed.dart';
import 'package:habit_adventure/data/settings.dart';
import 'package:habit_adventure/export/export_service.dart';
import 'package:habit_adventure/export/markdown.dart';
import 'package:habit_adventure/rules/day_cycle.dart';
import 'package:habit_adventure/rules/day_key.dart';
import 'package:habit_adventure/rules/delve.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/health_fields.dart';

import '../support/harness.dart';

// Phase 3 storage: the comeback quest, the weekly Delve, calendar choices,
// steps and the Health Log, settings, the backup, and the upgrade from the
// Phase 2 database.

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 2026-11-14 is a Saturday.
  late DateTime now;
  late AppDatabase db;
  late GameRepository repo;

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

  Future<QuestRow> named(String name) async =>
      (await repo.allQuests()).firstWhere((q) => q.name == name);

  Future<String> id(String name) async => (await named(name)).id;

  Future<DawnPlan> day(int dayOfMonth, [int hour = 9]) async {
    now = DateTime(2026, 11, dayOfMonth, hour);
    return repo.ensureDawn();
  }

  Future<List<String>> boardNames() async => <String>[
        for (final b in await repo.loadBoard(DayKey.of(now))) b.quest.name,
      ];

  Future<List<QuestRow>> comebackRows() async => <QuestRow>[
        for (final q in await repo.allQuests())
          if (q.systemKey == systemKeyComeback) q,
      ];

  setUp(() {
    now = DateTime(2026, 11, 14, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: () => now);
  });

  tearDown(() => db.close());

  group('The comeback quest (DESIGN §4.3)', () {
    test('one day away is just a new day', () async {
      await start();
      final plan = await day(16);
      expect(plan.fullDaysAway, 1);
      expect(plan.comebackDue, isFalse);
      expect(await boardNames(), isNot(contains(comebackQuestName)));
      expect(await comebackRows(), isEmpty);
    });

    test('after two full days away, one quest joins today’s ordinary board',
        () async {
      await start();
      final plan = await day(17);
      expect(plan.fullDaysAway, 2);
      expect(plan.comebackDue, isTrue);

      final names = await boardNames();
      expect(names.where((n) => n == comebackQuestName).length, 1);
      // Today's own quests are all there too; nothing from the days away is.
      expect(names, contains('Walk Babs'));
      expect(names, contains('7,000 Steps'));

      final quest = (await comebackRows()).single;
      expect(quest.difficulty, Difficulty.minor);
      expect(quest.track, Track.hero);
      expect(quest.source, QuestSource.system);
      expect(quest.completionType, CompletionType.tap);
      expect(quest.scheduleAnchorDay, '2026-11-17');

      // Opening the app again the same day adds nothing.
      await repo.ensureDawn();
      expect((await comebackRows()).length, 1);
      for (final gone in <String>['2026-11-15', '2026-11-16']) {
        expect(await repo.dayLog(gone), isNull);
        expect(await repo.completionsOn(gone), isEmpty);
      }
    });

    test('completing it gives a Minor quest’s XP and the bonus', () async {
      await start();
      await day(17);
      final quest = (await comebackRows()).single;
      final outcome = await repo.completeQuest(quest.id);
      expect(outcome!.award.heroXp, 10);
      expect(outcome.heroXpGained, 25);
      expect(outcome.comfortBond, 0);

      final hero = (await repo.hero())!;
      expect(hero.totalXp, 25);
      expect(decodeAttributeXp(hero.attributeXp)[Attribute.adventure], 25);
      final completion = (await repo.completionsOn('2026-11-17')).single;
      expect(completion.xpAwarded, 25);
      expect(completion.bondAwarded, 0);
      expect(decodeExtras(completion.extras)['bonusXp'], 15);
      expect((await repo.companion())!.bond, 0);
      // Once a day, like any quest.
      expect(await repo.completeQuest(quest.id), isNull);
    });

    test('with Comfort the companion’s welcome adds Bond', () async {
      await start();
      final companion = (await repo.companion())!;
      await (db.update(db.companions)..where((c) => c.id.equals(companion.id)))
          .write(const CompanionsCompanion(level: Value(8), bond: Value(30)));
      await day(18);
      final quest = (await comebackRows()).single;
      final outcome = await repo.completeQuest(quest.id);
      expect(outcome!.comfortBond, 2);
      expect(outcome.totalBond, 2);
      expect((await repo.companion())!.bond, 32);
      expect(
        (await repo.completionsOn('2026-11-18')).single.bondAwarded,
        2,
      );
    });

    test('left alone it simply goes, and it is the same quest next time',
        () async {
      await start();
      await day(17);
      final first = (await comebackRows()).single;

      await day(18);
      expect(await boardNames(), isNot(contains(comebackQuestName)));
      expect((await repo.questById(first.id))!.active, isFalse);

      // Away again on the 19th and 20th.
      await day(21);
      final again = (await comebackRows()).single;
      expect(again.id, first.id);
      expect(again.active, isTrue);
      expect(again.scheduleAnchorDay, '2026-11-21');
      expect(await boardNames(), contains(comebackQuestName));
      final completions = await repo.allCompletions();
      expect(completions.where((c) => c.questId == first.id), isEmpty);
    });

    test('it is not listed among the quest definitions in the vault',
        () async {
      await start();
      await day(17);
      final vault = MemoryVault(chosen: true);
      final export = ExportService(repo, vault);
      await export.exportPending();
      expect(vault.files[questsFile], isNot(contains(comebackQuestName)));
    });
  });

  group('The weekly Delve (DESIGN §3B, §4.2)', () {
    Future<void> saturdayAndSunday() async {
      await start();
      // Saturday: 1 Timber and a walk.
      await repo.completeQuest(await id('Morning Health Check'));
      await repo.completeQuest(await id('Walk Babs'));
      // Sunday: a Heroic quest, 4 Stone.
      await day(15);
      await repo.completeQuest(await id('Painting / Craft Block'), progress: 3600);
    }

    test('none waits for a week that ended before the journey began',
        () async {
      await start();
      // Saturday: the last Delve day was the Sunday before.
      expect(await repo.delveWaiting(), isNull);
      expect(await repo.resolveDelve(), isNull);
    });

    test('on the Delve day the week’s quests are its supplies', () async {
      await saturdayAndSunday();
      final waiting = (await repo.delveWaiting())!;
      expect(waiting.delveDay, '2026-11-15');
      expect(waiting.site, delveSiteFor('2026-11-15'));
      expect(waiting.supplies.provisions, 2);
      expect(waiting.supplies.trailMarks, 1);
      expect(waiting.supplies.keys, 1);
      expect(waiting.supplies.daysActive, 2);
      expect(waiting.supplies.score, 5);
      expect(waiting.tier, DelveTier.rested);
    });

    test('entering it brings the reward home once, with no XP', () async {
      await saturdayAndSunday();
      final before = (await repo.hero())!;
      expect(before.gold, 19);

      final result = (await repo.resolveDelve())!;
      expect(result.tier, DelveTier.rested);
      expect(result.reward.gold, 8);
      expect(result.reward.eachMaterial, 1);

      final hero = (await repo.hero())!;
      expect(hero.gold, 27);
      expect(hero.totalXp, before.totalXp);
      expect(hero.level, before.level);
      expect(decodeMaterials(hero.materials), <MaterialKind, int>{
        MaterialKind.timber: 2,
        MaterialKind.stone: 5,
        MaterialKind.starShard: 1,
      });

      // That second Timber wakes the Gate Lantern.
      expect(result.newRestorationIndexes, <int>[0]);
      expect(
        decodeStringMap((await repo.world())!.buildingState),
        <String, String>{'gate_lantern': '2026-11-15'},
      );

      final row = (await repo.delves()).single;
      expect(row.weekEnd, '2026-11-15');
      expect(row.tier, 'rested');
      expect(row.gold, 8);
      expect(row.eachMaterial, 1);
      expect(row.provisions, 2);
      expect(row.trailMarks, 1);
      expect(row.keys, 1);
      expect(row.daysActive, 2);

      // Once resolved it is done: nothing waits and nothing is given twice.
      expect(await repo.delveWaiting(), isNull);
      expect(await repo.resolveDelve(), isNull);
      expect((await repo.hero())!.gold, 27);
      // The day goes back into the export queue.
      expect((await repo.dayLog('2026-11-15'))!.exportedAt, isNull);
    });

    test('it waits for the next Campfire if its day goes by', () async {
      await saturdayAndSunday();
      await day(16);
      await repo.completeQuest(await id('Morning Health Check'));
      await day(17);
      final waiting = (await repo.delveWaiting())!;
      expect(waiting.delveDay, '2026-11-15');
      // Monday's quest belongs to the week after.
      expect(waiting.supplies.quests, 3);
      final result = (await repo.resolveDelve())!;
      expect(result.delveDay, '2026-11-15');
      expect(await repo.delveWaiting(), isNull);
    });

    test('at most one in any seven days, whatever day is chosen', () async {
      await saturdayAndSunday();
      await repo.resolveDelve();
      await repo.setDelveWeekday(DateTime.monday);
      await day(16);
      expect(await repo.delveWaiting(), isNull);
      await day(23);
      expect((await repo.delveWaiting())!.delveDay, '2026-11-23');
    });

    test('the Delve day can be any day of the week', () async {
      await repo.setDelveWeekday(DateTime.saturday);
      await start();
      await repo.completeQuest(await id('Walk Babs'));
      final waiting = (await repo.delveWaiting())!;
      expect(waiting.delveDay, '2026-11-14');
      expect(waiting.supplies.trailMarks, 1);
    });
  });

  group('Steps and the Auto quest (DESIGN §6.2, §9.3)', () {
    Future<BoardQuest> stepsQuest() async =>
        (await repo.loadBoard(DayKey.of(now)))
            .firstWhere((b) => b.quest.completionType == CompletionType.auto);

    test('the day’s steps fill the quest', () async {
      await start();
      expect(await repo.recordSteps(3200), isEmpty);
      final quest = await stepsQuest();
      expect(quest.banked, 3200);
      expect(quest.isDone, isFalse);
      final entry = (await repo.healthEntriesByKey('2026-11-14'))['steps']!;
      expect(entry.value, '3200');
    });

    test('it completes itself at the target, once', () async {
      await start();
      await repo.recordSteps(3200);
      final completed = await repo.recordSteps(7350);
      expect(completed.single.questId, await id('7,000 Steps'));
      expect(completed.single.outcome.heroXpGained, 25);
      final quest = await stepsQuest();
      expect(quest.isDone, isTrue);
      expect(quest.completion!.progress, 7350);
      expect((await repo.hero())!.totalXp, 25);

      // More steps later update the day's record and nothing else.
      expect(await repo.recordSteps(9100), isEmpty);
      expect((await repo.hero())!.totalXp, 25);
      expect(
        (await repo.healthEntriesByKey('2026-11-14'))['steps']!.value,
        '9100',
      );
    });

    test('without Health Connect a tap still completes it', () async {
      await start();
      final outcome = await repo.completeQuest(await id('7,000 Steps'));
      expect(outcome, isNotNull);
      expect((await stepsQuest()).isDone, isTrue);
      // Steps arriving afterwards do not complete it a second time.
      expect(await repo.recordSteps(8000), isEmpty);
    });

    test('a quiet day leaves no trace of a target', () async {
      await start();
      await repo.recordSteps(1200);
      await day(15);
      final quest = await stepsQuest();
      expect(quest.banked, 0);
      expect(quest.isDone, isFalse);
      expect(await repo.completionsOn('2026-11-14'), isEmpty);
    });
  });

  group('Calendar suggestions (DESIGN §9.3, §12 item 3)', () {
    test('accepting one makes today’s commitment, a Confirm quest', () async {
      await start();
      final questId = await repo.acceptSuggestion(
        externalId: '41@1794650400000',
        title: 'Dentist',
        timeLabel: '10:30 – 11:15',
      );
      final quest = (await repo.questById(questId))!;
      expect(quest.name, 'Dentist');
      expect(quest.completionType, CompletionType.confirm);
      expect(quest.attribute, Attribute.order);
      expect(quest.difficulty, Difficulty.standard);
      expect(quest.track, Track.hero);
      expect(quest.source, QuestSource.calendar);
      expect(quest.externalId, '41@1794650400000');
      expect(quest.scheduleType, ScheduleType.oneOff);
      expect(quest.scheduleAnchorDay, '2026-11-14');
      expect(quest.notes, '10:30 – 11:15');
      expect(await boardNames(), contains('Dentist'));
      expect(await repo.calendarChoicesOn('2026-11-14'), <String, String>{
        '41@1794650400000': choiceAccepted,
      });

      // Accepting the same event again changes nothing.
      expect(
        await repo.acceptSuggestion(
          externalId: '41@1794650400000',
          title: 'Dentist',
        ),
        questId,
      );
      expect((await boardNames()).where((n) => n == 'Dentist').length, 1);
    });

    test('it is never completed for you', () async {
      await start();
      final questId = await repo.acceptSuggestion(
        externalId: 'a',
        title: 'Coffee with Sam',
      );
      final entry = (await repo.loadBoard('2026-11-14'))
          .firstWhere((b) => b.quest.id == questId);
      expect(entry.isDone, isFalse);
      // The next day it has simply gone; nothing was recorded about it.
      await day(15);
      expect(await boardNames(), isNot(contains('Coffee with Sam')));
      expect(await repo.allCompletions(), isEmpty);
    });

    test('"I did this" completes it like any Standard quest', () async {
      await start();
      final questId =
          await repo.acceptSuggestion(externalId: 'a', title: 'Dentist');
      final outcome = await repo.completeQuest(questId);
      expect(outcome!.heroXpGained, 25);
      expect(outcome.attribute, Attribute.order);
    });

    test('dismissing one records the choice and nothing else', () async {
      await start();
      final before = await boardNames();
      await repo.dismissSuggestion('b');
      await repo.dismissSuggestion('b');
      expect(await boardNames(), before);
      expect(await repo.calendarChoicesOn('2026-11-14'), <String, String>{
        'b': choiceDismissed,
      });
      // Choices belong to their day.
      expect(await repo.calendarChoicesOn('2026-11-15'), isEmpty);
    });

    test('an event with no title becomes Today’s Commitment', () async {
      await start();
      final questId =
          await repo.acceptSuggestion(externalId: 'c', title: '   ');
      expect((await repo.questById(questId))!.name, commitmentFallbackName);
    });

    test('it can be re-tagged before completing, and stays a commitment',
        () async {
      await start();
      final questId =
          await repo.acceptSuggestion(externalId: 'd', title: 'School play');
      final draft = QuestDraft.fromRow((await repo.questById(questId))!)
        ..attribute = Attribute.care;
      await repo.saveQuest(draft);
      final quest = (await repo.questById(questId))!;
      expect(quest.attribute, Attribute.care);
      expect(quest.source, QuestSource.calendar);
      expect(quest.completionType, CompletionType.confirm);
      expect(quest.externalId, 'd');
    });
  });

  group('Health Log (DESIGN §8.7, §9.3)', () {
    test('what was logged reaches the day’s Markdown, named as chosen',
        () async {
      await start();
      await repo.setHealthFields(<HealthField>[
        ...healthPresets,
        const HealthField(key: 'hba1c', label: 'HbA1c', unit: '%'),
      ]);
      await repo.setHealthEntry('2026-11-14', 'glucose', '5.8', unit: 'mmol/L');
      await repo.setHealthEntry('2026-11-14', 'hba1c', '6.1', unit: '%');
      await repo.setHealthEntry(
        '2026-11-14',
        injectionFieldKey,
        encodeCheck('5 mg'),
      );
      await repo.recordSteps(8214);
      final export = ExportService(repo, MemoryVault(chosen: true));
      final files = await export.buildFiles(days: <String>['2026-11-14']);
      final daily = files[dailyFile('2026-11-14')]!;
      expect(daily, contains('steps: 8214'));
      expect(daily, contains('## Health'));
      expect(daily, contains('- Glucose: 5.8 mmol/L'));
      expect(daily, contains('- HbA1c: 6.1%'));
      expect(daily, contains('- Weekly injection: Done (5 mg)'));
      expect(daily, contains('- Steps: 8,214'));
    });

    test('nothing logged, no Health section', () async {
      await start();
      await repo.completeQuest(await id('Walk Babs'));
      final export = ExportService(repo, MemoryVault(chosen: true));
      final files = await export.buildFiles(days: <String>['2026-11-14']);
      expect(files[dailyFile('2026-11-14')], isNot(contains('## Health')));
    });
  });

  group('Quest reminders (DESIGN §6.1)', () {
    test('off unless set, and kept with the quest', () async {
      await start();
      for (final q in await repo.allQuests()) {
        expect(q.reminderTime, isNull);
      }
      final walk = await named('Walk Babs');
      await repo.saveQuest(QuestDraft.fromRow(walk)..reminderTime = '07:45');
      expect((await named('Walk Babs')).reminderTime, '07:45');
      await repo.saveQuest(
        QuestDraft.fromRow(await named('Walk Babs'))..reminderTime = null,
      );
      expect((await named('Walk Babs')).reminderTime, isNull);
    });
  });

  group('Settings', () {
    test('everything has a default', () async {
      final settings = await repo.settings();
      expect(settings.delveWeekday, DateTime.sunday);
      expect(settings.calendarOn, isFalse);
      expect(settings.calendarAsked, isFalse);
      expect(settings.excludedCalendars, isEmpty);
      expect(settings.stepsOn, isFalse);
      expect(
        settings.healthFields.map((f) => f.key),
        healthPresets.map((f) => f.key),
      );
    });

    test('each is stored, and clearing one restores its default', () async {
      await repo.setDelveWeekday(DateTime.wednesday);
      await repo.setSetting(SettingKey.calendarOn, '1');
      await repo.setSetting(SettingKey.stepsOn, '1');
      await repo.setExcludedCalendars(<String>{'7', '3'});
      await repo.setHealthFields(const <HealthField>[]);
      var settings = await repo.settings();
      expect(settings.delveWeekday, DateTime.wednesday);
      expect(settings.calendarOn, isTrue);
      expect(settings.stepsOn, isTrue);
      expect(settings.excludedCalendars, <String>{'3', '7'});
      expect(settings.healthFields, isEmpty);

      await repo.setSetting(SettingKey.calendarOn, null);
      await repo.setSetting(SettingKey.healthFields, null);
      settings = await repo.settings();
      expect(settings.calendarOn, isFalse);
      expect(settings.healthFields.length, healthPresets.length);
    });
  });

  group('JSON backup (DESIGN §9.2)', () {
    Future<void> play() async {
      await start();
      await repo.completeQuest(await id('Walk Babs'));
      await repo.acceptSuggestion(externalId: 'e1', title: 'Dentist');
      await repo.dismissSuggestion('e2');
      await repo.setDelveWeekday(DateTime.saturday);
      await repo.resolveDelve();
    }

    test('carries the Delves, calendar choices and settings', () async {
      await play();
      final backup = await repo.exportBackupJson();
      final decoded = jsonDecode(backup) as Map<String, dynamic>;
      expect(decoded['schema'], 4);
      final tables = decoded['tables'] as Map<String, dynamic>;
      expect((tables['delves'] as List<dynamic>).length, 1);
      expect((tables['calendarChoices'] as List<dynamic>).length, 2);
      expect((tables['settings'] as List<dynamic>).length, 1);

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final restored = GameRepository(other, clock: () => now);
      expect((await restored.importBackupJson(backup)).ok, isTrue);
      expect((await restored.delves()).single.weekEnd, '2026-11-14');
      expect(await restored.calendarChoicesOn('2026-11-14'), <String, String>{
        'e1': choiceAccepted,
        'e2': choiceDismissed,
      });
      expect((await restored.settings()).delveWeekday, DateTime.saturday);
      expect((await restored.hero())!.gold, (await repo.hero())!.gold);
    });

    test('a backup made before this version restores and gains its keys',
        () async {
      await play();
      final decoded =
          jsonDecode(await repo.exportBackupJson()) as Map<String, dynamic>;
      // As the Phase 2 build wrote it: schema 2, three fewer tables, and the
      // two seeded health quests without their keys.
      decoded['schema'] = 2;
      final tables = decoded['tables'] as Map<String, dynamic>
        ..remove('delves')
        ..remove('calendarChoices')
        ..remove('settings');
      for (final q in tables['quests'] as List<dynamic>) {
        final row = q as Map<String, dynamic>;
        if (row['systemKey'] == systemKeyHealthCheck ||
            row['systemKey'] == systemKeyInjection) {
          row['systemKey'] = null;
        }
      }

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final restored = GameRepository(other, clock: () => now);
      expect((await restored.importBackupJson(jsonEncode(decoded))).ok, isTrue);
      final quests = await restored.allQuests();
      expect(
        quests.firstWhere((q) => q.name == 'Morning Health Check').systemKey,
        systemKeyHealthCheck,
      );
      expect(
        quests
            .firstWhere((q) => q.name == 'Weekly Injection (Mounjaro)')
            .systemKey,
        systemKeyInjection,
      );
      expect(await restored.delves(), isEmpty);
      expect((await restored.settings()).delveWeekday, DateTime.sunday);
    });
  });

  group('Upgrade from the Phase 2 database (DESIGN §9.2)', () {
    // The tables exactly as schema 2 had them, with a day of play.
    const epoch = 1794650400; // 2026-11-14 10:00 UTC, in seconds.
    const v2 = <String>[
      "CREATE TABLE quests (id TEXT NOT NULL, name TEXT NOT NULL, icon_key TEXT NOT NULL DEFAULT 'star', attribute TEXT NOT NULL, difficulty TEXT NOT NULL, track TEXT NOT NULL, schedule_type TEXT NOT NULL, schedule_weekdays TEXT NOT NULL DEFAULT '', schedule_interval_days INTEGER NULL, schedule_anchor_day TEXT NULL, completion_type TEXT NOT NULL, target INTEGER NULL, reminder_time TEXT NULL, notes TEXT NOT NULL DEFAULT '', active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)), source TEXT NOT NULL, external_id TEXT NULL, system_key TEXT NULL, sort_order INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY (id))",
      "CREATE TABLE completions (id TEXT NOT NULL, quest_id TEXT NOT NULL, day TEXT NOT NULL, completed_at INTEGER NOT NULL, xp_awarded INTEGER NOT NULL, companion_xp_awarded INTEGER NOT NULL DEFAULT 0, paces_awarded INTEGER NOT NULL DEFAULT 0, bond_awarded INTEGER NOT NULL DEFAULT 0, gold_awarded INTEGER NOT NULL DEFAULT 0, material_kind TEXT NULL, material_amount INTEGER NOT NULL DEFAULT 0, difficulty_snapshot TEXT NOT NULL, track_snapshot TEXT NOT NULL, attribute_snapshot TEXT NOT NULL, quest_name_snapshot TEXT NOT NULL, progress INTEGER NULL, note TEXT NULL, extras TEXT NOT NULL DEFAULT '{}', PRIMARY KEY (id))",
      'CREATE TABLE quest_progress (id TEXT NOT NULL, quest_id TEXT NOT NULL, day TEXT NOT NULL, progress INTEGER NOT NULL DEFAULT 0, timer_started_at INTEGER NULL, set_aside INTEGER NOT NULL DEFAULT 0 CHECK (set_aside IN (0, 1)), PRIMARY KEY (id), UNIQUE (quest_id, day))',
      "CREATE TABLE characters (id TEXT NOT NULL, name TEXT NOT NULL, portrait_id TEXT NOT NULL, level INTEGER NOT NULL DEFAULT 1, total_xp INTEGER NOT NULL DEFAULT 0, attribute_xp TEXT NOT NULL DEFAULT '{}', gold INTEGER NOT NULL DEFAULT 0, materials TEXT NOT NULL DEFAULT '{}', unlocked_cosmetics TEXT NOT NULL DEFAULT '[]', titles TEXT NOT NULL DEFAULT '[]', hero_track_completions INTEGER NOT NULL DEFAULT 0, equipped_cosmetics TEXT NOT NULL DEFAULT '{}', created_at INTEGER NOT NULL, PRIMARY KEY (id))",
      "CREATE TABLE companions (id TEXT NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL, level INTEGER NOT NULL DEFAULT 1, total_xp INTEGER NOT NULL DEFAULT 0, bond INTEGER NOT NULL DEFAULT 0, tricks_unlocked TEXT NOT NULL DEFAULT '[]', gear_unlocked TEXT NOT NULL DEFAULT '[]', gear_equipped TEXT NULL, portrait_id TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at INTEGER NOT NULL, PRIMARY KEY (id))",
      "CREATE TABLE world_states (id TEXT NOT NULL, restoration_points INTEGER NOT NULL DEFAULT 0, region_state TEXT NOT NULL DEFAULT '{}', building_state TEXT NOT NULL DEFAULT '{}', npc_returned TEXT NOT NULL DEFAULT '{}', journey_paces INTEGER NOT NULL DEFAULT 0, discoveries_unlocked TEXT NOT NULL DEFAULT '[]', PRIMARY KEY (id))",
      "CREATE TABLE day_logs (id TEXT NOT NULL, day TEXT NOT NULL UNIQUE, dawn_generated_at INTEGER NOT NULL, campfire_at INTEGER NULL, day_note TEXT NOT NULL DEFAULT '', exported_at INTEGER NULL, bond_level_bonus_granted INTEGER NOT NULL DEFAULT 0 CHECK (bond_level_bonus_granted IN (0, 1)), sniff_out_granted INTEGER NOT NULL DEFAULT 0 CHECK (sniff_out_granted IN (0, 1)), fetch_granted INTEGER NOT NULL DEFAULT 0 CHECK (fetch_granted IN (0, 1)), quests_total INTEGER NULL, PRIMARY KEY (id))",
      "CREATE TABLE health_entries (id TEXT NOT NULL, day TEXT NOT NULL, field_key TEXT NOT NULL, value TEXT NOT NULL, unit TEXT NOT NULL DEFAULT '', PRIMARY KEY (id))",
      "INSERT INTO characters (id, name, portrait_id, level, total_xp, attribute_xp, gold, materials, titles, hero_track_completions, equipped_cosmetics, created_at) VALUES ('hero-1', 'Nhivanye', 'wayfarer', 1, 58, '{\"vitality\":35,\"care\":13,\"mind\":10}', 14, '{\"timber\":1,\"stone\":2,\"starShard\":1}', '[\"Newcomer to the Vale\"]', 3, '{\"frame\":\"traveller\"}', $epoch)",
      "INSERT INTO companions (id, name, kind, level, total_xp, bond, portrait_id, created_at) VALUES ('comp-1', 'Nhia', 'cat', 1, 25, 1, 'cat', $epoch)",
      "INSERT INTO world_states (id, journey_paces, discoveries_unlocked) VALUES ('world-1', 1, '[]')",
      "INSERT INTO quests (id, name, icon_key, attribute, difficulty, track, schedule_type, completion_type, source, sort_order, created_at, updated_at) VALUES ('q-check', 'Morning Health Check', 'sprig', 'vitality', 'minor', 'hero', 'daily', 'tap', 'recurring', 5, $epoch, $epoch)",
      "INSERT INTO quests (id, name, icon_key, attribute, difficulty, track, schedule_type, schedule_weekdays, completion_type, source, sort_order, created_at, updated_at) VALUES ('q-jab', 'Weekly Injection (Mounjaro)', 'vial', 'vitality', 'minor', 'hero', 'weekly', '6', 'tap', 'recurring', 60, $epoch, $epoch)",
      "INSERT INTO quests (id, name, icon_key, attribute, difficulty, track, schedule_type, completion_type, source, sort_order, created_at, updated_at) VALUES ('q-walk', 'Walk Nhia', 'paw', 'care', 'standard', 'shared', 'daily', 'tap', 'recurring', 10, $epoch, $epoch)",
      "INSERT INTO quests (id, name, icon_key, attribute, difficulty, track, schedule_type, completion_type, target, source, sort_order, created_at, updated_at) VALUES ('q-steps', '7,000 Steps', 'boot', 'vitality', 'standard', 'hero', 'daily', 'auto', 7000, 'health', 40, $epoch, $epoch)",
      "INSERT INTO quests (id, name, icon_key, attribute, difficulty, track, schedule_type, completion_type, source, system_key, sort_order, created_at, updated_at) VALUES ('q-fire', 'Campfire Review', 'campfire', 'mind', 'minor', 'hero', 'daily', 'tap', 'system', 'campfire', 900, $epoch, $epoch)",
      "INSERT INTO day_logs (id, day, dawn_generated_at, campfire_at, day_note, quests_total) VALUES ('day-1', '2026-11-13', $epoch, $epoch, 'First day.', 6)",
      "INSERT INTO completions (id, quest_id, day, completed_at, xp_awarded, companion_xp_awarded, paces_awarded, bond_awarded, gold_awarded, difficulty_snapshot, track_snapshot, attribute_snapshot, quest_name_snapshot, extras) VALUES ('c-1', 'q-walk', '2026-11-13', $epoch, 13, 25, 1, 1, 5, 'standard', 'shared', 'care', 'Walk Nhia', '{}')",
      "INSERT INTO health_entries (id, day, field_key, value, unit) VALUES ('h-1', '2026-11-13', 'glucose', '5.9', 'mmol/L')",
      'PRAGMA user_version = 2',
    ];

    test('gains a class column and an encounter column, both empty; a class '
        'can then be chosen and nothing earned moves', () async {
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            for (final statement in v2) {
              raw.execute(statement);
            }
          },
        ),
      );
      addTearDown(old.close);
      final upgraded = GameRepository(old, clock: () => now);
      final hero = (await upgraded.hero())!;
      expect(hero.classId, isNull);
      expect((await upgraded.dayLog('2026-11-13'))!.encounter, isNull);
      expect(await upgraded.encounterOn('2026-11-13'), isNull);

      await upgraded.setHeroClass(HeroClass.sage);
      final after = (await upgraded.hero())!;
      expect(after.classId, 'sage');
      expect(after.totalXp, hero.totalXp);
      expect(after.level, hero.level);
      expect(after.gold, hero.gold);
      expect(after.materials, hero.materials);
      expect(after.attributeXp, hero.attributeXp);
    });

    test('opens, keeps every row, and gains what Phase 3 adds', () async {
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            for (final statement in v2) {
              raw.execute(statement);
            }
          },
        ),
      );
      addTearDown(old.close);
      final upgraded = GameRepository(old, clock: () => now);

      // Everything that was there is still there.
      final hero = (await upgraded.hero())!;
      expect(hero.name, 'Nhivanye');
      expect(hero.totalXp, 58);
      expect(hero.gold, 14);
      expect(hero.equippedCosmetics, '{"frame":"traveller"}');
      final companion = (await upgraded.companion())!;
      expect(companion.name, 'Nhia');
      expect(companion.kind, CompanionKind.cat);
      expect(companion.bond, 1);
      expect((await upgraded.world())!.journeyPaces, 1);
      final log = (await upgraded.dayLog('2026-11-13'))!;
      expect(log.dayNote, 'First day.');
      expect(log.questsTotal, 6);
      expect((await upgraded.allCompletions()).single.xpAwarded, 13);
      expect(
        (await upgraded.healthEntriesOn('2026-11-13')).single.value,
        '5.9',
      );

      // The two seeded health quests gain their keys; nothing else changes.
      final quests = <String, QuestRow>{
        for (final q in await upgraded.allQuests()) q.id: q,
      };
      expect(quests.length, 5);
      expect(quests['q-check']!.systemKey, systemKeyHealthCheck);
      expect(quests['q-jab']!.systemKey, systemKeyInjection);
      expect(quests['q-walk']!.systemKey, isNull);
      expect(quests['q-steps']!.systemKey, isNull);
      expect(quests['q-fire']!.systemKey, systemKeyCampfire);

      // The new tables are there, empty, with every setting at its default.
      expect(await upgraded.delves(), isEmpty);
      expect(await upgraded.calendarChoicesOn('2026-11-13'), isEmpty);
      expect((await upgraded.settings()).delveWeekday, DateTime.sunday);

      // And play carries straight on with everything Phase 3 brings.
      await upgraded.ensureDawn();
      await upgraded.setDelveWeekday(DateTime.saturday);
      final completed = await upgraded.recordSteps(7200);
      expect(completed.single.questId, 'q-steps');
      expect((await upgraded.hero())!.totalXp, 83);
      await upgraded.acceptSuggestion(externalId: 'e1', title: 'Dentist');
      final result = (await upgraded.resolveDelve())!;
      expect(result.delveDay, '2026-11-14');
      expect((await upgraded.delves()).length, 1);
    });

    test('a seeded quest the user renamed is left as theirs', () async {
      final statements = <String>[
        for (final s in v2)
          s.replaceAll("'Morning Health Check'", "'Morning check-in'"),
      ];
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            for (final statement in statements) {
              raw.execute(statement);
            }
          },
        ),
      );
      addTearDown(old.close);
      final upgraded = GameRepository(old, clock: () => now);
      final quests = await upgraded.allQuests();
      expect(
        quests.firstWhere((q) => q.name == 'Morning check-in').systemKey,
        isNull,
      );
    });
  });
}
