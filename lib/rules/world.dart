/// The Vale: its regions, the places that wake, and the villagers who come
/// home (DESIGN §3A, §7).
///
/// Restoration is a pure function of the materials gathered so far. The
/// places wake in a fixed order; each asks for some Timber, Stone and Star
/// Shards. Gathered totals only ever grow, so nothing here can un-restore.
library;

import 'day_key.dart';
import 'enums.dart';

class Region {
  const Region(this.key, this.name, this.blurb);
  final String key;
  final String name;
  final String blurb;
}

/// Original place names, drafted for v1 (DESIGN §7).
const List<Region> regions = <Region>[
  Region('hearthmere', 'Hearthmere', 'The village at the valley mouth.'),
  Region('larkdown', 'Larkdown', 'Green hills and long views.'),
  Region('silverrun', 'The Silverrun', 'The river through the heart of the Vale.'),
  Region('highcairn', 'Highcairn', 'The high road and the peaks.'),
  Region('lanternhall', 'Old Lanternhall', 'The ruins where the lanterns were first made.'),
];

Region regionByKey(String key) =>
    regions.firstWhere((r) => r.key == key, orElse: () => regions.first);

/// A villager who returns when their place is restored. Presentation only:
/// a portrait and one warm line (DESIGN §7).
class Villager {
  const Villager({
    required this.key,
    required this.name,
    required this.role,
    required this.icon,
    required this.dawn,
    required this.campfire,
  });
  final String key;
  final String name;
  final String role;
  final String icon;
  final List<String> dawn;
  final String campfire;
}

class RestorationTarget {
  const RestorationTarget({
    required this.key,
    required this.name,
    required this.region,
    required this.timber,
    required this.stone,
    required this.shards,
    required this.wakes,
    this.villager,
  });
  final String key;
  final String name;
  final String region;
  final int timber;
  final int stone;
  final int shards;

  /// One line for the moment it is restored.
  final String wakes;
  final Villager? villager;

  int costOf(MaterialKind kind) => switch (kind) {
        MaterialKind.timber => timber,
        MaterialKind.stone => stone,
        MaterialKind.starShard => shards,
      };

  int get totalCost => timber + stone + shards;
}

