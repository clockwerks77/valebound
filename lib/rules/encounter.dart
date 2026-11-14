/// The day's encounter and the weekly boss (Amendment v0.3 §§3-5): which
/// creature holds the road today, what the scout says about it, what a win
/// brings home, and what is written down either way.
library;

import 'dart:convert';

import 'classes.dart';
import 'combat.dart';
import 'day_key.dart';
import 'enums.dart';

/// One of the Still as it is met in a fight.
class EnemyTemplate {
  const EnemyTemplate(this.key, this.name, this.type, this.art, this.line);

  final String key;

  /// As it reads after "a" or "the": "Fogfinch", "drift of Mistlings".
  final String name;
  final EnemyType type;

  /// Key of the Still creature whose picture it wears.
  final String art;

  /// How it is found, in a line.
  final String line;
}

/// Two to a type (Amendment v0.3 §7), in the order the days meet them, so
/// no two days running are the same type.
const List<EnemyTemplate> enemyTemplates = <EnemyTemplate>[
  EnemyTemplate('fogfinch', 'Fogfinch', EnemyType.swift, 'fogfinch',
      'It flits from post to post and will not be still.'),
  EnemyTemplate('yawnstone', 'Yawnstone', EnemyType.armoured, 'yawnstone',
      'It has settled across the road like a boulder.'),
  EnemyTemplate('great_drowsel', 'Great Drowsel', EnemyType.brute, 'drowsel',
      'It is very large, very slow, and rolling over.'),
  EnemyTemplate('mistlings', 'drift of Mistlings', EnemyType.swarm,
      'mistling', 'Three of them, tumbling over one another.'),
  EnemyTemplate('dozewisp', 'Dozewisp', EnemyType.arcane, 'dozewisp',
      'Its glow comes and goes, and so does the road.'),
  EnemyTemplate('hushmoth', 'Hushmoth', EnemyType.swift, 'hushmoth',
      'Dust falls from its wings and the air goes quiet.'),
  EnemyTemplate('burrowed_drowsel', 'Burrowed Drowsel', EnemyType.armoured,
      'drowsel', 'It has dug in under a crust of old leaves.'),
  EnemyTemplate('old_yawnstone', 'Old Yawnstone', EnemyType.brute,
      'yawnstone', 'It rocks back, slowly, before it rolls.'),
  EnemyTemplate('hushmoths', 'flutter of Hushmoths', EnemyType.swarm,
      'hushmoth', 'Three of them, circling the same lantern.'),
  EnemyTemplate('lantern_mistling', 'Lantern-eyed Mistling', EnemyType.arcane,
      'mistling', 'It looks at you, and you forget what you came for.'),
];

/// "a Fogfinch", "an Old Yawnstone": [name] with the article it takes.
String withArticle(String name, {bool capital = false}) {
  final vowel = name.isNotEmpty && 'aeiouAEIOU'.contains(name[0]);
  final article = vowel ? 'an' : 'a';
  return '${capital ? article[0].toUpperCase() + article.substring(1) : article} $name';
}

int _dayIndex(String day) => DayKey.daysBetween('2026-01-01', day);

/// The creature holding the road on [day]. A day always has the same one.
EnemyTemplate enemyFor(String day) {
  final n = enemyTemplates.length;
  final i = _dayIndex(day) % n;
  return enemyTemplates[i < 0 ? i + n : i];
}

EnemyTemplate? enemyByKey(String? key) {
  for (final e in enemyTemplates) {
    if (e.key == key) return e;
  }
  return null;
}

/// The seed for every roll in [day]'s fights. The same on every attempt, so
/// trying again is a matter of choosing differently (Amendment v0.3 §3).
int encounterSeed(String day) =>
    (_dayIndex(day) * 2654435761 + 0x5EED) & 0xFFFFFFFF;

/// The seed for the boss attempt of the week ending on [delveDay].
int bossSeed(String delveDay) =>
    (_dayIndex(delveDay) * 2246822519 + 0xB055) & 0xFFFFFFFF;

