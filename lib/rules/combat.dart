/// The fight itself (Amendment v0.3 §§3-5): hero and companion against one
/// creature of the Still, turn by turn, with seeded dice.
///
/// Everything here is whole-number arithmetic, so a fight replays exactly:
/// the same day, the same actions, the same rolls. `tool/sim/combat.py` is
/// the same rules in Python, where the numbers were tuned; the vectors in
/// `test/rules/combat_vectors.json` hold the two together.
library;

import 'classes.dart';

enum EnemyType {
  swift('Swift', 'quick and hard to pin down'),
  armoured('Armoured', 'slow, in a thick hide'),
  brute('Brute', 'one huge blow, slowly wound up'),
  swarm('Swarm', 'several small ones at once'),
  arcane('Arcane', 'tricks you cannot always read');

  const EnemyType(this.label, this.means);
  final String label;
  final String means;
}

/// How well a class's own blows land on a type (Amendment v0.3 §4).
enum Effect {
  strong(150, 'Strong'),
  normal(100, 'Even'),
  hard(67, 'Hard');

  const Effect(this.percent, this.label);
  final int percent;
  final String label;
}

/// The class and challenge matrix, exactly as the amendment has it.
const Map<EnemyType, Map<HeroClass, Effect>> _matrix =
    <EnemyType, Map<HeroClass, Effect>>{
  EnemyType.swift: <HeroClass, Effect>{
    HeroClass.ranger: Effect.strong,
    HeroClass.warden: Effect.hard,
    HeroClass.sage: Effect.normal,
    HeroClass.artificer: Effect.strong,
  },
  EnemyType.armoured: <HeroClass, Effect>{
    HeroClass.ranger: Effect.hard,
    HeroClass.warden: Effect.normal,
    HeroClass.sage: Effect.normal,
    HeroClass.artificer: Effect.strong,
  },
  EnemyType.brute: <HeroClass, Effect>{
    HeroClass.ranger: Effect.normal,
    HeroClass.warden: Effect.strong,
    HeroClass.sage: Effect.strong,
    HeroClass.artificer: Effect.normal,
  },
  EnemyType.swarm: <HeroClass, Effect>{
    HeroClass.ranger: Effect.strong,
    HeroClass.warden: Effect.hard,
    HeroClass.sage: Effect.normal,
    HeroClass.artificer: Effect.strong,
  },
  EnemyType.arcane: <HeroClass, Effect>{
    HeroClass.ranger: Effect.normal,
    HeroClass.warden: Effect.normal,
    HeroClass.sage: Effect.strong,
    HeroClass.artificer: Effect.hard,
  },
};

/// How [cls] fares against [type]. A class this build does not offer is
/// simply even.
Effect effectOf(HeroClass cls, EnemyType type) =>
    _matrix[type]![cls] ?? Effect.normal;

/// What the creature means to do this turn. Shown before the player acts.
enum EnemyIntent {
  hit,
  hitCompanion,
  heavy,
  charge,
  big,
  fortify,
  hex,
  ward,
  swarm,
  swarmCompanion,
  swarmAll,
}

enum CombatAction { strike, defend, ability, salve, trap, bomb, smoke }

/// The consumables in the shared pouch (Amendment v0.3 §3).
enum ItemKind {
  salve('Salve', 'Heals you by nearly half.'),
  trap('Trap', 'Breaks armour and bites for three turns.'),
  bomb('Bomb', 'A loud clay pot. Hits everything in front of you.'),
  smoke('Smoke', 'The creature does nothing this turn.');

  const ItemKind(this.label, this.does);
  final String label;
  final String does;

  CombatAction get action => switch (this) {
        ItemKind.salve => CombatAction.salve,
        ItemKind.trap => CombatAction.trap,
        ItemKind.bomb => CombatAction.bomb,
        ItemKind.smoke => CombatAction.smoke,
      };
}

enum FightOutcome { won, held }