/// The drafted places, in the order they wake: four to a region, following
/// the road from the village gate to Old Lanternhall.
const List<RestorationTarget> restorationTargets = <RestorationTarget>[
  RestorationTarget(
    key: 'gate_lantern',
    name: 'The Gate Lantern',
    region: 'hearthmere',
    timber: 2,
    stone: 1,
    shards: 0,
    wakes: 'A warm light at the village gate, and Wick is back at his post.',
    villager: Villager(
      key: 'wick',
      name: 'Wick',
      role: 'Lamplighter',
      icon: 'lantern',
      dawn: <String>[
        'The gate lantern is lit. Come and go as you please; it burns either way.',
        'Morning. I trimmed the wick for you.',
      ],
      campfire: 'I will keep the gate lit tonight. Rest well.',
    ),
  ),
  RestorationTarget(
    key: 'village_well',
    name: 'The Village Well',
    region: 'hearthmere',
    timber: 2,
    stone: 4,
    shards: 1,
    wakes: 'Clear water rises again, and Marla draws the first bucket.',
    villager: Villager(
      key: 'marla',
      name: 'Marla',
      role: 'Well-keeper',
      icon: 'cup',
      dawn: <String>[
        'Fresh water today. Take your time with it.',
        'The bucket came up full of sky this morning.',
      ],
      campfire: 'The well is still and full. So, I hope, are you.',
    ),
  ),
  RestorationTarget(
    key: 'bakehouse',
    name: 'The Bakehouse',
    region: 'hearthmere',
    timber: 5,
    stone: 3,
    shards: 1,
    wakes: 'Smoke from the chimney and the smell of bread across the green.',
    villager: Villager(
      key: 'bryn',
      name: 'Bryn',
      role: 'Baker',
      icon: 'wheat',
      dawn: <String>[
        'First loaves are out. One has your name on it, more or less.',
        'Whatever today holds, start it warm.',
      ],
      campfire: 'I have set tomorrow’s dough to rise. No hurry on your side.',
    ),
  ),
  RestorationTarget(
    key: 'moot_hall',
    name: 'The Moot Hall',
    region: 'hearthmere',
    timber: 6,
    stone: 6,
    shards: 2,
    wakes: 'The doors stand open and the banners are out.',
    villager: Villager(
      key: 'tamsin',
      name: 'Tamsin',
      role: 'Elder',
      icon: 'scroll',
      dawn: <String>[
        'The hall is open. Nobody is keeping count in there, I promise.',
        'One thing done well is a fine day’s work.',
      ],
      campfire: 'I have seen a good many evenings. This one will do nicely.',
    ),
  ),
  RestorationTarget(
    key: 'sheepfold',
    name: 'The Sheepfold',
    region: 'larkdown',
    timber: 7,
    stone: 4,
    shards: 2,
    wakes: 'Walls mended, gate swinging, and a few curious sheep.',
    villager: Villager(
      key: 'hob',
      name: 'Hob',
      role: 'Shepherd',
      icon: 'leaf',
      dawn: <String>[
        'The flock is out early. They go at their own pace and get there.',
        'Good walking weather on the hill today.',
      ],
      campfire: 'All counted and all in. Goodnight.',
    ),
  ),
  RestorationTarget(
    key: 'larkdown_mill',
    name: 'Larkdown Mill',
    region: 'larkdown',
    timber: 9,
    stone: 6,
    shards: 2,
    wakes: 'The sails turn again in the hill wind.',
    villager: Villager(
      key: 'anwen',
      name: 'Anwen',
      role: 'Miller',
      icon: 'mill',
      dawn: <String>[
        'Wind is up. The mill turns whether we watch it or not.',
        'A little grain at a time fills the sack.',
      ],
      campfire: 'The sails are tied down for the night. Sleep easy.',
    ),
  ),
  RestorationTarget(
    key: 'hill_beacon',
    name: 'The Hill Beacon',
    region: 'larkdown',
    timber: 6,
    stone: 8,
    shards: 3,
    wakes: 'A steady flame on the hilltop, seen from every road.',
    villager: Villager(
      key: 'corin',
      name: 'Corin',
      role: 'Beacon-keeper',
      icon: 'campfire',
      dawn: <String>[
        'I could see your camp from up here. Looked cosy.',
        'The beacon is lit, so you can always find the way back.',
      ],
      campfire: 'I will keep the flame. You keep warm.',
    ),
  ),
  RestorationTarget(
    key: 'orchard',
    name: 'The Orchard',
    region: 'larkdown',
    timber: 8,
    stone: 8,
    shards: 3,
    wakes: 'Blossom on the old trees, and baskets set out underneath.',
    villager: Villager(
      key: 'pell',
      name: 'Pell',
      role: 'Orchard-keeper',
      icon: 'sprig',
      dawn: <String>[
        'Trees do not rush, and look at them.',
        'I saved you the first good apple.',
      ],
      campfire: 'The orchard is quiet. A good sort of quiet.',
    ),
  ),
  RestorationTarget(
    key: 'heron_bridge',
    name: 'Heron Footbridge',
    region: 'silverrun',
    timber: 12,
    stone: 6,
    shards: 3,
    wakes: 'New planks over bright water.',
    villager: Villager(
      key: 'ness',
      name: 'Ness',
      role: 'Bridge-warden',
      icon: 'bridge',
      dawn: <String>[
        'The bridge is sound. Cross when you are ready.',
        'The heron was here before either of us this morning.',
      ],
      campfire: 'The river carries the day off downstream. Let it.',
    ),
  ),
  RestorationTarget(
    key: 'wheelhouse',
    name: 'The Wheelhouse',
    region: 'silverrun',
    timber: 10,
    stone: 10,
    shards: 4,
    wakes: 'The great wheel turns and the river sings through it.',
    villager: Villager(
      key: 'dunstan',
      name: 'Dunstan',
      role: 'Wheelwright',
      icon: 'compass',
      dawn: <String>[
        'A wheel only ever turns one notch at a time.',
        'Listen. That hum is the whole valley working.',
      ],
      campfire: 'I have let the sluice down. The wheel can rest, and so can you.',
    ),
  ),
  RestorationTarget(
    key: 'boathouse',
    name: 'The Boathouse',
    region: 'silverrun',
    timber: 12,
    stone: 8,
    shards: 5,
    wakes: 'Boats on the water, painted in every colour.',
    villager: Villager(
      key: 'mira',
      name: 'Mira',
      role: 'Boatwright',
      icon: 'brush',
      dawn: <String>[
        'I am painting the blue one today. What are you making?',
        'Fair water this morning.',
      ],
      campfire: 'Boats are in. Paint is drying. A good day.',
    ),
  ),
  RestorationTarget(
    key: 'ford_bell',
    name: 'The Ford Bell',
    region: 'silverrun',
    timber: 8,
    stone: 12,
    shards: 5,
    wakes: 'One clear note rolls down the river.',
    villager: Villager(
      key: 'fenn',
      name: 'Fenn',
      role: 'Bell-ringer',
      icon: 'bell',
      dawn: <String>[
        'I rang it once for morning. The rest of the day is yours.',
        'A bell does not mind when it is rung.',
      ],
      campfire: 'One soft note for evening. There.',
    ),
  ),
  RestorationTarget(
    key: 'waystation',
    name: 'The Waystation',
    region: 'highcairn',
    timber: 14,
    stone: 12,
    shards: 5,
    wakes: 'A lit window on the high road and a kettle on.',
    villager: Villager(
      key: 'greta',
      name: 'Greta',
      role: 'Road-warden',
      icon: 'home',
      dawn: <String>[
        'Kettle is on. The pass will keep until you have had a cup.',
        'High roads are walked in short stretches. Everyone does it that way.',
      ],
      campfire: 'There is a bunk made up, should you ever want it.',
    ),
  ),
  RestorationTarget(
    key: 'ropeway',
    name: 'The Ropeway',
    region: 'highcairn',
    timber: 16,
    stone: 10,
    shards: 6,
    wakes: 'Baskets glide between the crags again.',
    villager: Villager(
      key: 'tobin',
      name: 'Tobin',
      role: 'Rigger',
      icon: 'mountain',
      dawn: <String>[
        'Checked every knot twice. Go steady and enjoy the view.',
        'Up here you can see how far the colour has spread.',
      ],
      campfire: 'Baskets are tied off. Nothing more needs carrying tonight.',
    ),
  ),
  RestorationTarget(
    key: 'star_loft',
    name: 'The Star Loft',
    region: 'highcairn',
    timber: 10,
    stone: 16,
    shards: 8,
    wakes: 'The roof slides open and the brass telescope turns.',
    villager: Villager(
      key: 'edda',
      name: 'Edda',
      role: 'Stargazer',
      icon: 'moon',
      dawn: <String>[
        'The stars kept their places overnight. They always do.',
        'I named a small star after your companion. I hope that is all right.',
      ],
      campfire: 'Clear sky tonight. Look up once before you sleep.',
    ),
  ),
  RestorationTarget(
    key: 'summit_cairn',
    name: 'The Summit Cairn',
    region: 'highcairn',
    timber: 8,
    stone: 20,
    shards: 8,
    wakes: 'Stone on stone, the cairn stands tall above the cloud.',
    villager: Villager(
      key: 'orrin',
      name: 'Orrin',
      role: 'Cairn-builder',
      icon: 'stone',
      dawn: <String>[
        'Every traveller adds one stone. That is how it got this tall.',
        'Thin air, wide view. Take both slowly.',
      ],
      campfire: 'I put a stone on for you today.',
    ),
  ),
  RestorationTarget(
    key: 'great_arch',
    name: 'The Great Arch',
    region: 'lanternhall',
    timber: 12,
    stone: 22,
    shards: 9,
    wakes: 'The old arch stands, and the road runs under it.',
    villager: Villager(
      key: 'hal',
      name: 'Hal',
      role: 'Mason',
      icon: 'arch',
      dawn: <String>[
        'An arch is just patient stones leaning on each other.',
        'Mortar is setting nicely. Good things take the time they take.',
      ],
      campfire: 'Tools are down. The arch will hold till morning and long after.',
    ),
  ),
  RestorationTarget(
    key: 'reading_room',
    name: 'The Reading Room',
    region: 'lanternhall',
    timber: 18,
    stone: 16,
    shards: 10,
    wakes: 'Shelves righted, pages dried, a lamp on every desk.',
    villager: Villager(
      key: 'quill',
      name: 'Quill',
      role: 'Archivist',
      icon: 'book',
      dawn: <String>[
        'I found your chapter in the valley’s book. It reads well.',
        'A page a day is still a whole book in the end.',
      ],
      campfire: 'I have marked today’s page with a ribbon.',
    ),
  ),
  RestorationTarget(
    key: 'glasshouse',
    name: 'The Glasshouse',
    region: 'lanternhall',
    timber: 16,
    stone: 14,
    shards: 14,
    wakes: 'Green things press against clear new panes.',
    villager: Villager(
      key: 'sorrel',
      name: 'Sorrel',
      role: 'Gardener',
      icon: 'leaf',
      dawn: <String>[
        'Something new came up overnight. It usually does.',
        'Water, light and time. That is the whole trick.',
      ],
      campfire: 'The seedlings are tucked in. Goodnight to you both.',
    ),
  ),
  RestorationTarget(
    key: 'lanternhall',
    name: 'The Lanternhall',
    region: 'lanternhall',
    timber: 22,
    stone: 22,
    shards: 18,
    wakes: 'Every lantern in the hall is lit. The Vale is awake.',
    villager: Villager(
      key: 'maren',
      name: 'Maren',
      role: 'Keeper of the Hall',
      icon: 'star',
      dawn: <String>[
        'Every one of these was lit by something you did.',
        'The hall is bright. Stay as long as you like.',
      ],
      campfire: 'I will bank the lanterns low. They will be here tomorrow.',
    ),
  ),
];

