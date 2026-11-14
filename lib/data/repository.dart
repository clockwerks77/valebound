import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../rules/companion_rules.dart';
import '../rules/day_cycle.dart';
import '../rules/day_key.dart';
import '../rules/enums.dart';
import '../rules/gear.dart';
import '../rules/journey.dart';
import '../rules/progression.dart';
import '../rules/schedule.dart';
import '../rules/world.dart';
import '../rules/xp_curve.dart';
import 'database.dart';
import 'seed.dart';

/// One quest as it stands on a given day's board.
class BoardQuest {
  const BoardQuest({required this.quest, this.progress, this.completion});

  final QuestRow quest;
  final QuestProgressRow? progress;
  final CompletionRow? completion;

  bool get isDone => completion != null;
  bool get isSetAside => progress?.setAside ?? false;
  bool get timerRunning => progress?.timerStartedAt != null;

  /// Count units, or timer seconds already banked (not counting a running
  /// stretch; see [timerSeconds]).
  int get banked => progress?.progress ?? 0;

  /// Timer seconds including the stretch that is running right now.
  int timerSeconds(DateTime now) {
    final started = progress?.timerStartedAt;
    if (started == null) return banked;
    final running = now.difference(started).inSeconds;
    return banked + (running < 0 ? 0 : running);
  }

  /// Timer target in seconds, or 0 when none is set.
  int get timerTargetSeconds => (quest.target ?? 0) * 60;
}

/// What the user fills in when creating or editing a quest (DESIGN §6.1).
class QuestDraft {
  QuestDraft({
    this.id,
    this.name = '',
    this.iconKey = 'star',
    this.attribute,
    this.difficulty = Difficulty.standard,
    this.track = Track.hero,
    this.schedule = const Schedule.daily(),
    this.completionType = CompletionType.tap,
    this.target,
    this.notes = '',
  });

  factory QuestDraft.fromRow(QuestRow q) => QuestDraft(
        id: q.id,
        name: q.name,
        iconKey: q.iconKey,
        attribute: q.attribute,
        difficulty: q.difficulty,
        track: q.track,
        schedule: scheduleOf(q),
        completionType: q.completionType,
        target: q.target,
        notes: q.notes,
      );

  String? id;
  String name;
  String iconKey;
  Attribute? attribute;
  Difficulty difficulty;
  Track track;
  Schedule schedule;
  CompletionType completionType;
  int? target;
  String notes;

  bool get isValid => name.trim().isNotEmpty && attribute != null;
}

/// A past day, for the Quest Log history. Information only, never a score.
class DaySummary {
  const DaySummary({
    required this.day,
    required this.quests,
    required this.heroXp,
    required this.companionXp,
    required this.paces,
  });
  final String day;
  final int quests;
  final int heroXp;
  final int companionXp;
  final int paces;
}

Schedule scheduleOf(QuestRow q) => Schedule(
      type: q.scheduleType,
      weekdays: Schedule.decodeWeekdays(q.scheduleWeekdays),
      intervalDays: q.scheduleIntervalDays,
      anchorDay: q.scheduleAnchorDay,
    );

Map<Attribute, int> decodeAttributeXp(String json) {
  final raw = jsonDecode(json) as Map<String, dynamic>;
  final out = <Attribute, int>{};
  for (final a in Attribute.values) {
    final v = raw[a.name];
    if (v is int) out[a] = v;
  }
  return out;
}

String encodeAttributeXp(Map<Attribute, int> xp) =>
    jsonEncode(<String, int>{for (final e in xp.entries) e.key.name: e.value});

Map<MaterialKind, int> decodeMaterials(String json) {
  final raw = jsonDecode(json) as Map<String, dynamic>;
  final out = <MaterialKind, int>{};
  for (final m in MaterialKind.values) {
    final v = raw[m.name];
    if (v is int) out[m] = v;
  }
  return out;
}

String encodeMaterials(Map<MaterialKind, int> materials) => jsonEncode(
      <String, int>{for (final e in materials.entries) e.key.name: e.value},
    );

List<String> decodeStringList(String json) =>
    (jsonDecode(json) as List<dynamic>).whereType<String>().toList();

/// A JSON object of string values, e.g. place key to the day it woke.
Map<String, String> decodeStringMap(String json) {
  final raw = jsonDecode(json);
  if (raw is! Map<String, dynamic>) return <String, String>{};
  return <String, String>{
    for (final e in raw.entries)
      if (e.value is String) e.key: e.value as String,
  };
}

