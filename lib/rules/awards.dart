import 'enums.dart';

/// What a single completed quest hands out, before it is applied to totals.
///
/// DESIGN §7A.2:
///  * Hero quests award hero XP and attribute XP.
///  * Companion quests award Companion XP and Bond, and advance the Journey.
///  * Shared quests award Companion XP in full and hero XP at half value,
///    rounded up, to the quest's attribute.
class Award {
  const Award({
    required this.heroXp,
    required this.attributeXp,
    required this.companionXp,
    required this.bond,
    required this.paces,
    required this.gold,
    required this.materials,
  });

  final int heroXp;
  final int attributeXp;
  final int companionXp;
  final int bond;
  final int paces;
  final int gold;

  /// Count of restoration materials. The kind rotates; see `materials.dart`.
  final int materials;
}

/// Half of [value], rounded up. Integer arithmetic only.
int halfRoundedUp(int value) => (value + 1) ~/ 2;

/// DESIGN §7A.4: one Pace per companion or shared quest, two when that quest
/// is Heroic or Boss. Hero quests earn no Paces.
int pacesFor(Difficulty difficulty, Track track) {
  if (!track.travelsWithCompanion) return 0;
  return (difficulty == Difficulty.heroic || difficulty == Difficulty.boss)
      ? 2
      : 1;
}

/// Gold from any quest. DESIGN is silent on amounts; see DECISIONS.md D-08.
int goldFor(Difficulty difficulty) => switch (difficulty) {
      Difficulty.minor => 2,
      Difficulty.standard => 5,
      Difficulty.heroic => 12,
      Difficulty.boss => 30,
    };

/// Materials from a Hero-track quest. Companion and Shared quests earn Paces
/// instead (DESIGN §7A.4). Amounts are a DECISIONS.md default (D-08).
int materialsFor(Difficulty difficulty, Track track) {
  if (track != Track.hero) return 0;
  return switch (difficulty) {
    Difficulty.minor => 1,
    Difficulty.standard => 2,
    Difficulty.heroic => 4,
    Difficulty.boss => 10,
  };
}

Award awardFor({required Difficulty difficulty, required Track track}) {
  final xp = difficulty.xp;
  final heroXp = switch (track) {
    Track.hero => xp,
    Track.companion => 0,
    Track.shared => halfRoundedUp(xp),
  };
  final companionXp = track.travelsWithCompanion ? xp : 0;
  return Award(
    heroXp: heroXp,
    attributeXp: heroXp,
    companionXp: companionXp,
    bond: track.travelsWithCompanion ? 1 : 0,
    paces: pacesFor(difficulty, track),
    gold: goldFor(difficulty),
    materials: materialsFor(difficulty, track),
  );
}