/// Cost of each further lantern once every drafted place is awake. The Vale
/// never runs out of things to light (DECISIONS.md D-33).
const int valeLanternCost = 10;

/// The [index]th place to wake (zero-based). Past the drafted list, each
/// further target is one more lantern along the Vale.
RestorationTarget targetAt(int index) {
  if (index >= 0 && index < restorationTargets.length) {
    return restorationTargets[index];
  }
  final n = index - restorationTargets.length + 1;
  return RestorationTarget(
    key: 'vale_lantern_$n',
    name: 'Vale Lantern $n',
    region: regions[(n - 1) % regions.length].key,
    timber: valeLanternCost,
    stone: valeLanternCost,
    shards: valeLanternCost,
    wakes: 'One more lantern is lit along the road.',
  );
}

int _count(Map<MaterialKind, int> m, MaterialKind k) => m[k] ?? 0;

/// How many places the [gathered] materials have restored.
int restoredCount(Map<MaterialKind, int> gathered) {
  var timber = _count(gathered, MaterialKind.timber);
  var stone = _count(gathered, MaterialKind.stone);
  var shards = _count(gathered, MaterialKind.starShard);
  var n = 0;
  // Bounded: every target past the drafted list costs something.
  while (n < 100000) {
    final t = targetAt(n);
    if (timber < t.timber || stone < t.stone || shards < t.shards) break;
    timber -= t.timber;
    stone -= t.stone;
    shards -= t.shards;
    n++;
  }
  return n;
}

