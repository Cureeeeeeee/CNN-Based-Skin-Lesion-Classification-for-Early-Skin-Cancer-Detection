import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Persistent disclaimer ribbon. Sits in the [Scaffold.bottomNavigationBar]
/// slot of every screen that shows or sets up a prediction. Visible at all
/// times — the clinical safety contract of the prototype.
class DisclaimerRibbon extends StatelessWidget {
  const DisclaimerRibbon({super.key});

  static const String text =
      'Not a medical diagnosis. For research and educational use.';

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: AppColors.safetyBg,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.safetyBorder, width: 1),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 16,
                  color: AppColors.safetyAccent,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: AppColors.safetyText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
