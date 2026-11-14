/// The day's Still creature: a small daily challenge with nothing to lose.
///
/// Added on 14 November 2026 at Adam's request (DECISIONS D-70). DESIGN §7
/// puts a Still creature on Heroic and Boss quests only; this one turns up
/// every Dawn, whatever is on the board. Each quest finished that day stirs
/// it, the third wakes it, and it leaves a small gift as it wanders off. If
/// it sleeps on, it is simply somewhere else tomorrow: nothing is taken and
/// nothing is recorded (DESIGN §6.4).
library;

import 'day_key.dart';
import 'still.dart';

/// Quests finished in a day that wake the day's creature.
const int dailyStillStirs = 3;

/// What it leaves behind: a little gold and one material, of whichever kind
/// the place being restored still needs.
const int dailyStillGold = 3;
const int dailyStillMaterials = 1;

/// The creature for [day]. They take turns, so no two days running are the
/// same, and a day always has the same one however it goes.
StillCreature dailyStillFor(String day) {
  final count = stillCreatures.length;
  final index = DayKey.daysBetween('2026-01-01', day) % count;
  return stillCreatures[index < 0 ? index + count : index];
}

/// How far along the day's creature is.
class DailyStill {
  const DailyStill({
    required this.creature,
    required this.stirs,
    required this.awake,
  });

  final StillCreature creature;

  /// Quests that have stirred it today, never more than [dailyStillStirs].
  final int stirs;

  /// It has woken and left its gift.
  final bool awake;

  int get stirsLeft => awake ? 0 : dailyStillStirs - stirs;
}

/// The day's creature after [questsDone] quests. [giftGiven] is true once
/// its gift has been handed over, which is what "awake" means.
DailyStill dailyStill({
  required String day,
  required int questsDone,
  required bool giftGiven,
}) {
  final done = questsDone < 0 ? 0 : questsDone;
  return DailyStill(
    creature: dailyStillFor(day),
    stirs: done > dailyStillStirs ? dailyStillStirs : done,
    awake: giftGiven,
  );
}

/// True when the quest being finished now is the one that wakes it:
/// [doneBefore] quests were already finished today and the gift has not yet
/// been given.
bool wakesDailyStill({required int doneBefore, required bool giftGiven}) =>
    !giftGiven && doneBefore + 1 >= dailyStillStirs;
