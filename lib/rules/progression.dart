import 'awards.dart';
import 'companion_rules.dart';
import 'enums.dart';
import 'journey.dart';
import 'materials.dart';
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
  final Map<MaterialKind, int> materials;

  /// Drives the material rotation.
  final int heroTrackCompletions;

  int get heroLevel => XpCurve.levelForXp(heroXp);
  int get companionLevel => XpCurve.levelForXp(companionXp);
  int attributeLevel(Attribute a) => XpCurve.levelForXp(attributeXp[a] ?? 0);
  int materialCount(MaterialKind k) => materials[k] ?? 0;
  int get discoveries => discoveriesEarned(paces);
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

  int get totalBond => award.bond + bondBonus;
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
CompletionOutcome applyCompletion({
  required PartyTotals totals,
  required Difficulty difficulty,
  required Track track,
  required Attribute attribute,
  bool bondLevelBonusGrantedToday = false,
  MaterialKind? sniffOutFind,
}) {
  final award = awardFor(difficulty: difficulty, track: track);

  final attributeXp = Map<Attribute, int>.of(totals.attributeXp);
  if (award.attributeXp > 0) {
    attributeXp[attribute] = (attributeXp[attribute] ?? 0) + award.attributeXp;
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

  final paces = totals.paces + award.paces;

  final after = PartyTotals(
    heroXp: totals.heroXp + award.heroXp,
    attributeXp: Map<Attribute, int>.unmodifiable(attributeXp),
    companionXp: companionXp,
    bond: totals.bond + award.bond + bonus,
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
  );
}
