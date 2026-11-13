import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/data/seed.dart';
import 'package:habit_adventure/rules/day_key.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/schedule.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 2026-11-14 is a Saturday.
  late DateTime now;
  late AppDatabase db;
  late GameRepository repo;

  Future<void> start({bool activateReset = false}) async {
    await repo.createProfile(
      heroName: 'Adam',
      portraitId: 'wayfarer',
      companionName: 'Babs',
      companionKind: CompanionKind.hound,
      activateFiveMinuteReset: activateReset,
    );
    await repo.ensureDawn();
  }

  Future<QuestRow> questNamed(String name) async {
    final all = await repo.allQuests();
    return all.firstWhere((q) => q.name == name);
  }

  Future<List<String>> boardNames() async {
    final board = await repo.loadBoard(DayKey.of(now));
    return board.map((b) => b.quest.name).toList();
  }

  setUp(() {
    now = DateTime(2026, 11, 14, 8, 30);
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: () => now);
  });

  tearDown(() async {
    await db.close();
  });

  group('First run (DESIGN §12)', () {
    test('seeds the quests from the design, editable and archivable', () async {
      await start();
      final quests = await repo.allQuests();
      final names = quests.map((q) => q.name).toSet();
      expect(
        names,
        containsAll(<String>[
          'Walk Babs',
          'Play / Train with Babs',
          'Five-Minute Reset',
          '7,000 Steps',
          'Painting / Craft Block',
          'Morning Health Check',
          'Weekly Injection (Mounjaro)',
          'Campfire Review',
        ]),
      );

      final walk = await questNamed('Walk Babs');
      expect(walk.track, Track.shared);
      expect(walk.attribute, Attribute.care);
      expect(walk.difficulty, Difficulty.standard);
      expect(walk.completionType, CompletionType.tap);

      final play = await questNamed('Play / Train with Babs');
      expect(play.track, Track.companion);
      expect(play.completionType, CompletionType.timer);
      expect(play.target, 10);

      final reset = await questNamed('Five-Minute Reset');
      expect(reset.active, isFalse, reason: 'seeded inactive');
      expect(reset.track, Track.companion);
      expect(reset.attribute, Attribute.order);

      final steps = await questNamed('7,000 Steps');
      expect(steps.completionType, CompletionType.auto);
      expect(steps.target, 7000);

      final injection = await questNamed('Weekly Injection (Mounjaro)');
      expect(scheduleOf(injection).describe(), 'Weekly, Saturday');

      final campfire = await questNamed('Campfire Review');
      expect(campfire.systemKey, systemKeyCampfire);
      expect(campfire.source, QuestSource.system);

      // Every entity carries a UUID.
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (final q in quests) {
        expect(uuid.hasMatch(q.id), isTrue);
      }
      expect(uuid.hasMatch((await repo.hero())!.id), isTrue);
      expect(uuid.hasMatch((await repo.companion())!.id), isTrue);
      expect(uuid.hasMatch((await repo.world())!.id), isTrue);
    });

    test('creates the hero and the chosen companion', () async {
      await start();
      final hero = (await repo.hero())!;
      final companion = (await repo.companion())!;
      expect(hero.name, 'Adam');
      expect(hero.level, 1);
      expect(hero.totalXp, 0);
      expect(companion.name, 'Babs');
      expect(companion.kind, CompanionKind.hound);
      expect(companion.level, 1);
      expect(companion.bond, 0);
    });

    test('onboarding can activate Five-Minute Reset', () async {
      await start(activateReset: true);
      expect((await questNamed('Five-Minute Reset')).active, isTrue);
      expect(await boardNames(), contains('Five-Minute Reset'));
    });

    test('creating the profile twice changes nothing', () async {
      await start();
      final before = (await repo.allQuests()).length;
      await start();
      expect((await repo.allQuests()).length, before);
    });
  });

  group('Today’s board', () {
    test('Saturday shows the weekly and weekend quests', () async {
      await start();
      final names = await boardNames();
      expect(names, contains('Weekly Injection (Mounjaro)'));
      expect(names, contains('Painting / Craft Block'));
      expect(names, contains('Walk Babs'));
      expect(names, isNot(contains('Five-Minute Reset')));
    });

    test('Monday does not', () async {
      now = DateTime(2026, 11, 16, 8);
      await start();
      final names = await boardNames();
      expect(names, isNot(contains('Weekly Injection (Mounjaro)')));
      expect(names, isNot(contains('Painting / Craft Block')));
      expect(names, contains('Walk Babs'));
      expect(names, contains('7,000 Steps'));
    });
  });

  group('Completing quests', () {
    test('Walk Babs: full Companion XP + half hero Care XP, Bond and a Pace',
        () async {
      await start();
      final walk = await questNamed('Walk Babs');
      final outcome = await repo.completeQuest(walk.id);
      expect(outcome, isNotNull);

      final hero = (await repo.hero())!;
      final companion = (await repo.companion())!;
      final world = (await repo.world())!;
      expect(companion.totalXp, 25);
      expect(hero.totalXp, 13);
      expect(decodeAttributeXp(hero.attributeXp)[Attribute.care], 13);
      expect(companion.bond, 1);
      expect(world.journeyPaces, 1);

      final rows = await repo.completionsOn(DayKey.of(now));
      expect(rows.length, 1);
      final row = rows.single;
      expect(row.trackSnapshot, Track.shared);
      expect(row.xpAwarded, 13);
      expect(row.companionXpAwarded, 25);
      expect(row.pacesAwarded, 1);
      expect(row.difficultySnapshot, Difficulty.standard);
      expect(row.questNameSnapshot, 'Walk Babs');
    });

    test('a Companion quest awards Companion XP only', () async {
      await start();
      final play = await questNamed('Play / Train with Babs');
      await repo.completeQuest(play.id);
      final hero = (await repo.hero())!;
      final companion = (await repo.companion())!;
      expect(hero.totalXp, 0);
      expect(decodeAttributeXp(hero.attributeXp), isEmpty);
      expect(companion.totalXp, 10);
      expect(companion.bond, 1);
    });

    test('a Hero quest awards hero XP, attribute XP, gold and materials',
        () async {
      await start();
      final steps = await questNamed('7,000 Steps');
      await repo.completeQuest(steps.id);
      final hero = (await repo.hero())!;
      expect(hero.totalXp, 25);
      expect(decodeAttributeXp(hero.attributeXp)[Attribute.vitality], 25);
      expect(hero.gold, 5);
      expect(decodeMaterials(hero.materials)[MaterialKind.timber], 2);
      expect((await repo.companion())!.totalXp, 0);
      expect((await repo.world())!.journeyPaces, 0);
    });

    test('a quest completes once a day', () async {
      await start();
      final walk = await questNamed('Walk Babs');
      expect(await repo.completeQuest(walk.id), isNotNull);
      expect(await repo.completeQuest(walk.id), isNull);
      expect((await repo.companion())!.totalXp, 25);
      expect((await repo.completionsOn(DayKey.of(now))).length, 1);
    });

    test('level-up at 100 XP, with the title list kept current', () async {
      await start();
      // Heroic craft block (60) + steps (25) + health check (10) = 95.
      await repo.completeQuest((await questNamed('Painting / Craft Block')).id);
      await repo.completeQuest((await questNamed('7,000 Steps')).id);
      await repo.completeQuest((await questNamed('Morning Health Check')).id);
      expect((await repo.hero())!.level, 1);
      expect((await repo.hero())!.totalXp, 95);
      // Weekly injection (10) → 105.
      final outcome = await repo.completeQuest(
        (await questNamed('Weekly Injection (Mounjaro)')).id,
        note: '5 mg',
      );
      expect(outcome!.heroLevelledUp, isTrue);
      final hero = (await repo.hero())!;
      expect(hero.level, 2);
      expect(hero.totalXp, 105);
      expect(decodeStringList(hero.titles), contains('Lantern Bearer'));
      final rows = await repo.completionsOn(DayKey.of(now));
      final injection = rows.firstWhere(
        (r) => r.questNameSnapshot == 'Weekly Injection (Mounjaro)',
      );
      expect(injection.note, '5 mg');
    });

    test('companion level-up unlocks tricks and gives the Bond bonus once',
        () async {
      await start();
      // Raise the companion to 90 XP directly, then complete a 25 XP quest.
      final companion = (await repo.companion())!;
      await (db.update(db.companions)
            ..where((c) => c.id.equals(companion.id)))
          .write(const CompanionsCompanion(totalXp: Value(90)));
      final outcome =
          await repo.completeQuest((await questNamed('Walk Babs')).id);
      expect(outcome!.companionLevelledUp, isTrue);
      var after = (await repo.companion())!;
      expect(after.level, 2);
      expect(after.bond, 1 + 3);
      expect(decodeStringList(after.tricksUnlocked), <String>['sniff_out']);
      expect((await repo.dayLog(DayKey.of(now)))!.bondLevelBonusGranted, isTrue);

      // A second companion quest the same day adds 1 Bond, no second bonus.
      await repo.completeQuest((await questNamed('Play / Train with Babs')).id);
      after = (await repo.companion())!;
      expect(after.bond, 1 + 3 + 1);
    });

    test('ten Paces unlock the first Discovery, in order', () async {
      await start();
      final world = (await repo.world())!;
      await (db.update(db.worldStates)..where((w) => w.id.equals(world.id)))
          .write(const WorldStatesCompanion(journeyPaces: Value(9)));
      final outcome =
          await repo.completeQuest((await questNamed('Walk Babs')).id);
      expect(outcome!.newDiscoveryIndexes, <int>[0]);
      final after = (await repo.world())!;
      expect(after.journeyPaces, 10);
      expect(decodeStringList(after.discoveriesUnlocked), <String>[
        'standing_stone',
      ]);
    });

    test('Campfire Review closes the day', () async {
      await start();
      expect((await repo.dayLog(DayKey.of(now)))!.campfireAt, isNull);
      await repo.completeQuest((await questNamed('Campfire Review')).id);
      expect((await repo.dayLog(DayKey.of(now)))!.campfireAt, isNotNull);
    });
  });

  group('Count and timer progress', () {
    test('count progress persists through the day', () async {
      await start();
      final id = await repo.saveQuest(
        QuestDraft(
          name: 'Glasses of water',
          attribute: Attribute.vitality,
          completionType: CompletionType.count,
          target: 8,
        ),
      );
      await repo.setCount(id, 3);
      var board = await repo.loadBoard(DayKey.of(now));
      expect(board.firstWhere((b) => b.quest.id == id).banked, 3);
      await repo.setCount(id, -4);
      board = await repo.loadBoard(DayKey.of(now));
      expect(board.firstWhere((b) => b.quest.id == id).banked, 0);
    });

    test('a timer banks the time it ran and survives a pause', () async {
      await start();
      final play = await questNamed('Play / Train with Babs');
      await repo.startTimer(play.id);
      now = now.add(const Duration(minutes: 4));
      var board = await repo.loadBoard(DayKey.of(now));
      var entry = board.firstWhere((b) => b.quest.id == play.id);
      expect(entry.timerRunning, isTrue);
      expect(entry.timerSeconds(now), 240);

      await repo.pauseTimer(play.id);
      now = now.add(const Duration(minutes: 30));
      board = await repo.loadBoard(DayKey.of(now));
      entry = board.firstWhere((b) => b.quest.id == play.id);
      expect(entry.timerRunning, isFalse);
      expect(entry.timerSeconds(now), 240, reason: 'paused time is not counted');

      await repo.addTimerMinutes(play.id, 2);
      board = await repo.loadBoard(DayKey.of(now));
      entry = board.firstWhere((b) => b.quest.id == play.id);
      expect(entry.timerSeconds(now), 360);
      expect(entry.timerTargetSeconds, 600);

      // "Count it anyway": the user is the referee.
      final outcome = await repo.completeQuest(play.id, progress: 360);
      expect(outcome, isNotNull);
      expect((await repo.completionsOn(DayKey.of(now))).single.progress, 360);
    });

    test('a quest can be set aside for later today', () async {
      await start();
      final steps = await questNamed('7,000 Steps');
      await repo.setAside(steps.id, aside: true);
      var board = await repo.loadBoard(DayKey.of(now));
      expect(board.firstWhere((b) => b.quest.id == steps.id).isSetAside, isTrue);
      await repo.setAside(steps.id, aside: false);
      board = await repo.loadBoard(DayKey.of(now));
      expect(board.firstWhere((b) => b.quest.id == steps.id).isSetAside, isFalse);
    });
  });

  group('Quest Log', () {
    test('create, edit, archive and restore', () async {
      await start();
      final id = await repo.saveQuest(
        QuestDraft(
          name: '  Water the fern ',
          attribute: Attribute.care,
          difficulty: Difficulty.minor,
          track: Track.companion,
        ),
      );
      var quest = (await repo.questById(id))!;
      expect(quest.name, 'Water the fern');
      expect(quest.track, Track.companion);
      expect(quest.source, QuestSource.recurring);
      expect(await boardNames(), contains('Water the fern'));

      final draft = QuestDraft.fromRow(quest)
        ..name = 'Water the ferns'
        ..track = Track.hero
        ..schedule = const Schedule.workdays();
      await repo.saveQuest(draft);
      quest = (await repo.questById(id))!;
      expect(quest.name, 'Water the ferns');
      expect(quest.track, Track.hero);
      expect(scheduleOf(quest).describe(), 'Weekdays');

      await repo.setQuestActive(id, active: false);
      expect((await repo.questById(id))!.active, isFalse);
      await repo.setQuestActive(id, active: true);
      expect((await repo.questById(id))!.active, isTrue);
    });

    test('an ad-hoc quest for today can be completed straight away', () async {
      await start();
      final today = DayKey.of(now);
      final id = await repo.saveQuest(
        QuestDraft(
          name: 'Fixed the gate latch',
          attribute: Attribute.craft,
          schedule: Schedule.once(today),
        ),
      );
      expect((await repo.questById(id))!.source, QuestSource.manual);
      await repo.completeQuest(id);
      final board = await repo.loadBoard(today);
      final entry = board.firstWhere((b) => b.quest.id == id);
      expect(entry.isDone, isTrue, reason: 'stays in Done for the day');
      expect((await repo.questById(id))!.active, isFalse);
    });
  });

  group('Time away (DESIGN §4.3, §6.4)', () {
    test('missing days changes nothing except those days', () async {
      await start();
      final walk = await questNamed('Walk Babs');
      final steps = await questNamed('7,000 Steps');
      final play = await questNamed('Play / Train with Babs');
      await repo.completeQuest(walk.id);
      await repo.completeQuest(steps.id);
      await repo.startTimer(play.id);
      now = now.add(const Duration(minutes: 3));
      await repo.pauseTimer(play.id);

      final heroBefore = (await repo.hero())!;
      final companionBefore = (await repo.companion())!;
      final worldBefore = (await repo.world())!;

      // Five days later.
      now = DateTime(2026, 11, 19, 7, 45);
      final plan = await repo.ensureDawn();
      expect(plan.isNewDay, isTrue);
      expect(plan.fullDaysAway, 4);
      expect(plan.comebackDue, isTrue);

      final hero = (await repo.hero())!;
      final companion = (await repo.companion())!;
      final world = (await repo.world())!;
      expect(hero.totalXp, heroBefore.totalXp);
      expect(hero.level, heroBefore.level);
      expect(hero.attributeXp, heroBefore.attributeXp);
      expect(hero.gold, heroBefore.gold);
      expect(hero.materials, heroBefore.materials);
      expect(companion.totalXp, companionBefore.totalXp);
      expect(companion.level, companionBefore.level);
      expect(companion.bond, companionBefore.bond);
      expect(world.journeyPaces, worldBefore.journeyPaces);
      expect(world.restorationPoints, worldBefore.restorationPoints);

      // Nothing was written for the days in between.
      for (final day in <String>['2026-11-15', '2026-11-16', '2026-11-17', '2026-11-18']) {
        expect(await repo.completionsOn(day), isEmpty);
        expect(await repo.dayLog(day), isNull);
      }
      expect((await repo.history()).map((d) => d.day), <String>['2026-11-14']);

      // The new day starts clean: nothing done, no progress carried over.
      final board = await repo.loadBoard(DayKey.of(now));
      expect(board, isNotEmpty);
      for (final entry in board) {
        expect(entry.isDone, isFalse);
        expect(entry.banked, 0);
        expect(entry.timerRunning, isFalse);
      }
      // Recurring quests are all still active.
      expect((await repo.questById(walk.id))!.active, isTrue);
      expect((await repo.questById(play.id))!.active, isTrue);
    });

    test('an undone one-off simply retires; no record is kept of it',
        () async {
      await start();
      final id = await repo.saveQuest(
        QuestDraft(
          name: 'Post the parcel',
          attribute: Attribute.order,
          schedule: Schedule.once(DayKey.of(now)),
        ),
      );
      now = DateTime(2026, 11, 15, 9);
      await repo.ensureDawn();
      expect((await repo.questById(id))!.active, isFalse);
      expect(await boardNames(), isNot(contains('Post the parcel')));
      final completions = await db.select(db.completions).get();
      expect(completions.where((c) => c.questId == id), isEmpty);
    });

    test('opening the next day is just a new day', () async {
      await start();
      now = DateTime(2026, 11, 15, 6);
      final plan = await repo.ensureDawn();
      expect(plan.isNewDay, isTrue);
      expect(plan.comebackDue, isFalse);
      expect(await repo.dayLog('2026-11-15'), isNotNull);
    });
  });

  group('Persistence across restart (DESIGN §9.2)', () {
    test('progress is still there after the database is closed and reopened',
        () async {
      final dir = await Directory.systemTemp.createTemp('habit_adventure_test');
      final file = File('${dir.path}/restart.sqlite');
      addTearDown(() => dir.delete(recursive: true));

      var fileDb = AppDatabase(NativeDatabase(file));
      var fileRepo = GameRepository(fileDb, clock: () => now);
      await fileRepo.createProfile(
        heroName: 'Adam',
        portraitId: 'wayfarer',
        companionName: 'Babs',
        companionKind: CompanionKind.hound,
      );
      await fileRepo.ensureDawn();
      final walk = (await fileRepo.allQuests())
          .firstWhere((q) => q.name == 'Walk Babs');
      await fileRepo.completeQuest(walk.id);
      final customId = await fileRepo.saveQuest(
        QuestDraft(name: 'Read a chapter', attribute: Attribute.mind),
      );
      await fileDb.close();

      fileDb = AppDatabase(NativeDatabase(file));
      fileRepo = GameRepository(fileDb, clock: () => now);
      expect(await fileRepo.hasProfile(), isTrue);
      expect((await fileRepo.hero())!.totalXp, 13);
      expect((await fileRepo.companion())!.name, 'Babs');
      expect((await fileRepo.companion())!.totalXp, 25);
      expect((await fileRepo.world())!.journeyPaces, 1);
      expect((await fileRepo.questById(customId))!.name, 'Read a chapter');
      final board = await fileRepo.loadBoard(DayKey.of(now));
      expect(board.firstWhere((b) => b.quest.id == walk.id).isDone, isTrue);
      expect(await fileRepo.completionCount(), 1);
      await fileDb.close();
    });
  });
}
