import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Neutral, hairline-bordered card. Default visual container for
/// non-state content (sections, lists, controls).
class StandardCard extends StatelessWidget {
  const StandardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Status card with a 4px left accent strip and tinted background.
/// Used for: risk hero, disagreement banner, safety panels.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.child,
    required this.background,
    required this.accent,
    this.border,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final Color background;
  final Color accent;
  final Color? border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border ?? accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header with optional leading icon. Used inside StandardCards.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            label,
            style: AppText.subtitle.copyWith(color: AppColors.textPrimary),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Small key-value chip with a leading icon. Used in the metadata footer.
class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 5),
        Text(
          label,
          style: mono
              ? AppText.mono.copyWith(color: AppColors.textTertiary)
              : AppText.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
