import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primaryMuted,
    required this.accent,
    required this.accentMuted,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textOnPrimary,
    this.textOnAccent,
    required this.textOnDanger,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color primaryMuted;
  final Color accent;
  final Color accentMuted;
  final Color danger;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textOnPrimary;
  final Color? textOnAccent;
  final Color textOnDanger;

  Color get foregroundOnAccent => textOnAccent ?? textOnPrimary;

  static const defaultTheme = AppPalette(
    bg: Color(0xFF121218),
    surface: Color(0xFF1B1B24),
    surfaceAlt: Color(0xFF0C0C10),
    primary: Color(0xFF9B7EC7),
    primaryMuted: Color(0xFF6E5A90),
    accent: Color(0xFFA8D64B),
    accentMuted: Color(0xFF7A9C36),
    danger: Color(0xFFE5646B),
    textPrimary: Color(0xFFF5F4F8),
    textSecondary: Color(0xFFA8A6B3),
    textDisabled: Color(0xFF6B697A),
    textOnPrimary: Color(0xFF181820),
    textOnAccent: Color(0xFF14210A),
    textOnDanger: Color(0xFF181820),
  );

  static const light = AppPalette(
    bg: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEAEAEA),
    primary: Color(0xFF262626),
    primaryMuted: Color(0xFF595959),
    accent: Color(0xFF404040),
    accentMuted: Color(0xFF595959),
    danger: Color(0xFFB3261E),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF595959),
    textDisabled: Color(0xFF666666),
    textOnPrimary: Color(0xFFFFFFFF),
    textOnDanger: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette(
    bg: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceAlt: Color(0xFF2A2A2A),
    primary: Color(0xFFE0E0E0),
    primaryMuted: Color(0xFFA0A0A0),
    accent: Color(0xFFCFCFCF),
    accentMuted: Color(0xFFBDBDBD),
    danger: Color(0xFFFF6B6B),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFBDBDBD),
    textDisabled: Color(0xFF9E9E9E),
    textOnPrimary: Color(0xFF121212),
    textOnDanger: Color(0xFF121212),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<_AppPaletteTheme>()?.palette ??
      (Theme.of(context).brightness == Brightness.light ? light : dark);
}

class _AppPaletteTheme extends ThemeExtension<_AppPaletteTheme> {
  const _AppPaletteTheme(this.palette);

  final AppPalette palette;

  @override
  _AppPaletteTheme copyWith() => this;

  @override
  _AppPaletteTheme lerp(covariant _AppPaletteTheme? other, double t) => this;
}

extension AppPaletteContext on BuildContext {
  AppPalette get appColors => AppPalette.of(this);
}

enum AppThemeChoice { defaultTheme, light, dark }

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  /// Fully rounded: capsules (status pills, the selected nav item) and
  /// circles (pet avatars). Flutter clamps the radius to half the box, so the
  /// same token produces a stadium on a bar and a circle on a square.
  static const double pill = 999;

  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}

class AppTypography {
  AppTypography._();

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 30 / 24,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 14 / 11,
  );
}

class AppComponents {
  AppComponents._();

  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    elevation: 0,
    textStyle: AppTypography.bodyStrong,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
  );

  static ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    textStyle: AppTypography.bodyStrong,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
  );

  /// Destructive confirm actions. Takes the palette because the danger
  /// tokens differ per theme, unlike the static non-destructive styles.
  static ButtonStyle destructiveButtonFor(AppPalette palette) =>
      OutlinedButton.styleFrom(
        foregroundColor: palette.danger,
        side: BorderSide(color: palette.danger),
        minimumSize: const Size.fromHeight(48),
        textStyle: AppTypography.bodyStrong,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
      );
}

class AppTheme {
  AppTheme._();

  static final ThemeData defaultTheme = _build(
    AppPalette.defaultTheme,
    Brightness.dark,
  );
  static final ThemeData light = _build(AppPalette.light, Brightness.light);
  static final ThemeData dark = _build(AppPalette.dark, Brightness.dark);

