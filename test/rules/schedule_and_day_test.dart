import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/companion_rules.dart';
import 'package:habit_adventure/rules/day_cycle.dart';
import 'package:habit_adventure/rules/day_key.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/schedule.dart';

void main() {
  // 2026-11-09 is a Monday; 2026-11-14 is a Saturday.
  const monday = '2026-11-09';
  const saturday = '2026-11-14';
  const sunday = '2026-11-15';

  group('DayKey', () {
    test('formats and parses local days', () {
      expect(DayKey.of(DateTime(2026, 11, 14, 23, 59)), saturday);
      expect(DayKey.of(DateTime(2026, 1, 5, 0, 0)), '2026-01-05');
      expect(DayKey.parse(saturday), DateTime(2026, 11, 14));
    });

    test('weekday and day arithmetic', () {
      expect(DayKey.weekday(monday), 1);
      expect(DayKey.weekday(saturday), 6);
      expect(DayKey.weekday(sunday), 7);
      expect(DayKey.daysBetween(monday, saturday), 5);
      expect(DayKey.daysBetween(saturday, monday), -5);
      expect(DayKey.addDays(saturday, 1), sunday);
      expect(DayKey.addDays('2026-12-31', 1), '2027-01-01');
      expect(DayKey.addDays('2028-02-28', 1), '2028-02-29');
    });

    test('day counts are steady across daylight-saving changes', () {
      // Clocks change on 2026-03-08 and 2026-11-01 in Ontario.
      expect(DayKey.daysBetween('2026-03-07', '2026-03-09'), 2);
      expect(DayKey.daysBetween('2026-10-31', '2026-11-02'), 2);
      expect(DayKey.addDays('2026-03-07', 2), '2026-03-09');
      expect(DayKey.addDays('2026-10-31', 2), '2026-11-02');
    });

    test('friendly form', () {
      expect(DayKey.friendly(saturday), 'Saturday 14 November');
    });
  });

  group('Schedules (DESIGN §6.1)', () {
    test('daily is due every day', () {
      const s = Schedule.daily();
      expect(s.isDueOn(monday), isTrue);
      expect(s.isDueOn(sunday), isTrue);
      expect(s.describe(), 'Daily');
    });

    test('selected weekdays', () {
      const s = Schedule.workdays();
      expect(s.isDueOn(monday), isTrue);
      expect(s.isDueOn(saturday), isFalse);
      expect(s.describe(), 'Weekdays');

      const weekend = Schedule.onWeekdays(<int>{6, 7});
      expect(weekend.isDueOn(saturday), isTrue);
      expect(weekend.isDueOn(sunday), isTrue);
      expect(weekend.isDueOn(monday), isFalse);
      expect(weekend.describe(), 'Sat, Sun');
    });

    test('weekly on a day', () {
      final s = Schedule.weeklyOn(6);
      expect(s.isDueOn(saturday), isTrue);
      expect(s.isDueOn(sunday), isFalse);
      expect(s.isDueOn('2026-11-21'), isTrue);
      expect(s.describe(), 'Weekly, Saturday');
    });

    test('custom interval from an anchor day', () {
      const s = Schedule.every(3, from: monday);
      expect(s.isDueOn(monday), isTrue);
      expect(s.isDueOn('2026-11-10'), isFalse);
      expect(s.isDueOn('2026-11-12'), isTrue);
      expect(s.isDueOn('2026-11-08'), isFalse, reason: 'before the anchor');
      expect(s.describe(), 'Every 3 days');
    });

    test('one-off with a date', () {
      const s = Schedule.once(saturday);
      expect(s.isDueOn(saturday), isTrue);
      expect(s.isDueOn(sunday), isFalse);
      expect(s.isPastOneOff(saturday), isFalse);
      expect(s.isPastOneOff(sunday), isTrue);
      expect(const Schedule.daily().isPastOneOff(sunday), isFalse);
    });

    test('weekday text round-trips', () {
      expect(Schedule.encodeWeekdays(<int>{7, 6}), '6,7');
      expect(Schedule.decodeWeekdays('6,7'), <int>{6, 7});
      expect(Schedule.decodeWeekdays(''), isEmpty);
      expect(Schedule.decodeWeekdays('9,x,3'), <int>{3});
    });
  });

  group('Day rollover and time away (DESIGN §4.1, §4.3, §6.4)', () {
    DateTime at(String day, [int hour = 8]) {
      final d = DayKey.parse(day);
      return DateTime(d.year, d.month, d.day, hour);
    }

    test('the very first Dawn', () {
      final plan = planDawn(lastDawnDay: null, now: at(monday));
      expect(plan.isFirstDawn, isTrue);
      expect(plan.isNewDay, isTrue);
      expect(plan.comebackDue, isFalse);
      expect(plan.today, monday);
    });

    test('same day: nothing new', () {
      final plan = planDawn(lastDawnDay: monday, now: at(monday, 22));
      expect(plan.isNewDay, isFalse);
      expect(plan.comebackDue, isFalse);
    });

    test('a new day begins at local midnight', () {
      final late = planDawn(
        lastDawnDay: monday,
        now: DateTime(2026, 11, 9, 23, 59, 59),
      );
      expect(late.isNewDay, isFalse);
      final next = planDawn(
        lastDawnDay: monday,
        now: DateTime(2026, 11, 10, 0, 0, 1),
      );
      expect(next.isNewDay, isTrue);
      expect(next.fullDaysAway, 0);
      expect(next.comebackDue, isFalse);
    });

    test('one day away is just a new day', () {
      final plan = planDawn(lastDawnDay: monday, now: at('2026-11-11'));
      expect(plan.isNewDay, isTrue);
      expect(plan.fullDaysAway, 1);
      expect(plan.comebackDue, isFalse);
    });

    test('the comeback quest is due after 2+ days away', () {
      final two = planDawn(lastDawnDay: monday, now: at('2026-11-12'));
      expect(two.fullDaysAway, 2);
      expect(two.comebackDue, isTrue);

      final month = planDawn(lastDawnDay: monday, now: at('2026-12-09'));
      expect(month.fullDaysAway, 29);
      expect(month.comebackDue, isTrue);
    });

    test('a clock set backwards does no harm', () {
      final plan = planDawn(lastDawnDay: saturday, now: at(monday));
      expect(plan.isNewDay, isFalse);
      expect(plan.comebackDue, isFalse);
    });
  });

  group('Companion kinds, tricks and titles', () {
    test('the v1 roster is the six kinds in the design', () {
      expect(
        CompanionKind.values.map((k) => k.label).toList(),
        <String>['Hound', 'Cat', 'Fox', 'Owl', 'Hare', 'Clockwork Sprite'],
      );
    });

    test('each kind has a temperament and its own attribute affinity', () {
      final affinities = CompanionKind.values.map((k) => k.affinity).toSet();
      expect(affinities.length, CompanionKind.values.length);
      for (final k in CompanionKind.values) {
        expect(k.temperament.trim(), isNotEmpty);
      }
    });

    test('tricks unlock at companion levels 2, 4, 6, 8 and 10', () {
      expect(companionTricks.map((t) => t.level).toList(), <int>[2, 4, 6, 8, 10]);
      expect(tricksUnlockedAt(1), isEmpty);
      expect(tricksUnlockedAt(2), <String>['sniff_out']);
      expect(tricksUnlockedAt(3), <String>['sniff_out']);
      expect(tricksUnlockedAt(4), <String>['sniff_out', 'fetch']);
      expect(tricksUnlockedAt(6).last, 'scout');
      expect(tricksUnlockedAt(8).last, 'comfort');
      expect(tricksUnlockedAt(10).length, 5);
      expect(tricksUnlockedAt(40).length, 5);
    });

    test('titles', () {
      expect(titleForLevel(1), 'Newcomer to the Vale');
      expect(titleForLevel(5), 'Vale Walker');
      expect(titleForLevel(6), 'Vale Walker');
      expect(titleUnlockedAt(5), 'Vale Walker');
      expect(titleUnlockedAt(6), isNull);
      expect(titlesEarned(5).last, 'Vale Walker');
    });

    test('bond milestones', () {
      expect(nextBondMilestone(0), 10);
      expect(nextBondMilestone(10), 25);
      expect(previousBondMilestone(9), 0);
      expect(previousBondMilestone(30), 25);
      expect(nextBondMilestone(100000), isNull);
    });
  });
}
