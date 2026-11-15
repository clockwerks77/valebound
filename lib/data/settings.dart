import 'dart:convert';

import '../rules/checkin.dart';
import '../rules/combat.dart' show ItemKind;
import '../rules/delve.dart';
import '../rules/encounter.dart';
import '../rules/first_dawn.dart';
import '../rules/goals.dart';
import '../rules/health_fields.dart';

/// Keys of the simple settings kept in the database (so the JSON backup
/// carries them). Everything here is optional and has a default.
abstract final class SettingKey {
  /// ISO weekday of the weekly Delve, `1`–`7`.
  static const String delveWeekday = 'delve_weekday';

  /// `1` once the user has connected the calendar from the Dawn board.
  static const String calendarOn = 'calendar_on';

  /// `1` once the calendar offer has been answered either way, so it is
  /// made once and never repeated.
  static const String calendarAsked = 'calendar_asked';

  /// JSON list of the calendar ids the user has excluded.
  static const String calendarExcluded = 'calendar_excluded';

  /// JSON list of the Health Log's quick-entry fields.
  static const String healthFields = 'health_fields';

  /// `1` while steps are read from Health Connect.
  static const String stepsOn = 'steps_on';

  /// `1` while glucose is read from Health Connect (DECISIONS D-71).
  static const String glucoseOn = 'glucose_on';

  /// `1` once the first-run tour of the board has been seen or skipped.
  static const String tourDone = 'tour_done';

  /// JSON list of the screens whose one-time hint has been shown.
  static const String hintsSeen = 'hints_seen';

  /// `1` once the prologue has been read or skipped (DECISIONS D-76).
  static const String prologueSeen = 'prologue_seen';

  /// JSON map of consumable to how many are in the shared pouch
  /// (Amendment v0.3 §3).
  static const String pouch = 'pouch';

  /// The boss campaign as a `BossState` in JSON (Amendment v0.3 §5).
  static const String boss = 'boss';

  // Amendment v0.4. Goals, habit plans, calendar mappings and the rhythm
  // answers are small lists the user wrote: kept here as JSON so the
  // backup carries them and no table is needed (DECISIONS D-102).
  static const String goals = 'goals';
  static const String plans = 'plans';
  static const String mappings = 'mappings';
  static const String rhythm = 'rhythm';

  /// The class scores of Chapter 5 with the recommendation that was shown.
  static const String classScore = 'class_score';

  /// Where First Dawn stands (`FirstDawnState`), and the answers so far.
  static const String firstDawn = 'first_dawn';
  static const String firstDawnDraft = 'first_dawn_draft';

  /// The Sunday Check-Ins: answers, and suggestions declined or accepted.
  static const String checkIns = 'checkins';

  /// `1` to write calendar event names into exports. Off unless set.
  static const String exportEventNames = 'export_event_names';

  /// The day the calendar was last asked for, so a "not now" is not asked
  /// about again for a season.
  static const String calendarAskedOn = 'calendar_asked_on';
}

/// Reads the pouch as stored. Anything unreadable is an empty pouch.
Map<ItemKind, int> decodePouch(String? json) {
  if (json == null || json.isEmpty) return const <ItemKind, int>{};
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException {
    return const <ItemKind, int>{};
  }
  if (raw is! Map) return const <ItemKind, int>{};
  return <ItemKind, int>{
    for (final kind in ItemKind.values)
      if (raw[kind.name] is int && (raw[kind.name] as int) > 0)
        kind: raw[kind.name] as int,
  };
}

String encodePouch(Map<ItemKind, int> pouch) => jsonEncode(<String, int>{
      for (final e in pouch.entries)
        if (e.value > 0) e.key.name: e.value > pouchCap ? pouchCap : e.value,
    });

BossState decodeBoss(String? json) {
  if (json == null || json.isEmpty) return const BossState();
  try {
    return BossState.fromJson(jsonDecode(json));
  } on FormatException {
    return const BossState();
  }
}

