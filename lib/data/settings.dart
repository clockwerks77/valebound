import 'dart:convert';

import '../rules/delve.dart';
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
    );
  }

  final int delveWeekday;
  final bool calendarOn;
  final bool calendarAsked;
  final Set<String> excludedCalendars;
  final List<HealthField> healthFields;
  final bool stepsOn;

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
