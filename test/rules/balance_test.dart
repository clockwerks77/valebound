// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/rules/combat.dart';
import 'package:habit_adventure/rules/encounter.dart';

import '../support/combat_policies.dart';

// The balance guardrails of Amendment v0.3 §6, measured on the real engine:
// 100 days against each of the five types at seven party levels, 3,500
// fights for each class and way of playing. The counts are also the ones
// the Python reference model gives (tool/sim), so a change to either that
// moves the balance shows up here.

const List<(int, int)> levels = <(int, int)>[
  (1, 1), (2, 2), (3, 3), (5, 4), (8, 6), (12, 9), (20, 12), //
];

(int, int) wins(
  Policy policy,
  HeroClass cls,
  int resource, {
  bool heroic = false,
}) {
  var won = 0;
  var turns = 0;
  for (final type in EnemyType.values) {
    for (final (level, companion) in levels) {
      for (var d = 0; d < 100; d++) {
        final fight = play(
          policy,
          FightSetup(
            heroClass: cls,
            level: level,
            companionLevel: companion,
            bond: 8 * companion,
            type: type,
            seed: (d * 2654435761 + 12345) & 0xFFFFFFFF,
            resource: resource,
            heroic: heroic,
          ),
        );
        if (fight.outcome == FightOutcome.won) {
          won++;
          turns += fight.turn;
        }
      }
    }
  }
  return (won, turns);
}

String percent(int won) => '${(won / 35).toStringAsFixed(1)}%';