/// What Boss Marks buy at the start of a boss fight (Amendment v0.3 §5).
enum Advantage {
  debuff('It starts weakened', 'Its blows land a quarter lighter.'),
  shield('You start shielded', 'A Shield worth two fifths of your HP.'),
  item('One more Bomb', 'An extra Bomb in the pouch.');

  const Advantage(this.label, this.does);
  final String label;
  final String does;
}

// ---- The numbers (tuned in tool/sim) --------------------------------------
//
// Every stat grows as (4 + level), hero, companion and creature alike, so a
// fight is as hard at level 1 as at level 20 (DECISIONS D-101).

const int _heroHpBase = 24, _heroHpPer = 6;
const int _heroAtkBase = 8, _heroAtkPer = 2;
const int _compHpBase = 16, _compHpPer = 4;
const int _compAtkBase = 6, _compAtkNum = 3, _compAtkDen = 2;
const int _enemyHpBase = 52, _enemyHpPer = 13;
const int _enemyAtkBase = 8, _enemyAtkPer = 2;

/// The creature's level leans on the hero's: (3 x hero + companion + 2) ~/ 4.
int enemyLevel(int level, int companionLevel) =>
    (3 * level + companionLevel + 2) ~/ 4;

const Map<HeroClass, int> _classHp = <HeroClass, int>{
  HeroClass.ranger: 100,
  HeroClass.warden: 115,
  HeroClass.sage: 90,
  HeroClass.artificer: 100,
};
const Map<HeroClass, int> _classAtk = <HeroClass, int>{
  HeroClass.ranger: 95,
  HeroClass.warden: 105,
  HeroClass.sage: 115,
  HeroClass.artificer: 100,
};
const Map<EnemyType, int> _typeHp = <EnemyType, int>{
  EnemyType.swift: 90,
  EnemyType.armoured: 85,
  EnemyType.brute: 110,
  EnemyType.swarm: 105,
  EnemyType.arcane: 65,
};
const Map<EnemyType, int> _typeAtk = <EnemyType, int>{
  EnemyType.swift: 90,
  EnemyType.armoured: 95,
  EnemyType.brute: 115,
  EnemyType.swarm: 110,
  EnemyType.arcane: 140,
};

const int abilityCost = 3;
const int sageMinimum = 2;
const int strikeChance = 90, strikeChanceSwift = 75;
const int companionChance = 85, companionChanceSwift = 75;
const int _critOn = 19, _critPercent = 150;
const int _armour = 80, _big = 280, _heavy = 260;
const int _swarmHit = 45, _swarmAll = 105, _bodies = 3, _aoe = 50;
const int _fortify = 8, _volley = 220, _riposte = 150;
const int _firm = 25, _firmTurns = 2, _guardShield = 2;
const int _exploitBase = 45, _exploitPer = 25;
const int _trap = 100, _trapTurns = 3, _salve = 45;
const int _bombBase = 12, _bombPer = 3;
const int _heroicHp = 126, _heroicAtk = 110;
const int turnCap = 12;
const int _bossHp = 260, _bossAtk = 85;
const int bossTurns = 7;
const int _bossDebuff = 75, _bossShield = 40;

const Map<EnemyType, List<EnemyIntent>> _patterns = <EnemyType, List<EnemyIntent>>{
  EnemyType.swift: <EnemyIntent>[
    EnemyIntent.hit, EnemyIntent.hitCompanion, EnemyIntent.heavy, EnemyIntent.hit, //
  ],
  EnemyType.armoured: <EnemyIntent>[
    EnemyIntent.hit, EnemyIntent.fortify, EnemyIntent.heavy, EnemyIntent.hitCompanion, //
  ],
  EnemyType.brute: <EnemyIntent>[
    EnemyIntent.hit, EnemyIntent.charge, EnemyIntent.big, EnemyIntent.hitCompanion, //
  ],
  EnemyType.swarm: <EnemyIntent>[
    EnemyIntent.swarm, EnemyIntent.swarmCompanion, EnemyIntent.swarmAll, EnemyIntent.swarm, //
  ],
  EnemyType.arcane: <EnemyIntent>[
    EnemyIntent.hex, EnemyIntent.hit, EnemyIntent.ward, EnemyIntent.heavy, EnemyIntent.hitCompanion, //
  ],
};

