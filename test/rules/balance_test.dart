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
  const didQuests = <int>[2977, 2800, 3114, 2977];
  const strikes = <int>[821, 927, 862, 903];
  const heroicTier = <int>[1321, 1662, 2251, 2067];
  const noQuests = <int>[2292, 1868, 2748, 1781];
  const abilityFirst = <int>[1563, 2799, 2909, 1674];

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
      expect(b / 3500, lessThan(0.35),
          reason: 'really losable by ignoring intents');
      expect(turns / a, inInclusiveRange(3.0, 5.5),
          reason: 'won in three to five turns');
      expect(d, lessThan(a), reason: 'a day lived well makes you stronger');
    }
    final heroicAll = heroicTier.reduce((x, y) => x + y) / (4 * 3500);
    expect(heroicAll, inInclusiveRange(0.42, 0.60),
        reason: 'Heroic tier is about a coin toss');
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
  });
}
