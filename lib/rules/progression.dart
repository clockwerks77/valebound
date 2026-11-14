import 'awards.dart';
import 'companion_rules.dart';
import 'enums.dart';
import 'gear.dart';
import 'journey.dart';
import 'materials.dart';
import 'world.dart';
import 'xp_curve.dart';

/// Bond bonus on a day the companion gains a level (DESIGN §7A.3).
const int bondLevelUpBonus = 3;

/// Everything a completion can change. Immutable; [applyCompletion] returns a
/// new value. Every field only ever grows (DESIGN §6.4: nothing is removed).
class PartyTotals {
  const PartyTotals({
    this.heroXp = 0,
    this.attributeXp = const <Attribute, int>{},
    this.companionXp = 0,
    this.bond = 0,
    this.paces = 0,
    this.gold = 0,
    this.materials = const <MaterialKind, int>{},
    this.heroTrackCompletions = 0,
  });

  final int heroXp;
  final Map<Attribute, int> attributeXp;
  final int companionXp;
  final int bond;
  final int paces;
  final int gold;

  /// Materials gathered in all. This only ever grows; what has been built
  /// and what is left in the stores are worked out from it (`world.dart`).
  final Map<MaterialKind, int> materials;

  /// Drives the material rotation.
  final int heroTrackCompletions;

  int get heroLevel => XpCurve.levelForXp(heroXp);
  int get companionLevel => XpCurve.levelForXp(companionXp);
  int attributeLevel(Attribute a) => XpCurve.levelForXp(attributeXp[a] ?? 0);
  int materialCount(MaterialKind k) => materials[k] ?? 0;
  int get discoveries => discoveriesEarned(paces);

  /// Places restored so far.
  int get restored => restoredCount(materials);
}

/// The result of completing one quest.
class CompletionOutcome {
  const CompletionOutcome({
    required this.award,
    required this.before,
    required this.after,
    required this.attribute,
    required this.track,
    required this.difficulty,
    required this.bondBonus,
    required this.materialKind,
    required this.newDiscoveryIndexes,
    this.sniffOutFound,
    this.fetchCarried,
    this.newRestorationIndexes = const <int>[],
    this.newGear = const <String>[],
    this.newCosmetics = const <String>[],
    this.bonusHeroXp = 0,
    this.comfortBond = 0,
  });

  final Award award;
  final PartyTotals before;
  final PartyTotals after;
  final Attribute attribute;
  final Track track;
  final Difficulty difficulty;

  /// Extra Bond granted because the companion levelled up today.
  final int bondBonus;

  /// Kind of material dropped, when [Award.materials] is above zero.
  final MaterialKind? materialKind;

  /// Zero-based Discovery indexes unlocked by this completion.
  final List<int> newDiscoveryIndexes;

  /// The one bonus material the companion found today through Sniff Out.
  final MaterialKind? sniffOutFound;

  /// The one material Fetch carried to the current restoration today.
  final MaterialKind? fetchCarried;

  /// Zero-based indexes of the places this completion restored.
  final List<int> newRestorationIndexes;

  /// Keys of companion gear and hero cosmetics this completion unlocked.
  final List<String> newGear;
  final List<String> newCosmetics;

  /// Extra hero XP on top of the difficulty's own: the welcome that comes
  /// with the comeback quest (DESIGN §4.3).
  final int bonusHeroXp;

  /// Extra Bond from Comfort, when the companion presents the comeback
  /// quest (DESIGN §7A.3).
  final int comfortBond;

  /// Hero XP this completion gave in all.
  int get heroXpGained => award.heroXp + bonusHeroXp;

  /// Heroic and Boss quests wake a Still creature when they are done.
  bool get clearsStill =>
      difficulty == Difficulty.heroic || difficulty == Difficulty.boss;

  int get totalBond => award.bond + bondBonus + comfortBond;
  bool get heroLevelledUp => after.heroLevel > before.heroLevel;
  bool get companionLevelledUp => after.companionLevel > before.companionLevel;
  bool get attributeLevelledUp =>
      after.attributeLevel(attribute) > before.attributeLevel(attribute);
}

