import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/disclaimer_ribbon.dart';
import '../widgets/risk.dart';

/// Per-model and per-class performance on the HAM10000 held-out test split.
/// Values are sourced from `runs/<model>/test_metrics.json`.
class ModelComparisonScreen extends StatelessWidget {
  const ModelComparisonScreen({super.key});

  static const _models = <_ModelMetric>[
    _ModelMetric(
      name: 'ResNet50',
      shortCode: 'RN',
      accuracy: 0.8022,
      macroF1: 0.6903,
      weight: 0.38,
      isDefault: true,
    ),
    _ModelMetric(
      name: 'DenseNet121',
      shortCode: 'DN',
      accuracy: 0.7964,
      macroF1: 0.6896,
      weight: 0.37,
      isDefault: false,
    ),
    _ModelMetric(
      name: 'EfficientNet-B0',
      shortCode: 'EN',
      accuracy: 0.7745,
      macroF1: 0.6477,
      weight: 0.20,
      isDefault: false,
    ),
    _ModelMetric(
      name: 'MobileNetV3 Small',
      shortCode: 'MN',
      accuracy: 0.6776,
      macroF1: 0.5726,
      weight: 0.05,
      isDefault: false,
    ),
  ];

  // Per-class recall per model, sourced from test_metrics.json.
  // Order: RN, DN, EN, MN — matches _models order.
  static const _perClassRecall = <_ClassRecall>[
    _ClassRecall('mel', 'Melanoma', [0.548, 0.585, 0.574, 0.569]),
    _ClassRecall('bcc', 'Basal cell carcinoma', [0.868, 0.846, 0.692, 0.868]),
    _ClassRecall('akiec', 'Actinic / intraepithelial carcinoma',
        [0.596, 0.596, 0.692, 0.577]),
    _ClassRecall('bkl', 'Benign keratosis-like lesions',
        [0.658, 0.749, 0.628, 0.472]),
    _ClassRecall('df', 'Dermatofibroma', [0.800, 0.680, 0.720, 0.720]),
    _ClassRecall('nv', 'Melanocytic nevi', [0.869, 0.843, 0.840, 0.712]),
    _ClassRecall('vasc', 'Vascular lesions', [0.963, 0.963, 0.926, 1.000]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Performance')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: const [
            _OverviewCard(),
            SizedBox(height: AppSpacing.md),
            _ModelSummaryCard(models: _models),
            SizedBox(height: AppSpacing.md),
            _PerClassRecallCard(
              models: _models,
              rows: _perClassRecall,
            ),
            SizedBox(height: AppSpacing.md),
            _LimitationsCard(),
          ],
        ),
      ),
      bottomNavigationBar: const DisclaimerRibbon(),
    );
  }
}

class _ModelMetric {
  const _ModelMetric({
    required this.name,
    required this.shortCode,
    required this.accuracy,
    required this.macroF1,
    required this.weight,
    required this.isDefault,
  });

  final String name;
  final String shortCode;
  final double accuracy;
  final double macroF1;
  final double weight;
  final bool isDefault;
}

class _ClassRecall {
  const _ClassRecall(this.code, this.displayName, this.values);
  final String code;
  final String displayName;
  final List<double> values; // RN, DN, EN, MN
}

// ── Overview ──────────────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context) {
    return const StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            label: 'Test Set Evaluation',
            icon: Icons.science_outlined,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'All four CNN backbones were trained on HAM10000 and evaluated on '
            'the same held-out test split (1,734 images). The 4-model ensemble '
            'combines them by weighted average; weights are derived from '
            'validation macro-F1 and per-class recall.',
            style: AppText.bodyMuted,
          ),
        ],
      ),
    );
  }
}

// ── Model summary table ───────────────────────────────────────────────────────

class _ModelSummaryCard extends StatelessWidget {
  const _ModelSummaryCard({required this.models});

  final List<_ModelMetric> models;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            label: 'Model Summary',
            icon: Icons.table_chart_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          const _SummaryHeaderRow(),
          const Divider(height: 1),
          for (final m in models) ...[
            _SummaryRow(metric: m),
            const Divider(height: 1),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Acc = overall accuracy · F1 = macro F1 · Wt = ensemble weight',
            style: AppText.captionMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Single-model /predict uses ResNet50 v2 (focal loss + balanced '
            'sampler): test mel recall 73.40%, F1 70.08%. The 4-model ensemble '
            'continues to use v1 ResNet50 for stability (Phase C Stage B '
            'decision; see docs/phase_c_stage_b_ensemble_review.md).',
            style: AppText.captionMuted,
          ),
        ],
      ),
    );
  }
}

