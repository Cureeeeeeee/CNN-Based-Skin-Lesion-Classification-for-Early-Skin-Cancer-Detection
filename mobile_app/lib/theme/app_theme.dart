import 'package:flutter/material.dart';

import 'tokens.dart';

/// Single ThemeData factory for the skin-lesion app.
///
/// Visual register: clinical, calm, trustworthy. Cards use hairline
/// borders rather than shadows; buttons are dense; inputs are quiet.
ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.brandPrimary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.brandPrimary,
    onPrimary: AppColors.textOnBrand,
    secondary: AppColors.brandAccent,
    onSecondary: AppColors.textOnBrand,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: AppColors.background,

    textTheme: const TextTheme(
      displaySmall: AppText.display,
      titleLarge: AppText.title,
      titleMedium: AppText.subtitle,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
      labelSmall: AppText.eyebrow,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: AppColors.brandPrimary,
      foregroundColor: AppColors.textOnBrand,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.textOnBrand, size: 22),
      titleTextStyle: TextStyle(
        color: AppColors.textOnBrand,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    ),

    // Cards: we mostly use the StandardCard widget, but a sane default for
    // any stray Card() avoids a sudden shadow.
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.brandAccentSoft,
      selectedColor: AppColors.brandAccentSoft,
      labelStyle: const TextStyle(
        color: AppColors.brandPrimaryDark,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceMuted,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      hintStyle: const TextStyle(color: AppColors.textTertiary),
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 11.5,
      ),
      prefixIconColor: AppColors.textTertiary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.textOnBrand,
        disabledBackgroundColor: AppColors.borderStrong,
        disabledForegroundColor: AppColors.surface,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          letterSpacing: 0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.brandPrimary,
        side: const BorderSide(color: AppColors.borderStrong, width: 1.2),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandPrimary,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandAccentSoft;
          }
          return AppColors.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandPrimaryDark;
          }
          return AppColors.textSecondary;
        }),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.borderStrong),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.brandPrimary;
        return AppColors.surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.brandPrimary.withValues(alpha: 0.35);
        }
        return AppColors.borderStrong;
      }),
      trackOutlineColor:
          const WidgetStatePropertyAll(Colors.transparent),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brandPrimary,
      linearTrackColor: AppColors.border,
    ),

    iconTheme: const IconThemeData(
      color: AppColors.textSecondary,
      size: 20,
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
    ),

    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.textSecondary,
      collapsedIconColor: AppColors.textTertiary,
      textColor: AppColors.textPrimary,
      collapsedTextColor: AppColors.textPrimary,
      shape: Border(),
      collapsedShape: Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
    ),
  );
}
