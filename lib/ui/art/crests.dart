import 'package:flutter/widgets.dart';

import '../../rules/enums.dart';
import '../../theme/palette.dart';
import '../widgets/v_icon.dart' show VIcon, parseSvgPath;

// Code-drawn crest medallions for the hero and each companion kind.
//
// These are Phase 1 stand-ins, listed as such in ASSETS.md: the painterly
// portraits the design calls for need an illustration tool this build
// environment does not have. Shapes are original and drawn on a 100-unit grid.

enum _R { fur, furDark, light, ink, accent }

class _L {
  const _L(this.d, this.role, {this.stroke = false, this.width = 2.2});
  final String d;
  final _R role;
  final bool stroke;
  final double width;
}

class _Crest {
  const _Crest({
    required this.layers,
    required this.colors,
    required this.backgroundInner,
    required this.backgroundOuter,
  });
  final List<_L> layers;
  final Map<_R, Color> colors;
  final Color backgroundInner;
  final Color backgroundOuter;
}

const Map<CompanionKind, _Crest> _companionCrests = <CompanionKind, _Crest>{
  CompanionKind.hound: _Crest(
    backgroundInner: Color(0xFF7FB08C),
    backgroundOuter: Color(0xFF2E6650),
    colors: <_R, Color>{
      _R.fur: Color(0xFFC98A4B),
      _R.furDark: Color(0xFF5B3A29),
      _R.light: Color(0xFFF8ECD9),
      _R.ink: Color(0xFF2B2320),
      _R.accent: Color(0xFFB5543A),
    },
    layers: <_L>[
      _L('M25 36 C13 42 12 70 23 82 C32 78 37 60 37 42 Z', _R.furDark),
      _L('M75 36 C87 42 88 70 77 82 C68 78 63 60 63 42 Z', _R.furDark),
      _L('M50 20 C68 20 77 34 75 52 C73 70 63 82 50 82 C37 82 27 70 25 52 C23 34 32 20 50 20 Z', _R.fur),
      _L('M50 24 C54 33 55 44 61 54 C66 63 61 77 50 79 C39 77 34 63 39 54 C45 44 46 33 50 24 Z', _R.light),
      _L('M40 44.5 A3.4 3.4 0 1 1 39.99 44.5 Z', _R.ink),
      _L('M60 44.5 A3.4 3.4 0 1 1 59.99 44.5 Z', _R.ink),
      _L('M43.5 62 C45.5 57.5 54.5 57.5 56.5 62 C56.5 66.5 52.5 68.5 50 68.5 C47.5 68.5 43.5 66.5 43.5 62 Z', _R.ink),
      _L('M50 68.5 V72 M50 72 C48 75 44.5 75 43.5 72.5 M50 72 C52 75 55.5 75 56.5 72.5', _R.ink, stroke: true, width: 1.8),
    ],
  ),
  CompanionKind.cat: _Crest(
    backgroundInner: Color(0xFF9C8FC4),
    backgroundOuter: Color(0xFF40386B),
    colors: <_R, Color>{
      _R.fur: Color(0xFF75828C),
      _R.furDark: Color(0xFF4D5860),
      _R.light: Color(0xFFEDF1F2),
      _R.ink: Color(0xFF1F262B),
      _R.accent: Color(0xFFE2B24A),
    },
    layers: <_L>[
      _L('M25 46 L22 16 L45 30 Z', _R.fur),
      _L('M75 46 L78 16 L55 30 Z', _R.fur),
      _L('M28 38 L27 23 L38 30 Z', _R.light),
      _L('M72 38 L73 23 L62 30 Z', _R.light),
      _L('M50 27 C68 27 79 40 79 55 C79 71 66 82 50 82 C34 82 21 71 21 55 C21 40 32 27 50 27 Z', _R.fur),
      _L('M50 60 C58 60 63 66 61 73 C58 79 54 81 50 81 C46 81 42 79 39 73 C37 66 42 60 50 60 Z', _R.light),
      _L('M33 51 C36 45.5 43 45.5 46 51 C43 55.5 36 55.5 33 51 Z', _R.accent),
      _L('M54 51 C57 45.5 64 45.5 67 51 C64 55.5 57 55.5 54 51 Z', _R.accent),
      _L('M39.5 47 C41 49.5 41 52.5 39.5 55 C38 52.5 38 49.5 39.5 47 Z', _R.ink),
      _L('M60.5 47 C62 49.5 62 52.5 60.5 55 C59 52.5 59 49.5 60.5 47 Z', _R.ink),
      _L('M47 62.5 H53 L50 66.5 Z', _R.ink),
      _L('M50 66.5 C49 70.5 45 71 43.5 69 M50 66.5 C51 70.5 55 71 56.5 69', _R.ink, stroke: true, width: 1.6),
      _L('M31 65 L17 62 M31 69 L17 71 M69 65 L83 62 M69 69 L83 71', _R.light, stroke: true, width: 1.3),
    ],
  ),
  CompanionKind.fox: _Crest(
    backgroundInner: Color(0xFF6DB3A8),
    backgroundOuter: Color(0xFF1F5B57),
    colors: <_R, Color>{
      _R.fur: Color(0xFFDB7A31),
      _R.furDark: Color(0xFF6E3518),
      _R.light: Color(0xFFFCF2E3),
      _R.ink: Color(0xFF2A1D17),
      _R.accent: Color(0xFFE2B24A),
    },
    layers: <_L>[
      _L('M27 48 L20 13 L47 32 Z', _R.fur),
      _L('M73 48 L80 13 L53 32 Z', _R.fur),
      _L('M20 13 L24 30 L33 22 Z', _R.furDark),
      _L('M80 13 L76 30 L67 22 Z', _R.furDark),
      _L('M50 29 C66 29 81 39 84 52 C75 63 62 73 50 86 C38 73 25 63 16 52 C19 39 34 29 50 29 Z', _R.fur),
      _L('M16 52 C25 63 38 73 50 86 C47 73 41 63 35 57 C28 57 21 55.5 16 52 Z', _R.light),
      _L('M84 52 C75 63 62 73 50 86 C53 73 59 63 65 57 C72 57 79 55.5 84 52 Z', _R.light),
      _L('M35 50 C37.5 46.5 42.5 47 44.5 51 C41.5 53 38 53 35 50 Z', _R.ink),
      _L('M65 50 C62.5 46.5 57.5 47 55.5 51 C58.5 53 62 53 65 50 Z', _R.ink),
      _L('M46 79 C48 76.5 52 76.5 54 79 C53 83 51 85.5 50 86 C49 85.5 47 83 46 79 Z', _R.ink),
    ],
  ),
  CompanionKind.owl: _Crest(
    backgroundInner: Color(0xFF6F8FB8),
    backgroundOuter: Color(0xFF1E3454),
    colors: <_R, Color>{
      _R.fur: Color(0xFF86705A),
      _R.furDark: Color(0xFF55443A),
      _R.light: Color(0xFFEFE2CD),
      _R.ink: Color(0xFF231C17),
      _R.accent: Color(0xFFE9A93B),
    },
    layers: <_L>[
      _L('M25 32 L20 13 L40 23 Z', _R.furDark),
      _L('M75 32 L80 13 L60 23 Z', _R.furDark),
      _L('M50 18 C72 18 83 34 83 55 C83 73 69 86 50 86 C31 86 17 73 17 55 C17 34 28 18 50 18 Z', _R.fur),
      _L('M36.5 32 A14.5 14.5 0 1 1 36.49 32 Z', _R.light),
      _L('M63.5 32 A14.5 14.5 0 1 1 63.49 32 Z', _R.light),
      _L('M36.5 39 A7.5 7.5 0 1 1 36.49 39 Z', _R.accent),
      _L('M63.5 39 A7.5 7.5 0 1 1 63.49 39 Z', _R.accent),
      _L('M36.5 42.6 A3.9 3.9 0 1 1 36.49 42.6 Z', _R.ink),
      _L('M63.5 42.6 A3.9 3.9 0 1 1 63.49 42.6 Z', _R.ink),
      _L('M45.5 54 H54.5 L50 64 Z', _R.accent),
      _L('M38 71 C41 74.5 46 74.5 50 71 C54 74.5 59 74.5 62 71 M43 78 C45.5 80.5 48 80.5 50 78 C52 80.5 54.5 80.5 57 78', _R.light, stroke: true, width: 1.8),
    ],
  ),
  CompanionKind.hare: _Crest(
    backgroundInner: Color(0xFFC9D48A),
    backgroundOuter: Color(0xFF5E7A3A),
    colors: <_R, Color>{
      _R.fur: Color(0xFFBFA78D),
      _R.furDark: Color(0xFF8C755F),
      _R.light: Color(0xFFF7ECDF),
      _R.ink: Color(0xFF2B2320),
      _R.accent: Color(0xFFDD9383),
    },
    layers: <_L>[
      _L('M37 46 C27 32 27 12 37 5 C46 12 47 32 45 46 Z', _R.fur),
      _L('M63 46 C73 32 73 12 63 5 C54 12 53 32 55 46 Z', _R.fur),
      _L('M38 41 C33 31 33 18 37.5 12 C42 18 42.5 31 42 41 Z', _R.accent),
      _L('M62 41 C67 31 67 18 62.5 12 C58 18 57.5 31 58 41 Z', _R.accent),
      _L('M50 38 C64 38 73 48 73 61 C73 75 63 86 50 86 C37 86 27 75 27 61 C27 48 36 38 50 38 Z', _R.fur),
      _L('M50 63 C58 63 63 69 61 75.5 C58 81 54 82.5 50 82.5 C46 82.5 42 81 39 75.5 C37 69 42 63 50 63 Z', _R.light),
      _L('M40 53 A3.2 3.2 0 1 1 39.99 53 Z', _R.ink),
      _L('M60 53 A3.2 3.2 0 1 1 59.99 53 Z', _R.ink),
      _L('M47 66 H53 L50 69.5 Z', _R.accent),
      _L('M50 69.5 V73 M50 73 C48.5 75.5 45.5 75.5 44.5 73.5 M50 73 C51.5 75.5 54.5 75.5 55.5 73.5', _R.ink, stroke: true, width: 1.6),
    ],
  ),
  CompanionKind.clockworkSprite: _Crest(
    backgroundInner: Color(0xFF5E8F96),
    backgroundOuter: Color(0xFF1C3A44),
    colors: <_R, Color>{
      _R.fur: Color(0xFFCB9C3E),
      _R.furDark: Color(0xFF8A6420),
      _R.light: Color(0xFFF5E6BA),
      _R.ink: Color(0xFF26262B),
      _R.accent: Color(0xFF6FE0D8),
    },
    layers: <_L>[
      _L('M27 46 C12 36 9 54 24 60 Z', _R.light),
      _L('M73 46 C88 36 91 54 76 60 Z', _R.light),
      _L('M50 30 V19', _R.furDark, stroke: true, width: 3),
      _L('M50 8 A5.5 5.5 0 1 1 49.99 8', _R.furDark, stroke: true, width: 3),
      _L('M50.0 32.0 L53.0 27.2 L58.3 28.3 L59.1 34.0 L62.9 36.2 L68.2 34.1 L71.8 38.1 L69.1 43.2 L70.9 47.2 L76.5 48.6 L77.0 54.0 L71.9 56.5 L70.9 60.8 L74.6 65.2 L71.8 69.9 L66.2 68.9 L62.9 71.8 L63.3 77.5 L58.3 79.7 L54.4 75.6 L50.0 76.0 L47.0 80.8 L41.7 79.7 L40.9 74.0 L37.1 71.8 L31.8 73.9 L28.2 69.9 L30.9 64.8 L29.1 60.8 L23.5 59.4 L23.0 54.0 L28.1 51.5 L29.1 47.2 L25.4 42.8 L28.2 38.1 L33.8 39.1 L37.1 36.2 L36.7 30.5 L41.7 28.3 L45.6 32.4 Z', _R.fur),
      _L('M50 38 A16 16 0 1 1 49.99 38 Z', _R.furDark),
      _L('M50 40.5 A13.5 13.5 0 1 1 49.99 40.5 Z', _R.ink),
      _L('M44 47.5 A3.6 3.6 0 1 1 43.99 47.5 Z', _R.accent),
      _L('M56 47.5 A3.6 3.6 0 1 1 55.99 47.5 Z', _R.accent),
      _L('M44 58.5 C47 61.5 53 61.5 56 58.5', _R.accent, stroke: true, width: 2),
    ],
  ),
};

