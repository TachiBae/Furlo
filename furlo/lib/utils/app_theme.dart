import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Furlo Design System — Flutter tokens
///
/// Source: "Furlo Design System" spec (colors, type, spacing, shape,
/// elevation, icons, components).
///
/// Open decisions from the spec, resolved here with an explicit assumption
/// so they're easy to flip later:
///   - Font: spec says "Inter or Manrope, no mixing" — defaulted to Inter.
///     Add the `google_fonts` package (or bundle Inter as an asset font) and
///     update `AppTypography._fontFamily` if you want to swap to Manrope.
///   - Hex vs Figma: this file uses the hex values given in the spec.
///   - Info color (#6FA8DC): kept, since nothing in the spec/components uses
///     it yet — drop `AppColors.info` if it's cut for good.
/// ---------------------------------------------------------------------------

class AppColors {
  AppColors._();

  // Surfaces
  static const Color bg = Color(0xFF121218);
  static const Color surface = Color(0xFF1B1B24);
  static const Color surfaceAlt = Color(0xFF0C0C10);

  // Brand
  static const Color primary = Color(0xFF9B7EC7); // Wisteria
  static const Color primaryMuted = Color(0xFF6E5A90);
  static const Color accent = Color(0xFFA8D64B); // Lime
  static const Color accentMuted = Color(0xFF7A9C36);

  // Status
  static const Color warning = Color(0xFFE8B94A);
  static const Color danger = Color(0xFFE5646B);
  static const Color info = Color(0xFF6FA8DC); // optional — see note above

  // Text
  static const Color textPrimary = Color(0xFFF5F4F8);
  static const Color textSecondary = Color(0xFFA8A6B3);
  static const Color textDisabled = Color(0xFF6B697A);
  static const Color textOnPrimary = Color(0xFF181820);
  static const Color textOnAccent = Color(0xFF14210A);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24; // screen margin
  static const double xl = 32;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8; // badges
  static const double md = 12; // inputs/buttons
  static const double lg = 16; // cards

  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
}

class AppElevation {
  AppElevation._();

  /// "Soft" elevation: 0px 2px 8px rgba(0,0,0,.35)
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x59000000), // black @ 35%
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
}

class AppTypography {
  AppTypography._();

  static const String _fontFamily = 'Inter';

  // size / weight / line-height, per spec ("24/600/30" = size/weight/line)
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 30 / 24,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 14 / 11,
    color: AppColors.textSecondary,
  );
}

/// Reusable component styles, so screens don't hand-roll button/input specs.
class AppComponents {
  AppComponents._();

  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textOnPrimary,
    disabledBackgroundColor: AppColors.primaryMuted,
    disabledForegroundColor: AppColors.textDisabled,
    minimumSize: const Size.fromHeight(48),
    elevation: 0,
    textStyle: AppTypography.bodyStrong,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
  );

  static ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary, width: 1.5),
    minimumSize: const Size.fromHeight(48),
    textStyle: AppTypography.bodyStrong,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
  );

  static ButtonStyle destructiveButton = OutlinedButton.styleFrom(
    foregroundColor: AppColors.danger,
    side: const BorderSide(color: AppColors.danger, width: 1.5),
    minimumSize: const Size.fromHeight(48),
    textStyle: AppTypography.bodyStrong,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
  );

  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceAlt,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 14, // ~48h with default text scale
    ),
    hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
    border: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdRadius,
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

/// Full ThemeData wiring, so `MaterialApp(theme: AppTheme.dark)` picks up
/// every token above by default.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.surface,
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.accent,
        onSecondary: AppColors.textOnAccent,
        error: AppColors.danger,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: AppTypography.h1,
        titleMedium: AppTypography.h2,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.caption,
        labelLarge: AppTypography.label,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppComponents.primaryButton,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppComponents.secondaryButton,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textDisabled,
        ),
        thumbColor: const WidgetStatePropertyAll(AppColors.textPrimary),
      ),
      inputDecorationTheme: AppComponents.inputDecorationTheme,
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),
      dividerColor: AppColors.textDisabled,
    );
  }
}
