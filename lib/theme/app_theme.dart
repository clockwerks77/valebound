import 'package:flutter/material.dart';

import 'palette.dart';

/// Display serif for headings, clean sans for body (DESIGN Visual direction).
/// Both fonts are bundled; nothing is fetched at runtime.
class Fonts {
  Fonts._();
  static const String display = 'Fraunces';
  static const String body = 'Figtree';
}

class AppText {
  AppText._();

  static const TextStyle display = TextStyle(
    fontFamily: Fonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    height: 1.1,
    letterSpacing: -0.3,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: Fonts.display,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 1.15,
  );

  static const TextStyle title = TextStyle(
    fontFamily: Fonts.display,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.2,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: Fonts.body,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.2,
  );

  static const TextStyle body = TextStyle(
    fontFamily: Fonts.body,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.35,
  );

  static const TextStyle small = TextStyle(
    fontFamily: Fonts.body,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 1.3,
  );

  static const TextStyle label = TextStyle(
    fontFamily: Fonts.body,
    fontWeight: FontWeight.w700,
    fontSize: 11.5,
    height: 1.2,
    letterSpacing: 1.1,
  );

  /// The narrator's voice: the display serif, in italic. Used only for
  /// the storyteller's own words, so they are told apart at a glance.
  static const TextStyle narrator = TextStyle(
    fontFamily: Fonts.display,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    fontSize: 16,
    height: 1.35,
  );

  static const TextStyle number = TextStyle(
    fontFamily: Fonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 1.0,
  );
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.forest,
    brightness: Brightness.light,
  ).copyWith(
    primary: Palette.forest,
    onPrimary: Palette.onDark,
    secondary: Palette.gold,
    onSecondary: Palette.slate,
    surface: Palette.parchment,
    onSurface: Palette.slate,
    error: Palette.companionDeep,
  );

  const baseText = TextStyle(fontFamily: Fonts.body, color: Palette.slate);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.forestDeep,
    fontFamily: Fonts.body,
    splashFactory: InkRipple.splashFactory,
    textTheme: TextTheme(
      displaySmall: AppText.display.copyWith(color: Palette.slate),
      headlineSmall: AppText.heading.copyWith(color: Palette.slate),
      titleLarge: AppText.title.copyWith(color: Palette.slate),
      titleMedium: AppText.cardTitle.copyWith(color: Palette.slate),
      bodyLarge: AppText.body.copyWith(color: Palette.slate),
      bodyMedium: AppText.body.copyWith(fontSize: 14, color: Palette.slate),
      bodySmall: AppText.small.copyWith(color: Palette.slateSoft),
      labelLarge: baseText.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
      labelSmall: AppText.label.copyWith(color: Palette.slateSoft),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppText.body.copyWith(color: Palette.slateFaint),
      labelStyle: AppText.small.copyWith(color: Palette.slateSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.parchmentEdge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.parchmentEdge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.goldDeep, width: 1.6),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.parchment,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.parchment,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Palette.parchmentEdge,
      thickness: 1,
      space: 1,
    ),
  );
}
