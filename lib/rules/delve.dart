/// The weekly Delve (DESIGN §3B, §4.2): the week's capstone, resolved on one
/// screen at the Campfire on the chosen day.
///
/// Every outcome is a good one. A busy week clears it; a quiet week scouts
/// it or simply rests at the entrance. Nothing is ever taken, and a week
/// that was not resolved on its day waits for the next Campfire.
library;

import 'day_key.dart';
import 'enums.dart';

/// ISO weekday of the Delve unless the user picks another: Sunday.
const int defaultDelveWeekday = DateTime.sunday;

enum DelveTier {
  cleared('Cleared'),
  scouted('Scouted'),
  rested('Rested');

  const DelveTier(this.label);
  final String label;
}

/// Score needed for each tier. Three quests a day for a week clears it; one
/// a day scouts it.
const int delveClearedAt = 21;
const int delveScoutedAt = 7;

/// The most recent day on or before [today] that falls on [weekday].
String latestDelveDay(String today, int weekday) {
  final back = (DayKey.weekday(today) - weekday + 7) % 7;
  return DayKey.addDays(today, -back);
}

/// First day of the week that ends on [delveDay]: the six days before it.
String delveWeekStart(String delveDay) => DayKey.addDays(delveDay, -6);

/// What the week gathered, by kind of quest. Flavour for the resolution
/// screen; the score is what decides the outcome.
class DelveSupplies {
  const DelveSupplies({
    this.provisions = 0,
    this.trailMarks = 0,
    this.keys = 0,
    this.daysActive = 0,
  });

  /// Hero-track quests completed.
  final int provisions;

  /// Companion and Shared quests completed.
  final int trailMarks;

  /// Heroic and Boss quests completed (also counted above).
  final int keys;

  /// Days in the week with at least one quest.
  final int daysActive;

  int get quests => provisions + trailMarks;

  /// Every quest counts one; a Heroic or Boss quest counts two more.
  int get score => quests + keys * 2;
}

/// One completed quest, as the Delve sees it.
class DelveEntry {
  const DelveEntry(this.day, this.track, this.difficulty);
  final String day;
  final Track track;
  final Difficulty difficulty;
}

DelveSupplies suppliesFrom(Iterable<DelveEntry> week) {
  var provisions = 0;
  var trailMarks = 0;
  var keys = 0;
  final days = <String>{};
  for (final e in week) {
    days.add(e.day);
    if (e.track == Track.hero) {
      provisions++;
    } else {
      trailMarks++;
    }
    if (e.difficulty == Difficulty.heroic || e.difficulty == Difficulty.boss) {
      keys++;
    }
  }
  return DelveSupplies(
    provisions: provisions,
    trailMarks: trailMarks,
    keys: keys,
    daysActive: days.length,
  );
}

DelveTier tierFor(DelveSupplies supplies) {
  if (supplies.score >= delveClearedAt) return DelveTier.cleared;
  if (supplies.score >= delveScoutedAt) return DelveTier.scouted;
  return DelveTier.rested;
}

/// What the party brings home. Rewards scale with participation and there is
/// always something, even after a week of rest. No XP: levels come from
/// quests alone.
class DelveReward {
  const DelveReward({required this.gold, required this.eachMaterial});
  final int gold;

  /// This many of each of Timber, Stone and Star Shards.
  final int eachMaterial;

  Map<MaterialKind, int> get materials => <MaterialKind, int>{
        for (final k in MaterialKind.values) k: eachMaterial,
      };
}

DelveReward rewardFor(DelveTier tier) => switch (tier) {
      DelveTier.cleared => const DelveReward(gold: 40, eachMaterial: 3),
      DelveTier.scouted => const DelveReward(gold: 20, eachMaterial: 2),
      DelveTier.rested => const DelveReward(gold: 8, eachMaterial: 1),
    };

/// Original places under the Vale, one a week in rotation.
const List<String> delveSites = <String>[
  'The Root Cellars of Hearthmere',
  'The Hollow under Larkdown',
  'The Silverrun Caves',
  'The Old Cistern',
  'The Highcairn Ice Stair',
  'The Lanternmakers’ Vault',
];

String delveSiteFor(String delveDay) {
  final weeks = DayKey.daysBetween('2026-01-04', delveDay) ~/ 7;
  final i = weeks % delveSites.length;
  return delveSites[i < 0 ? i + delveSites.length : i];
}

/// One warm line for the outcome.
String delveLine(DelveTier tier, String companionName) => switch (tier) {
      DelveTier.cleared =>
        'You and $companionName went all the way down and lit the last lantern.',
      DelveTier.scouted =>
        'You mapped the first chambers with $companionName and marked the way '
            'for next time.',
      DelveTier.rested =>
        'You made camp at the entrance with $companionName and rested. The '
            'Delve will keep.',
    };
