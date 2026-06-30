import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/theme/app_typography.dart';

class AppTheme {
  static const _seedColor = Color(0xFF2E7D32);
  static const _fontFamily = 'DM Sans';

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    final textTheme = GoogleFonts.dmSansTextTheme();

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: _fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        scrolledUnderElevation: 4,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.14),
        surfaceTintColor: colorScheme.surface,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: TypeScale.appBarTitle,
          fontWeight: FontWeight.w600,
          height: 1.15,
          letterSpacing: -0.3,
          color: colorScheme.onSurface,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: TypeScale.cardTitle,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: GoogleFonts.dmSans(
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