/// Hero portrait choices (DESIGN OPEN item: four original portraits).
class HeroPortraitOption {
  const HeroPortraitOption(this.id, this.label, this.emblem);
  final String id;
  final String label;
  final String emblem;
}

const List<HeroPortraitOption> heroPortraits = <HeroPortraitOption>[
  HeroPortraitOption('wayfarer', 'Wayfarer', 'leaf'),
  HeroPortraitOption('lamplighter', 'Lamplighter', 'lantern'),
  HeroPortraitOption('riverwarden', 'River Warden', 'cup'),
  HeroPortraitOption('emberkeeper', 'Ember Keeper', 'campfire'),
];

const List<_L> _heroLayers = <_L>[
  _L('M10 104 C12 80 28 68 50 68 C72 68 88 80 90 104 Z', _R.fur),
  _L('M50 12 C71 12 82 31 80 52 C78 66 67 75 50 75 C33 75 22 66 20 52 C18 31 29 12 50 12 Z', _R.furDark),
  _L('M50 24 C63 24 70 35 69 48 C68 59 60 66 50 66 C40 66 32 59 31 48 C30 35 37 24 50 24 Z', _R.ink),
  _L('M36 70 C42 76 58 76 64 70 L60 84 C56 88 44 88 40 84 Z', _R.furDark),
  _L('M50 73 A5.5 5.5 0 1 1 49.99 73 Z', _R.accent),
  _L('M50 20 C56 22 60 26 62 30', _R.light, stroke: true, width: 1.6),
];