Map<String, dynamic> decodeExtras(String json) {
  final raw = jsonDecode(json);
  return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
}

/// The outcome of reading a backup file.
class BackupResult {
  const BackupResult.ok()
      : ok = true,
        message = 'Backup restored.';
  const BackupResult.notUsable(this.message) : ok = false;
  final bool ok;
  final String message;
}

/// Identifies a backup file. Deliberately not the app's display name, which
/// may change (DESIGN: data must not depend on the name).
const String backupFormat = 'habit-adventure-backup';

/// All reads and writes go through here. Nothing in this class touches the
/// network; the only I/O is the local SQLite file.
class GameRepository {
  GameRepository(this.db, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() clock;

  static const Uuid _uuid = Uuid();
  String newId() => _uuid.v4();

  // ---- Party ---------------------------------------------------------

  Future<CharacterRow?> hero() =>
      (db.select(db.characters)..limit(1)).getSingleOrNull();

  Future<CompanionRow?> companion() => (db.select(db.companions)
        ..where((c) => c.isActive.equals(true))
        ..limit(1))
      .getSingleOrNull();

  Future<WorldStateRow?> world() =>
      (db.select(db.worldStates)..limit(1)).getSingleOrNull();

  Future<bool> hasProfile() async => (await hero()) != null;

  /// First-run setup: hero, companion, world and the seeded quests.
  Future<void> createProfile({
    required String heroName,
    required String portraitId,
    required String companionName,
    required CompanionKind companionKind,
    bool activateFiveMinuteReset = false,
  }) async {
    final now = clock();
    await db.transaction(() async {
      if (await hasProfile()) return;
      await db.into(db.characters).insert(
            CharactersCompanion.insert(
              id: newId(),
              name: heroName.trim(),
              portraitId: portraitId,
              titles: Value(jsonEncode(titlesEarned(1))),
              createdAt: now,
            ),
          );
      await db.into(db.companions).insert(
            CompanionsCompanion.insert(
              id: newId(),
              name: companionName.trim(),
              kind: companionKind,
              portraitId: companionKind.name,
              createdAt: now,
            ),
          );
      await db
          .into(db.worldStates)
          .insert(WorldStatesCompanion.insert(id: newId()));
      final seeds = seedQuests(
        now: now,
        newId: newId,
        activateFiveMinuteReset: activateFiveMinuteReset,
      );
      for (final seed in seeds) {
        await db.into(db.quests).insert(seed);
      }
    });
  }

  // ---- Days ----------------------------------------------------------

  Future<DayLogRow?> dayLog(String day) => (db.select(db.dayLogs)
        ..where((d) => d.day.equals(day))
        ..limit(1))
      .getSingleOrNull();

  Future<DayLogRow?> _latestDayLog() => (db.select(db.dayLogs)
        ..orderBy([(d) => OrderingTerm.desc(d.day)])
        ..limit(1))
      .getSingleOrNull();

  /// Opens today. On a new day this writes the day's log entry and retires
  /// one-off quests whose day has gone by. It never looks back at what was
  /// or was not done on earlier days (DESIGN §4.3, §6.4).
  Future<DawnPlan> ensureDawn() async {
    final now = clock();
    final last = await _latestDayLog();
    final plan = planDawn(lastDawnDay: last?.day, now: now);
    await db.transaction(() async {
      await db.into(db.dayLogs).insert(
            DayLogsCompanion.insert(
              id: newId(),
              day: plan.today,
              dawnGeneratedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      if (plan.isNewDay) {
        final oneOffs = await (db.select(db.quests)
              ..where(
                (q) =>
                    q.active.equals(true) &
                    q.scheduleType.equalsValue(ScheduleType.oneOff),
              ))
            .get();
        for (final q in oneOffs) {
          if (scheduleOf(q).isPastOneOff(plan.today)) {
            await (db.update(db.quests)..where((t) => t.id.equals(q.id)))
                .write(
              QuestsCompanion(
                active: const Value(false),
                updatedAt: Value(now),
              ),
            );
          }
        }
      }
    });
    return plan;
  }

  /// Today's quests with their progress and completions.
  Future<List<BoardQuest>> loadBoard(String day) async {
    final quests = await (db.select(db.quests)
          ..orderBy([
            (q) => OrderingTerm.asc(q.sortOrder),
            (q) => OrderingTerm.asc(q.createdAt),
          ]))
        .get();
    final completions =
        await (db.select(db.completions)..where((c) => c.day.equals(day)))
            .get();
    final progress =
        await (db.select(db.questProgress)..where((p) => p.day.equals(day)))
            .get();
    final doneByQuest = <String, CompletionRow>{
      for (final c in completions) c.questId: c,
    };
    final progressByQuest = <String, QuestProgressRow>{
      for (final p in progress) p.questId: p,
    };
    final out = <BoardQuest>[];
    for (final q in quests) {
      final done = doneByQuest[q.id];
      final due = q.active && scheduleOf(q).isDueOn(day);
      if (due || done != null) {
        out.add(
          BoardQuest(
            quest: q,
            progress: progressByQuest[q.id],
            completion: done,
          ),
        );
      }
    }
    return out;
  }

  // ---- Completing quests ---------------------------------------------

  Future<QuestRow?> questById(String id) => (db.select(db.quests)
        ..where((q) => q.id.equals(id))
        ..limit(1))
      .getSingleOrNull();

  Future<CompletionRow?> _completionFor(String questId, String day) =>
      (db.select(db.completions)
            ..where((c) => c.questId.equals(questId) & c.day.equals(day))
            ..limit(1))
          .getSingleOrNull();

  Future<QuestProgressRow?> _progressFor(String questId, String day) =>
      (db.select(db.questProgress)
            ..where((p) => p.questId.equals(questId) & p.day.equals(day))
            ..limit(1))
          .getSingleOrNull();

  /// Completes [questId] for today and applies every award in one
  /// transaction. Returns null if there is nothing to do (already complete
  /// today, or the quest is gone).
  ///
  /// [at] is when the quest was actually done, if that was a moment ago (a
  /// completion waits a few seconds so it can be undone).
  Future<CompletionOutcome?> completeQuest(
    String questId, {
    String? note,
    int? progress,
    DateTime? at,
  }) async {
    final now = at ?? clock();
    final day = DayKey.of(now);
    return db.transaction(() async {
      final quest = await questById(questId);
      final heroRow = await hero();
      final companionRow = await companion();
      final worldRow = await world();
      if (quest == null ||
          heroRow == null ||
          companionRow == null ||
          worldRow == null) {
        return null;
      }
      if (await _completionFor(questId, day) != null) return null;

      await db.into(db.dayLogs).insert(
            DayLogsCompanion.insert(id: newId(), day: day, dawnGeneratedAt: now),
            mode: InsertMode.insertOrIgnore,
          );
      final log = await dayLog(day);

      final totals = PartyTotals(
        heroXp: heroRow.totalXp,
        attributeXp: decodeAttributeXp(heroRow.attributeXp),
        companionXp: companionRow.totalXp,
        bond: companionRow.bond,
        paces: worldRow.journeyPaces,
        gold: heroRow.gold,
        materials: decodeMaterials(heroRow.materials),
        heroTrackCompletions: heroRow.heroTrackCompletions,
      );
      final outcome = applyCompletion(
        totals: totals,
        difficulty: quest.difficulty,
        track: quest.track,
        attribute: quest.attribute,
        bondLevelBonusGrantedToday: log?.bondLevelBonusGranted ?? false,
        sniffOutFind:
            (log?.sniffOutGranted ?? false) ? null : sniffOutMaterial(day),
        fetchAvailable: !(log?.fetchGranted ?? false),
      );
      final after = outcome.after;

      // Guard rails for DESIGN §6.4: stored totals may only ever grow.
      int grow(int stored, int next) => next > stored ? next : stored;

      final heroLevel = XpCurve.levelForXp(grow(heroRow.totalXp, after.heroXp));
      await (db.update(db.characters)..where((c) => c.id.equals(heroRow.id)))
          .write(
        CharactersCompanion(
          totalXp: Value(grow(heroRow.totalXp, after.heroXp)),
          level: Value(grow(heroRow.level, heroLevel)),
          attributeXp: Value(encodeAttributeXp(after.attributeXp)),
          gold: Value(grow(heroRow.gold, after.gold)),
          materials: Value(encodeMaterials(after.materials)),
          titles: Value(jsonEncode(titlesEarned(grow(heroRow.level, heroLevel)))),
          heroTrackCompletions: Value(after.heroTrackCompletions),
          unlockedCosmetics: Value(
            jsonEncode(
              cosmeticsUnlockedAt(
                heroLevel: grow(heroRow.level, heroLevel),
                restored: after.restored,
              ),
            ),
          ),
        ),
      );

      final companionLevel =
          XpCurve.levelForXp(grow(companionRow.totalXp, after.companionXp));
      await (db.update(db.companions)
            ..where((c) => c.id.equals(companionRow.id)))
          .write(
        CompanionsCompanion(
          totalXp: Value(grow(companionRow.totalXp, after.companionXp)),
          level: Value(grow(companionRow.level, companionLevel)),
          bond: Value(grow(companionRow.bond, after.bond)),
          tricksUnlocked: Value(
            jsonEncode(
              tricksUnlockedAt(grow(companionRow.level, companionLevel)),
            ),
          ),
          gearUnlocked: Value(
            jsonEncode(
              gearUnlockedAt(
                level: grow(companionRow.level, companionLevel),
                bond: grow(companionRow.bond, after.bond),
              ),
            ),
          ),
        ),
      );

      if (outcome.award.paces > 0) {
        final unlocked = decodeStringList(worldRow.discoveriesUnlocked);
        for (final i in outcome.newDiscoveryIndexes) {
          unlocked.add(sceneFor(i).key);
        }
        await (db.update(db.worldStates)
              ..where((w) => w.id.equals(worldRow.id)))
            .write(
          WorldStatesCompanion(
            journeyPaces: Value(grow(worldRow.journeyPaces, after.paces)),
            discoveriesUnlocked: Value(jsonEncode(unlocked)),
          ),
        );
      }
      if (outcome.newRestorationIndexes.isNotEmpty) {
        await _recordRestorations(worldRow, after.restored, day);
      }

      // Today's once-a-day grants, and the day now needs exporting again.
      if (log != null) {
        await (db.update(db.dayLogs)..where((d) => d.id.equals(log.id))).write(
          DayLogsCompanion(
            bondLevelBonusGranted:
                outcome.bondBonus > 0 ? const Value(true) : const Value.absent(),
            sniffOutGranted: outcome.sniffOutFound != null
                ? const Value(true)
                : const Value.absent(),
            fetchGranted: outcome.fetchCarried != null
                ? const Value(true)
                : const Value.absent(),
            exportedAt: const Value(null),
          ),
        );
      }

      final existingProgress = await _progressFor(questId, day);
      if (existingProgress?.timerStartedAt != null) {
        await (db.update(db.questProgress)
              ..where((p) => p.id.equals(existingProgress!.id)))
            .write(
          const QuestProgressCompanion(timerStartedAt: Value(null)),
        );
      }

      await db.into(db.completions).insert(
            CompletionsCompanion.insert(
              id: newId(),
              questId: quest.id,
              day: day,
              completedAt: now,
              xpAwarded: outcome.award.heroXp,
              companionXpAwarded: Value(outcome.award.companionXp),
              pacesAwarded: Value(outcome.award.paces),
              bondAwarded: Value(outcome.totalBond),
              goldAwarded: Value(outcome.award.gold),
              materialKind: Value(
                outcome.materialKind ?? outcome.sniffOutFound,
              ),
              materialAmount: Value(
                outcome.award.materials +
                    (outcome.sniffOutFound == null ? 0 : 1),
              ),
              difficultySnapshot: quest.difficulty,
              trackSnapshot: quest.track,
              attributeSnapshot: quest.attribute,
              questNameSnapshot: quest.name,
              progress: Value(progress ?? existingProgress?.progress),
              note: Value(
                (note == null || note.trim().isEmpty) ? null : note.trim(),
              ),
              extras: Value(
                jsonEncode(<String, Object>{
                  if (outcome.sniffOutFound != null)
                    'sniff': outcome.sniffOutFound!.name,
                  if (outcome.fetchCarried != null)
                    'fetch': outcome.fetchCarried!.name,
                  if (outcome.newRestorationIndexes.isNotEmpty)
                    'restored': <String>[
                      for (final i in outcome.newRestorationIndexes)
                        targetAt(i).key,
                    ],
                  if (outcome.newGear.isNotEmpty) 'gear': outcome.newGear,
                  if (outcome.newCosmetics.isNotEmpty)
                    'cosmetics': outcome.newCosmetics,
                }),
              ),
            ),
          );

      if (quest.systemKey == systemKeyCampfire && log != null) {
        await (db.update(db.dayLogs)..where((d) => d.id.equals(log.id)))
            .write(DayLogsCompanion(campfireAt: Value(now)));
      }

      if (quest.scheduleType == ScheduleType.oneOff) {
        await (db.update(db.quests)..where((q) => q.id.equals(quest.id)))
            .write(
          QuestsCompanion(active: const Value(false), updatedAt: Value(now)),
        );
      }
      return outcome;
    });
  }

  // ---- Partial progress ----------------------------------------------

  Future<QuestProgressRow> _ensureProgress(String questId, String day) async {
    final existing = await _progressFor(questId, day);
    if (existing != null) return existing;
    await db.into(db.questProgress).insert(
          QuestProgressCompanion.insert(id: newId(), questId: questId, day: day),
          mode: InsertMode.insertOrIgnore,
        );
    return (await _progressFor(questId, day))!;
  }

  /// Sets a count quest's progress for today (never below zero).
  Future<void> setCount(String questId, int value) async {
    final day = DayKey.of(clock());
    final row = await _ensureProgress(questId, day);
    await (db.update(db.questProgress)..where((p) => p.id.equals(row.id)))
        .write(QuestProgressCompanion(progress: Value(value < 0 ? 0 : value)));
  }

  Future<void> startTimer(String questId) async {
    final now = clock();
    final row = await _ensureProgress(questId, DayKey.of(now));
    if (row.timerStartedAt != null) return;
    await (db.update(db.questProgress)..where((p) => p.id.equals(row.id)))
        .write(QuestProgressCompanion(timerStartedAt: Value(now)));
  }

  /// Stops a running timer and banks the time it recorded.
  Future<void> pauseTimer(String questId) async {
    final now = clock();
    final row = await _ensureProgress(questId, DayKey.of(now));
    final started = row.timerStartedAt;
    if (started == null) return;
    final ran = now.difference(started).inSeconds;
    await (db.update(db.questProgress)..where((p) => p.id.equals(row.id)))
        .write(
      QuestProgressCompanion(
        progress: Value(row.progress + (ran < 0 ? 0 : ran)),
        timerStartedAt: const Value(null),
      ),
    );
  }

  /// Manual minutes entry for a timer quest.
  Future<void> addTimerMinutes(String questId, int minutes) async {
    if (minutes <= 0) return;
    final row = await _ensureProgress(questId, DayKey.of(clock()));
    await (db.update(db.questProgress)..where((p) => p.id.equals(row.id)))
        .write(
      QuestProgressCompanion(progress: Value(row.progress + minutes * 60)),
    );
  }

  /// Moves a quest to "Later" for today, or back to "Now".
  Future<void> setAside(String questId, {required bool aside}) async {
    final row = await _ensureProgress(questId, DayKey.of(clock()));
    await (db.update(db.questProgress)..where((p) => p.id.equals(row.id)))
        .write(QuestProgressCompanion(setAside: Value(aside)));
  }

  // ---- Quest Log -----------------------------------------------------

  Future<List<QuestRow>> allQuests() => (db.select(db.quests)
        ..orderBy([
          (q) => OrderingTerm.asc(q.sortOrder),
          (q) => OrderingTerm.asc(q.createdAt),
        ]))
      .get();

  /// Creates or updates a quest. Returns its id.
  Future<String> saveQuest(QuestDraft draft) async {
    final now = clock();
    final schedule = draft.schedule;
    final source = schedule.type == ScheduleType.oneOff
        ? QuestSource.manual
        : QuestSource.recurring;
    final id = draft.id;
    if (id == null) {
      final newQuestId = newId();
      await db.into(db.quests).insert(
            QuestsCompanion.insert(
              id: newQuestId,
              name: draft.name.trim(),
              iconKey: Value(draft.iconKey),
              attribute: draft.attribute!,
              difficulty: draft.difficulty,
              track: draft.track,
              scheduleType: schedule.type,
              scheduleWeekdays: Value(Schedule.encodeWeekdays(schedule.weekdays)),
              scheduleIntervalDays: Value(schedule.intervalDays),
              scheduleAnchorDay: Value(schedule.anchorDay),
              completionType: draft.completionType,
              target: Value(draft.target),
              notes: Value(draft.notes.trim()),
              source: source,
              sortOrder: const Value(100),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return newQuestId;
    }
    await (db.update(db.quests)..where((q) => q.id.equals(id))).write(
      QuestsCompanion(
        name: Value(draft.name.trim()),
        iconKey: Value(draft.iconKey),
        attribute: Value(draft.attribute!),
        difficulty: Value(draft.difficulty),
        track: Value(draft.track),
        scheduleType: Value(schedule.type),
        scheduleWeekdays: Value(Schedule.encodeWeekdays(schedule.weekdays)),
        scheduleIntervalDays: Value(schedule.intervalDays),
        scheduleAnchorDay: Value(schedule.anchorDay),
        completionType: Value(draft.completionType),
        target: Value(draft.target),
        notes: Value(draft.notes.trim()),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  Future<void> setQuestActive(String questId, {required bool active}) async {
    await (db.update(db.quests)..where((q) => q.id.equals(questId))).write(
      QuestsCompanion(active: Value(active), updatedAt: Value(clock())),
    );
  }

  Future<int> completionCount() async {
    final count = db.completions.id.count();
    final query = db.selectOnly(db.completions)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Past days that have at least one completion, newest first.
  Future<List<DaySummary>> history({int days = 60}) async {
    final rows = await (db.select(db.completions)
          ..orderBy([(c) => OrderingTerm.desc(c.day)]))
        .get();
    final byDay = <String, List<CompletionRow>>{};
    for (final r in rows) {
      byDay.putIfAbsent(r.day, () => <CompletionRow>[]).add(r);
    }
    final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return <DaySummary>[
      for (final k in keys.take(days))
        DaySummary(
          day: k,
          quests: byDay[k]!.length,
          heroXp: byDay[k]!.fold(0, (sum, c) => sum + c.xpAwarded),
          companionXp:
              byDay[k]!.fold(0, (sum, c) => sum + c.companionXpAwarded),
          paces: byDay[k]!.fold(0, (sum, c) => sum + c.pacesAwarded),
        ),
    ];
  }

  Future<List<CompletionRow>> completionsOn(String day) =>
      (db.select(db.completions)
            ..where((c) => c.day.equals(day))
            ..orderBy([(c) => OrderingTerm.asc(c.completedAt)]))
          .get();

  // ---- The world -----------------------------------------------------

  /// Writes down every place the gathered materials have restored that is
  /// not yet on record, dated [day].
  Future<void> _recordRestorations(
    WorldStateRow worldRow,
    int restored,
    String day,
  ) async {
    final buildings = decodeStringMap(worldRow.buildingState);
    final villagers = decodeStringMap(worldRow.npcReturned);
    for (var i = 0; i < restored; i++) {
      final target = targetAt(i);
      buildings.putIfAbsent(target.key, () => day);
      final v = target.villager;
      if (v != null) villagers.putIfAbsent(v.key, () => day);
    }
    final perRegion = <String, int>{};
    for (var i = 0; i < restored; i++) {
      final region = targetAt(i).region;
      perRegion[region] = (perRegion[region] ?? 0) + 1;
    }
    final points = restorationPointsFor(restored);
    await (db.update(db.worldStates)..where((w) => w.id.equals(worldRow.id)))
        .write(
      WorldStatesCompanion(
        restorationPoints: Value(
          points > worldRow.restorationPoints
              ? points
              : worldRow.restorationPoints,
        ),
        buildingState: Value(jsonEncode(buildings)),
        npcReturned: Value(jsonEncode(villagers)),
        regionState: Value(jsonEncode(perRegion)),
      ),
    );
  }

  /// Brings the world, gear and cosmetics on record into line with the
  /// totals already earned. Needed once after an update from a build that
  /// gathered materials before the map existed; harmless every other time.
  Future<void> syncWorld() async {
    final heroRow = await hero();
    final companionRow = await companion();
    final worldRow = await world();
    if (heroRow == null || companionRow == null || worldRow == null) return;
    final restored = restoredCount(decodeMaterials(heroRow.materials));
    final recorded = decodeStringMap(worldRow.buildingState).length;
    if (restored > recorded) {
      await _recordRestorations(worldRow, restored, DayKey.of(clock()));
    }
    final cosmetics = jsonEncode(
      cosmeticsUnlockedAt(heroLevel: heroRow.level, restored: restored),
    );
    if (cosmetics != heroRow.unlockedCosmetics) {
      await (db.update(db.characters)..where((c) => c.id.equals(heroRow.id)))
          .write(CharactersCompanion(unlockedCosmetics: Value(cosmetics)));
    }
    final gear = jsonEncode(
      gearUnlockedAt(level: companionRow.level, bond: companionRow.bond),
    );
    if (gear != companionRow.gearUnlocked) {
      await (db.update(db.companions)
            ..where((c) => c.id.equals(companionRow.id)))
          .write(CompanionsCompanion(gearUnlocked: Value(gear)));
    }
  }

  // ---- Campfire and the day ------------------------------------------

  Future<void> _touchDay(String day, DayLogsCompanion change) async {
    final now = clock();
    await db.into(db.dayLogs).insert(
          DayLogsCompanion.insert(id: newId(), day: day, dawnGeneratedAt: now),
          mode: InsertMode.insertOrIgnore,
        );
    await (db.update(db.dayLogs)..where((d) => d.day.equals(day)))
        .write(change.copyWith(exportedAt: const Value(null)));
  }

  /// Saves the day's free-text note, exactly as typed.
  Future<void> setDayNote(String day, String note) =>
      _touchDay(day, DayLogsCompanion(dayNote: Value(note)));

  /// Remembers how many quests were on the board on [day].
  Future<void> recordBoardSize(String day, int total) async {
    final log = await dayLog(day);
    if (log == null || log.questsTotal == total) return;
    await (db.update(db.dayLogs)..where((d) => d.id.equals(log.id)))
        .write(DayLogsCompanion(questsTotal: Value(total)));
  }

  /// Campfire (DESIGN §4.1 step 4): saves the note and completes the
  /// Campfire Review quest, which closes the day. Safe to call again later
  /// the same evening; the note is updated and nothing is awarded twice.
  Future<CompletionOutcome?> closeDay({required String note}) async {
    final day = DayKey.of(clock());
    await setDayNote(day, note);
    final campfire = await (db.select(db.quests)
          ..where((q) => q.systemKey.equals(systemKeyCampfire))
          ..limit(1))
        .getSingleOrNull();
    CompletionOutcome? outcome;
    if (campfire != null) {
      outcome = await completeQuest(campfire.id);
    }
    final log = await dayLog(day);
    if (log != null && log.campfireAt == null) {
      await (db.update(db.dayLogs)..where((d) => d.id.equals(log.id)))
          .write(DayLogsCompanion(campfireAt: Value(clock())));
    }
    return outcome;
  }

  // ---- Health entries (the quick-entry form arrives in Phase 3) -------

  Future<List<HealthEntryRow>> healthEntriesOn(String day) =>
      (db.select(db.healthEntries)
            ..where((h) => h.day.equals(day))
            ..orderBy([(h) => OrderingTerm.asc(h.fieldKey)]))
          .get();

  /// Stores exactly what was typed for [fieldKey] on [day]. An empty value
  /// clears the entry.
  Future<void> setHealthEntry(
    String day,
    String fieldKey,
    String value, {
    String unit = '',
  }) async {
    await (db.delete(db.healthEntries)
          ..where((h) => h.day.equals(day) & h.fieldKey.equals(fieldKey)))
        .go();
    if (value.trim().isNotEmpty) {
      await db.into(db.healthEntries).insert(
            HealthEntriesCompanion.insert(
              id: newId(),
              day: day,
              fieldKey: fieldKey,
              value: value.trim(),
              unit: Value(unit),
            ),
          );
    }
    await _touchDay(day, const DayLogsCompanion());
  }

  // ---- Settings ------------------------------------------------------

  Future<void> renameHero(String name) async {
    final heroRow = await hero();
    if (heroRow == null || name.trim().isEmpty) return;
    await (db.update(db.characters)..where((c) => c.id.equals(heroRow.id)))
        .write(CharactersCompanion(name: Value(name.trim())));
  }

  /// A new chapter (DESIGN §7A.1): the companion's kind and name can change
  /// at any time. XP, level, Bond, tricks, gear and history all carry over.
  Future<void> changeCompanion({
    required String name,
    required CompanionKind kind,
  }) async {
    final row = await companion();
    if (row == null || name.trim().isEmpty) return;
    await (db.update(db.companions)..where((c) => c.id.equals(row.id))).write(
      CompanionsCompanion(
        name: Value(name.trim()),
        kind: Value(kind),
        portraitId: Value(kind.name),
      ),
    );
  }

  /// Puts an unlocked frame or banner into use.
  Future<void> equipCosmetic(String key) async {
    final heroRow = await hero();
    final cosmetic = cosmeticByKey(key);
    if (heroRow == null || cosmetic == null) return;
    if (!decodeStringList(heroRow.unlockedCosmetics).contains(key)) return;
    final equipped = decodeStringMap(heroRow.equippedCosmetics);
    equipped[cosmetic.kind.name] = key;
    await (db.update(db.characters)..where((c) => c.id.equals(heroRow.id)))
        .write(CharactersCompanion(equippedCosmetics: Value(jsonEncode(equipped))));
  }

  /// Wears a piece of unlocked gear, or none when [key] is null.
  Future<void> equipGear(String? key) async {
    final row = await companion();
    if (row == null) return;
    if (key != null && !decodeStringList(row.gearUnlocked).contains(key)) {
      return;
    }
    await (db.update(db.companions)..where((c) => c.id.equals(row.id)))
        .write(CompanionsCompanion(gearEquipped: Value(key)));
  }

  // ---- Export support ------------------------------------------------

  Future<List<CompletionRow>> allCompletions() =>
      (db.select(db.completions)
            ..orderBy([(c) => OrderingTerm.asc(c.completedAt)]))
          .get();

  Future<List<DayLogRow>> allDayLogs() =>
      (db.select(db.dayLogs)..orderBy([(d) => OrderingTerm.asc(d.day)])).get();

  /// Days opened so far. Information only, never a score (DESIGN §6.4).
  Future<int> daysVisited() async {
    final count = db.dayLogs.id.count();
    final row =
        await (db.selectOnly(db.dayLogs)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> markExported(Iterable<String> days) async {
    final now = clock();
    for (final day in days) {
      await (db.update(db.dayLogs)..where((d) => d.day.equals(day)))
          .write(DayLogsCompanion(exportedAt: Value(now)));
    }
  }

  // ---- Backup (DESIGN §9.2) ------------------------------------------

  /// Everything in the database as one JSON document.
  Future<String> exportBackupJson() async {
    final tables = <String, List<Map<String, dynamic>>>{
      'quests': [for (final r in await db.select(db.quests).get()) r.toJson()],
      'completions': [
        for (final r in await db.select(db.completions).get()) r.toJson(),
      ],
      'questProgress': [
        for (final r in await db.select(db.questProgress).get()) r.toJson(),
      ],
      'characters': [
        for (final r in await db.select(db.characters).get()) r.toJson(),
      ],
      'companions': [
        for (final r in await db.select(db.companions).get()) r.toJson(),
      ],
      'worldStates': [
        for (final r in await db.select(db.worldStates).get()) r.toJson(),
      ],
      'dayLogs': [for (final r in await db.select(db.dayLogs).get()) r.toJson()],
      'healthEntries': [
        for (final r in await db.select(db.healthEntries).get()) r.toJson(),
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(<String, Object>{
      'format': backupFormat,
      'schema': db.schemaVersion,
      'exportedAt': clock().toIso8601String(),
      'tables': tables,
    });
  }

  /// Replaces everything on this device with the contents of a backup made
  /// by [exportBackupJson]. Nothing is changed unless the whole file reads
  /// cleanly.
  Future<BackupResult> importBackupJson(String source) async {
    const notABackup =
        BackupResult.notUsable('That file is not a backup from this app.');
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return notABackup;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != backupFormat ||
        decoded['tables'] is! Map<String, dynamic>) {
      return notABackup;
    }
    final schema = decoded['schema'];
    if (schema is! int || schema < 2) return notABackup;
    if (schema > db.schemaVersion) {
      return const BackupResult.notUsable(
        'This backup comes from a newer version of the app. Update the app, '
        'then restore it.',
      );
    }
    final tables = decoded['tables'] as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(String name) => <Map<String, dynamic>>[
          for (final r in (tables[name] as List<dynamic>? ?? const <dynamic>[]))
            if (r is Map<String, dynamic>) r,
        ];

    try {
      final quests = rows('quests').map(QuestRow.fromJson).toList();
      final completions =
          rows('completions').map(CompletionRow.fromJson).toList();
      final progress =
          rows('questProgress').map(QuestProgressRow.fromJson).toList();
      final characters = rows('characters').map(CharacterRow.fromJson).toList();
      final companions = rows('companions').map(CompanionRow.fromJson).toList();
      final worlds = rows('worldStates').map(WorldStateRow.fromJson).toList();
      final dayLogs = rows('dayLogs').map(DayLogRow.fromJson).toList();
      final health =
          rows('healthEntries').map(HealthEntryRow.fromJson).toList();
      if (characters.isEmpty || companions.isEmpty || worlds.isEmpty) {
        return notABackup;
      }
      await db.transaction(() async {
        for (final table in db.allTables) {
          await db.delete(table).go();
        }
        await db.batch((b) {
          b.insertAll(db.quests, quests);
          b.insertAll(db.completions, completions);
          b.insertAll(db.questProgress, progress);
          b.insertAll(db.characters, characters);
          b.insertAll(db.companions, companions);
          b.insertAll(db.worldStates, worlds);
          b.insertAll(db.dayLogs, dayLogs);
          b.insertAll(db.healthEntries, health);
        });
      });
    } on Object {
      // A row that does not fit the tables: leave everything as it was.
      return notABackup;
    }
    return const BackupResult.ok();
  }
}
