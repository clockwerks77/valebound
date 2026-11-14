/// The Still (DESIGN §7): grey, sleepy obstacles that sit on Heroic and Boss
/// quests. Presentation only. Finishing the quest wakes the creature and it
/// wanders off; nothing is fought and nothing is at stake.
library;

import 'enums.dart';

class StillCreature {
  const StillCreature(this.key, this.name, this.sits, this.wakes);
  final String key;
  final String name;

  /// Shown on the quest while it waits.
  final String sits;

  /// Shown when the quest is done.
  final String wakes;
}

/// Original creatures, drafted for v1.
const List<StillCreature> stillCreatures = <StillCreature>[
  StillCreature(
    'drowsel',
    'Drowsel',
    'A Drowsel is napping across it.',
    'The Drowsel stirs, stretches and ambles off.',
  ),
  StillCreature(
    'mistling',
    'Mistling',
    'A Mistling has curled up on it.',
    'The Mistling yawns into a wisp and drifts away.',
  ),
  StillCreature(
    'hushmoth',
    'Hushmoth',
    'A Hushmoth is dusting it grey.',
    'The Hushmoth shakes out its wings and the colour returns.',
  ),
  StillCreature(
    'yawnstone',
    'Yawnstone',
    'A Yawnstone sits here, half asleep.',
    'The Yawnstone blinks, rolls over and trundles off.',
  ),
  StillCreature(
    'dozewisp',
    'Dozewisp',
    'A Dozewisp drifts in slow circles here.',
    'The Dozewisp brightens and floats off toward the hills.',
  ),
  StillCreature(
    'fogfinch',
    'Fogfinch',
    'A Fogfinch is roosting here, feathers puffed.',
    'The Fogfinch chirps once and takes wing.',
  ),
];

/// Only the bigger quests draw a creature.
bool drawsStill(Difficulty difficulty) =>
    difficulty == Difficulty.heroic || difficulty == Difficulty.boss;

/// The creature for [questId]. Chosen from the id's characters, so a quest
/// always meets the same one.
StillCreature stillFor(String questId) {
  var sum = 0;
  for (final unit in questId.codeUnits) {
    sum = (sum + unit) % 9973;
  }
  return stillCreatures[sum % stillCreatures.length];
}