/// Materials put into the first [count] places.
Map<MaterialKind, int> materialsSpentOn(int count) {
  var timber = 0;
  var stone = 0;
  var shards = 0;
  for (var i = 0; i < count; i++) {
    final t = targetAt(i);
    timber += t.timber;
    stone += t.stone;
    shards += t.shards;
  }
  return <MaterialKind, int>{
    MaterialKind.timber: timber,
    MaterialKind.stone: stone,
    MaterialKind.starShard: shards,
  };
}

/// Restoration points: every material that has gone into a restored place.
int restorationPointsFor(int count) {
  final spent = materialsSpentOn(count);
  return spent.values.fold(0, (sum, v) => sum + v);
}

/// What is in the stores: gathered materials not yet built into anything.
Map<MaterialKind, int> inStores(Map<MaterialKind, int> gathered) {
  final spent = materialsSpentOn(restoredCount(gathered));
  return <MaterialKind, int>{
    for (final k in MaterialKind.values)
      k: _count(gathered, k) - _count(spent, k),
  };
}

/// The place being worked toward now.
RestorationTarget currentTarget(Map<MaterialKind, int> gathered) =>
    targetAt(restoredCount(gathered));

/// The first material the current target still needs. There is always one:
/// a target with everything it needs is already restored.
MaterialKind stillNeeded(Map<MaterialKind, int> gathered) {
  final target = currentTarget(gathered);
  final stores = inStores(gathered);
  for (final k in MaterialKind.values) {
    if (_count(stores, k) < target.costOf(k)) return k;
  }
  return MaterialKind.timber;
}

