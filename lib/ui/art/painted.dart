import 'package:flutter/widgets.dart';

import '../../rules/enums.dart';
import '../../theme/palette.dart';

// The illustrated pieces that exist so far (ASSETS.md section 3), made to
// the style sheet in docs/STYLE.md. Anything not listed here keeps its
// code-drawn stand-in, so the app is whole at every stage.

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
};

/// Story pictures: the prologue's scenes by [StoryScene] name, and each
/// region as `<region>_asleep` and `<region>_awake`. Until a picture is
/// listed here the page shows a valley painted in code.
const Map<String, String> storyArt = <String, String>{};

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

/// Every illustrated asset, for loading ahead of time.
List<String> get allPaintedAssets => <String>[
      ...companionArt.values,
      ...heroArt.values,
      ...discoveryArt.values,
      ...storyArt.values,
      for (final k in _placeKeys) placeArt(k)!,
      for (final k in _villagerKeys) villagerArt(k)!,
      for (final k in _stillKeys) stillArt(k)!,
      for (final k in _gearKeys) gearArt(k)!,
    ];

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
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
