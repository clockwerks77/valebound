import 'package:habit_adventure/rules/classes.dart';
import 'package:habit_adventure/rules/combat.dart';

// Ways of playing a fight, for the balance tests. The same three policies
// as tool/sim/sim.py, so the two models can be held to the same numbers.

typedef Move = (CombatAction, bool);
typedef Policy = Move Function(Fight f);

/// Reads the intent and plays the class's natural plan (Amendment v0.3 §6:
/// "a player who does their quests and reads intents").
Move smart(Fight f) {
  final veiled = f.intentVeiled;
  final it = f.intent;
  final comp = f.companionReady;
  final c = f.cls;
  final dangerous = !veiled &&
      (it == Intent.big || it == Intent.heavy || it == Intent.swarmAll);
  final low = f.heroHp * 100 <= f.heroMax * 35;
  if (low && f.count(ItemKind.salve) > 0 && !dangerous) {
    return (CombatAction.salve, comp);
  }
  if (dangerous) {
    if (c == HeroClass.sage && f.canAbility) return (CombatAction.ability, comp);
    if (c == HeroClass.warden && f.canAbility && f.shield < f.heavyBlow) {
      return (CombatAction.ability, comp);
    }
    if (c == HeroClass.warden && f.shield >= f.heavyBlow) {
      return (CombatAction.strike, comp);
    }
    if (f.count(ItemKind.smoke) > 0) return (CombatAction.smoke, comp);
    return (CombatAction.defend, comp);
  }
  if (f.ward && !comp && !veiled) return (CombatAction.defend, comp);
  switch (c) {
    case HeroClass.ranger:
      if (f.canAbility && !f.ward) return (CombatAction.ability, comp);
      return (CombatAction.strike, comp);
    case HeroClass.warden:
      if (f.canAbility && f.taunt == 0) return (CombatAction.ability, comp);
      return (CombatAction.strike, comp);
    case HeroClass.sage:
      if (it == Intent.charge && f.resource < 2) {
        return (CombatAction.defend, comp);
      }
      if (it == Intent.charge) return (CombatAction.strike, comp);
      if (it == Intent.hex) return (CombatAction.defend, comp);
      if (f.canAbility &&
          f.resource >= 5 &&
          f.type != EnemyType.brute &&
          !f.boss) {
        return (CombatAction.ability, comp);
      }
      if (f.canAbility && f.resource >= 6) return (CombatAction.ability, comp);
      return (CombatAction.strike, comp);
    case HeroClass.artificer || HeroClass.herald:
      if (f.trap == 0 && f.canAbility) return (CombatAction.ability, comp);
      if (f.bodies.length > 1 && f.count(ItemKind.bomb) > 0) {
        return (CombatAction.bomb, comp);
      }
      return (CombatAction.strike, comp);
  }
}

/// Ignores intents entirely: strikes every turn.
Move strikeOnly(Fight f) => (CombatAction.strike, f.companionReady);

/// Uses the ability the moment it can, without reading anything.
Move greedy(Fight f) => (
      f.canAbility ? CombatAction.ability : CombatAction.strike,
      f.companionReady,
    );

/// Plays [setup] to its end with [policy].
Fight play(Policy policy, FightSetup setup) {
  final fight = Fight(setup);
  while (!fight.over) {
    final (action, companion) = policy(fight);
    fight.act(action, companion: companion);
  }
  return fight;
}
