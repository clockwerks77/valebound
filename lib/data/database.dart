import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../rules/enums.dart';

part 'database.g.dart';

// Local storage, DESIGN §9.2 and §10. On-device SQLite only.
//
// Every entity has a UUID primary key (text) rather than an auto-increment
// id: the one co-op-ready concession the design asks for in v1.
// Days are stored as `YYYY-MM-DD` text (see `DayKey`).

@DataClassName('QuestRow')
class Quests extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get iconKey => text().withDefault(const Constant('star'))();
  TextColumn get attribute => textEnum<Attribute>()();
  TextColumn get difficulty => textEnum<Difficulty>()();
  TextColumn get track => textEnum<Track>()();
  TextColumn get scheduleType => textEnum<ScheduleType>()();
  TextColumn get scheduleWeekdays => text().withDefault(const Constant(''))();
  IntColumn get scheduleIntervalDays => integer().nullable()();
  TextColumn get scheduleAnchorDay => text().nullable()();
  TextColumn get completionType => textEnum<CompletionType>()();

  /// Count: units. Timer: minutes. Auto: steps.
  IntColumn get target => integer().nullable()();

  /// `HH:mm`, or null. Reminders are off unless the user sets one.
  TextColumn get reminderTime => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// False means archived.
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get source => textEnum<QuestSource>()();

  /// Calendar event id for calendar-suggested quests.
  TextColumn get externalId => text().nullable()();

  /// Set for quests the app itself owns, e.g. `campfire`.
  TextColumn get systemKey => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CompletionRow')
class Completions extends Table {
  TextColumn get id => text()();
  TextColumn get questId => text()();
  TextColumn get day => text()();
  DateTimeColumn get completedAt => dateTime()();

  /// Hero XP awarded.
  IntColumn get xpAwarded => integer()();
  IntColumn get companionXpAwarded =>
      integer().withDefault(const Constant(0))();
  IntColumn get pacesAwarded => integer().withDefault(const Constant(0))();
  IntColumn get bondAwarded => integer().withDefault(const Constant(0))();
  IntColumn get goldAwarded => integer().withDefault(const Constant(0))();
  TextColumn get materialKind => textEnum<MaterialKind>().nullable()();
  IntColumn get materialAmount => integer().withDefault(const Constant(0))();

  // Snapshots, so a later edit to the quest never rewrites history and the
  // Shared-quest split stays auditable.
  TextColumn get difficultySnapshot => textEnum<Difficulty>()();
  TextColumn get trackSnapshot => textEnum<Track>()();
  TextColumn get attributeSnapshot => textEnum<Attribute>()();
  TextColumn get questNameSnapshot => text()();

  /// Count units, or timer seconds, at the moment of completion.
  IntColumn get progress => integer().nullable()();
  TextColumn get note => text().nullable()();

  /// JSON map of anything else this completion did: `sniff` and `fetch`
  /// (material names), `restored` (place keys), `gear` and `cosmetics`
  /// (keys unlocked). Added in schema 2.
  TextColumn get extras => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Partial progress for count and timer quests during a day.
@DataClassName('QuestProgressRow')
class QuestProgress extends Table {
  TextColumn get id => text()();
  TextColumn get questId => text()();
  TextColumn get day => text()();

  /// Count units, or timer seconds already banked.
  IntColumn get progress => integer().withDefault(const Constant(0))();

  /// Set while a timer is running; elapsed time is measured from here.
  DateTimeColumn get timerStartedAt => dateTime().nullable()();

  /// The user moved this quest to "Later" for today.
  BoolColumn get setAside => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {questId, day},
      ];
}

@DataClassName('CharacterRow')
class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get portraitId => text()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get totalXp => integer().withDefault(const Constant(0))();

  /// JSON map of attribute name to XP.
  TextColumn get attributeXp => text().withDefault(const Constant('{}'))();
  IntColumn get gold => integer().withDefault(const Constant(0))();

  /// JSON map of material name to count.
  TextColumn get materials => text().withDefault(const Constant('{}'))();
  TextColumn get unlockedCosmetics =>
      text().withDefault(const Constant('[]'))();
  TextColumn get titles => text().withDefault(const Constant('[]'))();
  IntColumn get heroTrackCompletions =>
      integer().withDefault(const Constant(0))();

  /// JSON map of cosmetic kind to the key in use, e.g. `{"frame":"oak"}`.
  /// Added in schema 2.
  TextColumn get equippedCosmetics =>
      text().withDefault(const Constant('{}'))();

  /// The hero's class, by `HeroClass` name; null until one is chosen
  /// (Amendment v0.3 §2). Added in schema 4.
  TextColumn get classId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Separate from [Characters] so a future stable or party is not blocked.
@DataClassName('CompanionRow')
class Companions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => textEnum<CompanionKind>()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get totalXp => integer().withDefault(const Constant(0))();
  IntColumn get bond => integer().withDefault(const Constant(0))();
  TextColumn get tricksUnlocked => text().withDefault(const Constant('[]'))();
  TextColumn get gearUnlocked => text().withDefault(const Constant('[]'))();

  /// Key of the gear being worn, or null. Added in schema 2.
  TextColumn get gearEquipped => text().nullable()();
  TextColumn get portraitId => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WorldStateRow')
