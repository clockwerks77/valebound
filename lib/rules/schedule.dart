import 'day_key.dart';
import 'enums.dart';

/// When a quest is due. DESIGN §6.1: daily / selected weekdays / weekly on a
/// day / custom interval / one-off with a date.
class Schedule {
  const Schedule({
    required this.type,
    this.weekdays = const <int>{},
    this.intervalDays,
    this.anchorDay,
  });

  const Schedule.daily() : this(type: ScheduleType.daily);

  /// Monday–Friday.
  const Schedule.workdays()
      : this(type: ScheduleType.weekdays, weekdays: const <int>{1, 2, 3, 4, 5});

  const Schedule.onWeekdays(Set<int> days)
      : this(type: ScheduleType.weekdays, weekdays: days);

  Schedule.weeklyOn(int weekday)
      : this(type: ScheduleType.weekly, weekdays: <int>{weekday});

  const Schedule.every(int days, {required String from})
      : this(type: ScheduleType.interval, intervalDays: days, anchorDay: from);

  const Schedule.once(String day)
      : this(type: ScheduleType.oneOff, anchorDay: day);

  final ScheduleType type;

  /// ISO weekdays, Monday = 1 … Sunday = 7. Used by weekdays and weekly.
  final Set<int> weekdays;

  /// For [ScheduleType.interval]: every N days counted from [anchorDay].
  final int? intervalDays;

  /// Interval start day, or the single day of a one-off quest.
  final String? anchorDay;

  bool isDueOn(String day) {
    switch (type) {
      case ScheduleType.daily:
        return true;
      case ScheduleType.weekdays:
      case ScheduleType.weekly:
        return weekdays.contains(DayKey.weekday(day));
      case ScheduleType.interval:
        final n = intervalDays ?? 0;
        final anchor = anchorDay;
        if (n <= 0 || anchor == null) return false;
        final gap = DayKey.daysBetween(anchor, day);
        return gap >= 0 && gap % n == 0;
      case ScheduleType.oneOff:
        return anchorDay == day;
    }
  }

  /// True for a one-off whose day has already gone by.
  bool isPastOneOff(String today) {
    final anchor = anchorDay;
    if (type != ScheduleType.oneOff || anchor == null) return false;
    return DayKey.daysBetween(anchor, today) > 0;
  }

  /// A short readable form, used in the Quest Log and later in `Quests.md`.
  String describe() {
    switch (type) {
      case ScheduleType.daily:
        return 'Daily';
      case ScheduleType.weekdays:
        if (weekdays.length == 5 &&
            weekdays.containsAll(const <int>{1, 2, 3, 4, 5})) {
          return 'Weekdays';
        }
        if (weekdays.length == 7) return 'Daily';
        final sorted = weekdays.toList()..sort();
        if (sorted.isEmpty) return 'No days chosen';
        return sorted.map((d) => DayKey.weekdayShort[d - 1]).join(', ');
      case ScheduleType.weekly:
        if (weekdays.isEmpty) return 'Weekly';
        return 'Weekly, ${DayKey.weekdayLong[weekdays.first - 1]}';
      case ScheduleType.interval:
        final n = intervalDays ?? 0;
        return n == 1 ? 'Daily' : 'Every $n days';
      case ScheduleType.oneOff:
        final anchor = anchorDay;
        return anchor == null ? 'One-off' : 'Once, $anchor';
    }
  }

  static String encodeWeekdays(Set<int> days) {
    final sorted = days.toList()..sort();
    return sorted.join(',');
  }

  static Set<int> decodeWeekdays(String text) {
    if (text.trim().isEmpty) return <int>{};
    return text
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toSet();
  }
}