/// A boss changes its ways as it wears down: three phases by thirds.
const List<List<EnemyIntent>> _bossPhases = <List<EnemyIntent>>[
  <EnemyIntent>[EnemyIntent.hit, EnemyIntent.charge, EnemyIntent.big, EnemyIntent.hitCompanion],
  <EnemyIntent>[EnemyIntent.heavy, EnemyIntent.hex, EnemyIntent.hit, EnemyIntent.ward],
  <EnemyIntent>[EnemyIntent.charge, EnemyIntent.big, EnemyIntent.heavy],
];

const int _mask = 0xFFFFFFFF;

/// The d20 for [slot] on [turn] of the fight seeded with [seed]: 1 to 20,
/// and always the same for the same three numbers. Slot 0 is the hero's
/// roll, slot 1 the companion's.
int rollD20(int seed, int turn, int slot) {
  var h = (seed ^
          ((turn * 0x9E3779B1) & _mask) ^
          ((slot * 0x85EBCA6B) & _mask)) &
      _mask;
  h ^= h >> 16;
  h = (h * 0x7FEB352D) & _mask;
  h ^= h >> 15;
  h = (h * 0x846CA68B) & _mask;
  h ^= h >> 16;
  return h % 20 + 1;
}

int _pct(int x, int percent) => (x * percent) ~/ 100;

/// True when a roll of [roll] lands at [chance] percent (a multiple of 5).
bool rollLands(int roll, int chance) => roll > (100 - chance) ~/ 5;

/// The lowest roll that lands at [chance] percent.
int needToLand(int chance) => (100 - chance) ~/ 5 + 1;

enum CombatEventKind {
  companionHit,
  companionWide,
  strikeHit,
  strikeWide,
  warded,
  defend,
  volley,
  standFirm,
  exploit,
  trapSet,
  salve,
  bomb,
  smoke,
  trapBite,
  riposte,
  enemyHit,
  enemyHitCompanion,
  enemyCharge,
  enemyBig,
  enemyHeavy,
  enemySwarm,
  enemyFortify,
  enemyHex,
  enemyHexShrugged,
  enemyWard,
  enemyStopped,
  companionWinded,
}

/// One thing that happened in a turn, for the log on screen.
class CombatEvent {
  const CombatEvent(
    this.kind, {
    this.amount = 0,
    this.roll = 0,
    this.crit = false,
    this.blocked = 0,
  });

  final CombatEventKind kind;

  /// Damage dealt, HP healed or Shield gained, by kind.
  final int amount;

  /// The d20 shown for a hero or companion roll; 0 when none was thrown.
  final int roll;
  final bool crit;

  /// How much of an enemy blow the Shield took.
  final int blocked;
}

/// What a fight starts from.
class FightSetup {
  const FightSetup({
    required this.heroClass,
    required this.level,
    required this.companionLevel,
    required this.bond,
    required this.type,
    required this.seed,
    required this.resource,
    this.heroic = false,
    this.items = const <ItemKind, int>{},
    this.boss = false,
    this.bossHp,
    this.advantage,
  });

  final HeroClass heroClass;
  final int level;
  final int companionLevel;
  final int bond;
  final EnemyType type;
  final int seed;
  final int resource;
  final bool heroic;
  final Map<ItemKind, int> items;
  final bool boss;

  /// What the boss has left from earlier attempts; null for a fresh one.
  final int? bossHp;
  final Advantage? advantage;
}