  static ThemeData forChoice(AppThemeChoice choice) => switch (choice) {
    AppThemeChoice.defaultTheme => defaultTheme,
    AppThemeChoice.light => light,
    AppThemeChoice.dark => dark,
  };

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final scheme = brightness == Brightness.light
        ? ColorScheme.light(
            primary: palette.primary,
            onPrimary: palette.textOnPrimary,
            primaryContainer: palette.surfaceAlt,
            onPrimaryContainer: palette.textPrimary,
            secondary: palette.accent,
            onSecondary: palette.foregroundOnAccent,
            secondaryContainer: palette.surfaceAlt,
            onSecondaryContainer: palette.textPrimary,
            tertiary: palette.primaryMuted,
            onTertiary: palette.textOnPrimary,
            tertiaryContainer: palette.surfaceAlt,
            onTertiaryContainer: palette.textPrimary,
            error: palette.danger,
            onError: palette.textOnDanger,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            surfaceContainerLowest: palette.surface,
            surfaceContainerLow: palette.bg,
            surfaceContainer: palette.surfaceAlt,
            surfaceContainerHigh: palette.surfaceAlt,
            surfaceContainerHighest: palette.surfaceAlt,
            outline: palette.primaryMuted,
            outlineVariant: palette.surfaceAlt,
            shadow: Colors.black,
            scrim: Colors.black,
            inverseSurface: palette.textPrimary,
            onInverseSurface: palette.surface,
            inversePrimary: palette.primaryMuted,
            surfaceTint: Colors.transparent,
          )
        : ColorScheme.dark(
            primary: palette.primary,
            onPrimary: palette.textOnPrimary,
            primaryContainer: palette.surfaceAlt,
            onPrimaryContainer: palette.textPrimary,
            secondary: palette.accent,
            onSecondary: palette.foregroundOnAccent,
            secondaryContainer: palette.surfaceAlt,
            onSecondaryContainer: palette.textPrimary,
            tertiary: palette.primaryMuted,
            onTertiary: palette.textOnPrimary,
            tertiaryContainer: palette.surfaceAlt,
            onTertiaryContainer: palette.textPrimary,
            error: palette.danger,
            onError: palette.textOnDanger,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            surfaceContainerLowest: palette.bg,
            surfaceContainerLow: palette.surface,
            surfaceContainer: palette.surface,
            surfaceContainerHigh: palette.surfaceAlt,
            surfaceContainerHighest: palette.surfaceAlt,
            outline: palette.primaryMuted,
            outlineVariant: palette.surfaceAlt,
            shadow: Colors.black,
            scrim: Colors.black,
            inverseSurface: palette.textPrimary,
            onInverseSurface: palette.surface,
            inversePrimary: palette.primaryMuted,
            surfaceTint: Colors.transparent,
          );
    final base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[_AppPaletteTheme(palette)],
      useMaterial3: true,
    );
    final textTheme = base.textTheme.copyWith(
      titleLarge: AppTypography.h1.copyWith(color: palette.textPrimary),
      titleMedium: AppTypography.h2.copyWith(color: palette.textPrimary),
      bodyLarge: AppTypography.body.copyWith(color: palette.textPrimary),
      bodyMedium: AppTypography.body.copyWith(color: palette.textPrimary),
      bodySmall: AppTypography.caption.copyWith(color: palette.textSecondary),
      labelLarge: AppTypography.label.copyWith(color: palette.textPrimary),
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(color: palette.surface),
      dialogTheme: DialogThemeData(backgroundColor: palette.surface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      // M3 FABs default to primaryContainer (surfaceAlt here), which almost
      // matches the background; use the brand primary instead.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.textOnPrimary,
        extendedTextStyle: AppTypography.bodyStrong,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.textOnPrimary,
          disabledBackgroundColor: palette.surfaceAlt,
          disabledForegroundColor: palette.textDisabled,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          textStyle: AppTypography.bodyStrong,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.primaryMuted, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          textStyle: AppTypography.bodyStrong,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.body.copyWith(color: palette.textSecondary),
        labelStyle: AppTypography.label.copyWith(color: palette.textSecondary),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: palette.primaryMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: palette.primaryMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: palette.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: palette.danger, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primary
              : palette.primaryMuted,
        ),
        thumbColor: WidgetStatePropertyAll(palette.surface),
      ),
      iconTheme: IconThemeData(color: palette.textSecondary, size: 24),
      dividerColor: palette.primaryMuted,
    );
  }
}
