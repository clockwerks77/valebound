/// The Journey road, DESIGN §7A.4.
///
/// Companion and shared quests earn Paces. Every 10 Paces is a Discovery.
/// Discoveries queue in order and nothing is ever missable.
library;

const int pacesPerDiscovery = 10;

/// Number of Discoveries earned by [totalPaces].
int discoveriesEarned(int totalPaces) =>
    totalPaces <= 0 ? 0 : totalPaces ~/ pacesPerDiscovery;

/// Zero-based indexes of the Discoveries unlocked by moving from
/// [pacesBefore] to [pacesAfter]. Usually empty or one entry.
List<int> newDiscoveries(int pacesBefore, int pacesAfter) {
  final before = discoveriesEarned(pacesBefore);
  final after = discoveriesEarned(pacesAfter);
  return <int>[for (var i = before; i < after; i++) i];
}

/// Paces still to walk before the next Discovery (1..10).
int pacesToNextDiscovery(int totalPaces) {
  final into = totalPaces <= 0 ? 0 : totalPaces % pacesPerDiscovery;
  return pacesPerDiscovery - into;
}

/// Paces walked since the last Discovery (0..9).
int pacesIntoStretch(int totalPaces) =>
    totalPaces <= 0 ? 0 : totalPaces % pacesPerDiscovery;

/// Camp position is the road distance walked: simply total Paces.
int campPosition(int totalPaces) => totalPaces < 0 ? 0 : totalPaces;

/// Paces from the village gate to Old Lanternhall: the road drawn on the
/// map. Five regions of 40 Paces each, so four Discoveries to a region.
const int roadPaces = 200;
const int pacesPerRegion = 40;

/// Index (0..4) of the region the camp is in after [totalPaces].
int regionIndexForPaces(int totalPaces) {
  if (totalPaces <= 0) return 0;
  final i = totalPaces ~/ pacesPerRegion;
  return i > 4 ? 4 : i;
}

/// 0..1 along the drawn road. Past its end the camp rests at Old Lanternhall
/// while the Paces and waymarkers carry on counting.
double roadFraction(int totalPaces) {
  if (totalPaces <= 0) return 0;
  if (totalPaces >= roadPaces) return 1;
  return totalPaces / roadPaces;
}

class DiscoveryScene {
  const DiscoveryScene(this.key, this.title, this.line, this.hint);
  final String key;
  final String title;
  final String line;

  /// What Scout shows before the scene is reached: a shape, not a name.
  final String hint;
}

/// Twenty original roadside scenes, four to a region (DESIGN asks for ~12;
/// the road on the map is 200 Paces long, see DECISIONS.md D-32).
const List<DiscoveryScene> discoveryScenes = <DiscoveryScene>[
  // Hearthmere
  DiscoveryScene(
    'standing_stone',
    'The Listening Stone',
    'A tall grey stone, warm on one side, as if it had been waiting.',
    'Something tall and patient',
  ),
  DiscoveryScene(
    'hot_spring',
    'Kettle Spring',
    'Steam rises from a ring of mossy rocks. The water is exactly right.',
    'A curl of steam',
  ),
  DiscoveryScene(
    'merchant_cart',
    'The Quiet Cart',
    'A travelling merchant’s cart, wheels deep in clover, bells still on.',
    'A shape with wheels',
  ),
  DiscoveryScene(
    'lantern_tree',
    'The Lantern Oak',
    'Someone hung glass lanterns in this oak long ago. One still glows.',
    'A glimmer in the branches',
  ),
  // Larkdown
  DiscoveryScene(
    'beehive_wall',
    'The Honey Wall',
    'An old field wall, and a drowsy hum from somewhere inside it.',
    'A low, drowsy hum',
  ),
  DiscoveryScene(
    'wind_chimes',
    'Chime Hollow',
    'A dip in the hills where the wind plays a tune on hanging shells.',
    'A tune on the wind',
  ),
  DiscoveryScene(
    'shepherd_hut',
    'The Shepherd’s Rest',
    'A round hut with a turf roof. The kettle hook is polished smooth.',
    'A round roof',
  ),
  DiscoveryScene(
    'mile_marker',
    'The Painted Milestone',
    'A waymarker in faded blue, pointing to a village you have yet to wake.',
    'A flash of blue',
  ),
  // The Silverrun
  DiscoveryScene(
    'stepping_stones',
    'Heron Crossing',
    'Flat stones across the river, each one carved with a small bird.',
    'Stones in the water',
  ),
  DiscoveryScene(
    'reed_flute',
    'The Whistling Reeds',
    'A stand of river reeds that plays three notes when the wind turns.',
    'A thin tune by the water',
  ),
  DiscoveryScene(
    'star_pool',
    'The Star Pool',
    'A still pool that shows the night sky, even at noon.',
    'A glint of still water',
  ),
  DiscoveryScene(
    'otter_slide',
    'The Otter Slide',
    'A smooth groove in the bank, well used and still wet.',
    'A splash, then quiet',
  ),
  // Highcairn
  DiscoveryScene(
    'cloud_bench',
    'The Cloud Bench',
    'A stone bench on the pass, set to face the whole valley.',
    'A seat with a view',
  ),
  DiscoveryScene(
    'watchtower',
    'Swallow Tower',
    'A broken watchtower, home now to a hundred swallows.',
    'A tower against the sky',
  ),
  DiscoveryScene(
    'echo_stone',
    'The Answering Rock',
    'Say good morning here and the mountain says it straight back, kindly.',
    'A voice in the rocks',
  ),
  DiscoveryScene(
    'snowbell',
    'Snowbell Meadow',
    'White flowers ring a patch of old snow, nodding as you pass.',
    'Something white among the green',
  ),
  // Old Lanternhall
  DiscoveryScene(
    'garden_gate',
    'The Open Gate',
    'A garden gate standing by itself in a meadow, kindly left ajar.',
    'A gate with no wall',
  ),
  DiscoveryScene(
    'sundial',
    'The Sundial Court',
    'A courtyard sundial, its shadow resting exactly on now.',
    'A shadow that keeps time',
  ),
  DiscoveryScene(
    'glass_stair',
    'The Glass Stair',
    'Seven steps of old lantern glass, each a different colour.',
    'Colour on the ground',
  ),
  DiscoveryScene(
    'first_lantern',
    'The First Lantern',
    'Small, plain and unlit for an age. It kindles as you come near.',
    'A small dark shape on a plinth',
  ),
];

/// The scene for the [index]th Discovery. Past the drafted list the road
/// still marks each tenth Pace with a plain waymarker (DECISIONS.md D-18).
DiscoveryScene sceneFor(int index) {
  if (index >= 0 && index < discoveryScenes.length) {
    return discoveryScenes[index];
  }
  final n = index + 1;
  return DiscoveryScene(
    'waymarker_$n',
    'Waymarker $n',
    'Another ten Paces together. The road goes on.',
    'A waymarker',
  );
}

/// The scene stored under [key], or the [index]th scene when the key is not
/// one this build knows. Keeps a discovery showing what was actually found
/// even if the drafted order changes between builds.
DiscoveryScene sceneByKey(String key, int index) {
  for (final s in discoveryScenes) {
    if (s.key == key) return s;
  }
  return sceneFor(index);
}