/// One fight, from the first turn to its outcome.
class Fight {
  Fight(FightSetup setup)
      : cls = setup.heroClass,
        type = setup.type,
        seed = setup.seed,
        boss = setup.boss,
        heroic = setup.heroic,
        _itemLevel = setup.level,
        items = Map<ItemKind, int>.of(setup.items) {
    heroMax = _pct(_heroHpBase + _heroHpPer * setup.level, _classHp[cls] ?? 100);
    heroHp = heroMax;
    attack =
        _pct(_heroAtkBase + _heroAtkPer * setup.level, _classAtk[cls] ?? 100);
    companionMax = _compHpBase + _compHpPer * setup.companionLevel;
    companionHp = companionMax;
    companionAttack = _compAtkBase +
        (_compAtkNum * setup.companionLevel) ~/ _compAtkDen +
        setup.bond ~/ 25;
    final e = enemyLevel(setup.level, setup.companionLevel);
    var hp = _pct(_enemyHpBase + _enemyHpPer * e, _typeHp[type]!);
    var atk = _pct(_enemyAtkBase + _enemyAtkPer * e, _typeAtk[type]!);
    if (!boss) {
      // No two days' creatures are quite the same size.
      hp = _pct(hp, 90 + 5 * (rollD20(seed, 0, 7) % 6));
      atk = _pct(atk, 90 + 5 * (rollD20(seed, 0, 8) % 5));
    }
    if (setup.heroic) {
      hp = _pct(hp, _heroicHp);
      atk = _pct(atk, _heroicAtk);
    }
    if (boss) {
      hp = _pct(_enemyHpBase + _enemyHpPer * e, _bossHp);
      atk = _pct(_enemyAtkBase + _enemyAtkPer * e, _bossAtk);
    }
    enemyAttack = atk;
    final n = (type == EnemyType.swarm && !boss) ? _bodies : 1;
    enemyMax = hp;
    final left = setup.bossHp;
    if (boss && left != null) hp = left;
    bodies = List<int>.filled(n, hp ~/ n);
    if (n > 1) enemyMax = (hp ~/ n) * n;
    startHp = enemyHp;
    resource = setup.resource > resourceCap ? resourceCap : setup.resource;
    // A percentage of max HP for each Guard, worked out in one step so that a
    // small hero's Shield is not rounded away to nothing.
    shield =
        cls == HeroClass.warden ? _pct(heroMax, _guardShield * resource) : 0;
    armoured = type == EnemyType.armoured;
    switch (setup.advantage) {
      case Advantage.debuff:
        enemyAttack = _pct(enemyAttack, _bossDebuff);
      case Advantage.shield:
        shield += _pct(heroMax, _bossShield);
      case Advantage.item:
        items[ItemKind.bomb] = (items[ItemKind.bomb] ?? 0) + 1;
      case null:
        break;
    }
  }

  final HeroClass cls;
  final EnemyType type;
  final int seed;
  final bool boss;
  final bool heroic;
  final int _itemLevel;

  /// The pouch as this fight sees it; what is used here is used.
  final Map<ItemKind, int> items;

  int turn = 1;
  late final int heroMax;
  late int heroHp;
  late final int attack;
  late final int companionMax;
  late int companionHp;
  late final int companionAttack;
  late int enemyAttack;
  late int enemyMax;
  late List<int> bodies;
  late final int startHp;
  late int resource;
  late int shield;
  late bool armoured;
  bool ward = false;
  bool dimmed = false;
  int taunt = 0;
  int trap = 0;
  bool charging = false;
  FightOutcome? outcome;
  int _step = 0;

  int get enemyHp {
    var sum = 0;
    for (final b in bodies) {
      sum += b;
    }
    return sum;
  }

  /// How many of a swarm are still up (1 for anything else alive).
  int get bodiesUp => bodies.where((b) => b > 0).length;

  Effect get effect => effectOf(cls, type);
  int get turnLimit => boss ? bossTurns : turnCap;
  bool get over => outcome != null;

  /// What this fight has taken off the creature so far.
  int get dealt => startHp - enemyHp;

  /// 1, 2 or 3: which third of its HP a boss is in.
  int get bossPhase {
    final left = enemyHp * 3;
    return left > enemyMax * 2 ? 1 : (left > enemyMax ? 2 : 3);
  }

  List<EnemyIntent> get _pattern =>
      boss ? _bossPhases[bossPhase - 1] : _patterns[type]!;

