import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/day_cycle.dart';
import 'package:habit_adventure/rules/delve.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/health_fields.dart';
import 'package:habit_adventure/rules/progression.dart';
import 'package:habit_adventure/rules/reminders.dart';
import 'package:habit_adventure/rules/schedule.dart';

// Phase 3 rules: the weekly Delve, the comeback bonus, reminder times and
// the Health Log's fields. Pure Dart, no database.

List<DelveEntry> _week(int quests, {int heroic = 0, int companion = 0}) =>
    <DelveEntry>[
      for (var i = 0; i < quests; i++)
        DelveEntry(
          '2026-11-${(9 + i % 7).toString().padLeft(2, '0')}',
          i < companion ? Track.companion : Track.hero,
          i >= quests - heroic ? Difficulty.heroic : Difficulty.minor,
        ),
    ];

void main() {
  group('The weekly Delve (DESIGN §3B, §4.2)', () {
    test('the Delve day is the latest chosen weekday, today included', () {
      // 2026-11-14 is a Saturday.
      expect(latestDelveDay('2026-11-14', DateTime.sunday), '2026-11-08');
      expect(latestDelveDay('2026-11-15', DateTime.sunday), '2026-11-15');
      expect(latestDelveDay('2026-11-17', DateTime.sunday), '2026-11-15');
      expect(latestDelveDay('2026-11-17', DateTime.tuesday), '2026-11-17');
      expect(latestDelveDay('2026-11-16', DateTime.saturday), '2026-11-14');
      expect(defaultDelveWeekday, DateTime.sunday);
    });

    test('the week is the seven days ending on the Delve day', () {
      expect(delveWeekStart('2026-11-15'), '2026-11-09');
      expect(delveWeekStart('2026-11-01'), '2026-10-26');
    });

    test('supplies come from the week’s quests', () {
      final supplies = suppliesFrom(const <DelveEntry>[
        DelveEntry('2026-11-09', Track.hero, Difficulty.minor),
        DelveEntry('2026-11-09', Track.shared, Difficulty.standard),
        DelveEntry('2026-11-11', Track.companion, Difficulty.minor),
        DelveEntry('2026-11-14', Track.hero, Difficulty.heroic),
        DelveEntry('2026-11-15', Track.hero, Difficulty.boss),
      ]);
      expect(supplies.provisions, 3);
      expect(supplies.trailMarks, 2);
      expect(supplies.keys, 2);
      expect(supplies.daysActive, 4);
      expect(supplies.quests, 5);
      // Every quest counts one; Heroic and Boss count two more each.
      expect(supplies.score, 9);
    });

    test('three outcomes: Cleared, Scouted, Rested', () {
      expect(tierFor(suppliesFrom(_week(0))), DelveTier.rested);
      expect(tierFor(suppliesFrom(_week(6))), DelveTier.rested);
      expect(tierFor(suppliesFrom(_week(7))), DelveTier.scouted);
      expect(tierFor(suppliesFrom(_week(20))), DelveTier.scouted);
      expect(tierFor(suppliesFrom(_week(21))), DelveTier.cleared);
      // Big quests count for more: 15 quests, three of them Heroic.
      expect(tierFor(suppliesFrom(_week(15, heroic: 3))), DelveTier.cleared);
      expect(tierFor(suppliesFrom(_week(14, heroic: 3))), DelveTier.scouted);
      // Companion quests count the same as the hero's.
      expect(
        tierFor(suppliesFrom(_week(7, companion: 7))),
        DelveTier.scouted,
      );
      expect(DelveTier.values.map((t) => t.label), <String>[
        'Cleared',
        'Scouted',
        'Rested',
      ]);
    });

    test('every outcome brings something home, and more for a fuller week',
        () {
      final rested = rewardFor(DelveTier.rested);
      final scouted = rewardFor(DelveTier.scouted);
      final cleared = rewardFor(DelveTier.cleared);
      for (final reward in <DelveReward>[rested, scouted, cleared]) {
        expect(reward.gold, greaterThan(0));
        expect(reward.eachMaterial, greaterThan(0));
        expect(reward.materials.keys, MaterialKind.values);
        expect(reward.materials.values.toSet(), <int>{reward.eachMaterial});
      }
      expect(scouted.gold, greaterThan(rested.gold));
      expect(cleared.gold, greaterThan(scouted.gold));
      expect(scouted.eachMaterial, greaterThan(rested.eachMaterial));
      expect(cleared.eachMaterial, greaterThan(scouted.eachMaterial));
      expect(rested.gold, 8);
      expect(cleared.gold, 40);
    });

    test('the site changes week by week and is the same all week', () {
      expect(delveSiteFor('2026-01-04'), delveSites[0]);
      expect(delveSiteFor('2026-01-11'), delveSites[1]);
      expect(delveSiteFor('2026-02-15'), delveSites[0]);
      expect(delveSiteFor('2025-12-28'), delveSites[5]);
      expect(delveSiteFor('2026-11-15'), delveSiteFor('2026-11-15'));
      expect(delveSites.toSet().length, delveSites.length);
    });

    test('each outcome has a warm line naming the companion', () {
      for (final tier in DelveTier.values) {
        expect(delveLine(tier, 'Babs'), contains('Babs'));
      }
    });
  });

  group('The comeback bonus (DESIGN §4.3, §7A.3)', () {
    test('a Minor quest plus the welcome is worth 25 XP', () {
      final outcome = applyCompletion(
        totals: const PartyTotals(),
        difficulty: Difficulty.minor,
        track: Track.hero,
        attribute: Attribute.adventure,
        bonusHeroXp: comebackBonusXp,
      );
      expect(outcome.award.heroXp, 10);
      expect(outcome.bonusHeroXp, 15);
      expect(outcome.heroXpGained, 25);
      expect(outcome.after.heroXp, 25);
      expect(outcome.after.attributeXp[Attribute.adventure], 25);
      expect(outcome.totalBond, 0);
    });

    test('Comfort adds Bond, which only ever rises', () {
      final outcome = applyCompletion(
        totals: const PartyTotals(bond: 40),
        difficulty: Difficulty.minor,
        track: Track.hero,
        attribute: Attribute.adventure,
        bonusHeroXp: comebackBonusXp,
        bonusBond: comfortBonusBond,
      );
      expect(outcome.comfortBond, 2);
      expect(outcome.totalBond, 2);
      expect(outcome.after.bond, 42);
    });

    test('an ordinary quest is unchanged, and a bonus can never take', () {
      final plain = applyCompletion(
        totals: const PartyTotals(),
        difficulty: Difficulty.standard,
        track: Track.hero,
        attribute: Attribute.vitality,
      );
      expect(plain.heroXpGained, plain.award.heroXp);
      expect(plain.bonusHeroXp, 0);
      expect(plain.comfortBond, 0);

      final odd = applyCompletion(
        totals: const PartyTotals(heroXp: 50, bond: 5),
        difficulty: Difficulty.minor,
        track: Track.hero,
        attribute: Attribute.mind,
        bonusHeroXp: -100,
        bonusBond: -9,
      );
      expect(odd.after.heroXp, 60);
      expect(odd.after.bond, 5);
    });

    test('the quest and its numbers', () {
      expect(comebackQuestName, 'Return to the Vale');
      expect(comebackAfterFullDaysAway, 2);
      expect(Difficulty.minor.xp + comebackBonusXp, Difficulty.standard.xp);
    });
  });

  group('Quest reminders (DESIGN §6.1)', () {
    // 2026-11-14 is a Saturday.
    final early = DateTime(2026, 11, 14, 7);
    final later = DateTime(2026, 11, 14, 9);

    test('times are HH:mm on a 24-hour clock', () {
      expect(parseReminderTime('07:30'), (hour: 7, minute: 30));
      expect(parseReminderTime('7:05'), (hour: 7, minute: 5));
      expect(parseReminderTime('23:59'), (hour: 23, minute: 59));
      expect(parseReminderTime('24:00'), isNull);
      expect(parseReminderTime('12:60'), isNull);
      expect(parseReminderTime('soon'), isNull);
      expect(parseReminderTime(null), isNull);
      expect(formatReminderTime(7, 5), '07:05');
      expect(formatReminderTime(18, 30), '18:30');
    });

    test('off by default: no time, no reminders', () {
      expect(
        upcomingReminders(
          schedule: const Schedule.daily(),
          time: null,
          now: early,
        ),
        isEmpty,
      );
    });

    test('a daily quest reminds today if the time is still ahead', () {
      final times = upcomingReminders(
        schedule: const Schedule.daily(),
        time: '08:00',
        now: early,
      );
      expect(times.length, remindersAhead);
      expect(times.first, DateTime(2026, 11, 14, 8));
      expect(times.last, DateTime(2026, 11, 20, 8));
    });

    test('once the time has gone by, the next one is tomorrow', () {
      final times = upcomingReminders(
        schedule: const Schedule.daily(),
        time: '08:00',
        now: later,
      );
      expect(times.first, DateTime(2026, 11, 15, 8));
    });

    test('a quest already done or set aside today does not remind today', () {
      final times = upcomingReminders(
        schedule: const Schedule.daily(),
        time: '08:00',
        now: early,
        settledToday: true,
      );
      expect(times.first, DateTime(2026, 11, 15, 8));
    });

    test('a weekly quest reminds on its day only', () {
      final times = upcomingReminders(
        schedule: Schedule.weeklyOn(DateTime.saturday),
        time: '09:00',
        now: early,
      );
      expect(times, <DateTime>[
        DateTime(2026, 11, 14, 9),
        DateTime(2026, 11, 21, 9),
        DateTime(2026, 11, 28, 9),
        DateTime(2026, 12, 5, 9),
        DateTime(2026, 12, 12, 9),
      ]);
    });

    test('a one-off whose time has gone by has nothing left to remind', () {
      expect(
        upcomingReminders(
          schedule: const Schedule.once('2026-11-14'),
          time: '08:00',
          now: later,
        ),
        isEmpty,
      );
    });

    test('ids are stable, small and distinct per reminder', () {
      const quest = '3f0c2a4e-7d1b-4c55-9a53-0e6f1b2c9d10';
      expect(reminderId(quest, 0), reminderId(quest, 0));
      expect(reminderId(quest, 0), isNot(reminderId(quest, 1)));
      expect(reminderId(quest, 6), lessThan(1 << 31));
      expect(reminderId(quest, 0), greaterThanOrEqualTo(0));
      expect(reminderId('another-quest', 0), isNot(reminderId(quest, 0)));
    });
  });

  group('Health Log fields (DESIGN §9.3)', () {
    test('the default is steps plus the presets, all optional', () {
      expect(defaultHealthFields().map((f) => f.key), <String>[
        'steps',
        'glucose',
        'time_in_range',
        'weight',
        'injection',
      ]);
      expect(
        defaultHealthFields().firstWhere((f) => f.key == 'injection').kind,
        HealthFieldKind.check,
      );
    });

    test('the chosen fields survive being stored', () {
      final fields = <HealthField>[
        healthPresets[1],
        const HealthField(key: 'blood_pressure', label: 'Blood pressure'),
        const HealthField(
          key: 'mood',
          label: 'How the day felt',
          kind: HealthFieldKind.text,
        ),
      ];
      final back = decodeHealthFields(encodeHealthFields(fields));
      expect(back.map((f) => f.key), <String>[
        'glucose',
        'blood_pressure',
        'mood',
      ]);
      expect(back[0].unit, 'mmol/L');
      expect(back[2].kind, HealthFieldKind.text);
      expect(back[2].label, 'How the day felt');
    });

    test('nothing stored means the defaults; an empty list stays empty', () {
      expect(decodeHealthFields(null).length, healthPresets.length);
      expect(decodeHealthFields('not json').length, healthPresets.length);
      expect(decodeHealthFields('[]'), isEmpty);
    });

    test('a field the user names gets a key of its own', () {
      expect(healthKeyFor('Blood pressure', const <String>[]), 'blood_pressure');
      expect(healthKeyFor('Weight', const <String>['weight']), 'weight_2');
      expect(healthKeyFor('  ', const <String>[]), 'field');
      expect(healthKeyFor('HbA1c (%)', const <String>[]), 'hba1c');
    });

    test('a tick stores Done, with the note when one was typed', () {
      expect(encodeCheck(''), 'Done');
      expect(encodeCheck(' 5 mg '), 'Done (5 mg)');
      expect(decodeCheck('Done'), '');
      expect(decodeCheck('Done (5 mg)'), '5 mg');
      expect(decodeCheck('7.5 mg, left side'), '7.5 mg, left side');
    });

    test('a unit can be changed without touching anything else', () {
      final pounds = healthPresets[3].withUnit('lb');
      expect(pounds.key, 'weight');
      expect(pounds.label, 'Weight');
      expect(pounds.unit, 'lb');
    });
  });
}
