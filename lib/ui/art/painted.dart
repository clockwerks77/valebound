import 'package:flutter/widgets.dart';

import '../../rules/enums.dart';

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

/// Every illustrated asset, for loading ahead of time.
List<String> get allPaintedAssets => <String>[
      ...companionArt.values,
      ...heroArt.values,
      ...discoveryArt.values,
    ];

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