  /// What the creature will do this turn unless it is stopped.
  EnemyIntent get intent {
    if (charging) return EnemyIntent.big;
    final p = _pattern;
    final it = p[_step % p.length];
    // A big blow only ever follows its own wind-up.
    return it == EnemyIntent.big ? EnemyIntent.hit : it;
  }

  /// Whether the class can read [intent] this turn. Only a Sage sees
  /// through an Arcane trick before it happens (Amendment v0.3 §2).
  bool get intentVeiled =>
      cls != HeroClass.sage && (intent == EnemyIntent.hex || intent == EnemyIntent.ward);

  /// What this turn's intent would take off the hero or companion if
  /// nothing softened it. For a swarm, what each one does.
  int get intentDamage => switch (intent) {
        EnemyIntent.hit || EnemyIntent.hitCompanion => enemyAttack,
        EnemyIntent.heavy => _pct(enemyAttack, _heavy),
        EnemyIntent.big => _pct(enemyAttack, _big),
        EnemyIntent.swarm || EnemyIntent.swarmCompanion => _pct(enemyAttack, _swarmHit),
        EnemyIntent.swarmAll => _pct(enemyAttack, _swarmAll),
        _ => 0,
      };

  /// What a heavy blow from this creature takes off, unsoftened.
  int get heavyBlow => _pct(enemyAttack, _heavy);

  bool get companionReady =>
      companionHp > 0 && (cls == HeroClass.ranger || turn.isEven);

  bool get canAbility {
    if (cls == HeroClass.sage) return resource >= sageMinimum;
    if (cls == HeroClass.ranger && companionHp <= 0) return false;
    return resource >= abilityCost;
  }

  int get heroStrikeChance => effect == Effect.strong
      ? 100
      : (type == EnemyType.swift ? strikeChanceSwift : strikeChance);

  int get companionHitChance =>
      type == EnemyType.swift ? companionChanceSwift : companionChance;

  /// What a Strike does when it lands without a crit, before armour.
  int get strikeDamage {
    final d = _pct(attack, effect.percent);
    return dimmed ? _pct(d, 50) : d;
  }

  int count(ItemKind kind) => items[kind] ?? 0;

  bool canDo(CombatAction action) => switch (action) {
        CombatAction.strike || CombatAction.defend => true,
        CombatAction.ability => canAbility,
        CombatAction.salve => count(ItemKind.salve) > 0,
        CombatAction.trap => count(ItemKind.trap) > 0,
        CombatAction.bomb => count(ItemKind.bomb) > 0,
        CombatAction.smoke => count(ItemKind.smoke) > 0,
      };

  // ---- Damage to the creature ----------------------------------------

  int _hurt(int damage, {bool allBodies = false, bool pierce = false}) {
    var dmg = damage;
    if (dmg <= 0) return 0;
    if (ward) {
      ward = false;
      return 0;
    }
    if (armoured && !pierce) dmg = _pct(dmg, _armour);
    var done = 0;
    if (allBodies && bodies.length > 1) {
      final each = _pct(dmg, _aoe);
      for (var i = 0; i < bodies.length; i++) {
        if (bodies[i] > 0) {
          final d = each < bodies[i] ? each : bodies[i];
          bodies[i] -= d;
          done += d;
        }
      }
    } else {
      for (var i = 0; i < bodies.length; i++) {
        if (bodies[i] > 0) {
          final d = dmg < bodies[i] ? dmg : bodies[i];
          bodies[i] -= d;
          done += d;
          break;
        }
      }
    }
    return done;
  }

  int _classDamage(int base) {
    var d = _pct(base, effect.percent);
    if (dimmed) {
      d = _pct(d, 50);
      dimmed = false;
    }
    return d;
  }