/// The scout's line: the matchup in words, so the player knows why a fight
/// is hard and what else to reach for (Amendment v0.3 §4).
String scoutLine(HeroClass cls, EnemyType type) {
  const lines = <EnemyType, Map<HeroClass, String>>{
    EnemyType.swift: <HeroClass, String>{
      HeroClass.ranger:
          'Your companion tracks it: your blows cannot be dodged.',
      HeroClass.warden:
          'Your heavy swings will often go wide. Stand Firm and let it '
              'come to your Shield.',
      HeroClass.sage: 'It dodges a plain strike, but Exploit always lands.',
      HeroClass.artificer: 'It cannot dodge a trap, or you.',
    },
    EnemyType.armoured: <HeroClass, String>{
      HeroClass.ranger:
          'Your Volley will struggle. Your companion and a trap will not.',
      HeroClass.warden: 'An even match. Outlast it.',
      HeroClass.sage: 'An even match: your blows pass through its hide.',
      HeroClass.artificer: 'Your trap breaks its hide open.',
    },
    EnemyType.brute: <HeroClass, String>{
      HeroClass.ranger:
          'An even match. Watch for the wind-up and Defend the big blow.',
      HeroClass.warden: 'Let the big blow break on your Shield.',
      HeroClass.sage: 'Save your Insight and stun it on the big blow.',
      HeroClass.artificer: 'An even match. Defend the big blow.',
    },
    EnemyType.swarm: <HeroClass, String>{
      HeroClass.ranger: 'A Volley hits every one of them.',
      HeroClass.warden:
          'Many small blows wear a Shield down fast. Thin them out.',
      HeroClass.sage: 'An even match, one at a time.',
      HeroClass.artificer: 'A Bomb hits every one of them.',
    },
    EnemyType.arcane: <HeroClass, String>{
      HeroClass.ranger:
          'An even match, but you cannot always read it. Let your '
              'companion break a ward.',
      HeroClass.warden: 'An even match, but its tricks are veiled to you.',
      HeroClass.sage: 'You read every trick, and its hexes slide off you.',
      HeroClass.artificer:
          'It muddles your devices. Lean on your companion and Defend.',
    },
  };
  return lines[type]![cls] ?? 'An even match.';
}

/// What every class is told about a type: one weakness and one resistance
/// in plain words (Amendment v0.3 §3).
String weaknessOf(EnemyType type) => switch (type) {
      EnemyType.swift => 'Weak to traps and to anything that cannot be '
          'dodged. Plain strikes often go wide.',
      EnemyType.armoured => 'Weak to a trap, which breaks its hide. Its '
          'hide blunts strikes and bombs until then.',
      EnemyType.brute => 'Weak on the turn of its big blow: Defend, smoke '
          'or stun it then. Shrugs off being rushed.',
      EnemyType.swarm => 'Weak to blows that hit them all. One at a time '
          'is slow.',
      EnemyType.arcane => 'Weak once its ward is broken by a small blow. '
          'Its hex halves your next strike unless you Defend.',
    };

/// Standard or the harder fight for half as much again (Amendment v0.3 §6).
int heroicBonus(int amount, {required bool heroic}) =>
    heroic ? (amount * 3) ~/ 2 : amount;

const int chestGold = 8;
const int chestMaterials = 2;
const int chestXp = 10;
const int marksCap = 9;
const int advantageCost = 3;

/// The consumable in [day]'s chest. They take turns.
ItemKind chestItemFor(String day) {
  const order = <ItemKind>[
    ItemKind.salve,
    ItemKind.smoke,
    ItemKind.trap,
    ItemKind.bomb,
  ];
  final i = _dayIndex(day) % order.length;
  return order[i < 0 ? i + order.length : i];
}

/// What the Artificer's Craft quests stock, in turn by how many they have
/// finished.
ItemKind artificerStock(int craftQuestsDone) {
  const order = <ItemKind>[ItemKind.trap, ItemKind.salve, ItemKind.bomb];
  return order[craftQuestsDone % order.length];
}

/// The most of one consumable the pouch holds.
const int pouchCap = 5;