class _SummaryHeaderRow extends StatelessWidget {
  const _SummaryHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Model',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _headerCell('ACC'),
          _headerCell('F1'),
          _headerCell('WT'),
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return SizedBox(
      width: 54,
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.metric});

  final _ModelMetric metric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    metric.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (metric.isDefault) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.brandAccentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'default',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandPrimaryDark,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _valueCell('${(metric.accuracy * 100).toStringAsFixed(1)}%'),
          _valueCell('${(metric.macroF1 * 100).toStringAsFixed(1)}%'),
          _valueCell('${(metric.weight * 100).toStringAsFixed(0)}%',
              primary: true),
        ],
      ),
    );
  }

  Widget _valueCell(String text, {bool primary = false}) {
    return SizedBox(
      width: 54,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: AppText.mono.copyWith(
          color: primary ? AppColors.brandPrimaryDark : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ── Per-class recall table ────────────────────────────────────────────────────

class _PerClassRecallCard extends StatelessWidget {
  const _PerClassRecallCard({required this.models, required this.rows});

  final List<_ModelMetric> models;
  final List<_ClassRecall> rows;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            label: 'Per-Class Recall',
            icon: Icons.percent_outlined,
          ),
          const SizedBox(height: 4),
          const Text(
            'How often the model identifies each class when it is present. '
            'Lower recall = the system misses more cases of that class.',
            style: AppText.captionMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          _RecallHeader(models: models),
          const Divider(height: 1),
          for (final row in rows) ...[
            _RecallRow(row: row),
            const Divider(height: 1),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Row(
            children: [
              Icon(Icons.warning_amber_outlined,
                  size: 13, color: AppColors.indetAccent),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Values below 70% are flagged. Melanoma recall is the most '
                  'clinically critical and remains below 60% across all models.',
                  style: AppText.captionMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Per-class recall shown is for v1 baseline models (ensemble path). '
            'v2 ResNet50 (single-model deployment): mel 73.40%, akiec 69.23%, '
            'bcc 82.42%.',
            style: AppText.captionMuted,
          ),
        ],
      ),
    );
  }
}

class _RecallHeader extends StatelessWidget {
  const _RecallHeader({required this.models});

  final List<_ModelMetric> models;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const SizedBox(
            width: 48,
            child: Text(
              'CLASS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final m in models)
            Expanded(
              child: Text(
                m.shortCode,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecallRow extends StatelessWidget {
  const _RecallRow({required this.row});

  final _ClassRecall row;

  @override
  Widget build(BuildContext context) {
    final risk = riskOf(row.code);
    final p = riskPalette(risk);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: p.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      row.code,
                      style: AppText.mono.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              for (final v in row.values)
                Expanded(
                  child: _ValueWithFlag(value: v),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              row.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.captionMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueWithFlag extends StatelessWidget {
  const _ValueWithFlag({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final flagged = value < 0.70;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (flagged)
          const Icon(
            Icons.warning_amber_outlined,
            size: 11,
            color: AppColors.indetAccent,
          ),
        if (flagged) const SizedBox(width: 3),
        Text(
          (value * 100).toStringAsFixed(0),
          style: AppText.mono.copyWith(
            color: flagged ? AppColors.indetText : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ── Limitations ──────────────────────────────────────────────────────────────

class _LimitationsCard extends StatelessWidget {
  const _LimitationsCard();

  static const _items = <String>[
    'v2 ResNet50 is the production single model (/predict); the 4-model '
        'ensemble (/predict-ensemble) uses v1 ResNet50. Phase C Stage B showed '
        'swapping v2 into the ensemble dilutes the melanoma signal.',
    'Melanoma recall: v2 ResNet50 (deployed single-model) reaches 73.40% '
        'in-distribution; v1 baselines (ensemble members) range 54-59%. '
        'Roughly 1 in 4 melanoma cases in the test set still missed by the '
        'v2 winner.',
    'HAM10000 contains predominantly Fitzpatrick skin types I–III. '
        'Performance on darker skin tones is not characterised.',
    'Phone-camera images differ optically from dermoscopic images and may '
        'produce less reliable predictions.',
    'The dataset is heavily skewed toward melanocytic nevi (nv). Rare '
        'classes receive less training signal and have higher variance.',
    'External validation performed on a HAM-disjoint subset of ISIC 2019 '
        '(4,353 images). v2 single mel recall drops from 73.40% (HAM) to '
        '37.09% (ISIC); v1 ensemble F1 drops 74.10% to 41.24%. The strong '
        'in-distribution numbers do not generalise. See '
        'docs/phase_e_external_validation.md for the full audit.',
  ];

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
                Icons.shield_outlined,
                size: 18,
                color: AppColors.safetyAccent,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Known Limitations',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: AppColors.safetyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in _items) ...[
            _LimitationItem(text: item),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _LimitationItem extends StatelessWidget {
  const _LimitationItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: AppSpacing.sm),
          child: Icon(
            Icons.circle,
            size: 5,
            color: AppColors.safetyAccent,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.safetyText,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
