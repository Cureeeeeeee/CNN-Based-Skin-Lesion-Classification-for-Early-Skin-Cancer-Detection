import 'package:flutter/material.dart';

import '../models/ensemble_result.dart';
import '../models/prediction_result.dart';
import '../models/selected_image.dart';
import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/disclaimer_ribbon.dart';
import '../widgets/metadata_strip.dart';
import '../widgets/risk.dart';
import 'model_comparison_screen.dart';
import 'safety_about_screen.dart';

/// Unified result screen. Renders an ensemble or single-model result with
/// shared chrome (metadata strip, hero, image card, disclaimer ribbon)
/// and conditional sections (disagreement banner, model breakdown — ensemble
/// only).
class ResultScreen extends StatelessWidget {
  const ResultScreen.ensemble({
    super.key,
    required this.selectedImage,
    required EnsembleResult result,
  })  : _ensemble = result,
        _single = null;

  const ResultScreen.single({
    super.key,
    required this.selectedImage,
    required PredictionResult result,
  })  : _ensemble = null,
        _single = result;

  final SelectedImage selectedImage;
  final EnsembleResult? _ensemble;
  final PredictionResult? _single;

  bool get _isEnsemble => _ensemble != null;

  String get _topClass =>
      _isEnsemble ? _ensemble!.predictedClass : _single!.predictedClass;

  String get _topDisplay =>
      _isEnsemble ? _ensemble!.displayLabel : _single!.topCandidates.first.displayLabel;

  double get _topConfidence =>
      _isEnsemble ? _ensemble!.confidence : _single!.confidence;

  List<PredictionCandidate> get _topCandidates =>
      _isEnsemble ? _ensemble!.topCandidates : _single!.topCandidates;

  String get _disclaimer =>
      _isEnsemble ? _ensemble!.disclaimer : _single!.disclaimer;

  bool get _modelsAgree => _isEnsemble ? _ensemble!.modelsAgree : true;

  /// True when the backend applied post-hoc temperature calibration. For
  /// ensembles this requires every loaded model to have a calibration file.
  bool get _calibrated =>
      _isEnsemble ? _ensemble!.calibrated : _single!.calibrated;

  /// Effective risk: disagreement (or indeterminate class) outranks the
  /// raw class-based risk. A disagreeing ensemble is uncertain by definition,
  /// regardless of what its top class would otherwise indicate.
  Risk get _effectiveRisk {
    final classRisk = riskOf(_topClass);
    if (_isEnsemble && !_modelsAgree) return Risk.indeterminate;
    return classRisk;
  }

