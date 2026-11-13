import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_adventure/rules/progression.dart';
import 'package:habit_adventure/rules/xp_curve.dart';

/// DESIGN §5.1: XP to go from level L to L+1 = round(100 × L^1.5 / 10) × 10.
int formula(int level) => (100 * math.pow(level, 1.5) / 10).round() * 10;

void main() {
  group('XP curve (DESIGN §5.1)', () {
    test('matches the worked examples in the design', () {
      expect(XpCurve.xpToNext[0], 100, reason: 'L1→2');
      expect(XpCurve.xpToNext[1], 280, reason: 'L2→3');
      expect(XpCurve.xpToNext[2], 520, reason: 'L3→4');
      expect(XpCurve.xpToNext[3], 800, reason: 'L4→5');
      expect(XpCurve.xpToNext[8], 2700, reason: 'L9→10');
    });

    test('every stored step equals the formula', () {
      for (var level = 1; level < XpCurve.maxLevel; level++) {
        expect(
          XpCurve.xpToNext[level - 1],
          formula(level),
          reason: 'step from level $level',
        );
      }
    });

    test('cumulative thresholds are the running sum of the steps', () {
      expect(XpCurve.cumulative.length, XpCurve.maxLevel);
      expect(XpCurve.xpToNext.length, XpCurve.maxLevel - 1);
      expect(XpCurve.cumulative.first, 0);
      for (var i = 1; i < XpCurve.cumulative.length; i++) {
        expect(
          XpCurve.cumulative[i],
          XpCurve.cumulative[i - 1] + XpCurve.xpToNext[i - 1],
        );
        expect(XpCurve.cumulative[i] > XpCurve.cumulative[i - 1], isTrue);
      }
    });

    test('the curve gets steeper at every level', () {
      for (var i = 1; i < XpCurve.xpToNext.length; i++) {
        expect(XpCurve.xpToNext[i] > XpCurve.xpToNext[i - 1], isTrue);
      }
    });

    test('level boundaries, including the L1→2 = 100 XP step', () {
      expect(XpCurve.levelForXp(-5), 1);
      expect(XpCurve.levelForXp(0), 1);
      expect(XpCurve.levelForXp(99), 1);
      expect(XpCurve.levelForXp(100), 2);
      expect(XpCurve.levelForXp(379), 2);
      expect(XpCurve.levelForXp(380), 3);
      expect(XpCurve.levelForXp(899), 3);
      expect(XpCurve.levelForXp(900), 4);
      expect(XpCurve.levelForXp(1700), 5);
      expect(XpCurve.levelForXp(11099), 9);
      expect(XpCurve.levelForXp(11100), 10);
    });

    test('progress inside a level', () {
      final p = XpCurve.progress(150);
      expect(p.level, 2);
      expect(p.xpIntoLevel, 50);
      expect(p.xpForLevel, 280);
      expect(p.xpRemaining, 230);
      expect(p.fraction, closeTo(50 / 280, 1e-9));

      final start = XpCurve.progress(0);
      expect(start.level, 1);
      expect(start.xpIntoLevel, 0);
      expect(start.xpForLevel, 100);
    });

    test('level never drops as XP grows', () {
      var last = 1;
      for (var xp = 0; xp <= 60000; xp += 7) {
        final level = XpCurve.levelForXp(xp);
        expect(level >= last, isTrue);
        last = level;
      }
    });

    test('the table tops out cleanly', () {
      final top = XpCurve.cumulative.last;
      expect(XpCurve.levelForXp(top), XpCurve.maxLevel);
      expect(XpCurve.levelForXp(top * 2), XpCurve.maxLevel);
      final p = XpCurve.progress(top + 123);
      expect(p.level, XpCurve.maxLevel);
      expect(p.xpForLevel, 0);
      expect(p.fraction, 1);
    });
  });

  group('Hero and companion share one curve (DESIGN §7A.3)', () {
    test('equal XP gives equal levels on both tracks', () {
      for (final xp in <int>[0, 99, 100, 379, 380, 900, 2819, 2820, 11100]) {
        final totals = PartyTotals(heroXp: xp, companionXp: xp);
        expect(totals.heroLevel, totals.companionLevel, reason: 'xp=$xp');
        expect(totals.companionLevel, XpCurve.levelForXp(xp));
      }
    });

    test('the companion reaches level 2 at exactly 100 Companion XP', () {
      expect(const PartyTotals(companionXp: 99).companionLevel, 1);
      expect(const PartyTotals(companionXp: 100).companionLevel, 2);
    });
  });
}