class WorldStates extends Table {
  TextColumn get id => text()();
  IntColumn get restorationPoints => integer().withDefault(const Constant(0))();
  TextColumn get regionState => text().withDefault(const Constant('{}'))();
  TextColumn get buildingState => text().withDefault(const Constant('{}'))();
  TextColumn get npcReturned => text().withDefault(const Constant('{}'))();
  IntColumn get journeyPaces => integer().withDefault(const Constant(0))();

  /// Ordered JSON list of discovery scene keys.
  TextColumn get discoveriesUnlocked =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DayLogRow')
class DayLogs extends Table {
  TextColumn get id => text()();
  TextColumn get day => text().unique()();
  DateTimeColumn get dawnGeneratedAt => dateTime()();
  DateTimeColumn get campfireAt => dateTime().nullable()();
  TextColumn get dayNote => text().withDefault(const Constant(''))();
  DateTimeColumn get exportedAt => dateTime().nullable()();

  /// The once-a-day Bond bonus for a companion level-up has been given.
  BoolColumn get bondLevelBonusGranted =>
      boolean().withDefault(const Constant(false))();

  /// Today's Sniff Out find has been made.
  BoolColumn get sniffOutGranted =>
      boolean().withDefault(const Constant(false))();

  /// Today's Fetch has been made. Added in schema 2.
  BoolColumn get fetchGranted =>
      boolean().withDefault(const Constant(false))();

  /// Quests on the board that day, kept so a later export of the day is
  /// exact. Added in schema 2.
  IntColumn get questsTotal => integer().nullable()();

  /// How the day's encounter went, as an `EncounterRecord` in JSON; null
  /// if it was never fought (Amendment v0.3 §3). Added in schema 4.
  TextColumn get encounter => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Free-form field key so user-defined stats need no migration (Phase 3).
@DataClassName('HealthEntryRow')
class HealthEntries extends Table {
  TextColumn get id => text()();
  TextColumn get day => text()();
  TextColumn get fieldKey => text()();
  TextColumn get value => text()();
  TextColumn get unit => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One weekly Delve, once it has been resolved (DESIGN §3B, §4.2). Added in
/// schema 3.
@DataClassName('DelveRow')
class Delves extends Table {
  TextColumn get id => text()();

  /// The Delve day that closes the week: the week is the seven days ending
  /// here.
  TextColumn get weekEnd => text().unique()();
  DateTimeColumn get resolvedAt => dateTime()();
  TextColumn get site => text()();

  /// `cleared`, `scouted` or `rested`.
  TextColumn get tier => text()();
  IntColumn get provisions => integer().withDefault(const Constant(0))();
  IntColumn get trailMarks => integer().withDefault(const Constant(0))();
  IntColumn get keys => integer().withDefault(const Constant(0))();
  IntColumn get daysActive => integer().withDefault(const Constant(0))();
  IntColumn get gold => integer().withDefault(const Constant(0))();

  /// How many of each material came home.
  IntColumn get eachMaterial => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// What the user decided about one calendar event on one day: accepted as a
/// quest, or dismissed (DESIGN §9.3). The calendar itself is never changed.
/// Added in schema 3.
@DataClassName('CalendarChoiceRow')
class CalendarChoices extends Table {
  TextColumn get id => text()();
  TextColumn get day => text()();

  /// The event instance: event id and start time.
  TextColumn get externalId => text()();

  /// `accepted` or `dismissed`.
  TextColumn get choice => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {day, externalId},
      ];
}

/// Simple settings, kept beside the data so the JSON backup carries them.
/// Added in schema 3.
@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Quests,
    Completions,
    QuestProgress,
    Characters,
    Companions,
    WorldStates,
    DayLogs,
    HealthEntries,
    Delves,
    CalendarChoices,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// 1: Phase 1. 2: Phase 2 (completion extras, Fetch flag, the day's quest
  /// total, equipped cosmetics and gear). 3: Phase 3 (Delves, calendar
  /// choices, settings; system keys on the two seeded health quests).
  /// 4: version 0.7 (the hero's class, the day's encounter).
  @override
  int get schemaVersion => 4;

  /// Data survives every update (DESIGN §9.2): an older database is carried
  /// forward step by step and nothing in it is rewritten or dropped.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(completions, completions.extras);
            await m.addColumn(characters, characters.equippedCosmetics);
            await m.addColumn(companions, companions.gearEquipped);
            await m.addColumn(dayLogs, dayLogs.fetchGranted);
            await m.addColumn(dayLogs, dayLogs.questsTotal);
          }
          if (from < 3) {
            await m.createTable(delves);
            await m.createTable(calendarChoices);
            await m.createTable(appSettings);
            await tagSeededHealthQuests();
          }
          if (from < 4) {
            await m.addColumn(characters, characters.classId);
            await m.addColumn(dayLogs, dayLogs.encounter);
          }
        },
      );

  /// The two seeded health quests gain their behaviour by key, so renaming
  /// them later changes nothing. Only untouched seeds are tagged: a quest
  /// the user has already renamed is theirs to define.
  Future<void> tagSeededHealthQuests() async {
    await customStatement(
      "UPDATE quests SET system_key = 'health_check' "
      "WHERE system_key IS NULL AND name = 'Morning Health Check'",
    );
    await customStatement(
      "UPDATE quests SET system_key = 'injection' "
      "WHERE system_key IS NULL AND name = 'Weekly Injection (Mounjaro)'",
    );
  }

  static QueryExecutor _open() {
    return driftDatabase(
      name: 'habit_adventure',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
