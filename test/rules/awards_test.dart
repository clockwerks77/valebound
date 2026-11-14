import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/awards.dart';
import 'package:habit_adventure/rules/companion_rules.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/journey.dart';
import 'package:habit_adventure/rules/materials.dart';
import 'package:habit_adventure/rules/progression.dart';

void main() {
  group('Difficulty awards (DESIGN §5.4)', () {
    test('XP values are fixed by the design', () {
      expect(Difficulty.minor.xp, 10);
      expect(Difficulty.standard.xp, 25);
      expect(Difficulty.heroic.xp, 60);
      expect(Difficulty.boss.xp, 150);
    });
  });

  group('Track splits (DESIGN §7A.2)', () {
    test('Hero quests award hero XP and attribute XP only', () {
      for (final d in Difficulty.values) {
        final a = awardFor(difficulty: d, track: Track.hero);
        expect(a.heroXp, d.xp);
        expect(a.attributeXp, d.xp);
        expect(a.companionXp, 0);
        expect(a.bond, 0);
        expect(a.paces, 0);
      }
    });

    test('Companion quests award Companion XP only, at the same values', () {
      for (final d in Difficulty.values) {
        final a = awardFor(difficulty: d, track: Track.companion);
        expect(a.heroXp, 0);
        expect(a.attributeXp, 0);
        expect(a.companionXp, d.xp);
        expect(a.bond, 1);
        expect(a.materials, 0);
      }
    });

    test('Shared quests award full Companion XP + half hero XP, rounded up',
        () {
      final expectedHero = <Difficulty, int>{
        Difficulty.minor: 5,
        Difficulty.standard: 13, // 12.5 rounds up
        Difficulty.heroic: 30,
        Difficulty.boss: 75,
      };
      for (final d in Difficulty.values) {
        final a = awardFor(difficulty: d, track: Track.shared);
        expect(a.companionXp, d.xp, reason: 'full companion XP for $d');
        expect(a.heroXp, expectedHero[d], reason: 'half hero XP for $d');
        expect(a.attributeXp, expectedHero[d]);
        expect(a.bond, 1);
      }
    });

    test('half is always rounded up', () {
      expect(halfRoundedUp(0), 0);
      expect(halfRoundedUp(1), 1);
      expect(halfRoundedUp(2), 1);
      expect(halfRoundedUp(25), 13);
      expect(halfRoundedUp(26), 13);
      expect(halfRoundedUp(27), 14);
    });
  });

  group('Applying a completion', () {
    test('a Hero quest feeds hero XP and its attribute', () {
      final o = applyCompletion(
        totals: const PartyTotals(),
        difficulty: Difficulty.standard,
        track: Track.hero,
        attribute: Attribute.vitality,
      );
      expect(o.after.heroXp, 25);
      expect(o.after.attributeXp[Attribute.vitality], 25);
      expect(o.after.attributeXp[Attribute.care], isNull);
      expect(o.after.companionXp, 0);
      expect(o.after.bond, 0);
      expect(o.after.paces, 0);
    });

    test('Walk Babs (Shared, Standard, Care): her adventure and your Care',
        () {
      final o = applyCompletion(
        totals: const PartyTotals(),
        difficulty: Difficulty.standard,
        track: Track.shared,
        attribute: Attribute.care,
      );
      expect(o.after.companionXp, 25);
      expect(o.after.heroXp, 13);
      expect(o.after.attributeXp[Attribute.care], 13);
      expect(o.after.bond, 1);
      expect(o.after.paces, 1);
    });

    test('a Companion quest leaves the hero untouched', () {
      const start = PartyTotals(
        heroXp: 340,
        attributeXp: <Attribute, int>{Attribute.care: 120},
      );
      final o = applyCompletion(
        totals: start,
        difficulty: Difficulty.minor,
        track: Track.companion,
        attribute: Attribute.care,
      );
      expect(o.after.heroXp, 340);
      expect(o.after.attributeXp[Attribute.care], 120);
      expect(o.after.companionXp, 10);
    });

    test('four Standard hero quests make level 2 (L1→2 = 100 XP)', () {
      var totals = const PartyTotals();
      CompletionOutcome? last;
      for (var i = 0; i < 4; i++) {
        last = applyCompletion(
          totals: totals,
          difficulty: Difficulty.standard,
          track: Track.hero,
          attribute: Attribute.order,
        );
        totals = last.after;
        if (i < 3) expect(last.heroLevelledUp, isFalse);
      }
      expect(totals.heroXp, 100);
      expect(totals.heroLevel, 2);
      expect(last!.heroLevelledUp, isTrue);
    });

    test('attribute XP levels on the same curve', () {
      var totals = const PartyTotals();
      for (var i = 0; i < 4; i++) {
        totals = applyCompletion(
          totals: totals,
          difficulty: Difficulty.standard,
          track: Track.hero,
          attribute: Attribute.craft,
        ).after;
      }
      expect(totals.attributeLevel(Attribute.craft), 2);
      expect(totals.attributeLevel(Attribute.mind), 1);
    });
  });

  group('Bond (DESIGN §7A.3)', () {
    test('+1 per companion or shared quest, nothing for hero quests', () {
      var totals = const PartyTotals();
      totals = applyCompletion(
        totals: totals,
        difficulty: Difficulty.minor,
        track: Track.companion,
        attribute: Attribute.care,
      ).after;
      expect(totals.bond, 1);
      totals = applyCompletion(
        totals: totals,
        difficulty: Difficulty.standard,
        track: Track.shared,
        attribute: Attribute.care,
      ).after;
      expect(totals.bond, 2);
      totals = applyCompletion(
        totals: totals,
        difficulty: Difficulty.boss,
        track: Track.hero,
        attribute: Attribute.craft,
      ).after;
      expect(totals.bond, 2);
    });

    test('+3 on a companion level-up day, once', () {
      const start = PartyTotals(companionXp: 90, bond: 7);
      final levelUp = applyCompletion(
        totals: start,
        difficulty: Difficulty.standard,
        track: Track.companion,
        attribute: Attribute.care,
      );
      expect(levelUp.companionLevelledUp, isTrue);
      expect(levelUp.bondBonus, 3);
      expect(levelUp.after.bond, 7 + 1 + 3);

      final alreadyGiven = applyCompletion(
        totals: start,
        difficulty: Difficulty.standard,
        track: Track.companion,
        attribute: Attribute.care,
        bondLevelBonusGrantedToday: true,
      );
      expect(alreadyGiven.companionLevelledUp, isTrue);
      expect(alreadyGiven.bondBonus, 0);
      expect(alreadyGiven.after.bond, 7 + 1);
    });

    test('no bonus without a level-up', () {
      final o = applyCompletion(
        totals: const PartyTotals(companionXp: 10),
        difficulty: Difficulty.minor,
        track: Track.companion,
        attribute: Attribute.care,
      );
      expect(o.companionLevelledUp, isFalse);
      expect(o.bondBonus, 0);
    });
  });

  group('Paces and Discoveries (DESIGN §7A.4)', () {
    test('1 Pace per companion/shared quest, 2 for Heroic and Boss', () {
      expect(pacesFor(Difficulty.minor, Track.companion), 1);
      expect(pacesFor(Difficulty.standard, Track.companion), 1);
      expect(pacesFor(Difficulty.heroic, Track.companion), 2);
      expect(pacesFor(Difficulty.boss, Track.companion), 2);
      expect(pacesFor(Difficulty.standard, Track.shared), 1);
      expect(pacesFor(Difficulty.heroic, Track.shared), 2);
      for (final d in Difficulty.values) {
        expect(pacesFor(d, Track.hero), 0);
      }
    });

    test('a Discovery fires on the tenth Pace', () {
      final o = applyCompletion(
        totals: const PartyTotals(paces: 9),
        difficulty: Difficulty.minor,
        track: Track.companion,
        attribute: Attribute.care,
      );
      expect(o.after.paces, 10);
      expect(o.newDiscoveryIndexes, <int>[0]);
      expect(o.after.discoveries, 1);
    });

    test('a two-Pace quest that steps over the mark still fires it', () {
      final o = applyCompletion(
        totals: const PartyTotals(paces: 19),
        difficulty: Difficulty.heroic,
        track: Track.companion,
        attribute: Attribute.adventure,
      );
      expect(o.after.paces, 21);
      expect(o.newDiscoveryIndexes, <int>[1]);
    });

    test('no Discovery between the marks', () {
      final o = applyCompletion(
        totals: const PartyTotals(paces: 3),
        difficulty: Difficulty.minor,
        track: Track.shared,
        attribute: Attribute.care,
      );
      expect(o.newDiscoveryIndexes, isEmpty);
    });

    test('exactly one Discovery every 10 Paces, in order, none skipped', () {
      var totals = const PartyTotals();
      final fired = <int>[];
      final firedAtPaces = <int>[];
      for (var i = 0; i < 200; i++) {
        final o = applyCompletion(
          totals: totals,
          difficulty: Difficulty.minor,
          track: Track.companion,
          attribute: Attribute.care,
        );
        totals = o.after;
        for (final index in o.newDiscoveryIndexes) {
          fired.add(index);
          firedAtPaces.add(totals.paces);
        }
      }
      expect(totals.paces, 200);
      expect(fired, List<int>.generate(20, (i) => i));
      expect(firedAtPaces, List<int>.generate(20, (i) => (i + 1) * 10));
    });

    test('journey helpers', () {
      expect(discoveriesEarned(0), 0);
      expect(discoveriesEarned(9), 0);
      expect(discoveriesEarned(10), 1);
      expect(discoveriesEarned(125), 12);
      expect(pacesToNextDiscovery(0), 10);
      expect(pacesToNextDiscovery(7), 3);
      expect(pacesToNextDiscovery(10), 10);
      expect(pacesIntoStretch(17), 7);
      expect(campPosition(42), 42);
      expect(newDiscoveries(8, 31), <int>[0, 1, 2]);
    });

    test('twenty drafted scenes, then plain waymarkers', () {
      expect(discoveryScenes.length, 20);
      expect(discoveryScenes.map((s) => s.key).toSet().length, 20);
      expect(discoveryScenes.map((s) => s.title).toSet().length, 20);
      expect(sceneFor(0).key, 'standing_stone');
      expect(sceneFor(20).title, 'Waymarker 21');
      // A stored key shows what was found, whatever its place in the list.
      expect(sceneByKey('hot_spring', 7).title, 'Kettle Spring');
      expect(sceneByKey('from_an_older_build', 2).key, 'merchant_cart');
    });
  });

  group('Materials and gold', () {
    test('Hero quests drop materials; companion and shared earn Paces', () {
      expect(materialsFor(Difficulty.standard, Track.hero), 2);
      expect(materialsFor(Difficulty.standard, Track.shared), 0);
      expect(materialsFor(Difficulty.standard, Track.companion), 0);
    });

    test('material kind rotates Timber, Stone, Star Shards', () {
      expect(materialForCompletion(0), MaterialKind.timber);
      expect(materialForCompletion(1), MaterialKind.stone);
      expect(materialForCompletion(2), MaterialKind.starShard);
      expect(materialForCompletion(3), MaterialKind.timber);

      var totals = const PartyTotals();
      for (var i = 0; i < 3; i++) {
        totals = applyCompletion(
          totals: totals,
          difficulty: Difficulty.standard,
          track: Track.hero,
          attribute: Attribute.order,
        ).after;
      }
      expect(totals.materialCount(MaterialKind.timber), 2);
      expect(totals.materialCount(MaterialKind.stone), 2);
      expect(totals.materialCount(MaterialKind.starShard), 2);
      expect(totals.gold, 15);
    });
  });

  group('Sniff Out (DESIGN §7A.3, learned at companion level 2)', () {
    test('finds one bonus material on a companion quest', () {
      final o = applyCompletion(
        totals: const PartyTotals(companionXp: 100),
        difficulty: Difficulty.minor,
        track: Track.companion,
        attribute: Attribute.care,
        sniffOutFind: MaterialKind.stone,
      );
      expect(o.sniffOutFound, MaterialKind.stone);
      expect(o.after.materialCount(MaterialKind.stone), 1);
      expect(o.after.materialCount(MaterialKind.timber), 0);
    });

    test('also on a shared quest', () {
      final o = applyCompletion(
        totals: const PartyTotals(companionXp: 400),
        difficulty: Difficulty.standard,
        track: Track.shared,
        attribute: Attribute.care,
        sniffOutFind: MaterialKind.starShard,
      );
      expect(o.sniffOutFound, MaterialKind.starShard);
      expect(o.after.materialCount(MaterialKind.starShard), 1);
    });

    test('not before the trick is learned', () {
      final o = applyCompletion(
        totals: const PartyTotals(companionXp: 10),
        difficulty: Difficulty.minor,
        track: Track.companion,
        attribute: Attribute.care,
        sniffOutFind: MaterialKind.stone,
      );
      expect(o.after.companionLevel, 1);
      expect(o.sniffOutFound, isNull);
      expect(o.after.materials, isEmpty);
    });

    test('starts on the very quest that reaches level 2', () {
      final o = applyCompletion(
        totals: const PartyTotals(companionXp: 90),
        difficulty: Difficulty.standard,
        track: Track.companion,
        attribute: Attribute.care,
        sniffOutFind: MaterialKind.timber,
      );
      expect(o.after.companionLevel, 2);
      expect(o.sniffOutFound, MaterialKind.timber);
    });

    test('never on a hero quest, and only once a day', () {
      final hero = applyCompletion(
        totals: const PartyTotals(companionXp: 500),
        difficulty: Difficulty.standard,
        track: Track.hero,
        attribute: Attribute.order,
        sniffOutFind: MaterialKind.stone,
      );
      expect(hero.sniffOutFound, isNull);
      expect(hero.after.materialCount(MaterialKind.stone), 0);
      expect(hero.after.materialCount(MaterialKind.timber), 2);

      final alreadyFound = applyCompletion(
        totals: const PartyTotals(companionXp: 500),
        difficulty: Difficulty.minor,
        track: Track.companion,
        attribute: Attribute.care,
      );
      expect(alreadyFound.sniffOutFound, isNull);
      expect(alreadyFound.after.materials, isEmpty);
    });

    test('the kind rotates by calendar day and is the same all day', () {
      expect(sniffOutMaterial('2026-01-01'), MaterialKind.timber);
      expect(sniffOutMaterial('2026-01-02'), MaterialKind.stone);
      expect(sniffOutMaterial('2026-01-03'), MaterialKind.starShard);
      expect(sniffOutMaterial('2026-01-04'), MaterialKind.timber);
      expect(sniffOutMaterial('2025-12-31'), MaterialKind.starShard);
      expect(sniffOutMaterial('2026-11-14'), sniffOutMaterial('2026-11-14'));
      expect(tricksInPlay, contains('sniff_out'));
      expect(sniffOutLevel, 2);
    });
  });

  group('Nothing is ever taken away (DESIGN §6.4)', () {
    test('every total only grows over 2,000 random completions', () {
      final random = math.Random(20261113);
      var totals = const PartyTotals();
      for (var i = 0; i < 2000; i++) {
        final attribute =
            Attribute.values[random.nextInt(Attribute.values.length)];
        final o = applyCompletion(
          totals: totals,
          difficulty:
              Difficulty.values[random.nextInt(Difficulty.values.length)],
          track: Track.values[random.nextInt(Track.values.length)],
          attribute: attribute,
          bondLevelBonusGrantedToday: random.nextBool(),
          sniffOutFind: random.nextBool()
              ? MaterialKind.values[random.nextInt(MaterialKind.values.length)]
              : null,
        );
        final next = o.after;
        expect(next.heroXp >= totals.heroXp, isTrue);
        expect(next.companionXp >= totals.companionXp, isTrue);
        expect(next.bond >= totals.bond, isTrue, reason: 'Bond only rises');
        expect(next.paces >= totals.paces, isTrue);
        expect(next.gold >= totals.gold, isTrue);
        expect(next.heroLevel >= totals.heroLevel, isTrue);
        expect(next.companionLevel >= totals.companionLevel, isTrue);
        expect(next.discoveries >= totals.discoveries, isTrue);
        for (final a in Attribute.values) {
          expect(
            (next.attributeXp[a] ?? 0) >= (totals.attributeXp[a] ?? 0),
            isTrue,
          );
        }
        for (final m in MaterialKind.values) {
          expect(next.materialCount(m) >= totals.materialCount(m), isTrue);
        }
        totals = next;
      }
    });
  });
}
