import 'package:flutter/widgets.dart';

import '../../rules/enums.dart';

/// The in-app icon set (DESIGN §6.1, §13): original line icons drawn in code
/// on a 24-unit grid. No icon font, no third-party artwork.
class VIcon extends StatelessWidget {
  const VIcon(this.name, {super.key, this.size = 24, required this.color});

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _VIconPainter(name, color)),
    );
  }
}

String attributeIcon(Attribute a) => switch (a) {
      Attribute.vitality => 'sprig',
      Attribute.care => 'home',
      Attribute.craft => 'brush',
      Attribute.mind => 'book',
      Attribute.adventure => 'compass',
      Attribute.order => 'scroll',
    };

String materialIcon(MaterialKind m) => switch (m) {
      MaterialKind.timber => 'timber',
      MaterialKind.stone => 'stone',
      MaterialKind.starShard => 'shard',
    };

/// Icons the user can pick for a quest.
const List<String> questIconChoices = <String>[
  'star', 'paw', 'ball', 'broom', 'boot', 'brush', 'sprig', 'vial',
  'book', 'cup', 'home', 'compass', 'scroll', 'moon', 'sun', 'people',
  'pen', 'music', 'leaf', 'campfire',
];

class _Spec {
  const _Spec({this.strokes = const <String>[], this.fills = const <String>[]});
  final List<String> strokes;
  final List<String> fills;
}

