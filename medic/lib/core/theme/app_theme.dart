import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _emojiFontFallback = <String>[
  'AppleColorEmoji',
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Noto Color Emoji',
];

TextStyle? _withEmojiFallback(TextStyle? style) {
  if (style == null) return null;
  final merged = <String>[
    ...?style.fontFamilyFallback,
    ..._emojiFontFallback,
  ];
  return style.copyWith(fontFamilyFallback: merged.toSet().toList());
}

TextTheme _applyEmojiFallback(TextTheme textTheme) {
  return textTheme.copyWith(
    displayLarge: _withEmojiFallback(textTheme.displayLarge),
    displayMedium: _withEmojiFallback(textTheme.displayMedium),
    displaySmall: _withEmojiFallback(textTheme.displaySmall),
    headlineLarge: _withEmojiFallback(textTheme.headlineLarge),
    headlineMedium: _withEmojiFallback(textTheme.headlineMedium),
    headlineSmall: _withEmojiFallback(textTheme.headlineSmall),
    titleLarge: _withEmojiFallback(textTheme.titleLarge),
    titleMedium: _withEmojiFallback(textTheme.titleMedium),
    titleSmall: _withEmojiFallback(textTheme.titleSmall),
    bodyLarge: _withEmojiFallback(textTheme.bodyLarge),
    bodyMedium: _withEmojiFallback(textTheme.bodyMedium),
    bodySmall: _withEmojiFallback(textTheme.bodySmall),
    labelLarge: _withEmojiFallback(textTheme.labelLarge),
    labelMedium: _withEmojiFallback(textTheme.labelMedium),
    labelSmall: _withEmojiFallback(textTheme.labelSmall),
  );
}

class GKColors {
  static const primary = Color(0xFF4A7C59);
  static const secondary = Color(0xFF1B5E73);
  static const accent = Color(0xFFC8992E);
  static const background = Color(0xFFF0F4F6);
  static const darkBackground = Color(0xFF1A1F2E);
  static const card = Color(0xFFFFFFFF);
  static const tealIce = Color(0xFFE8F4F8);
  static const danger = Color(0xFFDC2626);
  static const neutral = Color(0xFF6B7280);
}

class AppTheme {
  static TextTheme _textTheme(TextTheme base) {
    final textTheme = GoogleFonts.interTextTheme(base).copyWith(
      displayLarge:
          GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400),
      bodySmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
    return _applyEmojiFallback(textTheme);
  }

  static ThemeData light({
    Color primaryColor = GKColors.primary,
    Color secondaryColor = GKColors.secondary,
    Color accentColor = GKColors.accent,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: GKColors.card,
      ),
      scaffoldBackgroundColor: GKColors.background,
      cardColor: GKColors.card,
      brightness: Brightness.light,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme).apply(
        bodyColor: GKColors.darkBackground,
        displayColor: GKColors.darkBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GKColors.background,
        foregroundColor: GKColors.darkBackground,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primaryColor.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? primaryColor
                : GKColors.neutral,
          );
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryColor,
        selectionColor: primaryColor.withValues(alpha: 0.24),
        selectionHandleColor: primaryColor,
      ),
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: primaryColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: GKColors.neutral),
        hintStyle: const TextStyle(color: GKColors.neutral),
        floatingLabelStyle: TextStyle(color: primaryColor),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData dark({
    Color primaryColor = GKColors.primary,
    Color secondaryColor = GKColors.secondary,
    Color accentColor = GKColors.accent,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
      ),
      scaffoldBackgroundColor: GKColors.darkBackground,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme).apply(
        bodyColor: const Color(0xFFE9EDF7),
        displayColor: const Color(0xFFE9EDF7),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GKColors.darkBackground,
        foregroundColor: Color(0xFFE9EDF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardColor: const Color(0xFF23293D),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Color(0xFF101522),
        indicatorColor: primaryColor.withValues(alpha: 0.28),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFE9EDF7)
                : const Color(0xFFB4BED4),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF23293D),
        labelStyle: const TextStyle(color: Color(0xFFB4BED4)),
        hintStyle: const TextStyle(color: Color(0xFFB4BED4)),
        floatingLabelStyle: TextStyle(color: primaryColor),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF33405D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF33405D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }
}
