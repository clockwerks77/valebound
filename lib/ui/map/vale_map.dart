import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../rules/journey.dart';
import '../../rules/world.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../widgets/v_icon.dart';
import 'map_art.dart';

/// The World Map (DESIGN §8.2): the Vale and its regions, each waking as its
/// places are restored, with the Journey road, the camp and the Discovery
/// lanterns. Changes glide: fog lifts and the camp walks to its new spot.
class ValeMap extends StatelessWidget {
  const ValeMap({
    super.key,
    required this.restored,
    required this.paces,
    required this.discoveries,
    this.scout = false,
    this.stills = 0,
    this.decorations = const <String>[],
  });

  /// Places restored so far.
  final int restored;
  final int paces;

  /// Discoveries found so far.
  final int discoveries;

  /// Show the next Discovery as a silhouette (the Scout trick).
  final bool scout;

  /// Still creatures on the road today: open Heroic and Boss quests.
  final int stills;

  /// Keys of the village decorations unlocked.
  final List<String> decorations;

  @override
  Widget build(BuildContext context) {
    final region = regions[regionIndexForPaces(paces)].name;
    final drafted = restorationTargets.length;
    return Semantics(
      image: true,
      label: 'Map of the Vale. '
          '${restored > drafted ? drafted : restored} of $drafted places '
          'restored. Camp at $paces Paces, in $region.',
      child: AspectRatio(
        aspectRatio: mapWidth / mapHeight,
        child: RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: restored.toDouble()),
            duration: const Duration(milliseconds: 1600),
            curve: Curves.easeInOutCubic,
            builder: (context, restoredNow, _) {
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(end: paces.toDouble()),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOutCubic,
                builder: (context, pacesNow, _) => CustomPaint(
                  painter: ValeMapPainter(
                    restored: restoredNow,
                    paces: pacesNow,
                    discoveries: discoveries,
                    scout: scout,
                    stills: stills,
                    decorations: decorations,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ValeMapPainter extends CustomPainter {
  ValeMapPainter({
    required this.restored,
    required this.paces,
    required this.discoveries,
    required this.scout,
    required this.stills,
    required this.decorations,
  });

  final double restored;
  final double paces;
  final int discoveries;
  final bool scout;
  final int stills;
  final List<String> decorations;

  static final Map<String, Path> _paths = <String, Path>{};
  static Path _path(String d) => _paths.putIfAbsent(d, () => parseSvgPath(d));

  static List<ui.PathMetric>? _roadMetrics;
  static List<ui.PathMetric> get _road => _roadMetrics ??= <ui.PathMetric>[
        for (final d in roadSegments) _path(d).computeMetrics().first,
      ];

  /// 0..1 for region [index]: four places to a region, in order.
  double _wake(int index) => ((restored - index * 4) / 4).clamp(0.0, 1.0);

  double get _valeWake =>
      (restored / restorationTargets.length).clamp(0.0, 1.0);

  /// Asleep: drained toward the grey of the Still, a little lighter.
  static Color _tone(Color c, double wake) {
    final hsl = HSLColor.fromColor(c);
    final still = hsl
        .withSaturation(hsl.saturation * 0.18)
        .withLightness((hsl.lightness * 0.9 + 0.08).clamp(0.0, 1.0))
        .toColor();
    return Color.lerp(still, c, wake.clamp(0.0, 1.0))!;
  }

  /// A point on the road, [along] Paces from the gate (0..200).
  static Offset roadPoint(double along) {
    final clamped = along.clamp(0.0, roadPaces.toDouble());
    var segment = clamped ~/ pacesPerRegion;
    if (segment > roadSegments.length - 1) segment = roadSegments.length - 1;
    final local = (clamped - segment * pacesPerRegion) / pacesPerRegion;
    final metric = _road[segment];
    final tangent =
        metric.getTangentForOffset(metric.length * local.clamp(0.0, 1.0));
    return tangent?.position ?? Offset.zero;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / mapWidth;
    const frame = Rect.fromLTWH(0, 0, mapWidth, mapHeight);
    final card = RRect.fromRectAndRadius(frame, const Radius.circular(22));
    canvas.save();
    canvas.scale(scale);
    canvas.save();
    canvas.clipRRect(card);

    _paintLand(canvas);
    _paintDecorations(canvas);
    _paintFog(canvas);
    _paintRoad(canvas);
    _paintLanterns(canvas);
    _paintPlaces(canvas);
    _paintStills(canvas);
    _paintCamp(canvas);
    _paintLabels(canvas);

    canvas.restore();
    canvas.drawRRect(
      card.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.gold,
    );
    canvas.restore();
  }

  void _paintLand(Canvas canvas) {
    final whole = 0.3 + 0.7 * _valeWake;
    for (final layer in mapLayers) {
      final wake = layer.region < 0 ? whole : _wake(layer.region);
      final paint = Paint()
        ..isAntiAlias = true
        ..color = _tone(layer.color, wake);
      if (layer.stroke > 0) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.stroke
          ..strokeCap = StrokeCap.round;
      }
      canvas.drawPath(_path(layer.d), paint);
    }
  }

  void _paintFog(Canvas canvas) {
    for (var region = 0; region < mapFog.length; region++) {
      final thickness = 1 - _wake(region);
      if (thickness <= 0) continue;
      for (final bank in mapFog[region]) {
        canvas.save();
        canvas.translate(bank.centre.dx, bank.centre.dy);
        canvas.scale(bank.rx / bank.ry, 1);
        final circle = Rect.fromCircle(center: Offset.zero, radius: bank.ry);
        canvas.drawRect(
          circle,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                Palette.mist.withValues(alpha: 0.62 * thickness),
                Palette.mist.withValues(alpha: 0.0),
              ],
            ).createShader(circle),
        );
        canvas.restore();
      }
    }
  }

  void _paintRoad(Canvas canvas) {
    final bed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A2E22).withValues(alpha: 0.42);
    for (final d in roadSegments) {
      canvas.drawPath(_path(d), bed);
    }
    // Stepping dots: gold where the party has walked, pale ahead.
    final walked = Paint()..color = Palette.goldBright;
    final ahead = Paint()..color = const Color(0xFFE9D9B0).withValues(alpha: 0.9);
    for (var s = 0; s < _road.length; s++) {
      final metric = _road[s];
      final reach =
          ((paces - s * pacesPerRegion) / pacesPerRegion).clamp(0.0, 1.0) *
              metric.length;
      for (var at = 0.0; at <= metric.length; at += 7) {
        final p = metric.getTangentForOffset(at)?.position;
        if (p == null) continue;
        final done = at <= reach && paces > 0;
        canvas.drawCircle(p, done ? 2.1 : 1.6, done ? walked : ahead);
      }
    }
  }

  void _paintLanterns(Canvas canvas) {
    final total = roadPaces ~/ pacesPerDiscovery;
    for (var i = 0; i < total; i++) {
      final p = roadPoint((i + 1) * pacesPerDiscovery.toDouble());
      if (i < discoveries) {
        final glow = Rect.fromCircle(center: p, radius: 11);
        canvas.drawRect(
          glow,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                Palette.goldBright.withValues(alpha: 0.75),
                Palette.goldBright.withValues(alpha: 0.0),
              ],
            ).createShader(glow),
        );
        canvas.drawCircle(p, 3.6, Paint()..color = Palette.forestNight);
        canvas.drawCircle(p, 2.6, Paint()..color = Palette.goldBright);
      } else if (scout && i == discoveries) {
        // Scout: the next scene as a silhouette, something to look forward to.
        canvas.drawCircle(
          p,
          5.2,
          Paint()..color = Palette.forestNight.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          p,
          5.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Palette.sage,
        );
      } else {
        canvas.drawCircle(
          p,
          2.6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = Palette.parchment.withValues(alpha: 0.7),
        );
      }
    }
  }