/// Path data in SVG path syntax on a 24×24 grid.
const Map<String, _Spec> _icons = <String, _Spec>{
  // ---- interface ----
  'check': _Spec(strokes: <String>['M5 12.5 L10 17.5 L19.5 7']),
  'plus': _Spec(strokes: <String>['M12 5 V19', 'M5 12 H19']),
  'minus': _Spec(strokes: <String>['M5 12 H19']),
  'play': _Spec(fills: <String>['M8 5.5 L19 12 L8 18.5 Z']),
  'pause': _Spec(fills: <String>['M7 5 H10.5 V19 H7 Z', 'M13.5 5 H17 V19 H13.5 Z']),
  'close': _Spec(strokes: <String>['M6 6 L18 18', 'M18 6 L6 18']),
  'chevron': _Spec(strokes: <String>['M9 5 L16 12 L9 19']),
  'edit': _Spec(strokes: <String>['M5 19 L6 15 L16 5 L19 8 L9 18 Z', 'M14 7 L17 10']),
  'archive': _Spec(strokes: <String>['M4 6 H20 V9.5 H4 Z', 'M5.5 9.5 V19 H18.5 V9.5', 'M10 13 H14']),
  'clock': _Spec(strokes: <String>['M12 3.5 A8.5 8.5 0 1 1 11.99 3.5', 'M12 7.5 V12 L15.5 14']),
  'lock': _Spec(strokes: <String>['M6 11 H18 V20 H6 Z', 'M8.5 11 V8 A3.5 3.5 0 0 1 15.5 8 V11']),
  'later': _Spec(strokes: <String>['M12 3.5 A8.5 8.5 0 1 1 11.99 3.5', 'M9.5 9 L13.5 12 L9.5 15', 'M14 9 L17 12']),
  // ---- navigation ----
  'board': _Spec(strokes: <String>['M6 4 H18 V20 H6 Z', 'M9 9 H15', 'M9 12.5 H15', 'M9 16 H13']),
  'map': _Spec(strokes: <String>['M3.5 6 L9 4 L15 6 L20.5 4 V18 L15 20 L9 18 L3.5 20 Z', 'M9 4 V18', 'M15 6 V20']),
  'party': _Spec(strokes: <String>['M12 3 L19 5.5 V11.5 C19 15.5 16 18.8 12 21 C8 18.8 5 15.5 5 11.5 V5.5 Z', 'M12 8 V15', 'M9 11.5 H15']),
  'log': _Spec(strokes: <String>['M5 5 C7.5 4 10 4.2 12 6 C14 4.2 16.5 4 19 5 V18.5 C16.5 17.6 14 17.8 12 19.5 C10 17.8 7.5 17.6 5 18.5 Z', 'M12 6 V19.5']),
  // ---- attributes and quests ----
  'sprig': _Spec(strokes: <String>['M12 21 V9', 'M12 13 C8.5 13 6.5 11 6 7.5 C9.5 7.5 11.5 9.5 12 13', 'M12 10 C12 6.5 14 4.5 17.5 4 C17.5 7.5 15.5 9.5 12 10']),
  'leaf': _Spec(strokes: <String>['M5 19 C5 10 10 5 19 5 C19 14 14 19 5 19 Z', 'M5 19 L13 11']),
  'home': _Spec(strokes: <String>['M4 11.5 L12 4.5 L20 11.5', 'M6.5 10 V19.5 H17.5 V10', 'M10.5 19.5 V15 A1.5 1.5 0 0 1 13.5 15 V19.5']),
  'brush': _Spec(strokes: <String>['M19.5 4.5 L11 13', 'M11 13 C9 12.5 7 13.8 6.8 15.8 C6.6 17.6 5.6 18.6 4.5 19 C7.5 20 11.8 18.8 12.2 15.4 C12.3 14.5 11.9 13.6 11 13 Z']),
  'book': _Spec(strokes: <String>['M4 6 C6.8 5 9.5 5.3 12 7 C14.5 5.3 17.2 5 20 6 V18 C17.2 17 14.5 17.3 12 19 C9.5 17.3 6.8 17 4 18 Z', 'M12 7 V19']),
  'compass': _Spec(strokes: <String>['M12 3.5 A8.5 8.5 0 1 1 11.99 3.5', 'M15.5 8.5 L13.5 13.5 L8.5 15.5 L10.5 10.5 Z']),
  'scroll': _Spec(strokes: <String>['M7 5 H17.5 A1.5 1.5 0 0 1 19 6.5 V8 H16', 'M16 6.5 V17.5 A1.5 1.5 0 0 1 14.5 19 H6.5 A1.5 1.5 0 0 1 5 17.5 V16 H13 V17.5', 'M7 5 A1.5 1.5 0 0 0 5.5 6.5 V16', 'M8.5 9 H13', 'M8.5 12 H13']),
  'paw': _Spec(fills: <String>[
    'M12 12.2 C14.6 12.2 17 15 17 17.2 C17 19 15.6 19.8 14.2 19.3 C13.3 19 12.7 18.8 12 18.8 C11.3 18.8 10.7 19 9.8 19.3 C8.4 19.8 7 19 7 17.2 C7 15 9.4 12.2 12 12.2 Z',
    'M6.3 7.3 A1.7 2.1 0 1 1 6.29 7.3 Z',
    'M9.8 3.5 A1.7 2.2 0 1 1 9.79 3.5 Z',
    'M14.2 3.5 A1.7 2.2 0 1 1 14.19 3.5 Z',
    'M17.7 7.3 A1.7 2.1 0 1 1 17.69 7.3 Z',
  ]),
  'ball': _Spec(strokes: <String>['M12 3.5 A8.5 8.5 0 1 1 11.99 3.5', 'M5.5 7 C9 9 9 15 5.5 17', 'M18.5 7 C15 9 15 15 18.5 17']),
  'broom': _Spec(strokes: <String>['M19 4 L11.5 11.5', 'M8.5 10.5 L13.5 15.5', 'M8.5 10.5 C6.5 12 5 15.5 4.5 19.5 C8.5 19 12 17.5 13.5 15.5', 'M7.5 15 L9.5 17']),
  'boot': _Spec(strokes: <String>['M8 4 H13.5 V12 C15.5 12.5 19.5 13.5 19.5 16.5 V19 H5.5 V15.5 C7.5 14 8 11 8 4 Z', 'M5.5 16.5 H19.5']),
  'vial': _Spec(strokes: <String>['M9 4 H15', 'M10 4 V9.5 L6 17.5 A1.6 1.6 0 0 0 7.5 20 H16.5 A1.6 1.6 0 0 0 18 17.5 L14 9.5 V4', 'M8 14.5 H16']),
  'campfire': _Spec(strokes: <String>['M12 4 C15.5 7.5 16.5 10 15 12.8 C14.2 14.3 13 15 12 15 C11 15 9.8 14.3 9 12.8 C8 10.9 8.6 9 10.2 7.6 C10.6 9 11.2 9.6 12 9.6 C12.6 8 12.6 6 12 4 Z', 'M5 20 L19 16.5', 'M5 16.5 L19 20']),
  'star': _Spec(strokes: <String>['M12 3.8 L14.4 9.2 L20.2 9.8 L15.8 13.7 L17.1 19.5 L12 16.5 L6.9 19.5 L8.2 13.7 L3.8 9.8 L9.6 9.2 Z']),
  'cup': _Spec(strokes: <String>['M6 6 H18 L16.8 18 A2 2 0 0 1 14.8 20 H9.2 A2 2 0 0 1 7.2 18 Z', 'M6.6 11 C9 9.6 11 12.4 13.2 11 C15 9.9 16.4 10.3 17.4 11']),
  'moon': _Spec(strokes: <String>['M19 14.5 A8 8 0 1 1 9.5 5 A7.2 7.2 0 0 0 19 14.5 Z']),
  'sun': _Spec(strokes: <String>['M12 7.5 A4.5 4.5 0 1 1 11.99 7.5', 'M12 2.5 V4.5', 'M12 19.5 V21.5', 'M2.5 12 H4.5', 'M19.5 12 H21.5', 'M5.3 5.3 L6.7 6.7', 'M17.3 17.3 L18.7 18.7', 'M5.3 18.7 L6.7 17.3', 'M17.3 6.7 L18.7 5.3']),
  'people': _Spec(strokes: <String>['M9 5.5 A3 3 0 1 1 8.99 5.5', 'M3.5 19.5 C3.5 15.8 6 13.8 9 13.8 C12 13.8 14.5 15.8 14.5 19.5', 'M16 6.5 A2.5 2.5 0 1 1 15.99 6.5', 'M16.5 13.5 C18.8 13.8 20.5 15.6 20.5 18.5']),
  'pen': _Spec(strokes: <String>['M12 20 L7.5 11 L12 3.5 L16.5 11 Z', 'M12 20 V12.5', 'M12 10.5 A1 1 0 1 1 11.99 10.5']),
  'music': _Spec(strokes: <String>['M9 17.5 V6 L19 4 V15.5', 'M6.5 15.2 A2.5 2.3 0 1 1 6.49 15.2', 'M16.5 13.2 A2.5 2.3 0 1 1 16.49 13.2']),
  // ---- rewards ----
  'pace': _Spec(fills: <String>[
    'M8.2 4 C10 4 10.8 6 10.6 8.4 C10.4 10.6 9.6 12 8.2 12 C6.8 12 6 10.6 5.8 8.4 C5.6 6 6.4 4 8.2 4 Z',
    'M6.4 13.4 H10 V14.6 A1.8 1.8 0 0 1 6.4 14.6 Z',
    'M15.8 9 C17.6 9 18.4 11 18.2 13.4 C18 15.6 17.2 17 15.8 17 C14.4 17 13.6 15.6 13.4 13.4 C13.2 11 14 9 15.8 9 Z',
    'M14 18.4 H17.6 V19.6 A1.8 1.8 0 0 1 14 19.6 Z',
  ]),
  'bond': _Spec(strokes: <String>['M4 12 C4 8.5 7 7 9.5 9 L14.5 15 C17 17 20 15.5 20 12 C20 8.5 17 7 14.5 9 L9.5 15 C7 17 4 15.5 4 12 Z']),
  'coin': _Spec(strokes: <String>['M12 4 A8 8 0 1 1 11.99 4', 'M12 8 L14 12 L12 16 L10 12 Z']),
  'timber': _Spec(strokes: <String>['M4 9 L16 5.5 L20 8 L8 11.5 Z', 'M4 9 V15 L8 17.5 V11.5', 'M8 17.5 L20 14 V8']),
  'stone': _Spec(strokes: <String>['M4.5 16 L7 9 L13 6 L18.5 9.5 L19.5 16 L14 19.5 H8 Z', 'M7 9 L11 12.5 L18.5 9.5', 'M11 12.5 L8 19.5']),
  'shard': _Spec(strokes: <String>['M12 3 L16.5 9 L12 21 L7.5 9 Z', 'M7.5 9 H16.5', 'M12 3 V21']),
  'lantern': _Spec(strokes: <String>['M9.5 4 H14.5', 'M12 4 V6.5', 'M8 6.5 H16 L17 9 V16.5 L16 19 H8 L7 16.5 V9 Z', 'M12 11 C13.4 12.4 13.4 14 12 15 C10.6 14 10.6 12.4 12 11 Z']),
  'trick': _Spec(strokes: <String>['M12 3.5 L13.6 9 L19 10.4 L13.6 12 L12 17.5 L10.4 12 L5 10.4 L10.4 9 Z', 'M18 16 L18.7 18.3 L21 19 L18.7 19.7 L18 22 L17.3 19.7 L15 19 L17.3 18.3 Z']),
  'affinity': _Spec(fills: <String>['M12 3.8 L14.4 9.2 L20.2 9.8 L15.8 13.7 L17.1 19.5 L12 16.5 L6.9 19.5 L8.2 13.7 L3.8 9.8 L9.6 9.2 Z']),
};