/// Applies one completed quest to [totals].
///
/// [bondLevelBonusGrantedToday] is true when today's companion level-up bonus
/// has already been handed out, so it is given at most once a day.
///
/// [sniffOutFind] is the material Sniff Out would turn up today, or null when
/// today's find has already been made. It is only granted on a companion or
/// shared quest, and only once the companion has learned the trick.
///
/// [fetchAvailable] is true while today's Fetch has not been made. Fetch
/// carries one material the current restoration still needs, on a companion
/// or shared quest, once the companion has learned it.
///
/// [bonusHeroXp] and [bonusBond] are extras a system quest may carry (the
/// comeback quest, DESIGN §4.3 and §7A.3). They only ever add.
CompletionOutcome applyCompletion({
  required PartyTotals totals,
  required Difficulty difficulty,
  required Track track,
  required Attribute attribute,
  bool bondLevelBonusGrantedToday = false,
  MaterialKind? sniffOutFind,
  bool fetchAvailable = false,
  int bonusHeroXp = 0,
  int bonusBond = 0,
}) {
  final award = awardFor(difficulty: difficulty, track: track);
  final extraXp = bonusHeroXp < 0 ? 0 : bonusHeroXp;
  final extraBond = bonusBond < 0 ? 0 : bonusBond;

  final attributeXp = Map<Attribute, int>.of(totals.attributeXp);
  if (award.attributeXp + extraXp > 0) {
    attributeXp[attribute] =
        (attributeXp[attribute] ?? 0) + award.attributeXp + extraXp;
  }

  final materials = Map<MaterialKind, int>.of(totals.materials);
  MaterialKind? materialKind;
  var heroTrackCompletions = totals.heroTrackCompletions;
  if (track == Track.hero) {
    if (award.materials > 0) {
      materialKind = materialForCompletion(heroTrackCompletions);
      materials[materialKind] = (materials[materialKind] ?? 0) + award.materials;
    }
    heroTrackCompletions += 1;
  }

  final companionXp = totals.companionXp + award.companionXp;
  final companionLevelUp =
      XpCurve.levelForXp(companionXp) > totals.companionLevel;
  final bonus = (companionLevelUp && !bondLevelBonusGrantedToday)
      ? bondLevelUpBonus
      : 0;

  MaterialKind? sniffOutFound;
  if (sniffOutFind != null &&
      track.travelsWithCompanion &&
      XpCurve.levelForXp(companionXp) >= sniffOutLevel) {
    sniffOutFound = sniffOutFind;
    materials[sniffOutFind] = (materials[sniffOutFind] ?? 0) + 1;
  }

  MaterialKind? fetchCarried;
  if (fetchAvailable &&
      track.travelsWithCompanion &&
      XpCurve.levelForXp(companionXp) >= fetchLevel) {
    fetchCarried = stillNeeded(materials);
    materials[fetchCarried] = (materials[fetchCarried] ?? 0) + 1;
  }

  final paces = totals.paces + award.paces;

  final after = PartyTotals(
    heroXp: totals.heroXp + award.heroXp + extraXp,
    attributeXp: Map<Attribute, int>.unmodifiable(attributeXp),
    companionXp: companionXp,
    bond: totals.bond + award.bond + bonus + extraBond,
    paces: paces,
    gold: totals.gold + award.gold,
    materials: Map<MaterialKind, int>.unmodifiable(materials),
    heroTrackCompletions: heroTrackCompletions,
  );

  return CompletionOutcome(
    award: award,
    before: totals,
    after: after,
    attribute: attribute,
    track: track,
    difficulty: difficulty,
    bondBonus: bonus,
    materialKind: materialKind,
    newDiscoveryIndexes: newDiscoveries(totals.paces, paces),
    sniffOutFound: sniffOutFound,
    fetchCarried: fetchCarried,
    newRestorationIndexes: <int>[
      for (var i = totals.restored; i < after.restored; i++) i,
    ],
    newGear: _added(
      gearUnlockedAt(level: totals.companionLevel, bond: totals.bond),
      gearUnlockedAt(level: after.companionLevel, bond: after.bond),
    ),
    newCosmetics: _added(
      cosmeticsUnlockedAt(
        heroLevel: totals.heroLevel,
        restored: totals.restored,
      ),
      cosmeticsUnlockedAt(
        heroLevel: after.heroLevel,
        restored: after.restored,
      ),
    ),
    bonusHeroXp: extraXp,
    comfortBond: extraBond,
  );
}

List<String> _added(List<String> before, List<String> after) => <String>[
      for (final key in after)
        if (!before.contains(key)) key,
    ];