const Map<String, _Crest> _heroCrests = <String, _Crest>{
  'wayfarer': _Crest(
    layers: _heroLayers,
    backgroundInner: Color(0xFFF2D58E),
    backgroundOuter: Color(0xFFB98A35),
    colors: <_R, Color>{
      _R.fur: Color(0xFF2E6B55),
      _R.furDark: Color(0xFF1C4A3C),
      _R.ink: Color(0xFF11261F),
      _R.accent: Color(0xFFF5D27A),
      _R.light: Color(0xFF5FA387),
    },
  ),
  'lamplighter': _Crest(
    layers: _heroLayers,
    backgroundInner: Color(0xFF8FB7C9),
    backgroundOuter: Color(0xFF2C5068),
    colors: <_R, Color>{
      _R.fur: Color(0xFFD29A3A),
      _R.furDark: Color(0xFF9A6A21),
      _R.ink: Color(0xFF3B2A12),
      _R.accent: Color(0xFFFFF0C2),
      _R.light: Color(0xFFF1C56A),
    },
  ),
  'riverwarden': _Crest(
    layers: _heroLayers,
    backgroundInner: Color(0xFFBFE0D2),
    backgroundOuter: Color(0xFF4F8F7C),
    colors: <_R, Color>{
      _R.fur: Color(0xFF3B6FA0),
      _R.furDark: Color(0xFF274D74),
      _R.ink: Color(0xFF14283D),
      _R.accent: Color(0xFFF5D27A),
      _R.light: Color(0xFF7FA9CF),
    },
  ),
  'emberkeeper': _Crest(
    layers: _heroLayers,
    backgroundInner: Color(0xFFF3C7A2),
    backgroundOuter: Color(0xFFB0683F),
    colors: <_R, Color>{
      _R.fur: Color(0xFFA9442F),
      _R.furDark: Color(0xFF75291D),
      _R.ink: Color(0xFF34110C),
      _R.accent: Color(0xFFF5D27A),
      _R.light: Color(0xFFD3765D),
    },
  ),
};

