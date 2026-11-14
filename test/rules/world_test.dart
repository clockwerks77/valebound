import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/enums.dart';
import 'package:habit_adventure/rules/gear.dart';
import 'package:habit_adventure/rules/journey.dart';
import 'package:habit_adventure/rules/progression.dart';
import 'package:habit_adventure/rules/still.dart';
import 'package:habit_adventure/rules/world.dart';

Map<MaterialKind, int> mats(int timber, int stone, int shards) =>
    <MaterialKind, int>{
      MaterialKind.timber: timber,
      MaterialKind.stone: stone,
      MaterialKind.starShard: shards,
    };

void main() {
  group('The Vale as drafted (DESIGN §7)', () {
    test('five regions, four places each, every key and name its own', () {
      expect(regions.length, 5);
      expect(restorationTargets.length, 20);
      for (final r in regions) {
        expect(targetsIn(r.key).length, 4, reason: r.name);
      }
      expect(restorationTargets.map((t) => t.key).toSet().length, 20);
      expect(restorationTargets.map((t) => t.name).toSet().length, 20);
    });

    test('places wake region by region, along the road', () {
      final order = <String>[for (final t in restorationTargets) t.region];
      expect(order, <String>[
        for (final r in regions) ...List<String>.filled(4, r.key),
      ]);
    });

    test('every place asks for something and brings a villager home', () {
      for (final t in restorationTargets) {
        expect(t.totalCost, greaterThan(0), reason: t.name);
        expect(t.villager, isNotNull, reason: t.name);
        expect(t.villager!.dawn, isNotEmpty);
        expect(t.villager!.campfire, isNotEmpty);
      }
      final names = <String>[for (final t in restorationTargets) t.villager!.key];
      expect(names.toSet().length, 20);
    });
  });

  group('Restoration from materials (DESIGN §3A, §5.3)', () {
    test('nothing gathered, nothing restored', () {
      expect(restoredCount(const <MaterialKind, int>{}), 0);
      expect(currentTarget(const <MaterialKind, int>{}).key, 'gate_lantern');
    });

    test('a place wakes exactly when every material it asks for is in', () {
      // The Gate Lantern: 2 Timber, 1 Stone.
      expect(restoredCount(mats(1, 5, 5)), 0);
      expect(restoredCount(mats(2, 0, 5)), 0);
      expect(restoredCount(mats(2, 1, 0)), 1);
    });

    test('places wake in order and never out of turn', () {
      // Enough for the Well (second) but not the Gate Lantern (first).
      expect(restoredCount(mats(1, 9, 9)), 0);
      // First two: 4 Timber, 5 Stone, 1 Star Shard in all.
      expect(restoredCount(mats(4, 5, 1)), 2);
      expect(restoredCount(mats(4, 5, 0)), 1);
    });

    test('what is built leaves the stores; the rest waits there', () {
      final gathered = mats(5, 5, 3);
      expect(restoredCount(gathered), 2);
      expect(inStores(gathered), mats(1, 0, 2));
      expect(currentTarget(gathered).key, 'bakehouse');
      expect(stillNeeded(gathered), MaterialKind.timber);
      // Bakehouse: 5 Timber, 3 Stone, 1 Star Shard. Have 1, 0 and 1 of them.
      expect(targetProgress(gathered), closeTo(2 / 9, 1e-9));
      expect(restorationPointsFor(2), 10);
      expect(materialsSpentOn(2), mats(4, 5, 1));
    });

    test('more materials can only ever restore more', () {
      var last = 0;
      for (var n = 0; n <= 260; n++) {
        final now = restoredCount(mats(n, n, n));
        expect(now, greaterThanOrEqualTo(last));
        last = now;
      }
      expect(last, greaterThan(20));
    });

    test('the whole drafted Vale, then one lantern after another', () {
      final all = materialsSpentOn(20);
      expect(all, mats(203, 208, 109));
      expect(restoredCount(all), 20);
      expect(targetAt(20).name, 'Vale Lantern 1');
      expect(restoredCount(mats(213, 218, 119)), 21);
      expect(restoredCount(mats(223, 228, 129)), 22);
      expect(targetIndexByKey('vale_lantern_3'), 22);
      expect(targetIndexByKey('moot_hall'), 3);
      expect(targetIndexByKey('nowhere'), -1);
    });

    test('a region wakes by its own places; the Vale by all of them', () {
      expect(regionWake('hearthmere', 0), 0);
      expect(regionWake('hearthmere', 2), 0.5);
      expect(regionWake('hearthmere', 9), 1);
      expect(regionWake('larkdown', 4), 0);
      expect(regionWake('larkdown', 5), 0.25);
      expect(valeWake(10), 0.5);
      expect(valeWake(40), 1);
    });
  });

  group('Villagers (DESIGN §7)', () {
    test('nobody greets the board until someone has come home', () {
      expect(villagersReturned(0), isEmpty);
      expect(dawnVillager(0, '2026-11-14'), isNull);
      expect(campfireVillager(0, '2026-11-14'), isNull);
    });

    test('a returned villager greets the day, the same one all day', () {
      final a = dawnVillager(3, '2026-11-14')!;
      final b = dawnVillager(3, '2026-11-14')!;
      expect(a.villager.key, b.villager.key);
      expect(a.line, b.line);
      expect(<String>['wick', 'marla', 'bryn'], contains(a.villager.key));
      expect(a.villager.dawn, contains(a.line));
    });

    test('over a week every villager at home takes a turn', () {
      final seen = <String>{};
      for (var d = 14; d < 21; d++) {
        seen.add(dawnVillager(3, '2026-11-$d')!.villager.key);
      }
      expect(seen, <String>{'wick', 'marla', 'bryn'});
    });
  });

  group('Fetch (DESIGN §7A.3, companion level 4)', () {
    PartyTotals levelFour({Map<MaterialKind, int> materials = const {}}) =>
        PartyTotals(companionXp: 900, materials: materials);

    test('carries one material the current restoration still needs', () {
      final o = applyCompletion(
        totals: levelFour(),
        difficulty: Difficulty.minor,
        track: Track.companion,
        attribute: Attribute.care,
        fetchAvailable: true,
      );
      expect(o.fetchCarried, MaterialKind.timber);
      expect(o.after.materials, mats(1, 0, 0)..removeWhere((k, v) => v == 0));
    });

    test('goes for what is short, not what is already there', () {
      final o = applyCompletion(
        totals: levelFour(materials: mats(2, 0, 0)),
        difficulty: Difficulty.minor,
        track: Track.shared,
        attribute: Attribute.care,
        fetchAvailable: true,
      );
      // The Gate Lantern has its Timber; Stone is what it is waiting for.
      expect(o.fetchCarried, MaterialKind.stone);
      expect(o.newRestorationIndexes, <int>[0]);
    });

    test('once a day, only with the companion, only once learned', () {
      CompletionOutcome run({
        required PartyTotals totals,
        Track track = Track.companion,
        bool available = true,
      }) =>
          applyCompletion(
            totals: totals,
            difficulty: Difficulty.minor,
            track: track,
            attribute: Attribute.care,
            fetchAvailable: available,
          );
      expect(run(totals: levelFour(), available: false).fetchCarried, isNull);
      expect(run(totals: levelFour(), track: Track.hero).fetchCarried, isNull);
      expect(
        run(totals: const PartyTotals(companionXp: 500)).fetchCarried,
        isNull,
      );
      // Learned on this very quest: it counts.
      expect(
        run(totals: const PartyTotals(companionXp: 895)).fetchCarried,
        MaterialKind.timber,
      );
    });
  });

  group('A completion can restore a place', () {
    test('the Hero quest that brings the last material wakes it', () {
      // One Timber short of the Gate Lantern; the next drop is Timber.
      final o = applyCompletion(
        totals: PartyTotals(materials: mats(1, 1, 0), heroTrackCompletions: 3),
        difficulty: Difficulty.minor,
        track: Track.hero,
        attribute: Attribute.vitality,
      );
      expect(o.materialKind, MaterialKind.timber);
      expect(o.newRestorationIndexes, <int>[0]);
      expect(o.after.restored, 1);
    });

    test('a big haul can wake several at once', () {
      final o = applyCompletion(
        totals: PartyTotals(materials: mats(0, 9, 2)),
        difficulty: Difficulty.boss,
        track: Track.hero,
        attribute: Attribute.craft,
      );
      // +10 Timber on top of plenty of Stone: the first three places.
      expect(o.newRestorationIndexes, <int>[0, 1, 2]);
      expect(inStores(o.after.materials), mats(1, 1, 0));
    });

    test('most completions restore nothing, and that is fine', () {
      final o = applyCompletion(
        totals: const PartyTotals(),
        difficulty: Difficulty.minor,
        track: Track.hero,
        attribute: Attribute.vitality,
      );
      expect(o.newRestorationIndexes, isEmpty);
    });
  });

  group('Companion gear and hero cosmetics (DESIGN §5.3, §7A.3)', () {
    test('every piece of gear has one way to unlock, and no stats', () {
      for (final g in companionGear) {
        expect((g.bond == null) != (g.level == null), isTrue, reason: g.name);
      }
      expect(companionGear.map((g) => g.key).toSet().length, companionGear.length);
    });

    test('gifts at Bond milestones, gear at the odd companion levels', () {
      expect(gearUnlockedAt(level: 1, bond: 0), isEmpty);
      expect(gearUnlockedAt(level: 1, bond: 10), <String>['moss_neckerchief']);
      expect(
        gearUnlockedAt(level: 3, bond: 10),
        <String>['moss_neckerchief', 'brass_bell'],
      );
      expect(gearUnlockedAt(level: 10, bond: 400).length, companionGear.length);
    });

    test('the quest that reaches a Bond milestone brings the gift', () {
      final o = applyCompletion(
        totals: const PartyTotals(bond: 9),
        difficulty: Difficulty.minor,
        track: Track.companion,
        attribute: Attribute.care,
      );
      expect(o.after.bond, 10);
      expect(o.newGear, <String>['moss_neckerchief']);
    });

    test('everyone starts with a frame and a banner', () {
      expect(
        cosmeticsUnlockedAt(heroLevel: 1, restored: 0),
        <String>[defaultFrame, defaultBanner],
      );
    });

    test('levels bring frames and banners; restored places bring decorations',
        () {
      expect(cosmeticsUnlockedAt(heroLevel: 2, restored: 0), contains('dawn'));
      expect(cosmeticsUnlockedAt(heroLevel: 3, restored: 0), contains('oak'));
      expect(cosmeticsUnlockedAt(heroLevel: 1, restored: 2), contains('bunting'));
      expect(
        cosmeticsUnlockedAt(heroLevel: 15, restored: 20).length,
        heroCosmetics.length,
      );
      final o = applyCompletion(
        totals: const PartyTotals(heroXp: 90),
        difficulty: Difficulty.standard,
        track: Track.hero,
        attribute: Attribute.vitality,
      );
      expect(o.heroLevelledUp, isTrue);
      expect(o.newCosmetics, <String>['dawn']);
    });
  });

  group('The road on the map (DESIGN §7A.4)', () {
    test('200 Paces, five regions of 40, four Discoveries to a region', () {
      expect(roadPaces, 200);
      expect(roadPaces ~/ pacesPerDiscovery, discoveryScenes.length);
      expect(regionIndexForPaces(0), 0);
      expect(regionIndexForPaces(39), 0);
      expect(regionIndexForPaces(40), 1);
      expect(regionIndexForPaces(199), 4);
      expect(regionIndexForPaces(5000), 4);
      expect(roadFraction(0), 0);
      expect(roadFraction(100), 0.5);
      expect(roadFraction(260), 1);
    });

    test('every scene has a hint for Scout to show', () {
      for (final s in discoveryScenes) {
        expect(s.hint, isNotEmpty, reason: s.title);
        expect(s.hint, isNot(contains(s.title)));
      }
    });
  });

  group('The Still (DESIGN §7)', () {
    test('only Heroic and Boss quests draw a creature', () {
      expect(drawsStill(Difficulty.minor), isFalse);
      expect(drawsStill(Difficulty.standard), isFalse);
      expect(drawsStill(Difficulty.heroic), isTrue);
      expect(drawsStill(Difficulty.boss), isTrue);
    });

    test('a quest always meets the same creature', () {
      const id = '3f2b8c1e-aaaa-4bbb-8ccc-1234567890ab';
      expect(stillFor(id).key, stillFor(id).key);
      final seen = <String>{
        for (var i = 0; i < 200; i++) stillFor('quest-$i').key,
      };
      expect(seen.length, stillCreatures.length);
    });

    test('creatures wake and wander off; nothing is fought', () {
      for (final c in stillCreatures) {
        final text = '${c.sits} ${c.wakes}'.toLowerCase();
        for (final word in <String>['kill', 'slay', 'defeat', 'attack', 'die']) {
          expect(text.contains(word), isFalse, reason: '${c.name}: $word');
        }
      }
    });
  });
}
