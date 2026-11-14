/// The one notification the app may send (DESIGN §6.1, §14): an optional,
/// local reminder for a quest, off by default.
///
/// Reminders are planned a week ahead each time the app is opened. If the
/// app is not opened for a week they simply go quiet; they never pile up.
library;

import 'day_key.dart';
import 'schedule.dart';

/// `HH:mm` in 24-hour time, or null if [value] is not a time.
({int hour, int minute})? parseReminderTime(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

String formatReminderTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// How many reminders are planned ahead for one quest.
const int remindersAhead = 7;

/// The next times a quest with [schedule] and a reminder at [time] should
/// remind, starting from [now]. Today counts only if the time is still ahead
/// and the quest is not already done or set aside for today.
List<DateTime> upcomingReminders({
  required Schedule schedule,
  required String? time,
  required DateTime now,
  bool settledToday = false,
  int count = remindersAhead,
  int horizonDays = 28,
}) {
  final at = parseReminderTime(time);
  if (at == null) return const <DateTime>[];
  final today = DayKey.of(now);
  final out = <DateTime>[];
  for (var offset = 0; offset <= horizonDays && out.length < count; offset++) {
    final day = DayKey.addDays(today, offset);
    if (!schedule.isDueOn(day)) continue;
    final date = DayKey.parse(day);
    final when = DateTime(date.year, date.month, date.day, at.hour, at.minute);
    if (offset == 0 && (settledToday || !when.isAfter(now))) continue;
    out.add(when);
  }
  return out;
}

/// A stable, positive notification id for the [index]th reminder of a quest.
int reminderId(String questId, int index) {
  var hash = 7;
  for (final unit in questId.codeUnits) {
    hash = (hash * 31 + unit) & 0x03FFFFFF;
  }
  return hash * 8 + (index % 8);
}

/// The body under the quest's name. Never a nudge about what was not done.
const String reminderBody = 'Whenever you are ready.';