void main() {
  // Wins out of 3,500 from the reference model, by class in the order
  // ranger, warden, sage, artificer.
  const didQuests = <int>[2892, 2916, 3081, 2943];
  const strikes = <int>[1367, 708, 776, 741];
  const heroicTier = <int>[1491, 1534, 1914, 1821];
  const noQuests = <int>[2101, 2040, 2773, 1729];
  const abilityFirst = <int>[2136, 3176, 2813, 2083];
  // The same, for a player who did their quests and reads intents, at each
  // of the seven party levels: wins out of 500.
  const byLevel = <List<int>>[
    <int>[431, 428, 411, 413, 375, 442, 392],
    <int>[401, 415, 400, 397, 383, 448, 472],
    <int>[436, 424, 441, 438, 420, 457, 465],
    <int>[415, 425, 409, 420, 393, 425, 456],
  ];

  test('the balance holds, and matches the reference model fight for fight',
      () {
    print('BALANCE (3,500 fights a cell: 5 types x 7 party levels x 100 days)');
    print('class      quests+reads  turns  no quests  ability-first  '
        'strike-only  heroic');
    for (var i = 0; i < HeroClass.choices.length; i++) {
      final cls = HeroClass.choices[i];
      final (a, turns) = wins(smart, cls, 7);
      final (b, _) = wins(strikeOnly, cls, 7);
      final (c, _) = wins(smart, cls, 7, heroic: true);
      final (d, _) = wins(smart, cls, 2);
      final (e, _) = wins(greedy, cls, 7);
      print('${cls.name.padRight(10)} ${percent(a).padLeft(11)}  '
          '${(turns / a).toStringAsFixed(1).padLeft(5)}  '
          '${percent(d).padLeft(9)}  ${percent(e).padLeft(13)}  '
          '${percent(b).padLeft(11)}  ${percent(c).padLeft(6)}');
      expect(a, didQuests[i], reason: '${cls.name}, quests done and reading');
      expect(b, strikes[i], reason: '${cls.name}, striking only');
      expect(c, heroicTier[i], reason: '${cls.name}, Heroic tier');
      expect(d, noQuests[i], reason: '${cls.name}, no quests done');
      expect(e, abilityFirst[i], reason: '${cls.name}, ability first');

      // The guardrails themselves (Amendment v0.3 §6).
      expect(a / 3500, inInclusiveRange(0.75, 0.92),
          reason: 'about 80% for a player who did their quests and reads');
      expect(b / 3500, lessThan(0.45),
          reason: 'really losable by ignoring intents');
      expect(turns / a, inInclusiveRange(3.0, 5.5),
          reason: 'won in three to five turns');
      expect(d, lessThan(a), reason: 'a day lived well makes you stronger');
    }
    final heroicAll = heroicTier.reduce((x, y) => x + y) / (4 * 3500);
    expect(heroicAll, inInclusiveRange(0.42, 0.60),
        reason: 'Heroic tier is about a coin toss');
  });

  test('the fight is as hard at level 1 as at level 20', () {
    // Version 0.7.0 met the guardrail only on average: a level 1 Warden who
    // did everything right won 45%, a level 20 one always (DECISIONS D-101).
    print('BY LEVEL (quests done, reading intents; 500 fights a cell)');
    print('class      ${levels.map((l) => 'L${l.$1}/C${l.$2}'.padLeft(8)).join()}');
    for (var i = 0; i < HeroClass.choices.length; i++) {
      final cls = HeroClass.choices[i];
      final row = <int>[];
      for (final level in levels) {
        var won = 0;
        for (final type in EnemyType.values) {
          for (var d = 0; d < 100; d++) {
            final fight = play(
              smart,
              FightSetup(
                heroClass: cls,
                level: level.$1,
                companionLevel: level.$2,
                bond: 8 * level.$2,
                type: type,
                seed: (d * 2654435761 + 12345) & 0xFFFFFFFF,
                resource: 7,
              ),
            );
            if (fight.outcome == FightOutcome.won) won++;
          }
        }
        row.add(won);
      }
      print('${cls.name.padRight(10)} '
          '${row.map((w) => '${(w / 5).toStringAsFixed(0)}%'.padLeft(8)).join()}');
      expect(row, byLevel[i], reason: cls.name);
      for (final won in row) {
        expect(won / 500, inInclusiveRange(0.72, 0.96),
            reason: '${cls.name}: about 80% at every level');
      }
    }
  });

  test('no class is shut out by any kind of creature, at any level', () {
    for (final cls in HeroClass.choices) {
      for (final type in EnemyType.values) {
        for (final level in levels) {
          var won = 0;
          for (var d = 0; d < 100; d++) {
            final fight = play(
              smart,
              FightSetup(
                heroClass: cls,
                level: level.$1,
                companionLevel: level.$2,
                bond: 8 * level.$2,
                type: type,
                seed: (d * 2654435761 + 12345) & 0xFFFFFFFF,
                resource: 7,
              ),
            );
            if (fight.outcome == FightOutcome.won) won++;
          }
          expect(won, greaterThanOrEqualTo(30),
              reason: '${cls.name} against ${type.name} at level ${level.$1}');
        }
      }
    }
  });

  test('a Warden walks in with a Shield at every level', () {
    for (final level in <int>[1, 2, 3, 5, 12]) {
      final fight = Fight(
        FightSetup(
          heroClass: HeroClass.warden,
          level: level,
          companionLevel: 1,
          bond: 0,
          type: EnemyType.brute,
          seed: 3,
          resource: 5,
        ),
      );
      expect(fight.shield, greaterThan(0), reason: 'level $level');
      expect(fight.shield, (fight.heroMax * 10) ~/ 100);
    }
  });

  test('a simulated week for one class', () {
    // A Warden at hero level 4 with a level 3 companion, who finishes four
    // quests a day, one of them a Standard Vitality quest: Guard 2 + 2 + 3.
    const resource = 7;
    print('WEEK: Warden, hero level 4, companion level 3, Guard $resource');
    print('day         creature               type      match   outcome  '
        'turns  HP left');
    var won = 0;
    for (var i = 0; i < 7; i++) {
      final day = '2026-11-${15 + i}';
      final enemy = enemyFor(day);
      final fight = play(
        smart,
        FightSetup(
          heroClass: HeroClass.warden,
          level: 4,
          companionLevel: 3,
          bond: 30,
          type: enemy.type,
          seed: encounterSeed(day),
          resource: resource,
        ),
      );
      if (fight.outcome == FightOutcome.won) won++;
      print('$day  ${enemy.name.padRight(21)}  '
          '${enemy.type.label.padRight(8)}  '
          '${effectOf(HeroClass.warden, enemy.type).label.padRight(6)}  '
          '${(fight.outcome == FightOutcome.won ? 'won' : 'held').padRight(7)}  '
          '${fight.turn.toString().padLeft(5)}  '
          '${fight.heroHp}/${fight.heroMax}');
    }
    print('WEEK: $won of 7 won');
    expect(won, inInclusiveRange(3, 7));

    // The same week, same level and resource, for each class.
    for (final cls in HeroClass.choices) {
      var count = 0;
      for (var i = 0; i < 7; i++) {
        final day = '2026-11-${15 + i}';
        final fight = play(
          smart,
          FightSetup(
            heroClass: cls,
            level: 4,
            companionLevel: 3,
            bond: 30,
            type: enemyFor(day).type,
            seed: encounterSeed(day),
            resource: resource,
          ),
        );
        if (fight.outcome == FightOutcome.won) count++;
      }
      print('WEEK: ${cls.name} $count of 7');
      expect(count, inInclusiveRange(3, 7), reason: cls.name);
    }
  });
}
