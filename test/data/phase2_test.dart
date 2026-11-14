import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/rules/day_key.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/world.dart';

// Phase 2 storage: restoration on record, Fetch, gear, Campfire, settings,
// the JSON backup, and the upgrade from the Phase 1 database.

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

  Future<String> id(String name) async =>
      (await repo.allQuests()).firstWhere((q) => q.name == name).id;

  Future<void> nextDay() async {
    now = DateTime(now.year, now.month, now.day + 1, 8);
    await repo.ensureDawn();
  }

  setUp(() {
    now = DateTime(2026, 11, 14, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: () => now);
  });

  tearDown(() => db.close());

  group('Restoration on record (DESIGN §3A)', () {
    test('the quest that brings the last material wakes the place', () async {
      await start();
      // Morning Health Check: 1 Timber. Steps: 2 Stone. Campfire: 1 Shard.
      final first = await repo.completeQuest(await id('Morning Health Check'));
      expect(first!.newRestorationIndexes, isEmpty);
      await repo.completeQuest(await id('7,000 Steps'));
      await repo.completeQuest(await id('Campfire Review'));
      expect(decodeStringMap((await repo.world())!.buildingState), isEmpty);

      await nextDay();
      // The fourth hero quest drops Timber again: 2 Timber, 2 Stone in all.
      final wakes = await repo.completeQuest(await id('Morning Health Check'));
      expect(wakes!.newRestorationIndexes, <int>[0]);

      final world = (await repo.world())!;
      expect(decodeStringMap(world.buildingState), <String, String>{
        'gate_lantern': '2026-11-15',
      });
      expect(decodeStringMap(world.npcReturned), <String, String>{
        'wick': '2026-11-15',
      });
      expect(world.restorationPoints, 3);
      expect(jsonDecode(world.regionState), <String, dynamic>{'hearthmere': 1});

      final hero = (await repo.hero())!;
      // Gathered totals never go down; the stores are worked out from them.
      expect(decodeMaterials(hero.materials)[MaterialKind.timber], 2);
      expect(inStores(decodeMaterials(hero.materials))[MaterialKind.timber], 0);

      final completions = await repo.completionsOn('2026-11-15');
      expect(decodeExtras(completions.single.extras)['restored'], <String>[
        'gate_lantern',
      ]);
    });

    test('a restored place stays restored whatever happens next', () async {
      await start();
      for (var day = 0; day < 6; day++) {
        await repo.completeQuest(await id('Morning Health Check'));
        await repo.completeQuest(await id('7,000 Steps'));
        await nextDay();
      }
      final before = decodeStringMap((await repo.world())!.buildingState);
      expect(before, isNotEmpty);
      // A fortnight away.
      now = now.add(const Duration(days: 14));
      await repo.ensureDawn();
      await repo.syncWorld();
      final after = decodeStringMap((await repo.world())!.buildingState);
      expect(after, before);
    });

    test('syncWorld records what earlier totals already restored', () async {
      await start();
      final hero = (await repo.hero())!;
      // As if gathered before the map existed: enough for the first two.
      await (db.update(db.characters)..where((c) => c.id.equals(hero.id)))
          .write(
        CharactersCompanion(
          materials: Value(
            encodeMaterials(<MaterialKind, int>{
              MaterialKind.timber: 4,
              MaterialKind.stone: 6,
              MaterialKind.starShard: 1,
            }),
          ),
        ),
      );
      await repo.syncWorld();
      final world = (await repo.world())!;
      expect(decodeStringMap(world.buildingState).keys, <String>[
        'gate_lantern',
        'village_well',
      ]);
      expect(world.restorationPoints, 10);
      expect(
        decodeStringList((await repo.hero())!.unlockedCosmetics),
        contains('bunting'),
      );
      // Running it again changes nothing.
      await repo.syncWorld();
      expect((await repo.world())!.buildingState, world.buildingState);
    });
  });

  group('Tricks and gear (DESIGN §7A.3)', () {
    Future<void> setCompanion({int? xp, int? level, int? bond}) async {
      final c = (await repo.companion())!;
      await (db.update(db.companions)..where((t) => t.id.equals(c.id))).write(
        CompanionsCompanion(
          totalXp: xp == null ? const Value.absent() : Value(xp),
          level: level == null ? const Value.absent() : Value(level),
          bond: bond == null ? const Value.absent() : Value(bond),
        ),
      );
    }

    test('Fetch carries one material a day once the companion is level 4',
        () async {
      await start();
      await setCompanion(xp: 900, level: 4);
      final first = await repo.completeQuest(await id('Walk Babs'));
      expect(first!.fetchCarried, MaterialKind.timber);
      now = now.add(const Duration(hours: 1));
      final second =
          await repo.completeQuest(await id('Play / Train with Babs'));
      expect(second!.fetchCarried, isNull, reason: 'once a day');
      expect((await repo.dayLog(DayKey.of(now)))!.fetchGranted, isTrue);

      final completions = await repo.completionsOn(DayKey.of(now));
      expect(decodeExtras(completions.first.extras)['fetch'], 'timber');
      expect(decodeExtras(completions.last.extras).containsKey('fetch'), isFalse);

      await nextDay();
      final tomorrow = await repo.completeQuest(await id('Walk Babs'));
      expect(tomorrow!.fetchCarried, isNotNull, reason: 'and again tomorrow');
    });

    test('a Bond milestone brings a gift, kept on the companion', () async {
      await start();
      await setCompanion(bond: 9);
      final outcome = await repo.completeQuest(await id('Walk Babs'));
      expect(outcome!.newGear, <String>['moss_neckerchief']);
      expect(
        decodeStringList((await repo.companion())!.gearUnlocked),
        <String>['moss_neckerchief'],
      );
    });

    test('only gear that has been found can be worn', () async {
      await start();
      await repo.equipGear('moss_neckerchief');
      expect((await repo.companion())!.gearEquipped, isNull);
      await setCompanion(bond: 10);
      await repo.syncWorld();
      await repo.equipGear('moss_neckerchief');
      expect((await repo.companion())!.gearEquipped, 'moss_neckerchief');
      await repo.equipGear(null);
      expect((await repo.companion())!.gearEquipped, isNull);
    });

    test('a frame or banner can be used once unlocked, never before', () async {
      await start();
      await repo.syncWorld();
      await repo.equipCosmetic('oak');
      expect(
        decodeStringMap((await repo.hero())!.equippedCosmetics),
        isEmpty,
        reason: 'the Oak Frame unlocks at level 3',
      );
      final hero = (await repo.hero())!;
      await (db.update(db.characters)..where((c) => c.id.equals(hero.id)))
          .write(const CharactersCompanion(level: Value(3), totalXp: Value(380)));
      await repo.syncWorld();
      await repo.equipCosmetic('oak');
      await repo.equipCosmetic('dawn');
      expect(
        decodeStringMap((await repo.hero())!.equippedCosmetics),
        <String, String>{'frame': 'oak', 'banner': 'dawn'},
      );
    });
  });

  group('Campfire (DESIGN §4.1)', () {
    test('closing the day saves the note and completes the Campfire quest',
        () async {
      await start();
      now = DateTime(2026, 11, 14, 21, 30);
      const note = 'Line one.\n\n  - indented, kept as typed  ';
      final outcome = await repo.closeDay(note: note);
      expect(outcome, isNotNull);
      expect(outcome!.award.heroXp, 10);
      final log = (await repo.dayLog('2026-11-14'))!;
      expect(log.dayNote, note, reason: 'verbatim');
      expect(log.campfireAt, DateTime(2026, 11, 14, 21, 30));
      expect((await repo.hero())!.totalXp, 10);
    });

    test('the note can be changed afterwards; nothing is awarded twice',
        () async {
      await start();
      await repo.closeDay(note: 'First thoughts.');
      final again = await repo.closeDay(note: 'Second thoughts.');
      expect(again, isNull);
      expect((await repo.dayLog('2026-11-14'))!.dayNote, 'Second thoughts.');
      expect((await repo.hero())!.totalXp, 10);
      expect((await repo.completionsOn('2026-11-14')).length, 1);
    });

    test('every change to a day puts it back in the export queue', () async {
      await start();
      await repo.completeQuest(await id('Walk Babs'));
      await repo.markExported(<String>['2026-11-14']);
      expect((await repo.dayLog('2026-11-14'))!.exportedAt, isNotNull);

      await repo.completeQuest(await id('7,000 Steps'));
      expect((await repo.dayLog('2026-11-14'))!.exportedAt, isNull);

      await repo.markExported(<String>['2026-11-14']);
      await repo.setDayNote('2026-11-14', 'A note.');
      expect((await repo.dayLog('2026-11-14'))!.exportedAt, isNull);

      await repo.markExported(<String>['2026-11-14']);
      await repo.setHealthEntry('2026-11-14', 'steps', '8214');
      expect((await repo.dayLog('2026-11-14'))!.exportedAt, isNull);
    });
  });

  group('A completion can be recorded at the moment it was tapped', () {
    test('a tap just before midnight stays on its own day', () async {
      await start();
      final tapped = DateTime(2026, 11, 14, 23, 59, 58);
      now = DateTime(2026, 11, 15, 0, 0, 3);
      await repo.completeQuest(await id('Walk Babs'), at: tapped);
      final done = await repo.completionsOn('2026-11-14');
      expect(done.single.completedAt, tapped);
      expect(await repo.completionsOn('2026-11-15'), isEmpty);
    });
  });

  group('Health entries (form arrives in Phase 3)', () {
    test('stores exactly what was typed; an empty value clears it', () async {
      await start();
      await repo.setHealthEntry('2026-11-14', 'glucose', ' 5.8 ', unit: 'mmol/L');
      await repo.setHealthEntry('2026-11-14', 'steps', '8214');
      var entries = await repo.healthEntriesOn('2026-11-14');
      expect(entries.map((e) => '${e.fieldKey}=${e.value} ${e.unit}'.trim()), <String>[
        'glucose=5.8 mmol/L',
        'steps=8214',
      ]);
      await repo.setHealthEntry('2026-11-14', 'glucose', '6.1', unit: 'mmol/L');
      await repo.setHealthEntry('2026-11-14', 'steps', '');
      entries = await repo.healthEntriesOn('2026-11-14');
      expect(entries.single.value, '6.1');
    });
  });

  group('Settings: a new chapter (DESIGN §7A.1)', () {
    test('changing the companion’s kind and name keeps everything earned',
        () async {
      await start();
      await repo.completeQuest(await id('Walk Babs'));
      await repo.completeQuest(await id('Play / Train with Babs'));
      final before = (await repo.companion())!;
      final paces = (await repo.world())!.journeyPaces;

      await repo.changeCompanion(name: ' Tock ', kind: CompanionKind.clockworkSprite);
      final after = (await repo.companion())!;
      expect(after.id, before.id, reason: 'the same companion');
      expect(after.name, 'Tock');
      expect(after.kind, CompanionKind.clockworkSprite);
      expect(after.totalXp, before.totalXp);
      expect(after.level, before.level);
      expect(after.bond, before.bond);
      expect(after.tricksUnlocked, before.tricksUnlocked);
      expect(after.gearUnlocked, before.gearUnlocked);
      expect((await repo.world())!.journeyPaces, paces);
      expect((await repo.completionsOn('2026-11-14')).length, 2);

      await repo.changeCompanion(name: '   ', kind: CompanionKind.owl);
      expect((await repo.companion())!.name, 'Tock', reason: 'a name is needed');
    });

    test('the hero can be renamed', () async {
      await start();
      await repo.renameHero('  Adam S  ');
      expect((await repo.hero())!.name, 'Adam S');
      await repo.renameHero('');
      expect((await repo.hero())!.name, 'Adam S');
    });
  });

  group('JSON backup (DESIGN §9.2)', () {
    Future<void> play() async {
      await start();
      await repo.completeQuest(await id('Morning Health Check'));
      await repo.completeQuest(await id('Walk Babs'));
      await repo.setCount(await id('7,000 Steps'), 4200);
      await repo.setHealthEntry('2026-11-14', 'glucose', '5.8', unit: 'mmol/L');
      await repo.closeDay(note: 'A good day.');
    }

    test('a backup restores into an empty app exactly', () async {
      await play();
      final backup = await repo.exportBackupJson();
      expect(jsonDecode(backup)['format'], backupFormat);
      expect(jsonDecode(backup)['schema'], 2);

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final fresh = GameRepository(other, clock: () => now);
      final result = await fresh.importBackupJson(backup);
      expect(result.ok, isTrue, reason: result.message);

      expect((await fresh.hero())!.toJson(), (await repo.hero())!.toJson());
      expect(
        (await fresh.companion())!.toJson(),
        (await repo.companion())!.toJson(),
      );
      expect((await fresh.world())!.toJson(), (await repo.world())!.toJson());
      expect((await fresh.allQuests()).length, (await repo.allQuests()).length);
      expect(
        (await fresh.allCompletions()).map((c) => c.toJson()).toList(),
        (await repo.allCompletions()).map((c) => c.toJson()).toList(),
      );
      expect((await fresh.dayLog('2026-11-14'))!.dayNote, 'A good day.');
      expect((await fresh.healthEntriesOn('2026-11-14')).single.value, '5.8');
      // And the round trip is stable.
      expect(await fresh.exportBackupJson(), backup);
    });

    test('restoring replaces what was on the device', () async {
      await play();
      final backup = await repo.exportBackupJson();
      await nextDay();
      await repo.completeQuest(await id('Walk Babs'));
      expect((await repo.allCompletions()).length, 4);
      final result = await repo.importBackupJson(backup);
      expect(result.ok, isTrue);
      expect((await repo.allCompletions()).length, 3);
    });

    test('a file that is not a backup changes nothing', () async {
      await play();
      final before = await repo.exportBackupJson();
      for (final bad in <String>[
        'not json at all',
        '{"format":"something-else","schema":2,"tables":{}}',
        '{"format":"$backupFormat","schema":2,"tables":{}}',
        '{"format":"$backupFormat","schema":2,"tables":{"characters":[{"id":7}]}}',
        '[1,2,3]',
      ]) {
        final result = await repo.importBackupJson(bad);
        expect(result.ok, isFalse, reason: bad);
        expect(result.message, isNotEmpty);
        expect(await repo.exportBackupJson(), before, reason: bad);
      }
    });

    test('a backup from a newer version is declined, kindly', () async {
      await play();
      final newer = jsonDecode(await repo.exportBackupJson()) as Map<String, dynamic>;
      newer['schema'] = 99;
      final before = await repo.exportBackupJson();
      final result = await repo.importBackupJson(jsonEncode(newer));
      expect(result.ok, isFalse);
      expect(result.message, contains('newer version'));
      expect(await repo.exportBackupJson(), before);
    });
  });

  group('Upgrade from the Phase 1 database (DESIGN §9.2)', () {
    // The tables exactly as schema 1 created them, with a day of play.
    const epoch = 1794650400; // 2026-11-14 10:00 UTC, in seconds.
    const v1 = <String>[
      "CREATE TABLE quests (id TEXT NOT NULL, name TEXT NOT NULL, icon_key TEXT NOT NULL DEFAULT 'star', attribute TEXT NOT NULL, difficulty TEXT NOT NULL, track TEXT NOT NULL, schedule_type TEXT NOT NULL, schedule_weekdays TEXT NOT NULL DEFAULT '', schedule_interval_days INTEGER NULL, schedule_anchor_day TEXT NULL, completion_type TEXT NOT NULL, target INTEGER NULL, reminder_time TEXT NULL, notes TEXT NOT NULL DEFAULT '', active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)), source TEXT NOT NULL, external_id TEXT NULL, system_key TEXT NULL, sort_order INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY (id))",
      'CREATE TABLE completions (id TEXT NOT NULL, quest_id TEXT NOT NULL, day TEXT NOT NULL, completed_at INTEGER NOT NULL, xp_awarded INTEGER NOT NULL, companion_xp_awarded INTEGER NOT NULL DEFAULT 0, paces_awarded INTEGER NOT NULL DEFAULT 0, bond_awarded INTEGER NOT NULL DEFAULT 0, gold_awarded INTEGER NOT NULL DEFAULT 0, material_kind TEXT NULL, material_amount INTEGER NOT NULL DEFAULT 0, difficulty_snapshot TEXT NOT NULL, track_snapshot TEXT NOT NULL, attribute_snapshot TEXT NOT NULL, quest_name_snapshot TEXT NOT NULL, progress INTEGER NULL, note TEXT NULL, PRIMARY KEY (id))',
      'CREATE TABLE quest_progress (id TEXT NOT NULL, quest_id TEXT NOT NULL, day TEXT NOT NULL, progress INTEGER NOT NULL DEFAULT 0, timer_started_at INTEGER NULL, set_aside INTEGER NOT NULL DEFAULT 0 CHECK (set_aside IN (0, 1)), PRIMARY KEY (id), UNIQUE (quest_id, day))',
      "CREATE TABLE characters (id TEXT NOT NULL, name TEXT NOT NULL, portrait_id TEXT NOT NULL, level INTEGER NOT NULL DEFAULT 1, total_xp INTEGER NOT NULL DEFAULT 0, attribute_xp TEXT NOT NULL DEFAULT '{}', gold INTEGER NOT NULL DEFAULT 0, materials TEXT NOT NULL DEFAULT '{}', unlocked_cosmetics TEXT NOT NULL DEFAULT '[]', titles TEXT NOT NULL DEFAULT '[]', hero_track_completions INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, PRIMARY KEY (id))",
      "CREATE TABLE companions (id TEXT NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL, level INTEGER NOT NULL DEFAULT 1, total_xp INTEGER NOT NULL DEFAULT 0, bond INTEGER NOT NULL DEFAULT 0, tricks_unlocked TEXT NOT NULL DEFAULT '[]', gear_unlocked TEXT NOT NULL DEFAULT '[]', portrait_id TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at INTEGER NOT NULL, PRIMARY KEY (id))",
      "CREATE TABLE world_states (id TEXT NOT NULL, restoration_points INTEGER NOT NULL DEFAULT 0, region_state TEXT NOT NULL DEFAULT '{}', building_state TEXT NOT NULL DEFAULT '{}', npc_returned TEXT NOT NULL DEFAULT '{}', journey_paces INTEGER NOT NULL DEFAULT 0, discoveries_unlocked TEXT NOT NULL DEFAULT '[]', PRIMARY KEY (id))",
      "CREATE TABLE day_logs (id TEXT NOT NULL, day TEXT NOT NULL UNIQUE, dawn_generated_at INTEGER NOT NULL, campfire_at INTEGER NULL, day_note TEXT NOT NULL DEFAULT '', exported_at INTEGER NULL, bond_level_bonus_granted INTEGER NOT NULL DEFAULT 0 CHECK (bond_level_bonus_granted IN (0, 1)), sniff_out_granted INTEGER NOT NULL DEFAULT 0 CHECK (sniff_out_granted IN (0, 1)), PRIMARY KEY (id))",
      "CREATE TABLE health_entries (id TEXT NOT NULL, day TEXT NOT NULL, field_key TEXT NOT NULL, value TEXT NOT NULL, unit TEXT NOT NULL DEFAULT '', PRIMARY KEY (id))",
      "INSERT INTO characters (id, name, portrait_id, level, total_xp, attribute_xp, gold, materials, titles, hero_track_completions, created_at) VALUES ('hero-1', 'Adam', 'wayfarer', 2, 148, '{\"vitality\":110,\"care\":38}', 31, '{\"timber\":3,\"stone\":4,\"starShard\":2}', '[\"Newcomer to the Vale\",\"Lantern Bearer\"]', 9, $epoch)",
      "INSERT INTO companions (id, name, kind, level, total_xp, bond, tricks_unlocked, portrait_id, created_at) VALUES ('comp-1', 'Babs', 'hound', 2, 135, 9, '[\"sniff_out\"]', 'hound', $epoch)",
      "INSERT INTO world_states (id, journey_paces, discoveries_unlocked) VALUES ('world-1', 6, '[]')",
      "INSERT INTO quests (id, name, icon_key, attribute, difficulty, track, schedule_type, completion_type, source, sort_order, created_at, updated_at) VALUES ('q-walk', 'Walk Babs', 'paw', 'care', 'standard', 'shared', 'daily', 'tap', 'recurring', 10, $epoch, $epoch)",
      "INSERT INTO quests (id, name, icon_key, attribute, difficulty, track, schedule_type, completion_type, source, system_key, sort_order, created_at, updated_at) VALUES ('q-fire', 'Campfire Review', 'campfire', 'mind', 'minor', 'hero', 'daily', 'tap', 'system', 'campfire', 900, $epoch, $epoch)",
      "INSERT INTO day_logs (id, day, dawn_generated_at, sniff_out_granted) VALUES ('day-1', '2026-11-13', $epoch, 1)",
      "INSERT INTO completions (id, quest_id, day, completed_at, xp_awarded, companion_xp_awarded, paces_awarded, bond_awarded, gold_awarded, difficulty_snapshot, track_snapshot, attribute_snapshot, quest_name_snapshot) VALUES ('c-1', 'q-walk', '2026-11-13', $epoch, 13, 25, 1, 1, 5, 'standard', 'shared', 'care', 'Walk Babs')",
      'PRAGMA user_version = 1',
    ];

    test('opens, keeps every row, and carries on', () async {
      final old = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            for (final statement in v1) {
              raw.execute(statement);
            }
          },
        ),
      );
      addTearDown(old.close);
      final upgraded = GameRepository(old, clock: () => now);

      // Everything that was there is still there.
      final hero = (await upgraded.hero())!;
      expect(hero.name, 'Adam');
      expect(hero.totalXp, 148);
      expect(hero.level, 2);
      expect(hero.gold, 31);
      expect(decodeMaterials(hero.materials)[MaterialKind.stone], 4);
      final companion = (await upgraded.companion())!;
      expect(companion.name, 'Babs');
      expect(companion.kind, CompanionKind.hound);
      expect(companion.totalXp, 135);
      expect(companion.bond, 9);
      expect((await upgraded.world())!.journeyPaces, 6);
      expect((await upgraded.allQuests()).map((q) => q.name), <String>[
        'Walk Babs',
        'Campfire Review',
      ]);
      final completion = (await upgraded.allCompletions()).single;
      expect(completion.questNameSnapshot, 'Walk Babs');
      expect(completion.xpAwarded, 13);

      // The new columns are there with their defaults.
      expect(completion.extras, '{}');
      expect(hero.equippedCosmetics, '{}');
      expect(companion.gearEquipped, isNull);
      final log = (await upgraded.dayLog('2026-11-13'))!;
      expect(log.fetchGranted, isFalse);
      expect(log.sniffOutGranted, isTrue);
      expect(log.questsTotal, isNull);

      // Materials gathered before the map existed already count.
      await upgraded.ensureDawn();
      await upgraded.syncWorld();
      expect(
        decodeStringMap((await upgraded.world())!.buildingState).keys,
        <String>['gate_lantern'],
      );

      // And play carries straight on: Bond 9 → 10 brings the first gift.
      final outcome = await upgraded.completeQuest('q-walk');
      expect(outcome!.newGear, <String>['moss_neckerchief']);
      expect((await upgraded.companion())!.totalXp, 160);
      expect((await upgraded.hero())!.totalXp, 161);
      await upgraded.closeDay(note: 'Still here.');
      expect((await upgraded.dayLog('2026-11-14'))!.dayNote, 'Still here.');
    });
  });
}
