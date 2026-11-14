import 'package:flutter/widgets.dart';

import '../../rules/enums.dart';
import '../../rules/narrator.dart' show PartOfDay;
import '../../theme/palette.dart';
import '../motion.dart';

// The illustrated pieces (ASSETS.md sections 3, 6 and 7), made to the style
// sheet in docs/STYLE.md. Anything not listed here keeps its code-drawn
// stand-in, so the app is whole at every stage.

const Map<CompanionKind, String> companionArt = <CompanionKind, String>{
  CompanionKind.hound: 'assets/art/portraits/companion_hound.jpg',
  CompanionKind.cat: 'assets/art/portraits/companion_cat.jpg',
  CompanionKind.fox: 'assets/art/portraits/companion_fox.jpg',
  CompanionKind.owl: 'assets/art/portraits/companion_owl.jpg',
  CompanionKind.hare: 'assets/art/portraits/companion_hare.jpg',
  CompanionKind.clockworkSprite:
      'assets/art/portraits/companion_clockwork_sprite.jpg',
};

/// Hero portrait id to its illustration.
const Map<String, String> heroArt = <String, String>{
  'wayfarer': 'assets/art/portraits/hero_wayfarer.jpg',
  'lamplighter': 'assets/art/portraits/hero_lamplighter.jpg',
  'riverwarden': 'assets/art/portraits/hero_riverwarden.jpg',
  'emberkeeper': 'assets/art/portraits/hero_emberkeeper.jpg',
};

/// Discovery scene key to its illustration.
const Map<String, String> discoveryArt = <String, String>{
  'standing_stone': 'assets/art/discoveries/standing_stone.jpg',
  'hot_spring': 'assets/art/discoveries/hot_spring.jpg',
  'merchant_cart': 'assets/art/discoveries/merchant_cart.jpg',
  'lantern_tree': 'assets/art/discoveries/lantern_tree.jpg',
  'beehive_wall': 'assets/art/discoveries/beehive_wall.jpg',
  'wind_chimes': 'assets/art/discoveries/wind_chimes.jpg',
  'shepherd_hut': 'assets/art/discoveries/shepherd_hut.jpg',
  'mile_marker': 'assets/art/discoveries/mile_marker.jpg',
  'stepping_stones': 'assets/art/discoveries/stepping_stones.jpg',
  'reed_flute': 'assets/art/discoveries/reed_flute.jpg',
  'star_pool': 'assets/art/discoveries/star_pool.jpg',
  'otter_slide': 'assets/art/discoveries/otter_slide.jpg',
  'cloud_bench': 'assets/art/discoveries/cloud_bench.jpg',
  'watchtower': 'assets/art/discoveries/watchtower.jpg',
  'echo_stone': 'assets/art/discoveries/echo_stone.jpg',
  'snowbell': 'assets/art/discoveries/snowbell.jpg',
  'garden_gate': 'assets/art/discoveries/garden_gate.jpg',
  'sundial': 'assets/art/discoveries/sundial.jpg',
  'glass_stair': 'assets/art/discoveries/glass_stair.jpg',
  'first_lantern': 'assets/art/discoveries/first_lantern.jpg',
};

/// Story pictures: the prologue's scenes by [StoryScene] name, and each
/// region as `<region>_asleep` and `<region>_awake`. A key that is not
/// listed here shows a valley painted in code instead.
const Map<String, String> storyArt = <String, String>{
  'lastHill': 'assets/art/story/lastHill.jpg',
  'sleepingVale': 'assets/art/story/sleepingVale.jpg',
  'gateLantern': 'assets/art/story/gateLantern.jpg',
  'stillness': 'assets/art/story/stillness.jpg',
  'road': 'assets/art/story/road.jpg',
  'hearthmere_asleep': 'assets/art/story/hearthmere_asleep.jpg',
  'hearthmere_awake': 'assets/art/story/hearthmere_awake.jpg',
  'larkdown_asleep': 'assets/art/story/larkdown_asleep.jpg',
  'larkdown_awake': 'assets/art/story/larkdown_awake.jpg',
  'silverrun_asleep': 'assets/art/story/silverrun_asleep.jpg',
  'silverrun_awake': 'assets/art/story/silverrun_awake.jpg',
  'highcairn_asleep': 'assets/art/story/highcairn_asleep.jpg',
  'highcairn_awake': 'assets/art/story/highcairn_awake.jpg',
  'lanternhall_asleep': 'assets/art/story/lanternhall_asleep.jpg',
  'lanternhall_awake': 'assets/art/story/lanternhall_awake.jpg',
};

