import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/disclaimer_ribbon.dart';
import 'model_comparison_screen.dart';

class SafetyAboutScreen extends StatelessWidget {
  const SafetyAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About This System')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            const _IdentityCard(),
            const SizedBox(height: AppSpacing.md),
            const _IntendedUseCard(),
            const SizedBox(height: AppSpacing.md),
            const _NotIntendedCard(),
            const SizedBox(height: AppSpacing.md),
            const _DatasetCard(),
            const SizedBox(height: AppSpacing.md),
            const _ModelsCard(),
            const SizedBox(height: AppSpacing.md),
            const _CalibrationCard(),
            const SizedBox(height: AppSpacing.md),
            const _AttentionCard(),
            const SizedBox(height: AppSpacing.md),
            const _LicenseCard(),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ModelComparisonScreen(),
                ),
              ),
              icon: const Icon(Icons.assessment_outlined, size: 18),
              label: const Text('View Model Performance & Limitations'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DisclaimerRibbon(),
    );
  }
}

// ── Identity ──────────────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandAccentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.biotech_outlined,
                  color: AppColors.brandPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skin Lesion Diagnostic-Support Prototype',
                      style: AppText.title,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Research-grade · CNN ensemble · HAM10000',
                      style: AppText.captionMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          const _KvRow(label: 'Version', value: 'v1.0 (ensemble-v1)'),
          const SizedBox(height: 6),
          const _KvRow(label: 'Architecture', value: 'Weighted 4-CNN ensemble'),
          const SizedBox(height: 6),
          const _KvRow(label: 'Status', value: 'Research prototype'),
          const SizedBox(height: 6),
          const _KvRow(label: 'Regulatory', value: 'Not cleared for clinical use'),
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AppText.caption.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppText.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Intended use ──────────────────────────────────────────────────────────────

class _IntendedUseCard extends StatelessWidget {
  const _IntendedUseCard();

