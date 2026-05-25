import 'package:flutter/material.dart';

/// Design tokens for the skin-lesion diagnostic-support prototype.
///
/// The palette is institutional navy + teal. Cards use hairline borders
/// instead of shadows. Risk colours appear only when communicating
/// clinical state; they are never used decoratively.
class AppColors {
  AppColors._();

  // ── Brand chrome ──────────────────────────────────────────────────────
  static const Color brandPrimary = Color(0xFF0F4C81);
  static const Color brandPrimaryDark = Color(0xFF0A3A66);
  static const Color brandAccent = Color(0xFF0E7490);
  static const Color brandAccentSoft = Color(0xFFCFFAFE);

  // ── Neutral surfaces ──────────────────────────────────────────────────
  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // ── Text ──────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnBrand = Color(0xFFFFFFFF);

  // ── Risk: higher concern (red, used sparingly) ───────────────────────
  static const Color reviewBg = Color(0xFFFEF2F2);
  static const Color reviewBorder = Color(0xFFFCA5A5);
  static const Color reviewAccent = Color(0xFFB91C1C);
  static const Color reviewText = Color(0xFF7F1D1D);
  static const Color reviewBadgeBg = Color(0xFFFECACA);

  // ── Risk: indeterminate / disagreement (amber) ────────────────────────
  static const Color indetBg = Color(0xFFFFFBEB);
  static const Color indetBorder = Color(0xFFFCD34D);
  static const Color indetAccent = Color(0xFFB45309);
  static const Color indetText = Color(0xFF78350F);
  static const Color indetBadgeBg = Color(0xFFFDE68A);

  // ── Risk: lower concern (cool emerald, harmonises with teal) ─────────
  static const Color lowerBg = Color(0xFFECFDF5);
  static const Color lowerBorder = Color(0xFF86EFAC);
  static const Color lowerAccent = Color(0xFF047857);
  static const Color lowerText = Color(0xFF064E3B);
  static const Color lowerBadgeBg = Color(0xFFA7F3D0);

  // ── Persistent disclaimer ribbon (warm, calmer than indet amber) ─────
  static const Color safetyBg = Color(0xFFFFF7ED);
  static const Color safetyBorder = Color(0xFFFDBA74);
  static const Color safetyAccent = Color(0xFFC2410C);
  static const Color safetyText = Color(0xFF7C2D12);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppRadius {
  AppRadius._();

  static const double sm = 6;
  static const double md = 10;
  static const double lg = 12;
  static const double pill = 999;
}

/// Typography helpers. We keep the system font but enforce a strict scale.
class AppText {
  AppText._();

  static const TextStyle display = TextStyle(
    fontSize: 26,
    height: 1.18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle captionMuted = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  static const TextStyle eyebrow = TextStyle(
    fontSize: 10.5,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New'],
    fontSize: 12.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
