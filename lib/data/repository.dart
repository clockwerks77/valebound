import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../rules/classes.dart';
import '../rules/combat.dart';
import '../rules/companion_rules.dart';
import '../rules/daily_still.dart';
import '../rules/day_cycle.dart';
import '../rules/day_key.dart';
import '../rules/delve.dart';
import '../rules/encounter.dart';
import '../rules/enums.dart';
import '../rules/gear.dart';
import '../rules/health_fields.dart';
import '../rules/journey.dart';
import '../rules/progression.dart';
import '../rules/checkin.dart';
import '../rules/first_dawn.dart';
import '../rules/goals.dart';
import '../rules/schedule.dart';
import '../rules/world.dart';
import '../rules/xp_curve.dart';
import 'database.dart';
import 'seed.dart';
import 'settings.dart';

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
/// Key in a completion's `extras` for the gift the day's Still creature
/// left on the quest that woke it (DECISIONS D-70).
const String dailyStillExtra = 'dailyStill';

/// Keys in a completion's `extras` (Amendment v0.4 §8): the size a habit
/// was done at, the For-line it carried, and what kind of thing it came
/// from.
const String sizeExtra = 'size';
const String forExtra = 'for';
const String sourceExtra = 'source';

/// The size a completion was done at, or null for a quest with no sizes.
QuestSize? sizeOf(CompletionRow c) =>
    QuestSize.byName(decodeExtras(c.extras)[sizeExtra] as String?);

/// The For-line a completion carried, or empty for one from before 0.8.
String forLineOf(CompletionRow c) =>
    '${decodeExtras(c.extras)[forExtra] ?? ''}';

/// The source kind a completion recorded, or empty.
String sourceOf(CompletionRow c) =>
    '${decodeExtras(c.extras)[sourceExtra] ?? ''}';

