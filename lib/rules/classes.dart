/// Classes (Amendment v0.3 §2): who the hero is in a fight, and which of the
/// day's quests make them stronger there.
///
/// A class is identity and playstyle. Every class can beat every creature;
/// class changes how hard a given one is and which plan comes naturally
/// (the matrix in `combat.dart`). It can be changed for nothing at the
/// weekly Campfire, and changing it touches no XP, level or anything else.
library;

import 'enums.dart';

enum HeroClass {
  ranger(
    label: 'Ranger',
    role: 'Striker and scout',
    home: Attribute.adventure,
    resource: 'Focus',
    feeds: 'Adventure quests, and any quest shared with your companion',
    passive: 'Your companion can act on every turn, not every other one.',
    ability: 'Companion Volley',
    abilityLine: 'Your companion strikes hard, at every creature in front '
        'of you. Stronger the higher their level and Bond.',
    plan: 'Keep your companion busy and loose a Volley whenever Focus '
        'allows.',
  ),
  warden(
    label: 'Warden',
    role: 'Protector',
    home: Attribute.vitality,
    resource: 'Guard',
    feeds: 'Vitality quests and health check-ins',
    passive: 'You walk in with a Shield, bigger the more Guard you carry. '
        'It takes blows before you do.',
    ability: 'Stand Firm',
    abilityLine: 'Raise a large Shield and draw every blow to it for two '
        'turns. Each blow it takes, you answer.',
    plan: 'Stand Firm when the big blow is coming and let it break on '
        'your Shield.',
  ),
  sage(
    label: 'Sage',
    role: 'Controller',
    home: Attribute.mind,
    resource: 'Insight',
    feeds: 'Mind quests',
    passive: 'You read every intent in full, numbers and all, and no hex '
        'takes hold of you.',
    ability: 'Exploit',
    abilityLine: 'Spend all your Insight: the creature is stunned for the '
        'turn and takes more the more you spend.',
    plan: 'Hold your Insight for the turn the big blow is due, then stop '
        'it cold.',
  ),
  artificer(
    label: 'Artificer',
    role: 'Tactician',
    home: Attribute.craft,
    resource: 'Scrap',
    feeds: 'Craft quests',
    passive: 'Each Craft quest you finish also stocks the shared pouch '
        'with a trap, a salve or a bomb.',
    ability: 'Deploy Trap',
    abilityLine: 'Breaks armour and bites for three turns. A trap cannot '
        'be dodged.',
    plan: 'Set the trap first, then keep striking while it works.',
  ),

  /// Designed for, not built (Amendment v0.3 §2): the data can hold it and
  /// the app does not offer it.
  herald(
    label: 'Herald',
    role: 'Support',
    home: Attribute.order,
    resource: 'Morale',
    feeds: 'Order quests',
    passive: '',
    ability: 'Rally',
    abilityLine: '',
    plan: '',
    offered: false,
  );

  const HeroClass({
    required this.label,
    required this.role,
    required this.home,
    required this.resource,
    required this.feeds,
    required this.passive,
    required this.ability,
    required this.abilityLine,
    required this.plan,
    this.offered = true,
  });

  final String label;
  final String role;

  /// The attribute whose quests feed this class in full.
  final Attribute home;

  /// What the class spends in a fight.
  final String resource;

  /// Which quests feed it, in words.
  final String feeds;
  final String passive;
  final String ability;
  final String abilityLine;

  /// The natural way to play it, in a line.
  final String plan;
  final bool offered;

  /// The classes a player can choose.
  static List<HeroClass> get choices =>
      <HeroClass>[for (final c in values) if (c.offered) c];

  /// The class stored under [id], or null for none or one this build does
  /// not know.
  static HeroClass? byId(String? id) {
    for (final c in values) {
      if (c.name == id) return c;
    }
    return null;
  }
}

/// What a hero walks into a fight with before any quest is done, and the
/// most they can carry.
const int baseResource = 2;
const int resourceCap = 8;

/// True when a quest of [attribute] on [track] feeds [cls] in full: its
/// home attribute, plus (Amendment v0.3 §2) Shared quests for the Ranger.
/// Health check-ins are Vitality quests, so the Warden needs no extra rule.
bool feedsInFull(HeroClass cls, Attribute attribute, Track track) =>
    attribute == cls.home || (cls == HeroClass.ranger && track == Track.shared);

/// What one finished quest adds to the class resource for today's fights:
/// Minor 1, Standard 2, Heroic 3 (Boss 4) when it feeds the class in full,
/// and 1 for any other quest, so every finished quest counts for something.
/// The Ranger's Shared quests bring one more (their passive).
int resourceFrom(
  HeroClass cls,
  Attribute attribute,
  Track track,
  Difficulty difficulty,
) {
  if (!feedsInFull(cls, attribute, track)) return 1;
  final full = switch (difficulty) {
    Difficulty.minor => 1,
    Difficulty.standard => 2,
    Difficulty.heroic => 3,
    Difficulty.boss => 4,
  };
  return cls == HeroClass.ranger && track == Track.shared ? full + 1 : full;
}

/// One finished quest, as far as a class cares.
class QuestDone {
  const QuestDone(this.attribute, this.track, this.difficulty);
  final Attribute attribute;
  final Track track;
  final Difficulty difficulty;
}

/// The resource [cls] enters today's fight with, from the quests finished
/// so far today. Worked out, never stored.
int resourceToday(HeroClass cls, Iterable<QuestDone> done) {
  var total = baseResource;
  for (final q in done) {
    total += resourceFrom(cls, q.attribute, q.track, q.difficulty);
  }
  return total > resourceCap ? resourceCap : total;
}
