import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../rules/narrator.dart' show PartOfDay;
import '../../theme/palette.dart';

/// A layered valley, painted in code: sky, sun or moon, four ridges with
/// mist between them and a few lanterns. Used behind the Dawn header and the
/// story pages until the illustrated scenes exist (see ASSETS.md).
///
/// [wake] runs from 0 (asleep under the grey Still) to 1 (fully awake).
/// [part] is the time of day: the sky, the light and the sun follow it, so
/// the valley at the top of the board looks like the hour it is.
class Vista extends StatelessWidget {
  const Vista({
    super.key,
    this.wake = 1.0,
    this.part = PartOfDay.morning,
    this.child,
    this.radius = 0,
  });

  final double wake;
  final PartOfDay part;
  final Widget? child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: VistaPainter(wake: wake, part: part),
        child: child,
      ),
    );
  }
}

/// The sky and the light at one time of day.
class _Hour {
  const _Hour({
    required this.sky,
    required this.sun,
    required this.sunColor,
    required this.glow,
    required this.glowStrength,
    required this.stars,
    required this.shade,
    required this.shadeAmount,
    this.disc = true,
  });

  /// Top to horizon.
  final List<Color> sky;

  /// Where the sun or moon sits, as fractions of the width and height.
  final Offset sun;
  final Color sunColor;
  final Color glow;
  final double glowStrength;

  /// 0 (none) to 1 (a full night sky).
  final double stars;

  /// The land is mixed toward this colour by [shadeAmount].
  final Color shade;
  final double shadeAmount;

  /// Whether the sun is drawn as a disc. Low suns are; a high sun and the
  /// moon are only their light, so nothing pale sits behind the words that
  /// are set over the sky.
  final bool disc;

  static const _Hour morning = _Hour(
    sky: <Color>[
      Palette.skyDeep,
      Palette.skyMid,
      Palette.dawnRose,
      Palette.dawnPeach,
    ],
    sun: Offset(0.74, 0.6),
    sunColor: Color(0xFFFFF3D0),
    glow: Palette.goldBright,
    glowStrength: 0.75,
    stars: 0.55,
    shade: Palette.forest,
    shadeAmount: 0,
  );

  static const _Hour afternoon = _Hour(
    sky: <Color>[
      Color(0xFF2C6592),
      Color(0xFF5E9CBD),
      Color(0xFFB5D3D6),
      Color(0xFFF1E2B7),
    ],
    sun: Offset(0.72, -0.08),
    sunColor: Color(0xFFFFFBE8),
    glow: Color(0xFFFFF1BF),
    glowStrength: 0.55,
    stars: 0,
    shade: Palette.forest,
    shadeAmount: 0,
    disc: false,
  );

  static const _Hour evening = _Hour(
    sky: <Color>[
      Color(0xFF272646),
      Color(0xFF63466F),
      Color(0xFFD27A5F),
      Color(0xFFF2B46C),
    ],
    sun: Offset(0.24, 0.62),
    sunColor: Color(0xFFFFE2B0),
    glow: Color(0xFFF7B565),
    glowStrength: 0.8,
    stars: 0.35,
    shade: Color(0xFF4A3048),
    shadeAmount: 0.2,
  );

  static const _Hour night = _Hour(
    sky: <Color>[
      Color(0xFF09142B),
      Color(0xFF122445),
      Color(0xFF1F3858),
      Color(0xFF304B66),
    ],
    sun: Offset(0.78, 0.04),
    sunColor: Color(0xFFEFF2E6),
    glow: Color(0xFFBFD3E6),
    glowStrength: 0.3,
    stars: 1,
    shade: Color(0xFF0C1B33),
    shadeAmount: 0.52,
    disc: false,
  );

  static _Hour of(PartOfDay part) => switch (part) {
        PartOfDay.morning => morning,
        PartOfDay.afternoon => afternoon,
        PartOfDay.evening => evening,
        PartOfDay.night => night,
      };
}

class VistaPainter extends CustomPainter {
  const VistaPainter({this.wake = 1.0, this.part = PartOfDay.morning});

  final double wake;
  final PartOfDay part;

  Color _tone(Color c) {
    // Asleep: drained toward the grey of the Still, a little lighter.
    final hsl = HSLColor.fromColor(c);
    final still = hsl
        .withSaturation(hsl.saturation * 0.18)
        .withLightness((hsl.lightness * 0.9 + 0.08).clamp(0.0, 1.0))
        .toColor();
    return Color.lerp(still, c, wake.clamp(0.0, 1.0))!;
  }

  /// The land at this hour: [c] in the day's light, then drained by [wake].
  Color _land(Color c) {
    final hour = _Hour.of(part);
    return _tone(Color.lerp(c, hour.shade, hour.shadeAmount)!);
  }

