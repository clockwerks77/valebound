import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/data/database.dart';
import 'package:habit_adventure/data/repository.dart';
import 'package:habit_adventure/rules/daily_still.dart';
import 'package:habit_adventure/rules/day_key.dart';
import 'package:habit_adventure/rules/enums.dart';

// The day's Still creature in storage (DECISIONS D-70): the third quest of
// the day hands over its gift once, and a quiet day leaves no trace.

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 2026-11-14 is a Saturday.
  late DateTime now;
  late AppDatabase db;
  late GameRepository repo;

  Future<String> id(String name) async =>
      (await repo.allQuests()).firstWhere((q) => q.name == name).id;

  Future<void> nextDay() async {
    now = DateTime(now.year, now.month, now.day + 1, 8);
    await repo.ensureDawn();
  }

  setUp(() async {
    now = DateTime(2026, 11, 14, 8);
    db = AppDatabase(NativeDatabase.memory());
    repo = GameRepository(db, clock: () => now);
    await repo.createProfile(
      heroName: 'Adam',
      portraitId: 'wayfarer',
      companionName: 'Babs',
      companionKind: CompanionKind.hound,
      activateFiveMinuteReset: true,
    );
    await repo.ensureDawn();
  });

  tearDown(() => db.close());

  test('each quest stirs it and the third wakes it', () async {
    final day = DayKey.of(now);
    var today = await repo.dailyStillOn(day);
    expect(today.still.creature.key, dailyStillFor(day).key);
    expect(today.still.stirs, 0);
    expect(today.still.awake, isFalse);
    expect(today.gift, isNull);

    // Morning Health Check: 2 gold, 1 Timber. Steps: 5 gold, 2 Stone.
    final first = await repo.completeQuest(await id('Morning Health Check'));
    final second = await repo.completeQuest(await id('7,000 Steps'));
    expect(first!.wokeDailyStill, isFalse);
    expect(second!.wokeDailyStill, isFalse);
    today = await repo.dailyStillOn(day);
    expect(today.still.stirs, 2);
    expect(today.still.awake, isFalse);
    expect((await repo.hero())!.gold, 7);

    // Walk Babs: 5 gold, and the creature wakes.
    final third = await repo.completeQuest(await id('Walk Babs'));
    expect(third!.wokeDailyStill, isTrue);
    // The Gate Lantern asks for two Timber and had one.
    expect(third.dailyStillGift, MaterialKind.timber);
    expect((await repo.hero())!.gold, 12 + dailyStillGold);
    expect(
      decodeMaterials((await repo.hero())!.materials)[MaterialKind.timber],
      2,
    );

    today = await repo.dailyStillOn(day);
    expect(today.still.stirs, 3);
    expect(today.still.awake, isTrue);
    expect(today.gift, MaterialKind.timber);

    final woke = (await repo.completionsOn(day))
        .where((c) => dailyStillGiftOf(c) != null)
        .single;
    expect(decodeExtras(woke.extras)[dailyStillExtra], <String, dynamic>{
      'creature': dailyStillFor(day).key,
      'gold': dailyStillGold,
      'material': 'timber',
    });
  });

  test('it wakes once: later quests that day bring only their own reward',
      () async {
    await repo.completeQuest(await id('Morning Health Check'));
    await repo.completeQuest(await id('7,000 Steps'));
    await repo.completeQuest(await id('Walk Babs'));
    final gold = (await repo.hero())!.gold;

    // Play / Train with Babs is Minor: 2 gold.
    final fourth = await repo.completeQuest(await id('Play / Train with Babs'));
    expect(fourth!.wokeDailyStill, isFalse);
    expect((await repo.hero())!.gold, gold + 2);
    expect((await repo.dailyStillOn(DayKey.of(now))).still.awake, isTrue);
  });

  test('its gift gives no XP', () async {
    await repo.completeQuest(await id('Morning Health Check'));
    await repo.completeQuest(await id('7,000 Steps'));
    final before = (await repo.hero())!.totalXp;
    final third = await repo.completeQuest(await id('Campfire Review'));
    // Campfire Review is Minor: 10 XP, and nothing on top.
    expect(third!.wokeDailyStill, isTrue);
    expect((await repo.hero())!.totalXp, before + 10);
  });

  test('its gift can wake a place, on record for that day', () async {
    // Timber 1, Stone 2, then a Shard, and the gift is the second Timber.
    await repo.completeQuest(await id('Morning Health Check'));
    await repo.completeQuest(await id('7,000 Steps'));
    final third = await repo.completeQuest(await id('Campfire Review'));
    expect(third!.newRestorationIndexes, <int>[0]);
    expect(
      decodeStringMap((await repo.world())!.buildingState),
      <String, String>{'gate_lantern': '2026-11-14'},
    );
  });

  test('a quiet day leaves no trace, and tomorrow has another creature',
      () async {
    await repo.completeQuest(await id('Morning Health Check'));
    await repo.completeQuest(await id('Walk Babs'));
    final quiet = await repo.dailyStillOn('2026-11-14');
    expect(quiet.still.awake, isFalse);
    expect(quiet.gift, isNull);
    final heroBefore = (await repo.hero())!;

    await nextDay();
    final next = await repo.dailyStillOn('2026-11-15');
    expect(next.still.stirs, 0);
    expect(next.still.awake, isFalse);
    expect(next.still.creature.key, isNot(quiet.still.creature.key));
    // Nothing was taken overnight and nothing was written down.
    final heroAfter = (await repo.hero())!;
    expect(heroAfter.gold, heroBefore.gold);
    expect(heroAfter.materials, heroBefore.materials);
    for (final c in await repo.completionsOn('2026-11-14')) {
      expect(dailyStillGiftOf(c), isNull);
    }
  });

  test('the gift survives a backup and restore', () async {
    await repo.completeQuest(await id('Morning Health Check'));
    await repo.completeQuest(await id('7,000 Steps'));
    await repo.completeQuest(await id('Walk Babs'));
    final backup = await repo.exportBackupJson();

    final otherDb = AppDatabase(NativeDatabase.memory());
    addTearDown(otherDb.close);
    final other = GameRepository(otherDb, clock: () => now);
    expect((await other.importBackupJson(backup)).ok, isTrue);
    final today = await other.dailyStillOn('2026-11-14');
    expect(today.still.awake, isTrue);
    expect(today.gift, MaterialKind.timber);
    expect((await other.hero())!.gold, (await repo.hero())!.gold);
  });
}