/// What a won encounter brought home.
class Chest {
  const Chest({
    required this.gold,
    required this.material,
    required this.materials,
    required this.item,
    required this.xp,
  });

  final int gold;
  final MaterialKind material;
  final int materials;
  final ItemKind item;

  /// Bonus XP, to hero and companion alike.
  final int xp;

  Map<String, Object> toJson() => <String, Object>{
        'gold': gold,
        'material': material.name,
        'materials': materials,
        'item': item.name,
        'xp': xp,
      };

  static Chest? fromJson(Object? json) {
    if (json is! Map) return null;
    MaterialKind? material;
    for (final m in MaterialKind.values) {
      if (m.name == json['material']) material = m;
    }
    ItemKind? item;
    for (final k in ItemKind.values) {
      if (k.name == json['item']) item = k;
    }
    final gold = json['gold'];
    final materials = json['materials'];
    final xp = json['xp'];
    if (material == null ||
        item == null ||
        gold is! int ||
        materials is! int ||
        xp is! int) {
      return null;
    }
    return Chest(
      gold: gold,
      material: material,
      materials: materials,
      item: item,
      xp: xp,
    );
  }
}

Chest chestFor(String day, MaterialKind needed, {required bool heroic}) =>
    Chest(
      gold: heroicBonus(chestGold, heroic: heroic),
      material: needed,
      materials: heroicBonus(chestMaterials, heroic: heroic),
      item: chestItemFor(day),
      xp: heroicBonus(chestXp, heroic: heroic),
    );

/// How a day's encounter stands once it has been fought. Kept with the
/// day, so a later export of that day is exact.
class EncounterRecord {
  const EncounterRecord({
    required this.enemyKey,
    required this.heroic,
    required this.won,
    required this.attempts,
    required this.turns,
    required this.classId,
    this.retryReady = false,
    this.chest,
  });

  final String enemyKey;
  final bool heroic;

  /// False while the creature still holds the road.
  final bool won;
  final int attempts;

  /// Turns the last attempt took.
  final int turns;

  /// The class it was last fought as.
  final String classId;

  /// A quest has been finished since the creature held: another try is
  /// open (Amendment v0.3 §5).
  final bool retryReady;
  final Chest? chest;

  EnemyTemplate? get enemy => enemyByKey(enemyKey);

  EncounterRecord copyWith({bool? retryReady}) => EncounterRecord(
        enemyKey: enemyKey,
        heroic: heroic,
        won: won,
        attempts: attempts,
        turns: turns,
        classId: classId,
        retryReady: retryReady ?? this.retryReady,
        chest: chest,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'enemy': enemyKey,
        'heroic': heroic,
        'won': won,
        'attempts': attempts,
        'turns': turns,
        'cls': classId,
        'retry': retryReady,
        if (chest != null) 'chest': chest!.toJson(),
      };

  static EncounterRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final enemy = json['enemy'];
    final cls = json['cls'];
    if (enemy is! String || cls is! String) return null;
    return EncounterRecord(
      enemyKey: enemy,
      heroic: json['heroic'] == true,
      won: json['won'] == true,
      attempts: json['attempts'] is int ? json['attempts'] as int : 1,
      turns: json['turns'] is int ? json['turns'] as int : 0,
      classId: cls,
      retryReady: json['retry'] == true,
      chest: Chest.fromJson(json['chest']),
    );
  }
}

/// Reads a record as it is stored with the day. Null for none, or for one
/// that cannot be read.
EncounterRecord? decodeEncounter(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    return EncounterRecord.fromJson(jsonDecode(json));
  } on FormatException {
    return null;
  }
}

/// Where the day's encounter stands, for the board.
enum EncounterStatus {
  /// Not fought yet today.
  ready,
  won,

  /// The creature held; finishing any quest opens another try.
  holding,

  /// The creature held and another try is open.
  retry,
}

EncounterStatus statusOf(EncounterRecord? record) {
  if (record == null) return EncounterStatus.ready;
  if (record.won) return EncounterStatus.won;
  return record.retryReady ? EncounterStatus.retry : EncounterStatus.holding;
}