  void _paintPlaces(Canvas canvas) {
    final whole = restored.floor();
    final part = restored - whole;
    for (var i = 0; i < placeSpots.length; i++) {
      final p = placeSpots[i];
      final target = restorationTargets[i];
      final awake = i < whole ? 1.0 : (i == whole ? part : 0.0);
      final next = i == whole && part == 0;
      if (awake > 0) {
        final glow = Rect.fromCircle(center: p, radius: 21);
        canvas.drawRect(
          glow,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                Palette.goldBright.withValues(alpha: 0.6 * awake),
                Palette.goldBright.withValues(alpha: 0.0),
              ],
            ).createShader(glow),
        );
      }
      final fill = next
          ? Palette.parchment
          : Color.lerp(const Color(0xFF8D9A9B), Palette.forest, awake)!;
      final ring = next
          ? Palette.gold
          : Color.lerp(const Color(0xFFC9D2D0), Palette.goldBright, awake)!;
      canvas.drawCircle(p, 10.5, Paint()..color = fill);
      canvas.drawCircle(
        p,
        10.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (awake > 0 || next) ? 2.2 : 1.4
          ..color = ring,
      );
      final ink = next
          ? Palette.forest
          : Color.lerp(const Color(0xFFE4EAE8), Palette.goldBright, awake)!;
      paintVIcon(canvas, target.villager?.icon ?? 'lantern', p, 12.5, ink);
    }
  }

  void _paintCamp(Canvas canvas) {
    final p = roadPoint(paces);
    final glow = Rect.fromCircle(center: p, radius: 26);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Palette.ember.withValues(alpha: 0.7),
            Palette.ember.withValues(alpha: 0.0),
          ],
        ).createShader(glow),
    );
    // A small tent, with the hero and the companion beside it.
    final tent = Path()
      ..moveTo(p.dx, p.dy - 13)
      ..lineTo(p.dx + 10, p.dy + 4)
      ..lineTo(p.dx - 10, p.dy + 4)
      ..close();
    canvas.drawPath(tent, Paint()..color = Palette.parchment);
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - 5)
        ..lineTo(p.dx + 3.4, p.dy + 4)
        ..lineTo(p.dx - 3.4, p.dy + 4)
        ..close(),
      Paint()..color = Palette.forestDeep,
    );
    canvas.drawPath(
      tent,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = Palette.forestNight,
    );
    void dot(Offset at, Color color) {
      canvas.drawCircle(at, 3.6, Paint()..color = Palette.forestNight);
      canvas.drawCircle(at, 2.6, Paint()..color = color);
    }

    dot(p + const Offset(-12, 7), Palette.goldBright);
    dot(p + const Offset(12, 7), Palette.companion);
  }

  void _paintStills(Canvas canvas) {
    final count = stills > 3 ? 3 : stills;
    for (var i = 0; i < count; i++) {
      final along = (paces + 7.0 * (i + 1)).clamp(0.0, roadPaces.toDouble());
      final p = roadPoint(along) + Offset(0, i.isEven ? -9 : 9);
      final body = Rect.fromCenter(center: p, width: 17, height: 13);
      final blob = RRect.fromRectAndCorners(
        body,
        topLeft: const Radius.circular(9),
        topRight: const Radius.circular(9),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(blob.inflate(1.2), Paint()..color = Palette.forestNight);
      canvas.drawRRect(blob, Paint()..color = Palette.stillGrey);
      final eye = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = Palette.slate;
      for (final dx in const <double>[-3.4, 3.4]) {
        canvas.drawArc(
          Rect.fromCenter(center: p + Offset(dx, 0.5), width: 3.6, height: 3),
          0,
          math.pi,
          false,
          eye,
        );
      }
    }
  }

  void _paintDecorations(Canvas canvas) {
    final colours = <Color>[
      Palette.ember,
      Palette.goldBright,
      Palette.dawnRose,
      Palette.sage,
    ];
    if (decorations.contains('bunting')) {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Palette.parchment;
      final string = Path()
        ..moveTo(92, 388)
        ..quadraticBezierTo(120, 396, 150, 388);
      canvas.drawPath(string, line);
      final metric = string.computeMetrics().first;
      for (var i = 0; i < 7; i++) {
        final at = metric.getTangentForOffset(metric.length * (i + 0.5) / 7);
        if (at == null) continue;
        final p = at.position;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - 2.2, p.dy)
            ..lineTo(p.dx + 2.2, p.dy)
            ..lineTo(p.dx, p.dy + 4.4)
            ..close(),
          Paint()..color = colours[i % colours.length],
        );
      }
    }
    if (decorations.contains('flower_boxes')) {
      for (final at in const <Offset>[
        Offset(88, 416),
        Offset(116, 406),
        Offset(138, 422),
        Offset(100, 462),
        Offset(126, 470),
        Offset(164, 432),
      ]) {
        canvas.drawCircle(at, 1.5, Paint()..color = Palette.dawnRose);
        canvas.drawCircle(
          at + const Offset(4, 0),
          1.5,
          Paint()..color = Palette.goldBright,
        );
      }
    }
    if (decorations.contains('market_awnings')) {
      for (var i = 0; i < 3; i++) {
        final left = 104.0 + i * 11;
        canvas.drawRect(
          Rect.fromLTWH(left, 426, 9, 5),
          Paint()..color = i.isEven ? Palette.ember : Palette.parchment,
        );
      }
    }
    if (decorations.contains('lantern_strings')) {
      for (var along = 82.0; along <= 118; along += 4) {
        final p = roadPoint(along) + const Offset(0, -6);
        canvas.drawCircle(p, 1.3, Paint()..color = Palette.goldBright);
      }
    }
    if (decorations.contains('great_banner')) {
      canvas.drawRect(
        const Rect.fromLTWH(299, 12, 1.6, 20),
        Paint()..color = Palette.forestNight,
      );
      canvas.drawPath(
        Path()
          ..moveTo(300.6, 13)
          ..lineTo(318, 13)
          ..lineTo(313.5, 18.5)
          ..lineTo(318, 24)
          ..lineTo(300.6, 24)
          ..close(),
        Paint()..color = Palette.gold,
      );
    }
  }

  void _paintLabels(Canvas canvas) {
    for (final label in mapLabels) {
      final painter = TextPainter(
        text: TextSpan(
          text: regions[label.region].name.toUpperCase(),
          style: const TextStyle(
            fontFamily: Fonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 1.4,
            color: Palette.parchment,
            shadows: <Shadow>[
              Shadow(color: Palette.forestNight, blurRadius: 3),
              Shadow(color: Palette.forestNight, blurRadius: 6),
              Shadow(color: Palette.forestNight, offset: Offset(0, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      var left = label.at.dx - painter.width / 2;
      if (left < 8) left = 8;
      if (left + painter.width > mapWidth - 8) {
        left = mapWidth - 8 - painter.width;
      }
      painter.paint(canvas, Offset(left, label.at.dy - painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(ValeMapPainter old) =>
      old.restored != restored ||
      old.paces != paces ||
      old.discoveries != discoveries ||
      old.scout != scout ||
      old.stills != stills ||
      old.decorations.length != decorations.length;
}