/// 0..1: how far along the current target is, across all its materials.
double targetProgress(Map<MaterialKind, int> gathered) {
  final target = currentTarget(gathered);
  if (target.totalCost == 0) return 1;
  final stores = inStores(gathered);
  var have = 0;
  for (final k in MaterialKind.values) {
    final need = target.costOf(k);
    final got = _count(stores, k);
    have += got > need ? need : got;
  }
  return have / target.totalCost;
}

/// Drafted places in [regionKey], in waking order.
List<RestorationTarget> targetsIn(String regionKey) => <RestorationTarget>[
      for (final t in restorationTargets)
        if (t.region == regionKey) t,
    ];

/// 0..1: how awake a region is, by its drafted places restored.
double regionWake(String regionKey, int restored) {
  var total = 0;
  var awake = 0;
  for (var i = 0; i < restorationTargets.length; i++) {
    if (restorationTargets[i].region != regionKey) continue;
    total++;
    if (i < restored) awake++;
  }
  return total == 0 ? 0 : awake / total;
}

/// 0..1 for the whole Vale.
double valeWake(int restored) {
  final n = restorationTargets.length;
  return restored >= n ? 1 : restored / n;
}

/// Villagers who have come home, in the order they returned.
List<Villager> villagersReturned(int restored) => <Villager>[
      for (var i = 0; i < restorationTargets.length && i < restored; i++)
        if (restorationTargets[i].villager != null)
          restorationTargets[i].villager!,
    ];

/// A villager and one line of theirs.
class VillagerLine {
  const VillagerLine(this.villager, this.line);
  final Villager villager;
  final String line;
}

int _dayIndex(String day) {
  final i = DayKey.daysBetween('2026-01-01', day);
  return i < 0 ? -i : i;
}

/// The villager who greets the Dawn board on [day], or null before anyone
/// has come home. Rotates by calendar day, so it is the same all day.
VillagerLine? dawnVillager(int restored, String day) {
  final home = villagersReturned(restored);
  if (home.isEmpty) return null;
  final i = _dayIndex(day);
  final v = home[i % home.length];
  return VillagerLine(v, v.dawn[(i ~/ home.length) % v.dawn.length]);
}

/// The villager who says goodnight at the Campfire on [day].
VillagerLine? campfireVillager(int restored, String day) {
  final home = villagersReturned(restored);
  if (home.isEmpty) return null;
  final v = home[(_dayIndex(day) + 1) % home.length];
  return VillagerLine(v, v.campfire);
}

/// Zero-based index of the place stored under [key], or -1.
int targetIndexByKey(String key) {
  for (var i = 0; i < restorationTargets.length; i++) {
    if (restorationTargets[i].key == key) return i;
  }
  const prefix = 'vale_lantern_';
  if (key.startsWith(prefix)) {
    final n = int.tryParse(key.substring(prefix.length));
    if (n != null && n > 0) return restorationTargets.length + n - 1;
  }
  return -1;
}