/// The material the day's Still creature left on [c], or null when [c] is
/// not the quest that woke it.
MaterialKind? dailyStillGiftOf(CompletionRow c) {
  if (!c.extras.contains(dailyStillExtra)) return null;
  try {
    final extras = jsonDecode(c.extras);
    final gift = extras is Map ? extras[dailyStillExtra] : null;
    final name = gift is Map ? gift['material'] : null;
    for (final kind in MaterialKind.values) {
      if (kind.name == name) return kind;
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// The day's Still creature as it stands, with its gift once it has woken.
class DailyStillToday {
  const DailyStillToday(this.still, this.gift);
  final DailyStill still;
  final MaterialKind? gift;
}

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
    this.reminderTime,
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
        reminderTime: q.reminderTime,
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

  /// `HH:mm`, or null for no reminder (the default, DESIGN §6.1).
  String? reminderTime;

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

/// An Auto quest the app completed by itself when the day's steps reached
/// its target.
class AutoCompletion {
  const AutoCompletion(this.questId, this.outcome);
  final String questId;
  final CompletionOutcome outcome;
}

/// The weekly Delve, waiting to be entered at the Campfire.
class DelveWaiting {
  const DelveWaiting({
    required this.delveDay,
    required this.site,
    required this.supplies,
  });

  /// The day that closes the week.
  final String delveDay;
  final String site;
  final DelveSupplies supplies;

  DelveTier get tier => tierFor(supplies);
  DelveReward get reward => rewardFor(tier);
}

/// What came of entering the Delve.
class DelveResult {
  const DelveResult({
    required this.delveDay,
    required this.site,
    required this.supplies,
    required this.tier,
    required this.reward,
    required this.newRestorationIndexes,
  });

  final String delveDay;
  final String site;
  final DelveSupplies supplies;
  final DelveTier tier;
  final DelveReward reward;

  /// Zero-based indexes of the places the Delve's materials restored.
  final List<int> newRestorationIndexes;
}

/// What came of a day's fight, once it is written down.
class EncounterOutcome {
  const EncounterOutcome({
    required this.record,
    required this.enemy,
    required this.newRestorationIndexes,
    required this.heroLevel,
    required this.heroLevelBefore,
    required this.companionLevel,
    required this.companionLevelBefore,
    required this.marks,
  });

  final EncounterRecord record;
  final EnemyTemplate enemy;

  /// Zero-based indexes of the places the chest's materials restored.
  final List<int> newRestorationIndexes;
  final int heroLevel;
  final int heroLevelBefore;
  final int companionLevel;
  final int companionLevelBefore;

  /// Boss Marks in hand afterwards.
  final int marks;
}

/// What came of the week's attempt on the boss.
class BossOutcome {
  const BossOutcome({
    required this.boss,
    required this.woken,
    required this.left,
    required this.newRestorationIndexes,
    this.title,
  });

  final BossTemplate boss;

  /// It has been worn all the way down and has woken.
  final bool woken;

  /// What it has left for next week.
  final int left;
  final List<int> newRestorationIndexes;

  /// The title its waking earned, the first time.
  final String? title;
}

/// Calendar choices, as stored.
const String choiceAccepted = 'accepted';
const String choiceDismissed = 'dismissed';

/// Name used when a calendar event has no title of its own (DESIGN §12
/// item 3).
const String commitmentFallbackName = 'Today’s Commitment';

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
      // A new hero is asked about their goals once the story has been
      // told (Amendment v0.4 §3).
      if ((await settings()).firstDawn == null) {
        await setFirstDawn(FirstDawnState.fresh);
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
      if (plan.comebackDue) await _offerComeback(plan.today, now);
    });
    return plan;
  }

  /// Puts the single "Return to the Vale" quest on today's board (DESIGN
  /// §4.3). One row is kept and re-dated each time, so the Quest Log never
  /// fills with old welcomes. Nothing about the days away is recorded.
  Future<void> _offerComeback(String today, DateTime now) async {
    final existing = await (db.select(db.quests)
          ..where((q) => q.systemKey.equals(systemKeyComeback))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.quests)..where((q) => q.id.equals(existing.id)))
          .write(
        QuestsCompanion(
          scheduleAnchorDay: Value(today),
          active: const Value(true),
          updatedAt: Value(now),
        ),
      );
      return;
    }
    await db.into(db.quests).insert(
          QuestsCompanion.insert(
            id: newId(),
            name: comebackQuestName,
            iconKey: const Value('lantern'),
            attribute: Attribute.adventure,
            difficulty: Difficulty.minor,
            track: Track.hero,
            scheduleType: ScheduleType.oneOff,
            scheduleAnchorDay: Value(today),
            completionType: CompletionType.tap,
            source: QuestSource.system,
            systemKey: const Value(systemKeyComeback),
            sortOrder: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Today's quests with their progress and completions.
  Future<List<BoardQuest>> loadBoard(
    String day, {
    Set<String> alsoDue = const <String>{},
  }) async {
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
      final due =
          q.active && (scheduleOf(q).isDueOn(day) || alsoDue.contains(q.id));
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
    QuestSize? size,
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

      // A habit plan's quest is done at one of three sizes, and is worth
      // what that size is worth (Amendment v0.4 §4). Anything else is
      // worth what the quest says.
      final prefs = await settings();
      HabitPlan? plan;
      for (final p in prefs.plans) {
        if (p.id == quest.planId) plan = p;
      }
      final doneSize = plan == null
          ? null
          : (size ??
              plan.defaultSize(day, restDay: prefs.rhythm.isRestDay(day)));
      final worth = plan == null || doneSize == null
          ? quest.difficulty
          : plan.difficultyFor(doneSize);
      final kind = sourceKindOf(
        source: quest.source,
        systemKey: quest.systemKey,
        goalId: quest.goalId,
        planId: quest.planId,
      );
      Goal? goal;
      for (final g in prefs.goals) {
        if (g.id == (plan?.goalId ?? quest.goalId)) goal = g;
      }
      final fromCalendar = kind == SourceKind.calendar ||
          kind == SourceKind.prep ||
          kind == SourceKind.followThrough;
      // A calendar event's title is not written into the log unless the
      // user has asked for that (Amendment v0.4 §8).
      final String loggedName;
      if (plan != null && doneSize != null) {
        loggedName = doneSize == QuestSize.target
            ? targetTextOn(plan, prefs.rhythm.calibrationOn(day))
            : plan.textFor(doneSize);
      } else if (fromCalendar && !prefs.exportEventNames) {
        loggedName = calendarStandIn(kind);
      } else {
        loggedName = quest.name;
      }
      final loggedFor = forLine(
        kind: kind,
        goal: goal,
        anchor: plan?.anchor ?? '',
        calendarTime: kind == SourceKind.calendar ? quest.notes : '',
        systemKey: quest.systemKey ?? '',
      );

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
      final doneToday = await completionsOn(day);
      final outcome = applyCompletion(
        totals: totals,
        difficulty: worth,
        track: quest.track,
        attribute: quest.attribute,
        bondLevelBonusGrantedToday: log?.bondLevelBonusGranted ?? false,
        sniffOutFind:
            (log?.sniffOutGranted ?? false) ? null : sniffOutMaterial(day),
        fetchAvailable: !(log?.fetchGranted ?? false),
        // The welcome back (DESIGN §4.3), warmer still once the companion
        // knows Comfort (§7A.3).
        bonusHeroXp: quest.systemKey == systemKeyComeback ? comebackBonusXp : 0,
        bonusBond: quest.systemKey == systemKeyComeback &&
                companionRow.level >= comfortLevel
            ? comfortBonusBond
            : 0,
        // Since 0.7 the day's creature is met in a fight, not woken by
        // the third quest (Amendment v0.3; D-70 is retired).
        wakeDailyStill: false,
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
              xpAwarded: outcome.heroXpGained,
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
              difficultySnapshot: worth,
              trackSnapshot: quest.track,
              attributeSnapshot: quest.attribute,
              questNameSnapshot: loggedName,
              progress: Value(progress ?? existingProgress?.progress),
              note: Value(
                (note == null || note.trim().isEmpty) ? null : note.trim(),
              ),
              extras: Value(
                jsonEncode(<String, Object>{
                  if (doneSize != null) sizeExtra: doneSize.name,
                  forExtra: loggedFor,
                  sourceExtra: kind.exportName,
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
                  if (outcome.bonusHeroXp > 0) 'bonusXp': outcome.bonusHeroXp,
                  if (outcome.comfortBond > 0)
                    'comfortBond': outcome.comfortBond,
                  if (outcome.dailyStillGift != null)
                    dailyStillExtra: <String, Object>{
                      'creature': dailyStillFor(day).key,
                      'gold': outcome.stillGiftGold,
                      'material': outcome.dailyStillGift!.name,
                    },
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

      // Amendment v0.3 §5: when today's creature has held the road, any
      // finished quest opens another try and brings a Salve for it.
      final fought = decodeEncounter(log?.encounter);
      if (log != null && fought != null && !fought.won && !fought.retryReady) {
        await (db.update(db.dayLogs)..where((d) => d.id.equals(log.id))).write(
          DayLogsCompanion(
            encounter: Value(
              jsonEncode(fought.copyWith(retryReady: true).toJson()),
            ),
          ),
        );
        await _addToPouch(ItemKind.salve);
      }
      // An Artificer's Craft quests also stock the pouch (§2).
      if (HeroClass.byId(heroRow.classId) == HeroClass.artificer &&
          quest.attribute == Attribute.craft) {
        final craftedBefore = doneToday
            .where((c) => c.attributeSnapshot == Attribute.craft)
            .length;
        await _addToPouch(
          artificerStock(
            DayKey.daysBetween('2026-01-01', day).abs() + craftedBefore,
          ),
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
              reminderTime: Value(draft.reminderTime),
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
        reminderTime: Value(draft.reminderTime),
        notes: Value(draft.notes.trim()),
        updatedAt: Value(now),
      ),
    );
    await _planFollowsQuest(id, draft);
    return id;
  }

  /// A habit plan's quest edited in the Quest Log: the plan takes the new
  /// words, track and days, so the board and the plan never disagree.
  Future<void> _planFollowsQuest(String questId, QuestDraft draft) async {
    final plans = (await settings()).plans;
    final at = plans.indexWhere((p) => p.questId == questId);
    if (at < 0) return;
    final schedule = draft.schedule;
    final PlanFrequency frequency;
    var weekdays = const <int>{};
    if (schedule.type == ScheduleType.weekdays ||
        schedule.type == ScheduleType.weekly) {
      final workdays = schedule.weekdays.length == 5 &&
          schedule.weekdays.containsAll(const <int>{1, 2, 3, 4, 5});
      if (workdays) {
        frequency = PlanFrequency.weekdays;
      } else {
        weekdays = schedule.weekdays;
        frequency = weekdays.length == 1
            ? PlanFrequency.weekly
            : PlanFrequency.days;
      }
    } else {
      frequency = PlanFrequency.daily;
    }
    final name = draft.name.trim();
    final minutes = minutesIn(name);
    final next = List<HabitPlan>.of(plans);
    next[at] = plans[at].copyWith(
      target: name,
      track: draft.track,
      frequency: frequency,
      weekdays: weekdays,
      minutes: minutes,
      clearMinutes: minutes == null,
    );
    await _savePlans(next);
  }

  Future<void> setQuestActive(String questId, {required bool active}) async {
    await (db.update(db.quests)..where((q) => q.id.equals(questId))).write(
      QuestsCompanion(active: Value(active), updatedAt: Value(clock())),
    );
    // A habit plan's quest archived in the Quest Log archives the plan
    // with it, and bringing it back brings the plan back.
    final plans = (await settings()).plans;
    if (plans.any((p) => p.questId == questId && p.active != active)) {
      await _savePlans(<HabitPlan>[
        for (final p in plans)
          p.questId == questId ? p.copyWith(active: active) : p,
      ]);
    }
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

  /// The day's Still creature (DECISIONS D-70): how many quests have stirred
  /// it, and what it left if it has woken.
  Future<DailyStillToday> dailyStillOn(String day) async {
    final done = await completionsOn(day);
    MaterialKind? gift;
    for (final c in done) {
      gift ??= dailyStillGiftOf(c);
    }
    return DailyStillToday(
      dailyStill(day: day, questsDone: done.length, giftGiven: gift != null),
      gift,
    );
  }

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

  // ---- Health Log (DESIGN §8.7, §9.3) --------------------------------

  Future<List<HealthEntryRow>> healthEntriesOn(String day) =>
      (db.select(db.healthEntries)
            ..where((h) => h.day.equals(day))
            ..orderBy([(h) => OrderingTerm.asc(h.fieldKey)]))
          .get();

  Future<Set<String>> daysWithHealthEntries() async =>
      <String>{for (final h in await db.select(db.healthEntries).get()) h.day};

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

  /// Today's entries by field key.
  Future<Map<String, HealthEntryRow>> healthEntriesByKey(String day) async =>
      <String, HealthEntryRow>{
        for (final h in await healthEntriesOn(day)) h.fieldKey: h,
      };

  /// Records the day's step count, from Health Connect or typed by hand,
  /// and lets it fill every Auto quest on today's board (DESIGN §6.2). A
  /// quest that reaches its target completes itself; those are returned so
  /// the screen can mark the moment.
  ///
  /// The count is information, never a score: nothing is shown or stored
  /// about a target that was not reached.
  Future<List<AutoCompletion>> recordSteps(int steps) async {
    if (steps < 0) return const <AutoCompletion>[];
    final day = DayKey.of(clock());
    final existing = (await healthEntriesByKey(day))[stepsFieldKey];
    if (existing?.value != '$steps') {
      await setHealthEntry(day, stepsFieldKey, '$steps');
    }
    final completed = <AutoCompletion>[];
    for (final entry in await loadBoard(day)) {
      final quest = entry.quest;
      if (quest.completionType != CompletionType.auto || entry.isDone) {
        continue;
      }
      if (entry.banked != steps) {
        final row = await _ensureProgress(quest.id, day);
        await (db.update(db.questProgress)..where((p) => p.id.equals(row.id)))
            .write(QuestProgressCompanion(progress: Value(steps)));
      }
      final target = quest.target ?? 0;
      if (target > 0 && steps >= target) {
        final outcome = await completeQuest(quest.id, progress: steps);
        if (outcome != null) completed.add(AutoCompletion(quest.id, outcome));
      }
    }
    return completed;
  }

  /// Writes [steps] as the count for [day], a day already gone by, so its
  /// note carries the whole day's figure and not just what had been walked
  /// when the app was last open. Only for a day the app was opened on, and
  /// it completes nothing: that day's board is closed.
  Future<void> recordStepsFor(String day, int steps) async {
    if (steps < 0 || await dayLog(day) == null) return;
    final existing = (await healthEntriesByKey(day))[stepsFieldKey];
    if (existing?.value == '$steps') return;
    await setHealthEntry(day, stepsFieldKey, '$steps');
  }

  /// Writes [day]'s average glucose, as Health Connect holds it, into that
  /// day's Health Log (DECISIONS D-71). A number and its unit, nothing else.
  /// Only for a day the app was opened on.
  Future<void> recordGlucoseAverage(String day, double average) async {
    if (average <= 0 || await dayLog(day) == null) return;
    final value = formatGlucose(average);
    final existing = (await healthEntriesByKey(day))[glucoseAverageFieldKey];
    if (existing?.value == value) return;
    await setHealthEntry(
      day,
      glucoseAverageFieldKey,
      value,
      unit: glucoseAverageUnit,
    );
  }

  // ---- Calendar suggestions (DESIGN §9.3) -----------------------------

  /// What was decided about each of [day]'s calendar events: event id to
  /// `accepted` or `dismissed`.
  Future<Map<String, String>> calendarChoicesOn(String day) async {
    final rows = await (db.select(db.calendarChoices)
          ..where((c) => c.day.equals(day)))
        .get();
    return <String, String>{for (final r in rows) r.externalId: r.choice};
  }

  Future<void> _rememberChoice(
    String day,
    String externalId,
    String choice,
  ) async {
    await db.into(db.calendarChoices).insert(
          CalendarChoicesCompanion.insert(
            id: newId(),
            day: day,
            externalId: externalId,
            choice: choice,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Accepts a calendar suggestion: it becomes today's commitment, a
  /// one-off Confirm quest (DESIGN §12 item 3). Order by default; the user
  /// can re-tag it like any quest. The calendar itself is never touched.
  /// Returns the quest's id.
  Future<String> acceptSuggestion({
    required String externalId,
    required String title,
    String timeLabel = '',
    Attribute attribute = Attribute.order,
    QuestSource source = QuestSource.calendar,
    Difficulty difficulty = Difficulty.standard,
  }) async {
    final now = clock();
    final day = DayKey.of(now);
    return db.transaction(() async {
      final already = await (db.select(db.quests)
            ..where(
              (q) =>
                  q.externalId.equals(externalId) &
                  q.scheduleAnchorDay.equals(day),
            )
            ..limit(1))
          .getSingleOrNull();
      if (already != null) return already.id;
      await _rememberChoice(day, externalId, choiceAccepted);
      final id = newId();
      final name = title.trim().isEmpty ? commitmentFallbackName : title.trim();
      await db.into(db.quests).insert(
            QuestsCompanion.insert(
              id: id,
              name: name,
              iconKey: const Value('calendar'),
              attribute: attribute,
              difficulty: difficulty,
              track: Track.hero,
              scheduleType: ScheduleType.oneOff,
              scheduleAnchorDay: Value(day),
              completionType: source == QuestSource.calendar
                  ? CompletionType.confirm
                  : CompletionType.tap,
              notes: Value(timeLabel),
              source: source,
              externalId: Value(externalId),
              sortOrder: const Value(8),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  /// Dismisses a calendar suggestion for today. Nothing else happens: it is
  /// simply not offered again.
  Future<void> dismissSuggestion(String externalId) =>
      _rememberChoice(DayKey.of(clock()), externalId, choiceDismissed);

  // ---- The weekly Delve (DESIGN §3B, §4.2) ----------------------------

  Future<List<DelveRow>> delves() => (db.select(db.delves)
        ..orderBy([(d) => OrderingTerm.desc(d.weekEnd)]))
      .get();

  /// The Delve that can be entered at the Campfire now, or null.
  ///
  /// It opens on the chosen weekday and waits for the next Campfire if that
  /// day goes by. At most one opens in any seven days, and none for a week
  /// that ended before this journey began.
  Future<DelveWaiting?> delveWaiting() async {
    final today = DayKey.of(clock());
    final weekday = (await settings()).delveWeekday;
    final delveDay = latestDelveDay(today, weekday);
    final first = await (db.select(db.dayLogs)
          ..orderBy([(d) => OrderingTerm.asc(d.day)])
          ..limit(1))
        .getSingleOrNull();
    if (first == null || delveDay.compareTo(first.day) < 0) return null;
    final resolved = await delves();
    if (resolved.isNotEmpty &&
        DayKey.daysBetween(resolved.first.weekEnd, delveDay) < 7) {
      return null;
    }
    final start = delveWeekStart(delveDay);
    final week = await (db.select(db.completions)
          ..where(
            (c) =>
                c.day.isBiggerOrEqualValue(start) &
                c.day.isSmallerOrEqualValue(delveDay),
          ))
        .get();
    return DelveWaiting(
      delveDay: delveDay,
      site: delveSiteFor(delveDay),
      supplies: suppliesFrom(<DelveEntry>[
        for (final c in week)
          DelveEntry(c.day, c.trackSnapshot, c.difficultySnapshot),
      ]),
    );
  }

  /// Enters the waiting Delve: one screen, one outcome, and the party comes
  /// home with something whatever the week was like. Null if none waits.
  Future<DelveResult?> resolveDelve() async {
    final now = clock();
    final today = DayKey.of(now);
    final result = await db.transaction(() async {
      final waiting = await delveWaiting();
      final heroRow = await hero();
      final worldRow = await world();
      if (waiting == null || heroRow == null || worldRow == null) return null;
      final tier = waiting.tier;
      final reward = waiting.reward;
      final gathered = decodeMaterials(heroRow.materials);
      final restoredBefore = restoredCount(gathered);
      for (final e in reward.materials.entries) {
        gathered[e.key] = (gathered[e.key] ?? 0) + e.value;
      }
      final restoredAfter = restoredCount(gathered);
      await (db.update(db.characters)..where((c) => c.id.equals(heroRow.id)))
          .write(
        CharactersCompanion(
          gold: Value(heroRow.gold + reward.gold),
          materials: Value(encodeMaterials(gathered)),
        ),
      );
      if (restoredAfter > restoredBefore) {
        await _recordRestorations(worldRow, restoredAfter, today);
      }
      await db.into(db.delves).insert(
            DelvesCompanion.insert(
              id: newId(),
              weekEnd: waiting.delveDay,
              resolvedAt: now,
              site: waiting.site,
              tier: tier.name,
              provisions: Value(waiting.supplies.provisions),
              trailMarks: Value(waiting.supplies.trailMarks),
              keys: Value(waiting.supplies.keys),
              daysActive: Value(waiting.supplies.daysActive),
              gold: Value(reward.gold),
              eachMaterial: Value(reward.eachMaterial),
            ),
          );
      return DelveResult(
        delveDay: waiting.delveDay,
        site: waiting.site,
        supplies: waiting.supplies,
        tier: tier,
        reward: reward,
        newRestorationIndexes: <int>[
          for (var i = restoredBefore; i < restoredAfter; i++) i,
        ],
      );
    });
    if (result != null) {
      // Cosmetics that come with restored places, and today's file again.
      await syncWorld();
      await _touchDay(today, const DayLogsCompanion());
    }
    return result;
  }

  // ---- Classes and fights (Amendment v0.3) ----------------------------

  /// Sets the hero's class. Nothing else about the hero changes: XP,
  /// levels, attributes and everything gathered stay exactly as they are.
  Future<void> setHeroClass(HeroClass cls) async {
    final heroRow = await hero();
    if (heroRow == null) return;
    await (db.update(db.characters)..where((c) => c.id.equals(heroRow.id)))
        .write(CharactersCompanion(classId: Value(cls.name)));
    await _touchDay(DayKey.of(clock()), const DayLogsCompanion());
  }

  /// How [day]'s encounter went, or null if it has not been fought.
  Future<EncounterRecord?> encounterOn(String day) async =>
      decodeEncounter((await dayLog(day))?.encounter);

  /// The quests finished on [day], as a class counts them.
  Future<List<QuestDone>> questsDoneOn(String day) async => <QuestDone>[
        for (final c in await completionsOn(day))
          QuestDone(c.attributeSnapshot, c.trackSnapshot, c.difficultySnapshot),
      ];

  /// Bonus XP from every chest won on or before [day], so a later export
  /// of a past day shows the level as it stood.
  Future<int> chestXpThrough(String day) async {
    final logs = await (db.select(db.dayLogs)
          ..where((d) => d.day.isSmallerOrEqualValue(day) & d.encounter.isNotNull()))
        .get();
    var xp = 0;
    for (final log in logs) {
      final record = decodeEncounter(log.encounter);
      if (record != null && record.won) xp += record.chest?.xp ?? 0;
    }
    return xp;
  }

  Future<void> _addToPouch(ItemKind kind) async {
    final pouch = Map<ItemKind, int>.of((await settings()).pouch);
    final have = pouch[kind] ?? 0;
    pouch[kind] = have >= pouchCap ? pouchCap : have + 1;
    await setSetting(SettingKey.pouch, encodePouch(pouch));
  }

  /// Writes down today's fight. A win brings the chest home: gold,
  /// materials (which may wake a place), a consumable, bonus XP for hero
  /// and companion, and a Boss Mark. When the creature holds, nothing at
  /// all is taken (Amendment v0.3 §§1, 5): only the record changes, and
  /// what was used from the pouch stays used. Null if there is no class
  /// yet, or today's encounter is already won.
  Future<EncounterOutcome?> recordEncounter({
    required bool won,
    required bool heroic,
    required int turns,
    required Map<ItemKind, int> pouchAfter,
  }) async {
    final now = clock();
    final day = DayKey.of(now);
    final outcome = await db.transaction(() async {
      final heroRow = await hero();
      final companionRow = await companion();
      final worldRow = await world();
      final cls = HeroClass.byId(heroRow?.classId);
      if (heroRow == null ||
          companionRow == null ||
          worldRow == null ||
          cls == null) {
        return null;
      }
      await db.into(db.dayLogs).insert(
            DayLogsCompanion.insert(id: newId(), day: day, dawnGeneratedAt: now),
            mode: InsertMode.insertOrIgnore,
          );
      final before = decodeEncounter((await dayLog(day))?.encounter);
      if (before != null && before.won) return null;

      final enemy = enemyFor(day);
      final pouch = Map<ItemKind, int>.of(pouchAfter);
      final current = await settings();
      Chest? chest;
      var restoredBefore = 0;
      var restoredAfter = 0;
      var heroLevel = heroRow.level;
      var companionLevel = companionRow.level;
      var marks = current.boss.marks;
      if (won) {
        final gathered = decodeMaterials(heroRow.materials);
        restoredBefore = restoredCount(gathered);
        final prize = chestFor(day, stillNeeded(gathered), heroic: heroic);
        chest = prize;
        gathered[prize.material] = (gathered[prize.material] ?? 0) + prize.materials;
        restoredAfter = restoredCount(gathered);
        final heroXp = heroRow.totalXp + prize.xp;
        final reached = XpCurve.levelForXp(heroXp);
        if (reached > heroLevel) heroLevel = reached;
        await (db.update(db.characters)..where((c) => c.id.equals(heroRow.id)))
            .write(
          CharactersCompanion(
            totalXp: Value(heroXp),
            level: Value(heroLevel),
            gold: Value(heroRow.gold + prize.gold),
            materials: Value(encodeMaterials(gathered)),
            titles: Value(jsonEncode(titlesEarned(heroLevel))),
          ),
        );
        final companionXp = companionRow.totalXp + prize.xp;
        final companionReached = XpCurve.levelForXp(companionXp);
        if (companionReached > companionLevel) {
          companionLevel = companionReached;
        }
        await (db.update(db.companions)
              ..where((c) => c.id.equals(companionRow.id)))
            .write(
          CompanionsCompanion(
            totalXp: Value(companionXp),
            level: Value(companionLevel),
            tricksUnlocked: Value(jsonEncode(tricksUnlockedAt(companionLevel))),
            gearUnlocked: Value(
              jsonEncode(
                gearUnlockedAt(level: companionLevel, bond: companionRow.bond),
              ),
            ),
          ),
        );
        if (restoredAfter > restoredBefore) {
          await _recordRestorations(worldRow, restoredAfter, day);
        }
        final have = pouch[prize.item] ?? 0;
        pouch[prize.item] = have >= pouchCap ? pouchCap : have + 1;
        final boss = current.boss.withMark();
        marks = boss.marks;
        await setSetting(SettingKey.boss, jsonEncode(boss.toJson()));
      }
      await setSetting(SettingKey.pouch, encodePouch(pouch));
      final record = EncounterRecord(
        enemyKey: enemy.key,
        heroic: heroic,
        won: won,
        attempts: (before?.attempts ?? 0) + 1,
        turns: turns,
        classId: cls.name,
        chest: chest,
      );
      await _touchDay(
        day,
        DayLogsCompanion(encounter: Value(jsonEncode(record.toJson()))),
      );
      return EncounterOutcome(
        record: record,
        enemy: enemy,
        newRestorationIndexes: <int>[
          for (var i = restoredBefore; i < restoredAfter; i++) i,
        ],
        heroLevel: heroLevel,
        heroLevelBefore: heroRow.level,
        companionLevel: companionLevel,
        companionLevelBefore: companionRow.level,
        marks: marks,
      );
    });
    if (outcome != null && outcome.record.won) await syncWorld();
    return outcome;
  }

  /// Writes down the week's attempt on the boss, which left it with [left]
  /// HP. What was taken off it stays off (Amendment v0.3 §5). At zero it
  /// wakes: the week's big restoration, and its title the first time. Null
  /// if no Delve is waiting.
  Future<BossOutcome?> recordBossAttempt({
    required int left,
    required bool spentMarks,
    required int turns,
    required Map<ItemKind, int> pouchAfter,
  }) async {
    final now = clock();
    final today = DayKey.of(now);
    final result = await db.transaction(() async {
      final waiting = await delveWaiting();
      final heroRow = await hero();
      final worldRow = await world();
      if (waiting == null || heroRow == null || worldRow == null) return null;
      final state = (await settings()).boss;
      final boss = state.boss;
      final woken = left <= 0;
      var restoredBefore = 0;
      var restoredAfter = 0;
      if (woken) {
        final gathered = decodeMaterials(heroRow.materials);
        restoredBefore = restoredCount(gathered);
        for (final kind in MaterialKind.values) {
          gathered[kind] = (gathered[kind] ?? 0) + bossEachMaterial;
        }
        restoredAfter = restoredCount(gathered);
        await (db.update(db.characters)..where((c) => c.id.equals(heroRow.id)))
            .write(
          CharactersCompanion(
            gold: Value(heroRow.gold + bossGold),
            materials: Value(encodeMaterials(gathered)),
          ),
        );
        if (restoredAfter > restoredBefore) {
          await _recordRestorations(worldRow, restoredAfter, today);
        }
      }
      await setSetting(
        SettingKey.boss,
        jsonEncode(
          state.afterAttempt(left: left, spentMarks: spentMarks).toJson(),
        ),
      );
      await setSetting(SettingKey.pouch, encodePouch(pouchAfter));
      await db.into(db.delves).insert(
            DelvesCompanion.insert(
              id: newId(),
              weekEnd: waiting.delveDay,
              resolvedAt: now,
              site: boss.name,
              tier: woken ? bossTierWoken : bossTierHeld,
              daysActive: Value(turns),
              gold: Value(woken ? bossGold : 0),
              eachMaterial: Value(woken ? bossEachMaterial : 0),
            ),
          );
      return BossOutcome(
        boss: boss,
        woken: woken,
        left: left < 0 ? 0 : left,
        newRestorationIndexes: <int>[
          for (var i = restoredBefore; i < restoredAfter; i++) i,
        ],
        title: woken && !state.woken.contains(boss.key) ? boss.title : null,
      );
    });
    if (result != null) {
      await syncWorld();
      await _touchDay(today, const DayLogsCompanion());
    }
    return result;
  }

  // ---- Settings ------------------------------------------------------

  // ---- Goals, habit plans and First Dawn (Amendment v0.4) -------------

  Future<void> _saveGoals(List<Goal> goals) =>
      setSetting(SettingKey.goals, encodeGoals(goals));

  Future<void> _savePlans(List<HabitPlan> plans) =>
      setSetting(SettingKey.plans, encodePlans(plans));

  int _sortOrderOf(DayWindow window) => switch (window) {
        DayWindow.morning => 20,
        DayWindow.afternoon => 30,
        DayWindow.anytime => 35,
        DayWindow.evening => 40,
      };

  /// Writes the quest row that puts [plan] on the board, creating it the
  /// first time, and returns the plan carrying that quest's id.
  Future<HabitPlan> _syncPlanQuest(HabitPlan plan, {String? icon}) async {
    final now = clock();
    final schedule = plan.schedule;
    final questId = plan.questId;
    final existing = questId == null ? null : await questById(questId);
    if (existing == null) {
      final id = newId();
      await db.into(db.quests).insert(
            QuestsCompanion.insert(
              id: id,
              name: plan.target,
              iconKey: Value(icon ?? 'star'),
              attribute: plan.attribute,
              difficulty: plan.difficultyFor(QuestSize.target),
              track: plan.track,
              scheduleType: schedule.type,
              scheduleWeekdays:
                  Value(Schedule.encodeWeekdays(schedule.weekdays)),
              completionType: CompletionType.tap,
              source: QuestSource.habit,
              goalId: Value(plan.goalId),
              planId: Value(plan.id),
              active: Value(plan.active),
              sortOrder: Value(_sortOrderOf(plan.window)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return plan.copyWith(questId: id);
    }
    await (db.update(db.quests)..where((q) => q.id.equals(existing.id))).write(
      QuestsCompanion(
        name: Value(plan.target),
        iconKey: icon == null ? const Value.absent() : Value(icon),
        attribute: Value(plan.attribute),
        difficulty: Value(plan.difficultyFor(QuestSize.target)),
        track: Value(plan.track),
        scheduleType: Value(schedule.type),
        scheduleWeekdays: Value(Schedule.encodeWeekdays(schedule.weekdays)),
        goalId: Value(plan.goalId),
        planId: Value(plan.id),
        active: Value(plan.active),
        sortOrder: Value(_sortOrderOf(plan.window)),
        updatedAt: Value(now),
      ),
    );
    return plan;
  }

  /// Adds a goal, or replaces the one with the same id.
  Future<void> saveGoal(Goal goal) async {
    final goals = (await settings()).goals;
    final at = goals.indexWhere((g) => g.id == goal.id);
    final next = List<Goal>.of(goals);
    if (at < 0) {
      next.add(goal);
    } else {
      next[at] = goal;
    }
    await _saveGoals(next);
  }

  /// Adds a habit plan, or replaces the one with the same id, and keeps
  /// its quest in step. Returns the plan as stored.
  Future<HabitPlan> savePlan(HabitPlan plan) async {
    final prefs = await settings();
    String? icon;
    for (final g in prefs.goals) {
      if (g.id == plan.goalId) icon = g.domain.icon;
    }
    final stored = await _syncPlanQuest(plan, icon: icon);
    final next = List<HabitPlan>.of(prefs.plans);
    final at = next.indexWhere((p) => p.id == stored.id);
    if (at < 0) {
      next.add(stored);
    } else {
      next[at] = stored;
    }
    await _savePlans(next);
    return stored;
  }

  /// Archives a goal with its habits, or brings it back. Nothing is
  /// deleted: what was done for it stays in the log.
  Future<void> setGoalActive(String goalId, {required bool active}) async {
    final prefs = await settings();
    await _saveGoals(<Goal>[
      for (final g in prefs.goals)
        g.id == goalId ? g.copyWith(active: active) : g,
    ]);
    for (final p in prefs.plans) {
      if (p.goalId == goalId && p.active != active) {
        await savePlan(p.copyWith(active: active));
      }
    }
  }

  Future<void> setPlanActive(String planId, {required bool active}) async {
    for (final p in (await settings()).plans) {
      if (p.id == planId) await savePlan(p.copyWith(active: active));
    }
  }

  /// Pins a quest of the user's own to a goal, or unpins it with null.
  Future<void> pinQuestToGoal(String questId, String? goalId) async {
    await (db.update(db.quests)..where((q) => q.id.equals(questId))).write(
      QuestsCompanion(goalId: Value(goalId), updatedAt: Value(clock())),
    );
  }

  Future<void> setMappings(List<CalendarMapping> mappings) =>
      setSetting(SettingKey.mappings, encodeMappings(mappings));

  Future<void> setFirstDawn(FirstDawnState state) =>
      setSetting(SettingKey.firstDawn, state.name);

  Future<void> saveFirstDawnDraft(FirstDawnDraft? draft) =>
      setSetting(SettingKey.firstDawnDraft, draft?.encode());

  /// The quests First Dawn's review looks at for a hero who already has a
  /// board (Chapter 7, migration): active, the user's own, not yet pinned.
  Future<List<QuestRow>> unpinnedQuests() async => <QuestRow>[
        for (final q in await allQuests())
          if (q.active &&
              q.planId == null &&
              q.goalId == null &&
              q.scheduleType != ScheduleType.oneOff &&
              (q.source == QuestSource.manual ||
                  q.source == QuestSource.recurring ||
                  q.source == QuestSource.health))
            q,
      ];

  /// Turns First Dawn's answers into data (Amendment v0.4 §3): goals,
  /// habit plans with their quests, the rhythm, the class and its scores.
  ///
  /// [fresh] is a hero who has never had a board of their own: once they
  /// have designed habits, the untouched starter quests step back into the
  /// Quest Log as a library. For anyone else every existing quest is dealt
  /// with by the user's own choice in [draft], and nothing is archived that
  /// they did not archive. [wholeFlow] is false for a goal added later,
  /// which leaves the rhythm and class alone.
  Future<void> commitFirstDawn(
    FirstDawnDraft draft, {
    required bool fresh,
    bool wholeFlow = true,
  }) async {
    final today = DayKey.of(clock());
    await db.transaction(() async {
      final prefs = await settings();
      final made = plansFrom(draft, newId: newId, startDay: today);
      final goals = <Goal>[...prefs.goals, ...made.goals];
      await _saveGoals(goals);
      final plans = List<HabitPlan>.of(prefs.plans);
      for (final p in made.plans) {
        String? icon;
        for (final g in made.goals) {
          if (g.id == p.goalId) icon = g.domain.icon;
        }
        plans.add(await _syncPlanQuest(p, icon: icon));
      }
      await _savePlans(plans);

      for (final entry in draft.existing.entries) {
        final choice = entry.value;
        if (choice == 'archive') {
          await setQuestActive(entry.key, active: false);
        } else if (choice.startsWith('goal:')) {
          final index = int.tryParse(choice.substring(5));
          if (index != null && index >= 0 && index < made.goals.length) {
            await pinQuestToGoal(entry.key, made.goals[index].id);
          }
        }
      }

      if (fresh && made.plans.isNotEmpty) {
        final touched = <String>{
          for (final c in await allCompletions()) c.questId,
        };
        for (final q in await unpinnedQuests()) {
          if (!touched.contains(q.id)) {
            await setQuestActive(q.id, active: false);
          }
        }
      }

      if (wholeFlow) {
        await setSetting(
          SettingKey.rhythm,
          jsonEncode(draft.rhythm(startDay: today).toJson()),
        );
        await setSetting(
          SettingKey.classScore,
          jsonEncode(draft.classScore.toJson()),
        );
        final cls = HeroClass.byId(draft.chosenClass);
        if (cls != null && cls.offered) await setHeroClass(cls);
        await setFirstDawn(FirstDawnState.done);
        await saveFirstDawnDraft(null);
      }
    });
  }

  /// How many times each habit plan was done at each size from [fromDay]
  /// on. Information for the Sunday Check-In, never a grade.
  Future<Map<String, SizeCounts>> sizeCountsSince(String fromDay) async {
    final planOf = <String, String>{
      for (final q in await allQuests())
        if (q.planId != null) q.id: q.planId!,
    };
    final out = <String, SizeCounts>{};
    for (final c in await allCompletions()) {
      if (DayKey.daysBetween(fromDay, c.day) < 0) continue;
      final planId = planOf[c.questId];
      if (planId == null) continue;
      final size = sizeOf(c) ?? QuestSize.target;
      out[planId] = (out[planId] ?? const SizeCounts()).plus(size);
    }
    return out;
  }

  Future<void> _saveCheckIns(CheckIns checkIns) =>
      setSetting(SettingKey.checkIns, checkIns.encode());

  Future<void> recordFelt(String day, Felt felt) async =>
      _saveCheckIns((await settings()).checkIns.withFelt(day, felt));

  /// Declining is final for that suggestion (Amendment v0.4 §6).
  Future<void> declineProposal(Proposal proposal) async =>
      _saveCheckIns((await settings()).checkIns.withDeclined(proposal.key));

  /// The user said yes: the plan changes, and that is remembered.
  Future<void> acceptProposal(Proposal proposal) async {
    await savePlan(proposal.changed);
    await _saveCheckIns(
      (await settings()).checkIns.withAccepted(proposal.key),
    );
  }

  Future<GameSettings> settings() async => GameSettings.fromMap(
        <String, String>{
          for (final r in await db.select(db.appSettings).get()) r.key: r.value,
        },
      );

  /// Stores one setting; null puts it back to its default.
  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await (db.delete(db.appSettings)..where((s) => s.key.equals(key))).go();
      return;
    }
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<void> setDelveWeekday(int weekday) =>
      setSetting(SettingKey.delveWeekday, '$weekday');

  Future<void> setHealthFields(List<HealthField> fields) =>
      setSetting(SettingKey.healthFields, encodeHealthFields(fields));

  Future<void> setExcludedCalendars(Set<String> ids) => setSetting(
        SettingKey.calendarExcluded,
        jsonEncode(ids.toList()..sort()),
      );

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
      'delves': [for (final r in await db.select(db.delves).get()) r.toJson()],
      'calendarChoices': [
        for (final r in await db.select(db.calendarChoices).get()) r.toJson(),
      ],
      'settings': [
        for (final r in await db.select(db.appSettings).get()) r.toJson(),
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
      // Tables that arrived with schema 3; absent from an older backup.
      final delveRows = rows('delves').map(DelveRow.fromJson).toList();
      final choices =
          rows('calendarChoices').map(CalendarChoiceRow.fromJson).toList();
      final settingRows = rows('settings').map(SettingRow.fromJson).toList();
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
          b.insertAll(db.delves, delveRows);
          b.insertAll(db.calendarChoices, choices);
          b.insertAll(db.appSettings, settingRows);
        });
        // A backup from before schema 3 has the two seeded health quests
        // without their keys; give them the same step the upgrade does.
        if (schema < 3) await db.tagSeededHealthQuests();
      });
    } on Object {
      // A row that does not fit the tables: leave everything as it was.
      return notABackup;
    }
    return const BackupResult.ok();
  }
}
