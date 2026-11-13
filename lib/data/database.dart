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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() {
    return driftDatabase(
      name: 'habit_adventure',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
