/// Level curve from DESIGN §5.1.
///
/// XP to go from level L to L+1 = round(100 × L^1.5 / 10) × 10.
/// The values below were generated once from that formula and are stored as
/// integers so nothing in the app computes the curve in floating point.
/// `test/rules/xp_curve_test.dart` re-derives the table from the formula.
///
/// The same curve serves the hero, the companion and each attribute.
class XpCurve {
  XpCurve._();

  static const int maxLevel = 100;

  /// `xpToNext[L - 1]` is the XP needed to go from level L to level L + 1.
  static const List<int> xpToNext = <int>[
    100, 280, 520, 800, 1120, 1470, 1850, 2260, 2700, 3160,
    3650, 4160, 4690, 5240, 5810, 6400, 7010, 7640, 8280, 8940,
    9620, 10320, 11030, 11760, 12500, 13260, 14030, 14820, 15620, 16430,
    17260, 18100, 18960, 19830, 20710, 21600, 22510, 23420, 24360, 25300,
    26250, 27220, 28200, 29190, 30190, 31200, 32220, 33260, 34300, 35360,
    36420, 37500, 38580, 39680, 40790, 41910, 43030, 44170, 45320, 46480,
    47640, 48820, 50000, 51200, 52400, 53620, 54840, 56070, 57320, 58570,
    59830, 61090, 62370, 63660, 64950, 66260, 67570, 68890, 70220, 71550,
    72900, 74250, 75620, 76990, 78370, 79750, 81150, 82550, 83960, 85380,
    86810, 88240, 89690, 91140, 92590, 94060, 95530, 97020, 98500,
  ];

  /// `cumulative[L - 1]` is the total XP at which level L begins.
  static const List<int> cumulative = <int>[
    0, 100, 380, 900, 1700, 2820, 4290, 6140, 8400, 11100,
    14260, 17910, 22070, 26760, 32000, 37810, 44210, 51220, 58860, 67140,
    76080, 85700, 96020, 107050, 118810, 131310, 144570, 158600, 173420, 189040,
    205470, 222730, 240830, 259790, 279620, 300330, 321930, 344440, 367860, 392220,
    417520, 443770, 470990, 499190, 528380, 558570, 589770, 621990, 655250, 689550,
    724910, 761330, 798830, 837410, 877090, 917880, 959790, 1002820, 1046990, 1092310,
    1138790, 1186430, 1235250, 1285250, 1336450, 1388850, 1442470, 1497310, 1553380, 1610700,
    1669270, 1729100, 1790190, 1852560, 1916220, 1981170, 2047430, 2115000, 2183890, 2254110,
    2325660, 2398560, 2472810, 2548430, 2625420, 2703790, 2783540, 2864690, 2947240, 3031200,
    3116580, 3203390, 3291630, 3381320, 3472460, 3565050, 3659110, 3754640, 3851660, 3950160,
  ];

  /// The level reached with [totalXp] total experience. Never below 1.
  static int levelForXp(int totalXp) {
    if (totalXp <= 0) return 1;
    var lo = 0;
    var hi = cumulative.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (cumulative[mid] <= totalXp) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  /// Where [totalXp] sits inside its current level.
  static LevelProgress progress(int totalXp) {
    final xp = totalXp < 0 ? 0 : totalXp;
    final level = levelForXp(xp);
    final start = cumulative[level - 1];
    final span = level >= maxLevel ? 0 : xpToNext[level - 1];
    return LevelProgress(level: level, xpIntoLevel: xp - start, xpForLevel: span);
  }
}

class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForLevel,
  });

  final int level;

  /// XP earned since this level began.
  final int xpIntoLevel;

  /// XP this level asks for in total; 0 at the top of the table.
  final int xpForLevel;

  int get xpRemaining => xpForLevel == 0 ? 0 : xpForLevel - xpIntoLevel;

  /// 0..1 for drawing a bar.
  double get fraction {
    if (xpForLevel == 0) return 1;
    final f = xpIntoLevel / xpForLevel;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }
}
