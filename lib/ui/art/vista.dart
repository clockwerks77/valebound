import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/palette.dart';

/// A layered valley at dawn, painted in code: sky, low sun, four ridges with
/// mist between them and a few lanterns. Used behind the Dawn header and the
/// Vale panel until the illustrated scenes exist (see ASSETS.md).
///
/// [wake] runs from 0 (asleep under the grey Still) to 1 (fully awake).
class Vista extends StatelessWidget {
  const Vista({super.key, this.wake = 1.0, this.child, this.radius = 0});

  final double wake;
  final Widget? child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: VistaPainter(wake: wake),
        child: child,
      ),
    );
  }
}

class VistaPainter extends CustomPainter {
  const VistaPainter({this.wake = 1.0});

  final double wake;

  Color _tone(Color c) {
    // Asleep: drained toward the grey of the Still, a little lighter.
    final hsl = HSLColor.fromColor(c);
    final still = hsl
        .withSaturation(hsl.saturation * 0.18)
        .withLightness((hsl.lightness * 0.9 + 0.08).clamp(0.0, 1.0))
        .toColor();
    return Color.lerp(still, c, wake.clamp(0.0, 1.0))!;
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

    // Sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            _tone(Palette.skyDeep),
            _tone(Palette.skyMid),
            _tone(Palette.dawnRose),
            _tone(Palette.dawnPeach),
          ],
          stops: const <double>[0.0, 0.42, 0.74, 1.0],
        ).createShader(rect),
    );

    // A few early stars, fading toward the light.
    final stars = Paint()..color = _tone(Palette.onDark).withValues(alpha: 0.7);
    final random = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final x = random.nextDouble() * w;
      final y = random.nextDouble() * h * 0.38;
      final r = 0.5 + random.nextDouble() * 0.9;
      stars.color = _tone(Palette.onDark)
          .withValues(alpha: 0.25 + 0.5 * (1 - y / (h * 0.38)));
      canvas.drawCircle(Offset(x, y), r, stars);
    }

    // Low sun and its glow.
    final sun = Offset(w * 0.74, h * 0.6);
    final glowRadius = math.max(w, h) * 0.62;
    canvas.drawCircle(
      sun,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _tone(Palette.goldBright).withValues(alpha: 0.75),
            _tone(Palette.dawnPeach).withValues(alpha: 0.28),
            _tone(Palette.dawnPeach).withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.35, 1.0],
        ).createShader(Rect.fromCircle(center: sun, radius: glowRadius)),
    );
    canvas.drawCircle(
      sun,
      math.min(w, h) * 0.085,
      Paint()..color = _tone(const Color(0xFFFFF3D0)),
    );

    void mist(double top, double bottom, double alpha) {
      final band = Rect.fromLTRB(0, top * h, w, bottom * h);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              _tone(Palette.mist).withValues(alpha: 0.0),
              _tone(Palette.mist).withValues(alpha: alpha),
              _tone(Palette.mist).withValues(alpha: 0.0),
            ],
          ).createShader(band),
      );
    }

    // Ridges, far to near.
    canvas.drawPath(
      _ridge(size, 0.56, 0.05, 0.10, 1.3),
      Paint()..color = _tone(const Color(0xFF7E9FA6)),
    );
    mist(0.50, 0.70, 0.35);
    canvas.drawPath(
      _ridge(size, 0.66, 0.06, 0.55, 1.7),
      Paint()..color = _tone(const Color(0xFF4F8A7E)),
    );
    mist(0.62, 0.82, 0.28);

    final mid = _ridge(size, 0.76, 0.05, 0.25, 2.1);
    canvas.drawPath(mid, Paint()..color = _tone(Palette.moss));

    // Roofs and lanterns on the middle ridge: the sleeping village.
    final roof = Paint()..color = _tone(const Color(0xFF2B5B4C));
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
      Paint()..color = _tone(Palette.forest),
    );

    // Pines on the near ridge.
    final pine = Paint()..color = _tone(Palette.forestNight);
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
  bool shouldRepaint(VistaPainter oldDelegate) => oldDelegate.wake != wake;
}