// ---- The weekly boss ------------------------------------------------------

/// The heart of the stillness in one region: the weekly Delve's fight.
class BossTemplate {
  const BossTemplate(this.key, this.name, this.region, this.type, this.title,
      this.line);

  final String key;
  final String name;

  /// Key of the region it sleeps under.
  final String region;
  final EnemyType type;

  /// The title its waking earns.
  final String title;
  final String line;
}

const List<BossTemplate> bosses = <BossTemplate>[
  BossTemplate('long_doze', 'The Long Doze', 'hearthmere', EnemyType.brute,
      'Waker of Hearthmere',
      'Under the village green something vast breathes in, and out.'),
  BossTemplate('becalmer', 'The Becalmer', 'larkdown', EnemyType.swift,
      'Windbringer of Larkdown',
      'It moves like a breeze that has forgotten where it was going.'),
  BossTemplate('glassmere', 'The Glassmere', 'silverrun', EnemyType.arcane,
      'Ripple-Maker of the Silverrun',
      'The river is so flat here that it shows a sky from another day.'),
  BossTemplate('deep_drift', 'The Deep Drift', 'highcairn',
      EnemyType.armoured, 'Thaw of Highcairn',
      'Snow that has not moved in years, with something asleep inside.'),
  BossTemplate('last_hush', 'The Last Hush', 'lanternhall', EnemyType.arcane,
      'Voice of Old Lanternhall',
      'In the great hall the quiet is so deep it has a shape.'),
];

/// How a boss attempt is written in the week's Delve record.
const String bossTierWoken = 'won';
const String bossTierHeld = 'held';

const int bossGold = 60;
const int bossEachMaterial = 6;

/// The boss campaign as it stands: which one, what it has left, the Marks
/// in hand and the titles won. Kept as one small record.
class BossState {
  const BossState({
    this.index = 0,
    this.hpLeft,
    this.marks = 0,
    this.woken = const <String>[],
  });

  /// How many bosses have been woken; the next one is `index % 5`.
  final int index;

  /// What the current boss has left after earlier attempts; null when it
  /// has not been met yet.
  final int? hpLeft;
  final int marks;

  /// Keys of the bosses woken, oldest first.
  final List<String> woken;

  BossTemplate get boss => bosses[index % bosses.length];

  /// The titles earned from bosses, oldest first.
  List<String> get titles => <String>[
        for (final key in woken)
          for (final b in bosses)
            if (b.key == key) b.title,
      ];

  bool get canBuyAdvantage => marks >= advantageCost;

  BossState withMark() =>
      _copy(marks: marks + 1 > marksCap ? marksCap : marks + 1);

  /// After an attempt that left the boss with [left] HP, having spent
  /// Marks or not. At zero it wakes, and the next one waits.
  BossState afterAttempt({required int left, required bool spentMarks}) {
    final m = spentMarks ? marks - advantageCost : marks;
    if (left <= 0) {
      return BossState(
        index: index + 1,
        marks: m < 0 ? 0 : m,
        woken: <String>[
          ...woken,
          if (!woken.contains(boss.key)) boss.key,
        ],
      );
    }
    return BossState(
      index: index,
      hpLeft: left,
      marks: m < 0 ? 0 : m,
      woken: woken,
    );
  }

  BossState _copy({int? marks}) => BossState(
        index: index,
        hpLeft: hpLeft,
        marks: marks ?? this.marks,
        woken: woken,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'index': index,
        'hp': hpLeft,
        'marks': marks,
        'woken': woken,
      };

  static BossState fromJson(Object? json) {
    if (json is! Map) return const BossState();
    final woken = json['woken'];
    return BossState(
      index: json['index'] is int ? json['index'] as int : 0,
      hpLeft: json['hp'] is int ? json['hp'] as int : null,
      marks: json['marks'] is int ? json['marks'] as int : 0,
      woken: woken is List
          ? <String>[for (final k in woken) if (k is String) k]
          : const <String>[],
    );
  }
}