  @override
  Widget build(BuildContext context) {
    return StatusCard(
      background: AppColors.brandAccentSoft,
      accent: AppColors.brandAccent,
      border: AppColors.brandAccent.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: AppColors.brandAccent,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Intended Use',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: AppColors.brandPrimaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This system is designed to support research, education, and '
            'clinical review of skin lesion images. It produces probabilistic '
            'predictions across seven HAM10000 categories and surfaces '
            'per-model agreement as a confidence signal.',
            style: AppText.body.copyWith(
              color: AppColors.brandPrimaryDark,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Not intended for ──────────────────────────────────────────────────────────

class _NotIntendedCard extends StatelessWidget {
  const _NotIntendedCard();

  @override
  Widget build(BuildContext context) {
    return StatusCard(
      background: AppColors.safetyBg,
      accent: AppColors.safetyAccent,
      border: AppColors.safetyBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.do_not_disturb_alt_outlined,
                size: 18,
                color: AppColors.safetyAccent,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Not Intended For',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: AppColors.safetyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This system is NOT a medical diagnostic device. It must not be '
            'used to diagnose disease, determine treatment, or replace '
            'evaluation by a qualified healthcare professional. It has not '
            'been cleared by any regulatory body for clinical use.',
            style: AppText.body.copyWith(
              color: AppColors.safetyText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dataset ───────────────────────────────────────────────────────────────────

class _DatasetCard extends StatelessWidget {
  const _DatasetCard();

  static const _classes = <_ClassEntry>[
    _ClassEntry('akiec', 'Actinic keratoses / intraepithelial carcinoma'),
    _ClassEntry('bcc', 'Basal cell carcinoma'),
    _ClassEntry('bkl', 'Benign keratosis-like lesions'),
    _ClassEntry('df', 'Dermatofibroma'),
    _ClassEntry('mel', 'Melanoma'),
    _ClassEntry('nv', 'Melanocytic nevi'),
    _ClassEntry('vasc', 'Vascular lesions'),
  ];

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            label: 'Dataset',
            icon: Icons.dataset_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'HAM10000 ("Human Against Machine") — 10,015 dermoscopy images '
            'with seven lesion categories. Split into train / validation / '
            'test sets; class weights compensate for heavy nv skew.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Classes',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          for (final c in _classes) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      c.code,
                      style: AppText.mono.copyWith(
                        color: AppColors.brandPrimaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(c.name, style: AppText.body),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassEntry {
  const _ClassEntry(this.code, this.name);
  final String code;
  final String name;
}

// ── Models ────────────────────────────────────────────────────────────────────

class _ModelsCard extends StatelessWidget {
  const _ModelsCard();

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            label: 'Models',
            icon: Icons.hub_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Four CNN backbones via timm, fine-tuned on HAM10000 with class '
            'weighting and early stopping on validation macro-F1. The 4-model '
            'ensemble combines their softmax outputs by weighted average.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          _modelRow('ResNet50', 'weight 0.38 · default single-model · T=1.539'),
          _modelRow('DenseNet121', 'weight 0.37 · strongest melanoma recall · T=1.689'),
          _modelRow('EfficientNet-B0', 'weight 0.20 · strongest akiec recall · T=2.027'),
          _modelRow('MobileNetV3 Small', 'weight 0.05 · low-cost backbone · T=1.655'),
        ],
      ),
    );
  }

  Widget _modelRow(String name, String note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: AppSpacing.sm),
            child: Icon(
              Icons.circle,
              size: 5,
              color: AppColors.textTertiary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(note, style: AppText.captionMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calibration ───────────────────────────────────────────────────────────────

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard();

  @override
  Widget build(BuildContext context) {
    return const StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            label: 'Confidence Calibration',
            icon: Icons.thermostat_outlined,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            "Each model's logits are divided by a fitted scalar "
            'temperature before softmax. The temperatures are fit on the '
            'HAM10000 validation split to minimise negative log-likelihood. '
            'The T values shown above in the Models section are the fitted '
            'temperatures; all models were overconfident (T > 1) before '
            'calibration. Top-1 predictions are unchanged — calibration '
            'only reshapes the confidence distribution.',
            style: AppText.bodyMuted,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Confidence values shown by this app are temperature-calibrated '
            'model-estimated confidence on the validation set. They are not '
            'clinical probabilities of disease and do not generalise to '
            'out-of-distribution images.',
            style: AppText.captionMuted,
          ),
        ],
      ),
    );
  }
}

// ── Model attention (Grad-CAM) ────────────────────────────────────────────────

class _AttentionCard extends StatelessWidget {
  const _AttentionCard();

  @override
  Widget build(BuildContext context) {
    return const StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            label: 'Model Attention (Grad-CAM)',
            icon: Icons.visibility_outlined,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Single-model analyses expose an Attention toggle on the image '
            'card. When enabled, the app fetches a Grad-CAM overlay from '
            'the backend showing which image regions had the largest '
            'influence on the model\'s predicted class.',
            style: AppText.bodyMuted,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Grad-CAM produces a class-discriminative localisation map: '
            'it indicates which image regions had the largest influence on '
            'the model\'s prediction. It does not identify the location of '
            'pathology, does not validate the prediction, and does not '
            'constitute a clinical annotation. A focused, sensible-looking '
            'heatmap can still accompany a wrong prediction. Use it as a '
            'debugging or exploration aid only.',
            style: AppText.captionMuted,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Available in two places: the single-model (ResNet50) image-card '
            'toggle, and — new — per-model attention in ensemble mode. Expand '
            'any model in the breakdown to load that model\'s overlay (all four '
            'are fetched together once and cached). Each backbone uses its own '
            'deepest spatial layer. Overlays are rendered server-side and '
            'decoded by the client.',
            style: AppText.captionMuted,
          ),
        ],
      ),
    );
  }
}

// ── License & attribution ─────────────────────────────────────────────────────

class _LicenseCard extends StatelessWidget {
  const _LicenseCard();

  @override
  Widget build(BuildContext context) {
    return const StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            label: 'License & Attribution',
            icon: Icons.gavel_outlined,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Code: MIT License (Copyright © 2026 Jiahao Liu). See LICENSE in '
            'the repository.',
            style: AppText.bodyMuted,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Trained weights: derivative of HAM10000 (CC BY-NC 4.0) — academic '
            '/ research use only, no commercial use.',
            style: AppText.bodyMuted,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Required citation (HAM10000):',
            style: AppText.bodyMuted,
          ),
          SizedBox(height: 2),
          Text(
            'Tschandl P., Rosendahl C. & Kittler H. The HAM10000 dataset, a '
            'large collection of multi-source dermatoscopic images of common '
            'pigmented skin lesions. Scientific Data 5, 180161 (2018). '
            'doi:10.1038/sdata.2018.161',
            style: AppText.captionMuted,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'External validation set (ISIC 2019): Hospital Clínic de Barcelona '
            '/ International Skin Imaging Collaboration. CC BY-NC 4.0.',
            style: AppText.captionMuted,
          ),
        ],
      ),
    );
  }
}

