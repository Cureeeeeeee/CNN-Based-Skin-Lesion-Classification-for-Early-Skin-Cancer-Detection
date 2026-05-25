// mobile_app/lib/theme/design_tokens.dart
//
// DermaSense Apple-Health-inspired clinical design system.
// Mirrors docs/ui_redesign/mockup_stage2_reference.html CSS variables.
// Imported by all redesigned screens; original tokens.dart and
// app_theme.dart remain for screens not yet migrated.
//
// Color philosophy: NO traffic-light coloring. Use warm gray for
// benign, warm yellow-amber for monitoring, soft burgundy for urgent.
// Convey diagnostic state through wording + subtle tinted backgrounds,
// not saturation jumps.
//
// FONT NOTE (follow-up, not Stage 1): the type ramp names the 'Inter'
// family to match the mockup. Inter is NOT bundled yet — Stage 1 relies
// on the system fallback (Apple devices ship San Francisco, which renders
// similarly; other platforms fall back to the default sans). Adding the
// `google_fonts` package / bundling Inter is a deliberate later task so
// this stage stays a pure-Dart, no-pubspec-change diff.

import 'package:flutter/material.dart';

abstract class DSColors {
  // Primary (clinical green-blue)
  static const primary50 = Color(0xFFE8F4F1);
  static const primary100 = Color(0xFFC5E4DD);
  static const primary500 = Color(0xFF2A8F7A);
  static const primary700 = Color(0xFF1F6A5B);
  static const primary900 = Color(0xFF0F3D34);

  // Neutral (warm gray)
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFFAFAF8);
  static const neutral100 = Color(0xFFF2F1ED);
  static const neutral300 = Color(0xFFD6D4CE);
  static const neutral500 = Color(0xFF8B8A85);
  static const neutral700 = Color(0xFF4A4A47);
  static const neutral900 = Color(0xFF1C1C1A);

  // Diagnostic states (urgent darkened to A82E2E per design feedback)
  static const stateBenign50 = Color(0xFFE8F4F1);
  static const stateBenign500 = Color(0xFF2A8F7A);
  static const stateWatch50 = Color(0xFFFEF6E3);
  static const stateWatch500 = Color(0xFFC68E14);
  static const stateUrgent50 = Color(0xFFFBEAEA);
  static const stateUrgent500 = Color(0xFFA82E2E);
  static const stateUrgent900 = Color(0xFF5A1B1B);

  // Info (badges)
  static const info50 = Color(0xFFECF1FA);
  static const info500 = Color(0xFF3A6FB8);

  // Class colors for Top-3 stacked bar (reuse state hues, harmonized)
  static const classAkiec = Color(0xFFA82E2E);
  static const classBcc = Color(0xFFC68E14);
  static const classBkl = Color(0xFF8B8A85);
  static const classOther = Color(0xFFD6D4CE);
}

abstract class DSSpacing {
  static const double s1 = 4.0;
  static const double s2 = 8.0;
  static const double s3 = 12.0;
  static const double s4 = 16.0;
  static const double s5 = 24.0;
  static const double s6 = 32.0;
  static const double s7 = 48.0;
  static const double s8 = 64.0;

  static const double cardPad = 24.0;
  static const double cardGap = 16.0;
  static const double pageHPadding = 20.0;
  static const double sectionGap = 32.0;
}

abstract class DSRadius {
  static const double card = 16.0;
  static const double pill = 999.0;
  static const double input = 10.0;
  static const double btn = 12.0;
}

abstract class DSBorders {
  static const Color hairline = DSColors.neutral100;
  static const Color hover = DSColors.neutral300;
  static const double width = 1.0;
}

/// Inter font family with -apple-system fallback. The Flutter web
/// build will load Inter from Google Fonts; on mobile/desktop, the
/// system falls back gracefully. Add `google_fonts` package only if
/// it's already a dependency — otherwise rely on the system Inter
/// (Apple devices ship San Francisco which renders similarly).
abstract class DSText {
  // Display L — Hero numbers (e.g. confidence 77.7%)
  static const TextStyle displayL = TextStyle(
    fontFamily: 'Inter',
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.05,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Display M — Screen titles
  static const TextStyle displayM = TextStyle(
    fontFamily: 'Inter',
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.1,
  );

  // Heading L — Card titles
  static const TextStyle headingL = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.2,
  );

  // Heading M — Sub-section titles
  static const TextStyle headingM = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // Body L — default body
  static const TextStyle bodyL = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // Body M — secondary
  static const TextStyle bodyM = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // Label — chip / pill / small bold labels
  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  // Label uppercase — for section labels like "ANALYSIS MODE"
  static const TextStyle labelUp = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: DSColors.neutral500,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: DSColors.neutral500,
    height: 1.5,
  );

  // Tabular — numbers in tables (same family, tabular nums)
  static const TextStyle tabular = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