class _VIconPainter extends CustomPainter {
  _VIconPainter(this.name, this.color);

  final String name;
  final Color color;

  static final Map<String, Path> _cache = <String, Path>{};

  static Path _path(String d) => _cache.putIfAbsent(d, () => parseSvgPath(d));

  @override
  void paint(Canvas canvas, Size size) {
    final spec = _icons[name] ?? _icons['star']!;
    final scale = size.shortestSide / 24.0;
    canvas.save();
    canvas.scale(scale);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final d in spec.fills) {
      canvas.drawPath(_path(d), fill);
    }
    for (final d in spec.strokes) {
      canvas.drawPath(_path(d), stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VIconPainter oldDelegate) =>
      oldDelegate.name != name || oldDelegate.color != color;
}

/// A small SVG path-data parser: M L H V C Q A Z, absolute and relative.
/// Enough for the hand-written icon and crest shapes in this app.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcQqAaZz]|-?\d*\.?\d+')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var x = 0.0;
  var y = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  var command = '';

  bool isCommand(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCommand(tokens[i])) {
      command = tokens[i++];
    }
    final relative = command == command.toLowerCase();
    switch (command.toUpperCase()) {
      case 'M':
        var nx = next();
        var ny = next();
        if (relative) {
          nx += x;
          ny += y;
        }
        path.moveTo(nx, ny);
        x = nx;
        y = ny;
        startX = x;
        startY = y;
        // Further pairs after a move are implicit line-tos.
        command = relative ? 'l' : 'L';
      case 'L':
        var nx = next();
        var ny = next();
        if (relative) {
          nx += x;
          ny += y;
        }
        path.lineTo(nx, ny);
        x = nx;
        y = ny;
      case 'H':
        var nx = next();
        if (relative) nx += x;
        path.lineTo(nx, y);
        x = nx;
      case 'V':
        var ny = next();
        if (relative) ny += y;
        path.lineTo(x, ny);
        y = ny;
      case 'C':
        var x1 = next();
        var y1 = next();
        var x2 = next();
        var y2 = next();
        var nx = next();
        var ny = next();
        if (relative) {
          x1 += x;
          y1 += y;
          x2 += x;
          y2 += y;
          nx += x;
          ny += y;
        }
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        x = nx;
        y = ny;
      case 'Q':
        var x1 = next();
        var y1 = next();
        var nx = next();
        var ny = next();
        if (relative) {
          x1 += x;
          y1 += y;
          nx += x;
          ny += y;
        }
        path.quadraticBezierTo(x1, y1, nx, ny);
        x = nx;
        y = ny;
      case 'A':
        final rx = next();
        final ry = next();
        final rotation = next();
        final largeArc = next() != 0;
        final sweep = next() != 0;
        var nx = next();
        var ny = next();
        if (relative) {
          nx += x;
          ny += y;
        }
        path.arcToPoint(
          Offset(nx, ny),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
        x = nx;
        y = ny;
      case 'Z':
        path.close();
        x = startX;
        y = startY;
      default:
        // Unknown token: skip it so a typo cannot hang the loop.
        i++;
    }
  }
  return path;
}