/// Where the subject of each story picture sits. The pictures are tall;
/// a frame that is shorter than they are is cut to this point, so the
/// lantern, the doorstep or the mill stays in view.
const Map<String, Alignment> _storyFocus = <String, Alignment>{
  'lastHill': Alignment(0, -0.2),
  'sleepingVale': Alignment(0, -0.25),
  'gateLantern': Alignment(0, 0.35),
  'stillness': Alignment(0, 0.75),
  'road': Alignment(0, 0.5),
  'hearthmere_asleep': Alignment(0, 0.85),
  'hearthmere_awake': Alignment(0, 1),
  'larkdown_asleep': Alignment(0, 0.15),
  'larkdown_awake': Alignment(0, 0.1),
  'silverrun_asleep': Alignment.center,
  'silverrun_awake': Alignment(0, 0.9),
  'highcairn_asleep': Alignment(0, 0.55),
  'highcairn_awake': Alignment(0, -0.15),
  'lanternhall_asleep': Alignment(0, 0.25),
  'lanternhall_awake': Alignment(0, 0.1),
};

/// The point a story picture is cut to when its frame is not its shape.
Alignment storyFocus(String key) => _storyFocus[key] ?? Alignment.center;

/// The valley behind the Today board in the light of [part]: one painting,
/// graded for morning, afternoon, evening and night (ASSETS.md section 7).
String dawnArt(PartOfDay part) => 'assets/art/scenes/dawn_${part.name}.jpg';

/// The camp beside the road, behind the Campfire.
const String campfireArt = 'assets/art/scenes/campfire.jpg';

const Set<String> _placeKeys = <String>{
  'gate_lantern', 'village_well', 'bakehouse', 'moot_hall',
  'sheepfold', 'larkdown_mill', 'hill_beacon', 'orchard',
  'heron_bridge', 'wheelhouse', 'boathouse', 'ford_bell',
  'waystation', 'ropeway', 'star_loft', 'summit_cairn',
  'great_arch', 'reading_room', 'glasshouse', 'lanternhall',
};

const Set<String> _villagerKeys = <String>{
  'wick', 'marla', 'bryn', 'tamsin', 'hob', 'anwen', 'corin', 'pell',
  'ness', 'dunstan', 'mira', 'fenn', 'greta', 'tobin', 'edda', 'orrin',
  'hal', 'quill', 'sorrel', 'maren',
};

const Set<String> _stillKeys = <String>{
  'drowsel', 'mistling', 'hushmoth', 'yawnstone', 'dozewisp', 'fogfinch',
};

const Set<String> _gearKeys = <String>{
  'moss_neckerchief', 'brass_bell', 'hearth_blanket', 'trail_cloak',
  'lantern_charm', 'silver_bell', 'star_blanket', 'dawn_cloak',
  'golden_tag', 'song_bell', 'old_road_cloak',
};

/// The picture of the place stored under [key], if it has one.
String? placeArt(String key) =>
    _placeKeys.contains(key) ? 'assets/art/places/$key.jpg' : null;

/// The picture of the villager stored under [key], if they have one.
String? villagerArt(String key) =>
    _villagerKeys.contains(key) ? 'assets/art/villagers/$key.jpg' : null;

