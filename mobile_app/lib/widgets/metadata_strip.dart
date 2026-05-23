import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Slim context strip rendered between AppBar and scroll content.
///
/// Communicates the analysis mode (single / ensemble), model version,
/// and a right-aligned suffix (e.g. inference time). Visually quiet —
/// monospaced for version/IDs to signal "system metadata".
class MetadataStrip extends StatelessWidget {
  const MetadataStrip({
    super.key,
    required this.leadingIcon,
    required this.label,
    this.version,
    this.trailing,
  });

  final IconData leadingIcon;
  final String label;
  final String? version;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(leadingIcon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (version != null) ...[
            const SizedBox(width: 6),
            Text(
              '· ',
              style: AppText.caption.copyWith(color: AppColors.textTertiary),
            ),
            Flexible(
              child: Text(
                version!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.mono.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: AppText.mono.copyWith(color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }
}
