import 'package:flutter/painting.dart';

import '../rules/enums.dart';

/// Colours from the style sheet (docs/STYLE.md). DESIGN Visual direction:
/// deep greens, warm gold, parchment-cream cards, dark slate text.
class Palette {
  Palette._();

  // Greens
  static const Color forestNight = Color(0xFF0C2620);
  static const Color forestDeep = Color(0xFF12352C);
  static const Color forest = Color(0xFF1D4C3F);
  static const Color moss = Color(0xFF3B7C60);
  static const Color sage = Color(0xFF9FC2AB);
  static const Color mist = Color(0xFFD7E4DE);

  // Golds and warm light
  static const Color gold = Color(0xFFD9A441);
  static const Color goldBright = Color(0xFFF5D27A);
  static const Color goldDeep = Color(0xFF9A6A21);
  static const Color ember = Color(0xFFE27A3B);
  static const Color dawnPeach = Color(0xFFF6C08F);
  static const Color dawnRose = Color(0xFFE59A86);

  // Sky
  static const Color skyDeep = Color(0xFF1B3550);
  static const Color skyMid = Color(0xFF3D6480);

  // Parchment
  static const Color parchment = Color(0xFFF8F0DE);
  static const Color parchmentShade = Color(0xFFEDDFC2);
  static const Color parchmentEdge = Color(0xFFD7C39B);

  // Text
  static const Color slate = Color(0xFF24303A);
  static const Color slateSoft = Color(0xFF566570);
  static const Color slateFaint = Color(0xFF8B979E);
  static const Color onDark = Color(0xFFF3ECDB);
  static const Color onDarkSoft = Color(0xFFB9CEC3);

  // Companion accent: warm terracotta, with a pale tint for its cards.
  static const Color companion = Color(0xFFC5653C);
  static const Color companionDeep = Color(0xFF8E4425);
  static const Color companionTint = Color(0xFFFCEBDB);
  static const Color companionEdge = Color(0xFFEBC3A3);

  // The Still: grey, sleepy, never frightening.
  static const Color stillGrey = Color(0xFF9BA7A8);

  static Color attribute(Attribute a) => switch (a) {
        Attribute.vitality => const Color(0xFFC2573F),
        Attribute.care => const Color(0xFFD08A3E),
        Attribute.craft => const Color(0xFF7B5EA7),
        Attribute.mind => const Color(0xFF3C78A8),
        Attribute.adventure => const Color(0xFF3B8A68),
        Attribute.order => const Color(0xFF5F7482),
      };

  static Color material(MaterialKind m) => switch (m) {
        MaterialKind.timber => const Color(0xFF9A6B3F),
        MaterialKind.stone => const Color(0xFF7F8C92),
        MaterialKind.starShard => const Color(0xFF6C7FD0),
      };
}