  void _openAbout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SafetyAboutScreen()),
    );
  }

  void _openModels(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ModelComparisonScreen()),
    );
  }

  void _runNew(BuildContext context) {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final risk = _effectiveRisk;
    final eyebrow = _isEnsemble ? 'ENSEMBLE PREDICTION' : 'RESNET50 PREDICTION';
    final modeLabel = _isEnsemble
        ? '4-model ensemble · ${_ensemble!.modelOutputs.length} models'
        : 'Single model · ResNet50';
    final version = _isEnsemble ? _ensemble!.modelVersion : _single!.model;
    final trailing = _isEnsemble
        ? '${_ensemble!.inferenceTimeMs.toStringAsFixed(0)} ms'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Result'),
        actions: [
          IconButton(
            tooltip: 'About this system',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _openAbout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          MetadataStrip(
            leadingIcon: _isEnsemble
                ? Icons.account_tree_outlined
                : Icons.memory_outlined,
            label: modeLabel,
            version: version,
            trailing: trailing,
            calibrated: _calibrated,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                _RiskHero(
                  eyebrow: eyebrow,
                  risk: risk,
                  classCode: _topClass,
                  classDisplay: _topDisplay,
                  confidence: _topConfidence,
                  isEnsemble: _isEnsemble,
                  modelsAgree: _modelsAgree,
                  modelCount: _isEnsemble ? _ensemble!.modelOutputs.length : 1,
                  agreeCount: _isEnsemble
                      ? _ensemble!.modelOutputs
                          .where((m) => m.predictedClass == _topClass)
                          .length
                      : 1,
                  calibrated: _calibrated,
                ),
                const SizedBox(height: AppSpacing.md),
                _ImageCard(image: selectedImage),
                if (_isEnsemble && !_modelsAgree) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DisagreementBanner(note: _ensemble!.agreementNote),
                ],
                const SizedBox(height: AppSpacing.md),
                _DifferentialCard(
                  candidates: _topCandidates,
                  topClass: _topClass,
                  overrideRisk:
                      _isEnsemble && !_modelsAgree ? Risk.indeterminate : null,
                ),
                if (_isEnsemble) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ModelBreakdownCard(
                    outputs: _ensemble!.modelOutputs,
                    ensembleTopClass: _topClass,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _MetadataFooter(
                  inferenceMs:
                      _isEnsemble ? _ensemble!.inferenceTimeMs : null,
                  version: version,
                  requestId: _isEnsemble ? _ensemble!.requestId : null,
                  isMock: _isEnsemble ? false : _single!.isMock,
                ),
                const SizedBox(height: AppSpacing.md),
                _DisclaimerCard(text: _disclaimer),
                const SizedBox(height: AppSpacing.md),
                if (!_isEnsemble) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    label: const Text('Switch to Ensemble Mode'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                FilledButton.icon(
                  onPressed: () => _runNew(context),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('New Analysis'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _openModels(context),
                  icon: const Icon(Icons.assessment_outlined, size: 18),
                  label: const Text('Model Performance'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const DisclaimerRibbon(),
    );
  }
}

// ── Risk hero ─────────────────────────────────────────────────────────────────

class _RiskHero extends StatelessWidget {
  const _RiskHero({
    required this.eyebrow,
    required this.risk,
    required this.classCode,
    required this.classDisplay,
    required this.confidence,
    required this.isEnsemble,
    required this.modelsAgree,
    required this.modelCount,
    required this.agreeCount,
    required this.calibrated,
  });

  final String eyebrow;
  final Risk risk;
  final String classCode;
  final String classDisplay;
  final double confidence;
  final bool isEnsemble;
  final bool modelsAgree;
  final int modelCount;
  final int agreeCount;
  final bool calibrated;

  @override
  Widget build(BuildContext context) {
    final p = riskPalette(risk);
    final clamped = confidence.clamp(0.0, 1.0).toDouble();

    return StatusCard(
      background: p.bg,
      accent: p.accent,
      border: p.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  eyebrow,
                  style: AppText.eyebrow.copyWith(color: p.accent),
                ),
              ),
              if (isEnsemble) _AgreementBadge(palette: p, agreeCount: agreeCount, total: modelCount, allAgree: modelsAgree)
              else _SingleModelBadge(palette: p),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            classCode.toUpperCase(),
            style: AppText.mono.copyWith(
              color: p.accent,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            classDisplay,
            style: AppText.display.copyWith(color: p.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          RiskPill(risk: risk),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${(clamped * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: p.text,
                  height: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  confidenceLabel(clamped),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: clamped,
              backgroundColor: p.badgeBg,
              valueColor: AlwaysStoppedAnimation<Color>(p.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            calibrated
                ? 'Temperature-calibrated model-estimated confidence on '
                    'the validation set. Not a probability of disease.'
                : 'Confidence reflects model certainty, not the probability '
                    'of a correct diagnosis.',
            style: AppText.caption.copyWith(
              color: p.text.withValues(alpha: 0.75),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgreementBadge extends StatelessWidget {
  const _AgreementBadge({
    required this.palette,
    required this.agreeCount,
    required this.total,
    required this.allAgree,
  });

  final RiskPalette palette;
  final int agreeCount;
  final int total;
  final bool allAgree;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.badgeBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            allAgree
                ? Icons.verified_outlined
                : Icons.alt_route_outlined,
            size: 13,
            color: palette.accent,
          ),
          const SizedBox(width: 4),
          Text(
            '$agreeCount / $total agree',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleModelBadge extends StatelessWidget {
  const _SingleModelBadge({required this.palette});

  final RiskPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.badgeBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'Single model',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: palette.text,
        ),
      ),
    );
  }
}

// ── Image card ────────────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.image});

  final SelectedImage image;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Image.memory(image.bytes, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    image.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Disagreement banner ───────────────────────────────────────────────────────

class _DisagreementBanner extends StatelessWidget {
  const _DisagreementBanner({this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    return StatusCard(
      background: AppColors.indetBg,
      accent: AppColors.indetAccent,
      border: AppColors.indetBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.alt_route_outlined,
                size: 18,
                color: AppColors.indetAccent,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Models Disagree',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: AppColors.indetText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note ??
                "The models did not converge on a single top prediction. "
                    "The ensemble's weighted result above is shown for "
                    "reference.",
            style: const TextStyle(
              color: AppColors.indetText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.indetBadgeBg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Text(
              'Clinical review recommended',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.indetText,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Differential card ─────────────────────────────────────────────────────────

class _DifferentialCard extends StatelessWidget {
  const _DifferentialCard({
    required this.candidates,
    required this.topClass,
    this.overrideRisk,
  });

  final List<PredictionCandidate> candidates;
  final String topClass;
  final Risk? overrideRisk;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            label: 'Differential — Top 3',
            icon: Icons.list_alt_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < candidates.length; i++) ...[
            _DifferentialRow(
              candidate: candidates[i],
              isTop: i == 0,
              risk: overrideRisk ?? riskOf(candidates[i].className),
            ),
            if (i < candidates.length - 1)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _DifferentialRow extends StatelessWidget {
  const _DifferentialRow({
    required this.candidate,
    required this.isTop,
    required this.risk,
  });

  final PredictionCandidate candidate;
  final bool isTop;
  final Risk risk;

  @override
  Widget build(BuildContext context) {
    final p = riskPalette(risk);
    final value = candidate.confidence.clamp(0.0, 1.0).toDouble();
    final barColor = isTop ? p.accent : AppColors.borderStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              candidate.className.toUpperCase(),
              style: AppText.mono.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10.5,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).toStringAsFixed(1)}%',
              style: AppText.mono.copyWith(
                color: isTop ? p.text : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          candidate.displayLabel,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isTop ? FontWeight.w800 : FontWeight.w600,
            color: isTop ? AppColors.textPrimary : AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            minHeight: isTop ? 7 : 5,
            value: value,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

// ── Model breakdown ───────────────────────────────────────────────────────────

class _ModelBreakdownCard extends StatelessWidget {
  const _ModelBreakdownCard({
    required this.outputs,
    required this.ensembleTopClass,
  });

  final List<ModelPrediction> outputs;
  final String ensembleTopClass;

  @override
  Widget build(BuildContext context) {
    final sorted = [...outputs]..sort((a, b) => b.weight.compareTo(a.weight));
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
            label: 'Model Outputs',
            icon: Icons.hub_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _ModelRow(
              output: sorted[i],
              agrees: sorted[i].predictedClass == ensembleTopClass,
            ),
          ],
        ],
      ),
    );
  }
}

class _ModelRow extends StatefulWidget {
  const _ModelRow({required this.output, required this.agrees});

  final ModelPrediction output;
  final bool agrees;

  @override
  State<_ModelRow> createState() => _ModelRowState();
}

class _ModelRowState extends State<_ModelRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final risk = riskOf(widget.output.predictedClass);
    final p = riskPalette(risk);
    final conf = widget.output.confidence.clamp(0.0, 1.0).toDouble();

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.output.model,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.brandAccentSoft,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  '${(widget.output.weight * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brandPrimaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                widget.agrees
                                    ? Icons.check_circle_outline
                                    : Icons.alt_route_outlined,
                                size: 12,
                                color: widget.agrees
                                    ? AppColors.lowerAccent
                                    : AppColors.indetAccent,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.output.displayLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: p.accent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${(conf * 100).toStringAsFixed(1)}%',
                      style: AppText.mono.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: conf,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(p.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.md,
              top: 2,
            ),
            child: Column(
              children: [
                for (var i = 0; i < widget.output.topCandidates.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          child: Text(
                            '${i + 1}.',
                            style: AppText.captionMuted,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${widget.output.topCandidates[i].className.toUpperCase()} — ${widget.output.topCandidates[i].displayLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${(widget.output.topCandidates[i].confidence * 100).toStringAsFixed(1)}%',
                          style: AppText.mono.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Metadata footer ───────────────────────────────────────────────────────────

class _MetadataFooter extends StatelessWidget {
  const _MetadataFooter({
    required this.inferenceMs,
    required this.version,
    required this.requestId,
    required this.isMock,
  });

  final double? inferenceMs;
  final String version;
  final String? requestId;
  final bool isMock;

  @override
  Widget build(BuildContext context) {
    final shortId = requestId == null
        ? null
        : (requestId!.length > 8 ? requestId!.substring(0, 8) : requestId!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          if (inferenceMs != null)
            MetaChip(
              icon: Icons.timer_outlined,
              label: '${inferenceMs!.toStringAsFixed(0)} ms',
              mono: true,
            ),
          MetaChip(
            icon: Icons.label_outline,
            label: version,
            mono: true,
          ),
          if (shortId != null)
            MetaChip(
              icon: Icons.fingerprint_outlined,
              label: shortId,
              mono: true,
            ),
          if (isMock)
            const MetaChip(
              icon: Icons.science_outlined,
              label: 'mock',
              mono: true,
            ),
        ],
      ),
    );
  }
}

// ── Disclaimer (within scroll) ────────────────────────────────────────────────

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return StatusCard(
      background: AppColors.safetyBg,
      accent: AppColors.safetyAccent,
      border: AppColors.safetyBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 16,
            color: AppColors.safetyAccent,
          ),
          const SizedBox(width: AppSpacing.sm),
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
      ),
    );
  }
}
