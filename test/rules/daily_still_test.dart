import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/daily_still.dart';
import 'package:habit_adventure/rules/day_key.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/progression.dart';
import 'package:habit_adventure/rules/still.dart';

// The day's Still creature (DECISIONS D-70): one each Dawn, stirred by every
// quest, woken by the third, and nothing to lose if it sleeps on.

void main() {
  group('Which creature', () {
    test('a day always has the same one', () {
      expect(dailyStillFor('2026-11-14').key, dailyStillFor('2026-11-14').key);
    });

    test('they take turns: no two days running are the same', () {
      for (var i = 0; i < 40; i++) {
        final day = DayKey.addDays('2026-11-01', i);
        expect(
          dailyStillFor(day).key,
          isNot(dailyStillFor(DayKey.addDays(day, 1)).key),
          reason: day,
        );
      }
    });

    test('over six days every drafted creature has its day', () {
      final seen = <String>{
        for (var i = 0; i < stillCreatures.length; i++)
          dailyStillFor(DayKey.addDays('2026-11-14', i)).key,
      };
      expect(seen.length, stillCreatures.length);
    });

    test('days before the reference date work too', () {
      expect(stillCreatures, contains(dailyStillFor('2025-12-25')));
    });
  });

  group('Stirring and waking', () {
    test('three quests wake it', () {
      expect(dailyStillStirs, 3);
      expect(wakesDailyStill(doneBefore: 0, giftGiven: false), isFalse);
      expect(wakesDailyStill(doneBefore: 1, giftGiven: false), isFalse);
      expect(wakesDailyStill(doneBefore: 2, giftGiven: false), isTrue);
    });

    test('it wakes once a day, however many quests follow', () {
      expect(wakesDailyStill(doneBefore: 3, giftGiven: true), isFalse);
      expect(wakesDailyStill(doneBefore: 9, giftGiven: true), isFalse);
    });

    test('a day already past three when the creature first appears', () {
      // The day the app is updated: the next quest wakes it.
      expect(wakesDailyStill(doneBefore: 5, giftGiven: false), isTrue);
    });

    test('each quest is one stir, and it never shows more than three', () {
      DailyStill at(int done, {bool given = false}) =>
          dailyStill(day: '2026-11-14', questsDone: done, giftGiven: given);
      expect(at(0).stirs, 0);
      expect(at(0).stirsLeft, 3);
      expect(at(2).stirs, 2);
      expect(at(2).stirsLeft, 1);
      expect(at(2).awake, isFalse);
      expect(at(3, given: true).awake, isTrue);
      expect(at(3, given: true).stirsLeft, 0);
      expect(at(7, given: true).stirs, 3);
      expect(at(-1).stirs, 0);
    });
  });

  group('The gift', () {
    const totals = PartyTotals(
      materials: <MaterialKind, int>{
        MaterialKind.timber: 1,
        MaterialKind.stone: 2,
      },
    );

    CompletionOutcome complete({required bool wake}) => applyCompletion(
          totals: totals,
          difficulty: Difficulty.minor,
          track: Track.companion,
          attribute: Attribute.care,
          wakeDailyStill: wake,
        );

    test('a little gold and one material the place still needs', () {
      final plain = complete(wake: false);
      final woke = complete(wake: true);
      expect(plain.wokeDailyStill, isFalse);
      expect(plain.dailyStillGift, isNull);
      expect(plain.stillGiftGold, 0);

      expect(woke.wokeDailyStill, isTrue);
      expect(woke.stillGiftGold, dailyStillGold);
      expect(woke.after.gold, plain.after.gold + dailyStillGold);
      // The Gate Lantern asks for two Timber and has one.
      expect(woke.dailyStillGift, MaterialKind.timber);
      expect(
        woke.after.materialCount(MaterialKind.timber),
        plain.after.materialCount(MaterialKind.timber) + dailyStillMaterials,
      );
    });

    test('no XP: a level stays the sum of the quests done', () {
      final plain = complete(wake: false);
      final woke = complete(wake: true);
      expect(woke.after.heroXp, plain.after.heroXp);
      expect(woke.after.companionXp, plain.after.companionXp);
      expect(woke.after.bond, plain.after.bond);
      expect(woke.after.paces, plain.after.paces);
    });

    test('the gift can be the last thing a place needs', () {
      expect(complete(wake: false).newRestorationIndexes, isEmpty);
      expect(complete(wake: true).newRestorationIndexes, <int>[0]);
    });
  });
}