  /// The hero takes [damage]. Returns what reached their HP.
  int _take(int damage, bool defended, List<CombatEvent> events,
      CombatEventKind kind) {
    var dmg = defended ? _pct(damage, 50) : damage;
    var blocked = 0;
    var answered = -1;
    if (shield > 0) {
      blocked = shield < dmg ? shield : dmg;
      shield -= blocked;
      dmg -= blocked;
      // A Warden standing firm answers every blow the Shield takes.
      if (cls == HeroClass.warden && taunt > 0 && blocked > 0) {
        answered = _hurt(_pct(_pct(attack, _riposte), effect.percent));
      }
    }
    heroHp -= dmg;
    events.add(CombatEvent(kind, amount: dmg, blocked: blocked));
    if (answered >= 0) {
      events.add(CombatEvent(CombatEventKind.riposte, amount: answered));
    }
    return dmg;
  }

  void _hitCompanion(int damage, List<CombatEvent> events) {
    companionHp -= damage;
    events.add(
      CombatEvent(CombatEventKind.enemyHitCompanion, amount: damage),
    );
  }

  /// Plays one turn: the companion's command if [companion] is asked for
  /// and ready, then [action], then the creature's move. Returns what
  /// happened, in order.
  List<CombatEvent> act(CombatAction action, {bool companion = false}) {
    assert(outcome == null, 'the fight is over');
    assert(canDo(action), 'that action is not available');
    final events = <CombatEvent>[];
    var defended = false;
    var skip = false;

    void land(CombatEventKind kind, int base,
        {int roll = 0, bool crit = false, bool all = false, bool pierce = false}) {
      final wasWarded = ward;
      final done = _hurt(base, allBodies: all, pierce: pierce);
      events.add(
        wasWarded && base > 0
            ? const CombatEvent(CombatEventKind.warded)
            : CombatEvent(kind, amount: done, roll: roll, crit: crit),
      );
    }

    if (companion && companionReady) {
      final r = rollD20(seed, turn, 1);
      if (rollLands(r, companionHitChance)) {
        final crit = r >= _critOn;
        final d = crit ? _pct(companionAttack, _critPercent) : companionAttack;
        land(CombatEventKind.companionHit, d, roll: r, crit: crit, pierce: true);
      } else {
        events.add(CombatEvent(CombatEventKind.companionWide, roll: r));
      }
    }

    switch (action) {
      case CombatAction.strike:
        final r = rollD20(seed, turn, 0);
        if (rollLands(r, heroStrikeChance)) {
          final crit = r >= _critOn;
          var d = _classDamage(attack);
          if (crit) d = _pct(d, _critPercent);
          land(CombatEventKind.strikeHit, d,
              roll: r, crit: crit, pierce: cls == HeroClass.sage);
        } else {
          events.add(CombatEvent(CombatEventKind.strikeWide, roll: r));
        }
      case CombatAction.defend:
        defended = true;
        resource = resource + 1 > resourceCap ? resourceCap : resource + 1;
        events.add(const CombatEvent(CombatEventKind.defend));
      case CombatAction.ability:
        switch (cls) {
          case HeroClass.ranger:
            resource -= abilityCost;
            land(CombatEventKind.volley,
                _classDamage(_pct(companionAttack, _volley)),
                all: true);
          case HeroClass.warden:
            resource -= abilityCost;
            final gained = _pct(heroMax, _firm);
            shield += gained;
            taunt = _firmTurns;
            events.add(CombatEvent(CombatEventKind.standFirm, amount: gained));
          case HeroClass.sage:
            final spent = resource;
            resource = 0;
            land(
              CombatEventKind.exploit,
              _classDamage(_pct(attack, _exploitBase + _exploitPer * spent)),
              pierce: true,
            );
            skip = true;
            charging = false;
          case HeroClass.artificer || HeroClass.herald:
            resource -= abilityCost;
            armoured = false;
            trap = _trapTurns;
            events.add(const CombatEvent(CombatEventKind.trapSet));
        }
      case CombatAction.salve:
        items[ItemKind.salve] = count(ItemKind.salve) - 1;
        final before = heroHp;
        final healed = heroHp + _pct(heroMax, _salve);
        heroHp = healed > heroMax ? heroMax : healed;
        events.add(CombatEvent(CombatEventKind.salve, amount: heroHp - before));
      case CombatAction.trap:
        items[ItemKind.trap] = count(ItemKind.trap) - 1;
        armoured = false;
        trap = _trapTurns;
        events.add(const CombatEvent(CombatEventKind.trapSet));
      case CombatAction.bomb:
        items[ItemKind.bomb] = count(ItemKind.bomb) - 1;
        land(CombatEventKind.bomb, _bombBase + _bombPer * _itemLevel, all: true);
      case CombatAction.smoke:
        items[ItemKind.smoke] = count(ItemKind.smoke) - 1;
        skip = true;
        events.add(const CombatEvent(CombatEventKind.smoke));
    }

    // The trap bites before the creature moves.
    if (trap > 0 && enemyHp > 0) {
      land(
        CombatEventKind.trapBite,
        _pct(
          _pct(attack, _trap),
          cls == HeroClass.artificer ? effect.percent : 100,
        ),
        pierce: true,
      );
      trap -= 1;
    }
    if (enemyHp <= 0) {
      outcome = FightOutcome.won;
      return events;
    }

    // ---- The creature's move
    final it = intent;
    final companionWasUp = companionHp > 0;
    if (!skip) {
      final atCompanion =
          (it == EnemyIntent.hitCompanion || it == EnemyIntent.swarmCompanion) &&
              companionHp > 0 &&
              taunt == 0;
      switch (it) {
        case EnemyIntent.hit:
          _take(enemyAttack, defended, events, CombatEventKind.enemyHit);
        case EnemyIntent.hitCompanion:
          if (atCompanion) {
            _hitCompanion(enemyAttack, events);
          } else {
            _take(enemyAttack, defended, events, CombatEventKind.enemyHit);
          }
        case EnemyIntent.charge:
          charging = true;
          events.add(const CombatEvent(CombatEventKind.enemyCharge));
        case EnemyIntent.big:
          _take(_pct(enemyAttack, _big), defended, events,
              CombatEventKind.enemyBig);
          charging = false;
        case EnemyIntent.heavy:
          _take(_pct(enemyAttack, _heavy), defended, events,
              CombatEventKind.enemyHeavy);
        case EnemyIntent.swarm || EnemyIntent.swarmCompanion || EnemyIntent.swarmAll:
          final each =
              _pct(enemyAttack, it == EnemyIntent.swarmAll ? _swarmAll : _swarmHit);
          final up = bodiesUp;
          for (var k = 0; k < up; k++) {
            if (atCompanion && k == 0) {
              _hitCompanion(each, events);
            } else {
              _take(each, defended, events, CombatEventKind.enemySwarm);
            }
          }
        case EnemyIntent.fortify:
          final healed = bodies[0] + _pct(enemyMax, _fortify);
          final before = bodies[0];
          bodies[0] = healed > enemyMax ? enemyMax : healed;
          events.add(
            CombatEvent(CombatEventKind.enemyFortify, amount: bodies[0] - before),
          );
        case EnemyIntent.hex:
          if (!defended && cls != HeroClass.sage) {
            dimmed = true;
            resource = resource > 0 ? resource - 1 : 0;
            events.add(const CombatEvent(CombatEventKind.enemyHex));
          } else {
            events.add(const CombatEvent(CombatEventKind.enemyHexShrugged));
          }
        case EnemyIntent.ward:
          ward = true;
          events.add(const CombatEvent(CombatEventKind.enemyWard));
      }
    } else {
      if (it == EnemyIntent.big) charging = false;
      events.add(const CombatEvent(CombatEventKind.enemyStopped));
    }
    if (companionWasUp && companionHp <= 0) {
      events.add(const CombatEvent(CombatEventKind.companionWinded));
    }
    if (companionHp < 0) companionHp = 0;
    if (taunt > 0) taunt -= 1;
    if (enemyHp <= 0) {
      // A Warden's answering blow can end it.
      outcome = FightOutcome.won;
      return events;
    }
    _step += 1;
    turn += 1;
    if (heroHp <= 0) {
      heroHp = 0;
      outcome = FightOutcome.held;
    } else if (turn > turnLimit) {
      outcome = FightOutcome.held;
    }
    return events;
  }
}
