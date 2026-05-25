import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Clinical risk bucket inferred from the HAM10000 class code.
///
/// The mapping reflects clinical priority, not biological certainty:
///   - review:        mel, bcc, akiec  (higher concern — escalate)
///   - indeterminate: bkl              (easily confused — caution)
///   - lower:         nv, df, vasc     (lower concern indicator)
enum Risk { lower, indeterminate, review }

Risk riskOf(String classCode) {
  switch (classCode) {
    case 'nv':
    case 'df':
    case 'vasc':
      return Risk.lower;
    case 'bkl':
      return Risk.indeterminate;
    default:
      return Risk.review;
  }
}

/// User-facing risk label. Deliberately non-diagnostic wording.
String riskLabel(Risk r) {
  switch (r) {
    case Risk.lower:
      return 'Lower Concern Indicator';
    case Risk.indeterminate:
      return 'Indeterminate — Review Suggested';
    case Risk.review:
      return 'Requires Clinical Evaluation';
  }
}

String confidenceLabel(double v) {
  if (v >= 0.85) return 'High confidence';
  if (v >= 0.65) return 'Moderate confidence';
  if (v >= 0.45) return 'Low confidence';
  return 'Uncertain';
}

@immutable
class RiskPalette {
  const RiskPalette({
    required this.bg,
    required this.border,
    required this.accent,
    required this.text,
    required this.badgeBg,
  });

  final Color bg;
  final Color border;
  final Color accent;
  final Color text;
  final Color badgeBg;
}

RiskPalette riskPalette(Risk r) {
  switch (r) {
    case Risk.lower:
      return const RiskPalette(
        bg: AppColors.lowerBg,
        border: AppColors.lowerBorder,
        accent: AppColors.lowerAccent,
        text: AppColors.lowerText,
        badgeBg: AppColors.lowerBadgeBg,
      );
    case Risk.indeterminate:
      return const RiskPalette(
        bg: AppColors.indetBg,
        border: AppColors.indetBorder,
        accent: AppColors.indetAccent,
        text: AppColors.indetText,
        badgeBg: AppColors.indetBadgeBg,
      );
    case Risk.review:
      return const RiskPalette(
        bg: AppColors.reviewBg,
        border: AppColors.reviewBorder,
        accent: AppColors.reviewAccent,
        text: AppColors.reviewText,
        badgeBg: AppColors.reviewBadgeBg,
      );
  }
}

/// Small risk-coloured pill. Used inline (e.g. inside the hero card)
/// to label the system's risk categorisation alongside the class name.
class RiskPill extends StatelessWidget {
  const RiskPill({super.key, required this.risk});

  final Risk risk;

  @override
  Widget build(BuildContext context) {
    final p = riskPalette(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.badgeBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Text(
        riskLabel(risk),
        style: TextStyle(
          color: p.text,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