/// Ring colour for a portrait frame (see `heroCosmetics`).
Color frameColor(String key) => switch (key) {
      'oak' => const Color(0xFF8A5A2B),
      'riverstone' => const Color(0xFF7F9AA8),
      'gilded' => Palette.goldBright,
      'starlit' => const Color(0xFF6C7FD0),
      _ => Palette.gold,
    };

/// Colour of a hero banner (see `heroCosmetics`).
Color bannerColor(String key) => switch (key) {
      'dawn' => Palette.dawnRose,
      'river' => const Color(0xFF4E8FB8),
      'ember' => Palette.ember,
      'gold' => Palette.gold,
      _ => Palette.forest,
    };

class CompanionPortrait extends StatelessWidget {
  const CompanionPortrait({
    super.key,
    required this.kind,
    this.size = 56,
    this.gearIcon,
  });

  final CompanionKind kind;
  final double size;

  /// Icon of the gear being worn, shown as a small badge.
  final String? gearIcon;

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.36;
    return Semantics(
      label: '${kind.label} portrait',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _CrestPainter(_companionCrests[kind]!, Palette.companion),
              ),
            ),
            if (gearIcon != null)
              Positioned(
                right: -badge * 0.12,
                bottom: -badge * 0.12,
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Palette.parchment,
                    border: Border.all(color: Palette.companionDeep, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: VIcon(
                    gearIcon!,
                    size: badge * 0.62,
                    color: Palette.companionDeep,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HeroPortrait extends StatelessWidget {
  const HeroPortrait({
    super.key,
    required this.portraitId,
    this.size = 56,
    this.frame,
  });

  final String portraitId;
  final double size;

  /// Key of the portrait frame in use; plain gold when null.
  final String? frame;

  @override
  Widget build(BuildContext context) {
    final crest = _heroCrests[portraitId] ?? _heroCrests['wayfarer']!;
    return Semantics(
      label: 'Hero portrait',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CrestPainter(
            crest,
            frame == null ? Palette.gold : frameColor(frame!),
          ),
        ),
      ),
    );
  }
}

class _CrestPainter extends CustomPainter {
  _CrestPainter(this.crest, this.ring);

  final _Crest crest;
  final Color ring;

  static final Map<String, Path> _cache = <String, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(s / 2, s / 2);
    final radius = s / 2;
    final ringWidth = (s * 0.055).clamp(1.5, 6.0);
    final inner = radius - ringWidth;
    final circle = Rect.fromCircle(center: center, radius: inner);

    // Soft painted background.
    canvas.drawCircle(
      center,
      inner,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.45),
          radius: 1.05,
          colors: <Color>[crest.backgroundInner, crest.backgroundOuter],
        ).createShader(circle),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    final scale = s / 100.0;
    canvas.scale(scale);
    for (final layer in crest.layers) {
      final path = _cache.putIfAbsent(layer.d, () => parseSvgPath(layer.d));
      final paint = Paint()
        ..isAntiAlias = true
        ..color = crest.colors[layer.role] ?? Palette.slate;
      if (layer.stroke) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();

    // Light from the upper left, shade at the lower right.
    canvas.drawCircle(
      center,
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFFFFFFFF).withValues(alpha: 0.16),
            const Color(0x00FFFFFF),
            const Color(0xFF000000).withValues(alpha: 0.18),
          ],
          stops: const <double>[0.0, 0.5, 1.0],
        ).createShader(circle),
    );

    // Ring.
    canvas.drawCircle(
      center,
      radius - ringWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(ring, const Color(0xFFFFFFFF), 0.45)!,
            ring,
            Color.lerp(ring, const Color(0xFF000000), 0.3)!,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_CrestPainter oldDelegate) =>
      oldDelegate.crest != crest || oldDelegate.ring != ring;
}
