/// Core vocabulary of the game rules. Pure Dart: nothing in `lib/rules`
/// imports Flutter or the database, so every rule can be unit-tested alone.
library;

/// DESIGN §5.2. Every quest belongs to exactly one attribute.
enum Attribute {
  vitality('Vitality', 'Steps, exercise, health check-ins'),
  care('Care', 'Dog walks, home and family'),
  craft('Craft', 'Painting, making, printing, hobby blocks'),
  mind('Mind', 'Reading, learning, reflection'),
  adventure('Adventure', 'Outings, new places, social plans'),
  order('Order', 'Appointments, admin, errands');

  const Attribute(this.label, this.covers);
  final String label;
  final String covers;
}

/// DESIGN §5.4. XP values are fixed by the design.
enum Difficulty {
  minor('Minor', 10, 'About two minutes, low dread'),
  standard('Standard', 25, '15–30 minutes, or a normal daily act'),
  heroic('Heroic', 60, '60+ minutes, or high effort'),
  boss('Boss', 150, 'Weekly-scale effort');

  const Difficulty(this.label, this.xp, this.means);
  final String label;
  final int xp;
  final String means;
}

/// DESIGN §7A.2. Which character a quest belongs to.
enum Track {
  hero('Hero'),
  companion('Companion'),
  shared('Shared');

  const Track(this.label);
  final String label;

  /// Companion and Shared quests both travel with the companion.
  bool get travelsWithCompanion => this != Track.hero;
}

/// DESIGN §6.2.
enum CompletionType {
  tap('Tap'),
  count('Count'),
  timer('Timer'),
  auto('Auto'),
  confirm('Confirm');

  const CompletionType(this.label);
  final String label;
}

/// DESIGN §6.1 schedules.
enum ScheduleType {
  daily,
  weekdays,
  weekly,
  interval,
  oneOff,
}

/// DESIGN §6.1 source.
enum QuestSource { manual, recurring, calendar, health, system }

/// DESIGN §7A.1. Kind is identity and flavour only; no kind is stronger.
enum CompanionKind {
  hound('Hound', 'Loyal, with a nose for discoveries.', Attribute.care),
  cat('Cat', 'Particular, and always finds the warm spot.', Attribute.order),
  fox('Fox', 'Clever, and fond of the long way round.', Attribute.adventure),
  owl('Owl', 'Quiet and night-wise.', Attribute.mind),
  hare('Hare', 'Quick-footed and glad of open ground.', Attribute.vitality),
  clockworkSprite(
    'Clockwork Sprite',
    'A small ticking helper that loves a workbench.',
    Attribute.craft,
  );

  const CompanionKind(this.label, this.temperament, this.affinity);
  final String label;
  final String temperament;

  /// Flavour only: shown as a star beside this attribute. No bonus attached.
  final Attribute affinity;
}

/// DESIGN §5.3 materials.
enum MaterialKind {
  timber('Timber'),
  stone('Stone'),
  starShard('Star Shards');

  const MaterialKind(this.label);
  final String label;
}