  Path _ridge(Size s, double base, double amp, double phase, double freq) {
    final path = Path()..moveTo(0, s.height);
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final a = (t * freq + phase) * math.pi * 2;
      final b = (t * freq * 2.3 + phase * 1.7) * math.pi * 2;
      final y = base + amp * (0.62 * math.sin(a) + 0.38 * math.sin(b));
      path.lineTo(t * s.width, y * s.height);
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final hour = _Hour.of(part);

    // Sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[for (final c in hour.sky) _tone(c)],
          stops: const <double>[0.0, 0.42, 0.74, 1.0],
        ).createShader(rect),
    );

    // Stars: a few early ones at dawn and dusk, a skyful at night.
    if (hour.stars > 0) {
      final stars = Paint();
      final random = math.Random(7);
      final count = part == PartOfDay.night ? 60 : 26;
      final depth = part == PartOfDay.night ? 0.5 : 0.38;
      for (var i = 0; i < count; i++) {
        final x = random.nextDouble() * w;
        final y = random.nextDouble() * h * depth;
        final r = 0.5 + random.nextDouble() * 0.9;
        stars.color = _tone(Palette.onDark).withValues(
          alpha: hour.stars * (0.45 + 0.9 * (1 - y / (h * depth))) / 1.35,
        );
        canvas.drawCircle(Offset(x, y), r, stars);
      }
    }

    // The sun, or at night the moon, and its glow.
    final sun = Offset(w * hour.sun.dx, h * hour.sun.dy);
    final glowRadius = math.max(w, h) * 0.62;
    // Painted across the whole sky rather than as a disc, so the glow has no
    // edge of its own.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _tone(hour.glow).withValues(alpha: hour.glowStrength),
            _tone(hour.sky.last).withValues(alpha: hour.glowStrength * 0.37),
            _tone(hour.sky.last).withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.35, 1.0],
        ).createShader(Rect.fromCircle(center: sun, radius: glowRadius)),
    );
    if (hour.disc) {
      canvas.drawCircle(
        sun,
        math.min(w, h) * 0.085,
        Paint()..color = _tone(hour.sunColor),
      );
    }

    void mist(double top, double bottom, double alpha) {
      final band = Rect.fromLTRB(0, top * h, w, bottom * h);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              _land(Palette.mist).withValues(alpha: 0.0),
              _land(Palette.mist).withValues(alpha: alpha),
              _land(Palette.mist).withValues(alpha: 0.0),
            ],
          ).createShader(band),
      );
    }

    // Ridges, far to near.
    canvas.drawPath(
      _ridge(size, 0.56, 0.05, 0.10, 1.3),
      Paint()..color = _land(const Color(0xFF7E9FA6)),
    );
    mist(0.50, 0.70, 0.35);
    canvas.drawPath(
      _ridge(size, 0.66, 0.06, 0.55, 1.7),
      Paint()..color = _land(const Color(0xFF4F8A7E)),
    );
    mist(0.62, 0.82, 0.28);

    final mid = _ridge(size, 0.76, 0.05, 0.25, 2.1);
    canvas.drawPath(mid, Paint()..color = _land(Palette.moss));

    // Roofs and lanterns on the middle ridge: the sleeping village.
    final roof = Paint()..color = _land(const Color(0xFF2B5B4C));
    final lantern = Paint()..color = _tone(Palette.goldBright);
    final lanternGlow = Paint()
      ..color = _tone(Palette.goldBright).withValues(alpha: 0.28);
    for (final fx in const <double>[0.16, 0.22, 0.29, 0.36]) {
      final x = fx * w;
      final y = (0.735 + 0.012 * math.sin(fx * 40)) * h;
      final rw = w * 0.034;
      final rh = h * 0.05;
      canvas.drawPath(
        Path()
          ..moveTo(x - rw, y)
          ..lineTo(x, y - rh)
          ..lineTo(x + rw, y)
          ..lineTo(x + rw * 0.8, y + rh * 0.9)
          ..lineTo(x - rw * 0.8, y + rh * 0.9)
          ..close(),
        roof,
      );
      canvas.drawCircle(Offset(x, y + rh * 0.35), 4.2, lanternGlow);
      canvas.drawCircle(Offset(x, y + rh * 0.35), 1.5, lantern);
    }

    mist(0.74, 0.92, 0.2);
    canvas.drawPath(
      _ridge(size, 0.88, 0.045, 0.8, 2.6),
      Paint()..color = _land(Palette.forest),
    );

    // Pines on the near ridge.
    final pine = Paint()..color = _land(Palette.forestNight);
    for (final fx in const <double>[0.05, 0.11, 0.62, 0.69, 0.9, 0.96]) {
      final x = fx * w;
      final base = (0.9 + 0.02 * math.sin(fx * 23)) * h;
      final ph = h * (0.13 + 0.04 * math.sin(fx * 51).abs());
      canvas.drawPath(
        Path()
          ..moveTo(x, base - ph)
          ..lineTo(x + ph * 0.3, base)
          ..lineTo(x - ph * 0.3, base)
          ..close(),
        pine,
      );
    }
  }

  @override
  bool shouldRepaint(VistaPainter oldDelegate) =>
      oldDelegate.wake != wake || oldDelegate.part != part;
}
