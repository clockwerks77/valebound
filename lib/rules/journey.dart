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

class DiscoveryScene {
  const DiscoveryScene(this.key, this.title, this.line);
  final String key;
  final String title;
  final String line;
}

/// Twelve original roadside scenes, drafted for v1 (DESIGN asks for ~12).
const List<DiscoveryScene> discoveryScenes = <DiscoveryScene>[
  DiscoveryScene(
    'standing_stone',
    'The Listening Stone',
    'A tall grey stone, warm on one side, as if it had been waiting.',
  ),
  DiscoveryScene(
    'hot_spring',
    'Kettle Spring',
    'Steam rises from a ring of mossy rocks. The water is exactly right.',
  ),
  DiscoveryScene(
    'merchant_cart',
    'The Quiet Cart',
    'A travelling merchant’s cart, wheels deep in clover, bells still on.',
  ),
  DiscoveryScene(
    'lantern_tree',
    'The Lantern Oak',
    'Someone hung glass lanterns in this oak long ago. One still glows.',
  ),
  DiscoveryScene(
    'stepping_stones',
    'Heron Crossing',
    'Flat stones across the river, each one carved with a small bird.',
  ),
  DiscoveryScene(
    'beehive_wall',
    'The Honey Wall',
    'An old orchard wall, and a drowsy hum from somewhere inside it.',
  ),
  DiscoveryScene(
    'wind_chimes',
    'Chime Hollow',
    'A dip in the hills where the wind plays a tune on hanging shells.',
  ),
  DiscoveryScene(
    'shepherd_hut',
    'The Shepherd’s Rest',
    'A round hut with a turf roof. The kettle hook is polished smooth.',
  ),
  DiscoveryScene(
    'star_pool',
    'The Star Pool',
    'A still pool that shows the night sky, even at noon.',
  ),
  DiscoveryScene(
    'mile_marker',
    'The Painted Milestone',
    'A waymarker in faded blue, pointing to a village you have yet to wake.',
  ),
  DiscoveryScene(
    'watchtower',
    'Swallow Tower',
    'A broken watchtower, home now to a hundred swallows.',
  ),
  DiscoveryScene(
    'garden_gate',
    'The Open Gate',
    'A garden gate standing by itself in a meadow, kindly left ajar.',
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
  );
}
