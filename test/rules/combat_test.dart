import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/rules/combat.dart';
import 'package:habit_adventure/rules/encounter.dart';
import 'package:habit_adventure/rules/enums.dart';

import '../support/combat_policies.dart';

// The fight rules (Amendment v0.3 §§3-5): the matrix, the seeded dice, and
// the Dart engine held to the Python reference model move for move.

T byName<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((v) => v.name == name);

const Map<String, CombatAction> actions = <String, CombatAction>{
  'strike': CombatAction.strike,
  'defend': CombatAction.defend,
  'ability': CombatAction.ability,
  'salve': CombatAction.salve,
  'trap': CombatAction.trap,
  'bomb': CombatAction.bomb,
  'smoke': CombatAction.smoke,
};

FightSetup setupFrom(Map<String, dynamic> v) => FightSetup(
      heroClass: byName(HeroClass.values, v['cls'] as String),
      level: v['level'] as int,
      companionLevel: v['comp_level'] as int,
      bond: v['bond'] as int,
      type: byName(EnemyType.values, v['etype'] as String),
      seed: v['seed'] as int,
      resource: v['resource'] as int,
      heroic: v['heroic'] == true,
      items: <ItemKind, int>{
        for (final e in ((v['items'] as Map?) ?? const <String, dynamic>{})
            .entries)
          byName(ItemKind.values, e.key as String): e.value as int,
      },
      boss: v['boss'] == true,
      bossHp: v['boss_hp'] as int?,
      advantage: v['advantage'] == null
          ? null
          : byName(Advantage.values, v['advantage'] as String),
    );