/// The settings as the app uses them.
class GameSettings {
  const GameSettings({
    this.delveWeekday = defaultDelveWeekday,
    this.calendarOn = false,
    this.calendarAsked = false,
    this.excludedCalendars = const <String>{},
    this.healthFields = healthPresets,
    this.stepsOn = false,
    this.glucoseOn = false,
    this.tourDone = false,
    this.hintsSeen = const <String>{},
    this.prologueSeen = false,
    this.pouch = const <ItemKind, int>{},
    this.boss = const BossState(),
    this.goals = const <Goal>[],
    this.plans = const <HabitPlan>[],
    this.mappings = const <CalendarMapping>[],
    this.rhythm = const Rhythm(),
    this.classScore,
    this.firstDawn,
    this.firstDawnDraft,
    this.checkIns = const CheckIns(),
    this.exportEventNames = false,
    this.calendarAskedOn,
  });

  factory GameSettings.fromMap(Map<String, String> raw) {
    final weekday = int.tryParse(raw[SettingKey.delveWeekday] ?? '');
    return GameSettings(
      delveWeekday: (weekday != null && weekday >= 1 && weekday <= 7)
          ? weekday
          : defaultDelveWeekday,
      calendarOn: raw[SettingKey.calendarOn] == '1',
      calendarAsked: raw[SettingKey.calendarAsked] == '1',
      excludedCalendars: _stringSet(raw[SettingKey.calendarExcluded]),
      healthFields: decodeHealthFields(raw[SettingKey.healthFields]),
      stepsOn: raw[SettingKey.stepsOn] == '1',
      glucoseOn: raw[SettingKey.glucoseOn] == '1',
      tourDone: raw[SettingKey.tourDone] == '1',
      hintsSeen: _stringSet(raw[SettingKey.hintsSeen]),
      prologueSeen: raw[SettingKey.prologueSeen] == '1',
      pouch: decodePouch(raw[SettingKey.pouch]),
      boss: decodeBoss(raw[SettingKey.boss]),
      goals: decodeGoals(raw[SettingKey.goals]),
      plans: decodePlans(raw[SettingKey.plans]),
      mappings: decodeMappings(raw[SettingKey.mappings]),
      rhythm: decodeRhythm(raw[SettingKey.rhythm]),
      classScore: _classScore(raw[SettingKey.classScore]),
      firstDawn: raw[SettingKey.firstDawn] == null
          ? null
          : FirstDawnState.byName(raw[SettingKey.firstDawn]),
      firstDawnDraft: raw[SettingKey.firstDawnDraft],
      checkIns: CheckIns.decode(raw[SettingKey.checkIns]),
      exportEventNames: raw[SettingKey.exportEventNames] == '1',
      calendarAskedOn: raw[SettingKey.calendarAskedOn],
    );
  }

  static ClassScore? _classScore(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final raw = jsonDecode(json);
      return raw is Map<String, dynamic> ? ClassScore.fromJson(raw) : null;
    } on FormatException {
      return null;
    }
  }

  final int delveWeekday;
  final bool calendarOn;
  final bool calendarAsked;
  final Set<String> excludedCalendars;
  final List<HealthField> healthFields;
  final bool stepsOn;
  final bool glucoseOn;
  final bool tourDone;
  final Set<String> hintsSeen;
  final bool prologueSeen;

  /// Consumables in the shared pouch.
  final Map<ItemKind, int> pouch;

  /// The weekly boss: which one, what it has left, Marks, titles.
  final BossState boss;

  /// Everything the user has stated (Amendment v0.4 §2), archived ones
  /// included.
  final List<Goal> goals;
  final List<HabitPlan> plans;
  final List<CalendarMapping> mappings;
  final Rhythm rhythm;
  final ClassScore? classScore;

  /// Null for a hero from before 0.8 who has not been offered it yet.
  final FirstDawnState? firstDawn;

  /// The answers so far, as saved, or null.
  final String? firstDawnDraft;
  final CheckIns checkIns;
  final bool exportEventNames;
  final String? calendarAskedOn;

  List<Goal> get activeGoals => <Goal>[for (final g in goals) if (g.active) g];
  List<HabitPlan> get activePlans =>
      <HabitPlan>[for (final p in plans) if (p.active) p];

  static Set<String> _stringSet(String? json) {
    if (json == null || json.isEmpty) return const <String>{};
    final Object? raw;
    try {
      raw = jsonDecode(json);
    } on FormatException {
      return const <String>{};
    }
    if (raw is! List) return const <String>{};
    return raw.whereType<String>().toSet();
  }
}