/// The picture of the Still creature stored under [key], if it has one.
String? stillArt(String key) =>
    _stillKeys.contains(key) ? 'assets/art/still/$key.jpg' : null;

/// The picture of the piece of gear stored under [key], if it has one.
String? gearArt(String key) =>
    _gearKeys.contains(key) ? 'assets/art/gear/$key.jpg' : null;

/// The pictures that are shown small: portraits and medallions.
List<String> get smallPaintedAssets => <String>[
      ...companionArt.values,
      ...heroArt.values,
      for (final k in _placeKeys) placeArt(k)!,
      for (final k in _villagerKeys) villagerArt(k)!,
      for (final k in _stillKeys) stillArt(k)!,
      for (final k in _gearKeys) gearArt(k)!,
    ];

/// The pictures that are shown large: Discovery cards, story pages and the
/// two scenes.
List<String> get largePaintedAssets => <String>[
      ...discoveryArt.values,
      ...storyArt.values,
      for (final part in PartOfDay.values) dawnArt(part),
      campfireArt,
    ];

/// Every illustrated asset.
List<String> get allPaintedAssets => <String>[
      ...smallPaintedAssets,
      ...largePaintedAssets,
    ];

/// A large picture from the art set, filling its box. If it was not ready
/// at once it fades in, so nothing pops; if it cannot be shown at all,
/// [fallback] is.
class ArtPicture extends StatelessWidget {
  const ArtPicture({
    super.key,
    required this.asset,
    required this.fallback,
    this.alignment = Alignment.center,
  });

  final String asset;
  final Widget fallback;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, wasThere) => wasThere
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: motion(context, Motion.gentle),
              curve: Curves.easeOut,
              child: child,
            ),
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

/// Drains a picture toward grey: how a place looks while it is asleep
/// (DESIGN §3A). One painting serves both states.
const ColorFilter asleepFilter = ColorFilter.matrix(<double>[
  0.330, 0.608, 0.062, 0, 14, //
  0.181, 0.757, 0.062, 0, 14, //
  0.181, 0.608, 0.211, 0, 14, //
  0, 0, 0, 0.92, 0, //
]);

/// A round picture from the art set, or [fallback] when [asset] is null or
/// cannot be shown. [asleep] drains it to grey.
class ArtMedallion extends StatelessWidget {
  const ArtMedallion({
    super.key,
    required this.asset,
    required this.size,
    required this.fallback,
    this.ring = Palette.gold,
    this.asleep = false,
  });

  final String? asset;
  final double size;
  final Widget fallback;
  final Color ring;
  final bool asleep;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    if (asset == null) return fallback;
    final medallion = PaintedMedallion(
      asset: asset,
      ring: asleep ? Palette.slateFaint : ring,
      size: size,
      fallback: fallback,
    );
    if (!asleep) return medallion;
    return ColorFiltered(colorFilter: asleepFilter, child: medallion);
  }
}

/// A round illustrated portrait inside a coloured ring. If the picture
/// cannot be shown, [fallback] is.
class PaintedMedallion extends StatelessWidget {
  const PaintedMedallion({
    super.key,
    required this.asset,
    required this.ring,
    required this.size,
    required this.fallback,
  });

  final String asset;
  final Color ring;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final edge = (size * 0.045).clamp(1.5, 5.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: edge),
      ),
      padding: EdgeInsets.all(edge),
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stack) => fallback,
        ),
      ),
    );
  }
}

/// A Discovery's illustration with rounded corners, or nothing if that
/// scene has none yet.
class DiscoveryPicture extends StatelessWidget {
  const DiscoveryPicture({super.key, required this.sceneKey, this.radius = 16});

  final String sceneKey;
  final double radius;

  static bool exists(String sceneKey) => discoveryArt.containsKey(sceneKey);

  @override
  Widget build(BuildContext context) {
    final asset = discoveryArt[sceneKey];
    if (asset == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ArtPicture(asset: asset, fallback: const SizedBox.shrink()),
      ),
    );
  }
}