void main() {
  final vectors = jsonDecode(
    File('test/rules/combat_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group('the matrix (Amendment v0.3 §4)', () {
    const s = Effect.strong, n = Effect.normal, h = Effect.hard;
    const table = <EnemyType, List<Effect>>{
      // ranger, warden, sage, artificer
      EnemyType.swift: <Effect>[s, h, n, s],
      EnemyType.armoured: <Effect>[h, n, n, s],
      EnemyType.brute: <Effect>[n, s, s, n],
      EnemyType.swarm: <Effect>[s, h, n, s],
      EnemyType.arcane: <Effect>[n, n, s, h],
    };

    test('every class meets every type as the amendment says', () {
      for (final type in EnemyType.values) {
        for (var i = 0; i < HeroClass.choices.length; i++) {
          expect(
            effectOf(HeroClass.choices[i], type),
            table[type]![i],
            reason: '${HeroClass.choices[i].name} against ${type.name}',
          );
        }
      }
      expect(Effect.strong.percent, 150);
      expect(Effect.normal.percent, 100);
      expect(Effect.hard.percent, 67);
    });

    test('a strike does half as much again when Strong, a third less when '
        'Hard, and a Strong strike cannot be dodged', () {
      for (final cls in HeroClass.choices) {
        for (final type in EnemyType.values) {
          final fight = Fight(
            FightSetup(
              heroClass: cls,
              level: 10,
              companionLevel: 10,
              bond: 0,
              type: type,
              seed: 1,
              resource: 2,
            ),
          );
          final effect = effectOf(cls, type);
          expect(
            fight.strikeDamage,
            (fight.attack * effect.percent) ~/ 100,
            reason: '${cls.name} against ${type.name}',
          );
          expect(
            fight.heroStrikeChance,
            effect == Effect.strong
                ? 100
                : (type == EnemyType.swift ? 75 : 90),
          );
        }
      }
    });

    test('the scout has a line for every pairing, and a weakness for every '
        'type', () {
      for (final cls in HeroClass.choices) {
        for (final type in EnemyType.values) {
          expect(scoutLine(cls, type), isNotEmpty);
        }
      }
      for (final type in EnemyType.values) {
        expect(weaknessOf(type), isNotEmpty);
      }
    });
  });

  group('seeded dice (Amendment v0.3 §3)', () {
    test('the d20 matches the reference model', () {
      for (final r in vectors['rolls'] as List) {
        final row = r as List;
        expect(
          rollD20(row[0] as int, row[1] as int, row[2] as int),
          row[3],
          reason: 'seed ${row[0]} turn ${row[1]} slot ${row[2]}',
        );
      }
    });

    test('a roll depends on the day, the turn and who throws it, and on '
        'nothing else', () {
      final seed = encounterSeed('2026-11-15');
      expect(encounterSeed('2026-11-15'), seed);
      expect(encounterSeed('2026-11-16'), isNot(seed));
      for (var turn = 1; turn <= 12; turn++) {
        final roll = rollD20(seed, turn, 0);
        expect(roll, inInclusiveRange(1, 20));
        expect(rollD20(seed, turn, 0), roll);
      }
    });

    test('trying again with the same actions gives the same fight, blow for '
        'blow', () {
      FightSetup setup() => FightSetup(
            heroClass: HeroClass.warden,
            level: 4,
            companionLevel: 3,
            bond: 20,
            type: enemyFor('2026-11-15').type,
            seed: encounterSeed('2026-11-15'),
            resource: 5,
          );
      List<String> run() {
        final fight = Fight(setup());
        final told = <String>[];
        while (!fight.over) {
          final (action, companion) = strikeOnly(fight);
          for (final e in fight.act(action, companion: companion)) {
            told.add('${e.kind.name}:${e.amount}:${e.roll}:${e.crit}');
          }
        }
        told.add('${fight.outcome}:${fight.turn}:${fight.heroHp}');
        return told;
      }

      expect(run(), run());
    });

    test('a different choice on a turn changes the fight but not the dice',
        () {
      final setup = FightSetup(
        heroClass: HeroClass.sage,
        level: 5,
        companionLevel: 5,
        bond: 0,
        type: EnemyType.brute,
        seed: 4242,
        resource: 6,
      );
      final a = Fight(setup);
      final b = Fight(setup);
      a.act(CombatAction.strike);
      b.act(CombatAction.defend);
      expect(a.enemyHp, isNot(b.enemyHp));
      // Turn two: both strike, and both see the same d20.
      final ea = a.act(CombatAction.strike).first;
      final eb = b.act(CombatAction.strike).first;
      expect(ea.roll, rollD20(4242, 2, 0));
      expect(eb.roll, ea.roll);
    });
  });

  test('the engine and the reference model agree on 96 whole fights', () {
    final fights = vectors['fights'] as List;
    expect(fights, hasLength(96));
    for (var i = 0; i < fights.length; i++) {
      final v = fights[i] as Map<String, dynamic>;
      final fight = Fight(setupFrom(v));
      for (final step in v['actions'] as List) {
        final pair = step as List;
        expect(fight.over, isFalse, reason: 'fight $i ended early');
        fight.act(actions[pair[0]]!, companion: pair[1] == 1);
      }
      final out = v['out'] as Map<String, dynamic>;
      final why = 'fight $i: ${v['cls']} against ${v['etype']}';
      expect(
        fight.outcome,
        out['outcome'] == 'won' ? FightOutcome.won : FightOutcome.held,
        reason: why,
      );
      expect(fight.turn, out['turn'], reason: why);
      expect(fight.heroHp, out['hero'], reason: why);
      expect(fight.enemyHp, out['enemy'], reason: why);
      expect(fight.companionHp, out['comp'], reason: why);
      expect(fight.resource, out['res'], reason: why);
      expect(fight.shield, out['shield'], reason: why);
    }
  });

  group('the turn', () {
    // A seasoned hero with a young companion, so nothing here ends early.
    FightSetup against(
      EnemyType type,
      HeroClass cls, {
      int resource = 6,
      Map<ItemKind, int> items = const <ItemKind, int>{},
    }) =>
        FightSetup(
          heroClass: cls,
          level: 12,
          companionLevel: 1,
          bond: 0,
          type: type,
          seed: 77,
          resource: resource,
          items: items,
        );

    test('a Brute winds up, then lands a big blow that Defend halves', () {
      final open = Fight(against(EnemyType.brute, HeroClass.ranger));
      final guarded = Fight(against(EnemyType.brute, HeroClass.ranger));
      for (final f in <Fight>[open, guarded]) {
        f.act(CombatAction.defend);
        expect(f.intent, EnemyIntent.charge);
        f.act(CombatAction.defend);
        expect(f.intent, EnemyIntent.big);
      }
      final big = open.intentDamage;
      final before = open.heroHp;
      expect(big, greaterThan(open.enemyAttack * 2));
      open.act(CombatAction.strike);
      guarded.act(CombatAction.defend);
      expect(before - open.heroHp, big);
      expect(before - guarded.heroHp, big ~/ 2);
    });

    test('a Sage reads an Arcane trick; nobody else can', () {
      final sage = Fight(against(EnemyType.arcane, HeroClass.sage));
      final ranger = Fight(against(EnemyType.arcane, HeroClass.ranger));
      expect(sage.intent, EnemyIntent.hex);
      expect(sage.intentVeiled, isFalse);
      expect(ranger.intentVeiled, isTrue);
    });

    test('a ward takes the next blow whole, then it is gone', () {
      final fight = Fight(
        against(
          EnemyType.arcane,
          HeroClass.artificer,
          items: const <ItemKind, int>{ItemKind.bomb: 2},
        ),
      );
      fight.act(CombatAction.defend);
      fight.act(CombatAction.defend);
      expect(fight.intent, EnemyIntent.ward);
      fight.act(CombatAction.defend);
      expect(fight.ward, isTrue);
      final before = fight.enemyHp;
      final events = fight.act(CombatAction.bomb);
      expect(events.first.kind, CombatEventKind.warded);
      expect(fight.enemyHp, before);
      expect(fight.ward, isFalse);
      expect(fight.count(ItemKind.bomb), 1, reason: 'the bomb is still used');
    });

    test('a fight that runs to the turn limit is held, not won', () {
      final fight = Fight(against(EnemyType.armoured, HeroClass.warden));
      var turns = 0;
      while (!fight.over) {
        fight.act(CombatAction.defend);
        turns++;
      }
      expect(turns, lessThanOrEqualTo(turnCap));
      expect(fight.outcome, FightOutcome.held);
    });

    test('the companion is winded, never worse, and sits the rest out', () {
      final fight = Fight(
        FightSetup(
          heroClass: HeroClass.sage,
          level: 20,
          companionLevel: 1,
          bond: 0,
          type: EnemyType.swift,
          seed: 5,
          resource: 2,
        ),
      );
      var winded = false;
      while (!fight.over && !winded) {
        final events = fight.act(CombatAction.defend);
        winded = events.any((e) => e.kind == CombatEventKind.companionWinded);
      }
      expect(winded, isTrue);
      expect(fight.companionHp, 0);
      expect(fight.companionReady, isFalse);
    });
  });

  group('the boss (Amendment v0.3 §5)', () {
    test('what an attempt takes off it stays off', () {
      const first = FightSetup(
        heroClass: HeroClass.ranger,
        level: 4,
        companionLevel: 4,
        bond: 10,
        type: EnemyType.brute,
        seed: 9,
        resource: 7,
        boss: true,
      );
      final one = play(smart, first);
      expect(one.outcome, FightOutcome.held, reason: 'seven turns is short');
      expect(one.turn, greaterThan(1));
      final left = one.enemyHp;
      expect(left, lessThan(one.enemyMax));
      final two = Fight(
        FightSetup(
          heroClass: HeroClass.ranger,
          level: 4,
          companionLevel: 4,
          bond: 10,
          type: EnemyType.brute,
          seed: 10,
          resource: 7,
          boss: true,
          bossHp: left,
        ),
      );
      expect(two.enemyHp, left);
      expect(two.enemyMax, one.enemyMax);
    });

    test('the state remembers the boss, its HP, the Marks and the titles',
        () {
      var state = const BossState();
      expect(state.boss.key, 'long_doze');
      for (var i = 0; i < 4; i++) {
        state = state.withMark();
      }
      expect(state.marks, 4);
      expect(state.canBuyAdvantage, isTrue);
      state = state.afterAttempt(left: 120, spentMarks: true);
      expect(state.marks, 1);
      expect(state.hpLeft, 120);
      expect(state.boss.key, 'long_doze');
      final again = BossState.fromJson(jsonDecode(jsonEncode(state.toJson())));
      expect(again.hpLeft, 120);
      expect(again.marks, 1);
      state = again.afterAttempt(left: 0, spentMarks: false);
      expect(state.index, 1);
      expect(state.hpLeft, isNull);
      expect(state.titles, <String>['Waker of Hearthmere']);
      expect(state.boss.key, 'becalmer');
    });
  });

  group('the day', () {
    test('ten templates, two to a type, and no two days running alike', () {
      expect(enemyTemplates, hasLength(10));
      for (final type in EnemyType.values) {
        expect(
          enemyTemplates.where((e) => e.type == type),
          hasLength(2),
          reason: type.name,
        );
      }
      for (var i = 0; i < 30; i++) {
        final day = DateTime.utc(2026, 11, 1 + i);
        final a = enemyFor(day.toIso8601String().substring(0, 10));
        final b = enemyFor(
          day.add(const Duration(days: 1)).toIso8601String().substring(0, 10),
        );
        expect(a.type, isNot(b.type));
        expect(enemyFor(day.toIso8601String().substring(0, 10)).key, a.key);
      }
    });

    test('quests feed the class resource: more for the home attribute',
        () {
      expect(resourceToday(HeroClass.warden, const <QuestDone>[]), 2);
      final day = <QuestDone>[
        const QuestDone(Attribute.vitality, Track.hero, Difficulty.standard),
        const QuestDone(Attribute.mind, Track.hero, Difficulty.heroic),
        const QuestDone(Attribute.care, Track.shared, Difficulty.minor),
      ];
      expect(resourceToday(HeroClass.warden, day), 2 + 2 + 1 + 1);
      expect(resourceToday(HeroClass.sage, day), 2 + 1 + 3 + 1);
      // A Ranger's Shared quest counts in full, and one more.
      expect(resourceToday(HeroClass.ranger, day), 2 + 1 + 1 + 2);
      expect(
        resourceToday(HeroClass.sage, <QuestDone>[
          for (var i = 0; i < 9; i++)
            const QuestDone(Attribute.mind, Track.hero, Difficulty.boss),
        ]),
        resourceCap,
      );
    });

    test('an encounter record survives being written down', () {
      const record = EncounterRecord(
        enemyKey: 'yawnstone',
        heroic: true,
        won: true,
        attempts: 2,
        turns: 4,
        classId: 'warden',
        chest: Chest(
          gold: 12,
          material: MaterialKind.stone,
          materials: 3,
          item: ItemKind.trap,
          xp: 15,
        ),
      );
      final back =
          EncounterRecord.fromJson(jsonDecode(jsonEncode(record.toJson())))!;
      expect(back.enemy!.name, 'Yawnstone');
      expect(back.won, isTrue);
      expect(back.attempts, 2);
      expect(back.chest!.item, ItemKind.trap);
      expect(statusOf(back), EncounterStatus.won);
      expect(statusOf(null), EncounterStatus.ready);
    });
  });
}
