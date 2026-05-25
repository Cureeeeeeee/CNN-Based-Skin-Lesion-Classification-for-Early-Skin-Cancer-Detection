import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/cam_ensemble_response.dart';
import '../models/ensemble_result.dart';
import '../models/prediction_result.dart';
import '../models/selected_image.dart';
import '../services/prediction_api.dart';
import '../theme/design_tokens.dart';
import 'model_comparison_screen.dart';
import 'safety_about_screen.dart';

/// Redesigned result screen — mockup Screen 3 (data-screen-key="result").
/// Visual-only rewrite. The `.single` / `.ensemble` constructors, all state
/// (single-model attention toggle + lazy /predict-cam fetch; ensemble per-model
/// /predict-cam-ensemble fetch + cache), and navigation are preserved.
class ResultScreen extends StatefulWidget {
  const ResultScreen.ensemble({
    super.key,
    required this.selectedImage,
    required EnsembleResult result,
    this.apiBaseUrl,
  })  : ensembleResult = result,
        singleResult = null;

  const ResultScreen.single({
    super.key,
    required this.selectedImage,
    required PredictionResult result,
    this.apiBaseUrl,
  })  : ensembleResult = null,
        singleResult = result;

  final SelectedImage selectedImage;
  final EnsembleResult? ensembleResult;
  final PredictionResult? singleResult;
  final String? apiBaseUrl;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Uint8List? _heatmapBytes;
  bool _heatmapLoading = false;
  String? _heatmapError;
  bool _attentionOn = false;

  bool get _isEnsemble => widget.ensembleResult != null;
  bool get _isMock => _isEnsemble ? false : widget.singleResult!.isMock;

  bool get _camAvailable =>
      !_isEnsemble &&
      !_isMock &&
      widget.apiBaseUrl != null &&
      widget.apiBaseUrl!.isNotEmpty;

  bool get _ensembleCamAvailable =>
      _isEnsemble &&
      widget.apiBaseUrl != null &&
      widget.apiBaseUrl!.isNotEmpty;

  String get _topClass => _isEnsemble
      ? widget.ensembleResult!.predictedClass
      : widget.singleResult!.predictedClass;

  String get _topDisplay => _isEnsemble
      ? widget.ensembleResult!.displayLabel
      : widget.singleResult!.topCandidates.first.displayLabel;

  double get _topConfidence => _isEnsemble
      ? widget.ensembleResult!.confidence
      : widget.singleResult!.confidence;

  List<PredictionCandidate> get _topCandidates => _isEnsemble
      ? widget.ensembleResult!.topCandidates
      : widget.singleResult!.topCandidates;

  bool get _calibrated => _isEnsemble
      ? widget.ensembleResult!.calibrated
      : widget.singleResult!.calibrated;

  double get _temperature =>
      _isEnsemble ? 1.0 : widget.singleResult!.temperature;

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SafetyAboutScreen()),
    );
  }

  void _openModels() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ModelComparisonScreen()),
    );
  }

  void _runNew() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _toggleAttention() async {
    if (_heatmapBytes != null) {
      setState(() => _attentionOn = !_attentionOn);
      return;
    }
    setState(() {
      _attentionOn = true;
      _heatmapLoading = true;
      _heatmapError = null;
    });
    try {
      final cam = await PredictionApi(baseUrl: widget.apiBaseUrl!)
          .predictCam(widget.selectedImage);
      if (!mounted) return;
      setState(() {
        _heatmapBytes = cam.heatmapBytes;
        _heatmapLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _heatmapError = error.toString().replaceFirst('Exception: ', '');
        _heatmapLoading = false;
        _attentionOn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(_stateOf(_topClass));
    return Scaffold(
      backgroundColor: DSColors.neutral0,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            DSSpacing.pageHPadding,
            DSSpacing.pageHPadding,
            DSSpacing.pageHPadding,
            DSSpacing.s5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScreenTop(
                title: 'Analysis Result',
                onBack: () => Navigator.of(context).pop(),
                trailing: _IconBtn(icon: Icons.info_outline, onTap: _openAbout),
              ),
              const SizedBox(height: DSSpacing.s4),
              _MetaStrip(
                segments: _isEnsemble
                    ? ['Ensemble', '${widget.ensembleResult!.modelOutputs.length} models']
                    : ['Single model', widget.singleResult!.model],
                badge: _calibrated
                    ? (_isEnsemble
                        ? 'All calibrated'
                        : 'Calibrated · T = ${_temperature.toStringAsFixed(3)}')
                    : null,
              ),
              const SizedBox(height: DSSpacing.s4),
              _Hero(
                palette: palette,
                confidence: _topConfidence,
                isEnsemble: _isEnsemble,
                classDisplay: _topDisplay,
                classCode: _topClass,
                agreement: _isEnsemble ? _agreementText() : null,
              ),
              const SizedBox(height: DSSpacing.cardGap),
              if (!_isEnsemble) ...[
                _LesionImageCard(
                  image: widget.selectedImage,
                  camAvailable: _camAvailable,
                  attentionOn: _attentionOn,
                  heatmapBytes: _heatmapBytes,
                  loading: _heatmapLoading,
                  error: _heatmapError,
                  onToggle: _toggleAttention,
                ),
                const SizedBox(height: DSSpacing.cardGap),
              ],
              _Top3Card(candidates: _topCandidates),
              const SizedBox(height: DSSpacing.cardGap),
              if (!_isEnsemble)
                _CalibrationCard(temperature: _temperature)
              else ...[
                _PerModelGrid(
                  outputs: widget.ensembleResult!.modelOutputs,
                  selectedImage: widget.selectedImage,
                  apiBaseUrl: widget.apiBaseUrl,
                  camAvailable: _ensembleCamAvailable,
                ),
                const SizedBox(height: DSSpacing.s3),
                const _Footnote(
                  'Ensemble uses v1 baseline models. Single-model uses v2 '
                  'ResNet50 (focal-trained). Predictions may differ between '
                  'modes; both are valid views.',
                ),
              ],
              const SizedBox(height: DSSpacing.s5),
              // Actions — kept for navigation parity (the legacy screen exposed
              // these; the mockup omits them but back-only would strand users).
              if (!_isEnsemble)
                Row(
                  children: [
                    Expanded(
                      child: _DSButton(
                        label: 'Switch to Ensemble',
                        primary: false,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DSButton(
                        label: 'New Analysis',
                        primary: false,
                        onTap: _runNew,
                      ),
                    ),
                  ],
                )
              else
                _DSButton(
                  label: 'New Analysis',
                  primary: false,
                  onTap: _runNew,
                ),
              const SizedBox(height: 8),
              _DSButton(
                label: 'View Model Performance',
                primary: false,
                onTap: _openModels,
              ),
              const SizedBox(height: DSSpacing.s4),
              const _DisclaimerRibbon(
                text: 'Illustrative output. Not a diagnosis. Always consult '
                    'a qualified clinician.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _agreementText() {
    final outputs = widget.ensembleResult!.modelOutputs;
    final agree =
        outputs.where((m) => m.predictedClass == _topClass).length;
    final total = outputs.length;
    final allCal = widget.ensembleResult!.calibrated;
    if (agree == total) {
      return 'All $total models agree${allCal ? ' · all calibrated' : ''}';
    }
    return '$agree of $total models agree${allCal ? ' · all calibrated' : ''}';
  }
}

// ── Diagnostic state mapping (no traffic-light; tinted-bg + wording) ──────────

enum _DState { benign, watch, urgent }

_DState _stateOf(String code) {
  switch (code) {
    case 'mel':
    case 'akiec':
    case 'bcc':
      return _DState.urgent;
    case 'bkl':
    case 'df':
      return _DState.watch;
    default: // nv, vasc
      return _DState.benign;
  }
}

class _StatePalette {
  const _StatePalette({
    required this.bg,
    required this.border,
    required this.accent,
    required this.deep,
    required this.pillLabel,
  });
  final Color bg;
  final Color border;
  final Color accent;
  final Color deep;
  final String pillLabel;
}

_StatePalette _paletteOf(_DState s) {
  switch (s) {
    case _DState.urgent:
      return const _StatePalette(
        bg: DSColors.stateUrgent50,
        border: Color(0xFFF3D2D2),
        accent: DSColors.stateUrgent500,
        deep: DSColors.stateUrgent900,
        pillLabel: 'REQUIRES CLINICAL EVALUATION',
      );
    case _DState.watch:
      return const _StatePalette(
        bg: DSColors.stateWatch50,
        border: Color(0xFFEADBAE),
        accent: DSColors.stateWatch500,
        deep: Color(0xFF5A4708),
        pillLabel: 'WORTH MONITORING',
      );
    case _DState.benign:
      return const _StatePalette(
        bg: DSColors.stateBenign50,
        border: Color(0xFFC3DDD5),
        accent: DSColors.primary700,
        deep: DSColors.primary900,
        pillLabel: 'LOWER CONCERN',
      );
  }
}

// ── Meta strip ────────────────────────────────────────────────────────────────

class _MetaStrip extends StatelessWidget {
  const _MetaStrip({required this.segments, this.badge});

  final List<String> segments;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(const Text('·',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: DSColors.neutral300)));
      }
      children.add(Text(segments[i], style: DSText.caption));
    }
    if (badge != null) {
      children.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: DSColors.info50,
          borderRadius: BorderRadius.circular(DSRadius.pill),
        ),
        child: Text(
          badge!,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: DSColors.info500,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: children),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({
    required this.palette,
    required this.confidence,
    required this.isEnsemble,
    required this.classDisplay,
    required this.classCode,
    this.agreement,
  });

  final _StatePalette palette;
  final double confidence;
  final bool isEnsemble;
  final String classDisplay;
  final String classCode;
  final String? agreement;

  @override
  Widget build(BuildContext context) {
    final pct = '${(confidence.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isEnsemble ? 20 : 22),
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border.all(color: palette.border, width: DSBorders.width),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: DSColors.neutral0,
              borderRadius: BorderRadius.circular(DSRadius.pill),
              border: Border.all(color: palette.border, width: DSBorders.width),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  palette.pillLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: palette.accent,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isEnsemble ? 14 : 16),
          Text(
            pct,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: isEnsemble ? 48 : 56,
              fontWeight: FontWeight.w700,
              letterSpacing: isEnsemble ? -0.8 : -1,
              height: 1,
              color: palette.accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: isEnsemble ? 6 : 8),
          if (isEnsemble) ...[
            Text(
              '$classDisplay · ensemble prediction',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: palette.deep.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 12),
            if (agreement != null) _AgreementChip(palette: palette, text: agreement!),
          ] else ...[
            Text(
              'Calibrated confidence. Not a probability of disease.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: palette.deep.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              classDisplay,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: palette.deep,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              classCode.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: palette.accent.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgreementChip extends StatelessWidget {
  const _AgreementChip({required this.palette, required this.text});

  final _StatePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: DSColors.neutral0,
        borderRadius: BorderRadius.circular(DSRadius.pill),
        border: Border.all(color: palette.border, width: DSBorders.width),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DSColors.primary500,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 9, color: DSColors.neutral0),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: DSColors.primary700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lesion image card with cross-fade attention ───────────────────────────────

class _LesionImageCard extends StatelessWidget {
  const _LesionImageCard({
    required this.image,
    required this.camAvailable,
    required this.attentionOn,
    required this.heatmapBytes,
    required this.loading,
    required this.error,
    required this.onToggle,
  });

  final SelectedImage image;
  final bool camAvailable;
  final bool attentionOn;
  final Uint8List? heatmapBytes;
  final bool loading;
  final String? error;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final hasCam = heatmapBytes != null;
    final showCam = attentionOn && hasCam;
    return _DSCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lesion image',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DSColors.neutral900,
                  )),
              if (camAvailable) _AttnToggle(on: attentionOn, loading: loading, onTap: onToggle),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: showCam ? 0.55 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Image.memory(image.bytes, fit: BoxFit.cover),
                  ),
                  if (hasCam)
                    AnimatedOpacity(
                      opacity: showCam ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Image.memory(heatmapBytes!,
                          fit: BoxFit.cover, gaplessPlayback: true),
                    ),
                  if (loading)
                    const ColoredBox(
                      color: Color(0x55000000),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        ),
                      ),
                    ),
                  if (showCam)
                    const Positioned(left: 8, bottom: 8, child: _HeatScale()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Grad-CAM · final conv layer', style: DSText.caption),
              Text('Resolution 224 × 224', style: DSText.caption),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text('Could not load attention overlay: $error',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: DSColors.stateWatch500,
                )),
          ],
        ],
      ),
    );
  }
}

class _AttnToggle extends StatelessWidget {
  const _AttnToggle({required this.on, required this.loading, required this.onTap});

  final bool on;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? DSColors.primary50 : DSColors.neutral0,
      borderRadius: BorderRadius.circular(DSRadius.pill),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(DSRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DSRadius.pill),
            border: Border.all(
              color: on ? DSColors.primary100 : DSColors.neutral300,
              width: DSBorders.width,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: DSColors.primary500),
                )
              else
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: on ? DSColors.primary500 : DSColors.neutral300,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                on ? 'Hide attention' : 'Show attention',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: on ? DSColors.primary700 : DSColors.neutral700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatScale extends StatelessWidget {
  const _HeatScale();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x8C141412),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('LOW',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: DSColors.neutral0,
              )),
          const SizedBox(width: 5),
          Container(
            width: 36,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(colors: [
                Color(0x993C8C64),
                Color(0xB3BED228),
                Color(0xD9F5AF1E),
                Color(0xFFDC281E),
              ]),
            ),
          ),
          const SizedBox(width: 5),
          const Text('HIGH',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: DSColors.neutral0,
              )),
        ],
      ),
    );
  }
}

// ── Top-3 differential ────────────────────────────────────────────────────────

class _Top3Card extends StatelessWidget {
  const _Top3Card({required this.candidates});

  final List<PredictionCandidate> candidates;

  static const _rankColors = [
    DSColors.classAkiec,
    DSColors.classBcc,
    DSColors.classBkl,
  ];
  static const _allClasses = ['akiec', 'bcc', 'bkl', 'df', 'mel', 'nv', 'vasc'];

  @override
  Widget build(BuildContext context) {
    final top = candidates.take(3).toList();
    final shownSum =
        top.fold<double>(0, (a, c) => a + c.confidence.clamp(0.0, 1.0));
    final other = (1.0 - shownSum).clamp(0.0, 1.0);
    final shownCodes = top.map((c) => c.className).toSet();
    final otherCodes =
        _allClasses.where((c) => !shownCodes.contains(c)).toList();

    return _DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LabelUp('TOP-3 DIFFERENTIAL'),
              Text('Calibrated', style: DSText.caption),
            ],
          ),
          const SizedBox(height: 14),
          // stacked bar
          SizedBox(
            height: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DSRadius.pill),
              child: Row(
                children: [
                  for (var i = 0; i < top.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      flex: (top[i].confidence.clamp(0.0, 1.0) * 1000).round() + 1,
                      child: ColoredBox(color: _rankColors[i]),
                    ),
                  ],
                  if (other > 0) ...[
                    const SizedBox(width: 3),
                    Expanded(
                      flex: (other * 1000).round() + 1,
                      child: const ColoredBox(color: DSColors.classOther),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < top.length; i++)
            _Top3Row(
              color: _rankColors[i],
              code: top[i].className.toUpperCase(),
              name: top[i].displayLabel,
              pct: top[i].confidence,
            ),
          _Top3Row(
            color: DSColors.classOther,
            code: 'Other ${otherCodes.length} classes',
            name: otherCodes.join(' · '),
            pct: other,
            muted: true,
          ),
        ],
      ),
    );
  }
}

class _Top3Row extends StatelessWidget {
  const _Top3Row({
    required this.color,
    required this.code,
    required this.name,
    required this.pct,
    this.muted = false,
  });

  final Color color;
  final String code;
  final String name;
  final double pct;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final txt = muted ? DSColors.neutral500 : DSColors.neutral900;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(code,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: txt,
                    )),
                if (name.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: DSColors.neutral500,
                        )),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${(pct * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: txt,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

// ── Calibration card ──────────────────────────────────────────────────────────

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.temperature});

  final double temperature;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DSSpacing.cardPad),
      decoration: BoxDecoration(
        color: DSColors.info50,
        border: Border.all(color: const Color(0xFFD5DFEF), width: DSBorders.width),
        borderRadius: BorderRadius.circular(DSRadius.card),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CALIBRATION',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: DSColors.info500,
              )),
          SizedBox(height: 6),
          Text(
            'Temperature scaling fitted on validation; verified on test. '
            'ECE 0.0248 (in-distribution). Confidence does not transfer '
            'out-of-distribution (Phase E).',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              height: 1.55,
              color: Color(0xFF1F3D6A),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-model attention grid (ensemble) ───────────────────────────────────────

class _PerModelGrid extends StatefulWidget {
  const _PerModelGrid({
    required this.outputs,
    required this.selectedImage,
    required this.apiBaseUrl,
    required this.camAvailable,
  });

  final List<ModelPrediction> outputs;
  final SelectedImage selectedImage;
  final String? apiBaseUrl;
  final bool camAvailable;

  @override
  State<_PerModelGrid> createState() => _PerModelGridState();
}

class _PerModelGridState extends State<_PerModelGrid> {
  // Re-skin of the Phase D lazy CAM fetch: one /predict-cam-ensemble call
  // serves the whole grid, cached here. The grid always shows attention
  // thumbnails, so the fetch is kicked off on init (rather than on expand).
  CamEnsembleResponse? _cams;
  bool _loading = false;
  String? _error;
  bool _fetchStarted = false;

  @override
  void initState() {
    super.initState();
    _ensureCams();
  }

  Future<void> _ensureCams() async {
    if (!widget.camAvailable || _fetchStarted) return;
    _fetchStarted = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cams = await PredictionApi(baseUrl: widget.apiBaseUrl!)
          .fetchEnsembleCams(widget.selectedImage);
      if (!mounted) return;
      setState(() {
        _cams = cams;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _fetchStarted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.outputs]
      ..sort((a, b) => b.weight.compareTo(a.weight));
    return _DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _LabelUp('PER-MODEL ATTENTION'),
              Text(widget.camAvailable ? 'Tap to expand' : 'Attention in API mode',
                  style: DSText.caption),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: [
              for (final m in sorted)
                _ModelTile(
                  output: m,
                  image: widget.selectedImage,
                  cam: _cams?.camFor(m.model),
                  loading: _loading,
                  error: _error,
                  camAvailable: widget.camAvailable,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.output,
    required this.image,
    required this.cam,
    required this.loading,
    required this.error,
    required this.camAvailable,
  });

  final ModelPrediction output;
  final SelectedImage image;
  final ModelCam? cam;
  final bool loading;
  final String? error;
  final bool camAvailable;

  @override
  Widget build(BuildContext context) {
    final heatmap = cam?.heatmapBytes;
    return Material(
      color: DSColors.neutral0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showDialog<void>(
          context: context,
          barrierColor: const Color(0xBF141412),
          builder: (_) => _Lightbox(output: output, image: image, heatmap: heatmap),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: DSColors.neutral100, width: DSBorders.width),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(output.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DSColors.neutral900,
                        )),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: DSColors.neutral100,
                      borderRadius: BorderRadius.circular(DSRadius.pill),
                    ),
                    child: Text('${(output.weight * 100).round()}%',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: DSColors.neutral500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: output.predictedClass,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DSColors.primary700,
                    ),
                  ),
                  TextSpan(
                    text: ' · ${(output.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: DSColors.neutral500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _Thumb(label: 'Original', bytes: image.bytes)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _Thumb(
                        label: 'Attention',
                        bytes: heatmap,
                        loading: camAvailable && loading && heatmap == null,
                        unavailable: !camAvailable || (heatmap == null && !loading),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.label,
    required this.bytes,
    this.loading = false,
    this.unavailable = false,
    this.radius = 8,
  });

  final String label;
  final Uint8List? bytes;
  final bool loading;
  final bool unavailable;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)
            else
              ColoredBox(
                color: DSColors.neutral100,
                child: Center(
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: DSColors.primary500),
                        )
                      : (unavailable
                          ? const Icon(Icons.image_not_supported_outlined,
                              size: 16, color: DSColors.neutral300)
                          : const SizedBox.shrink()),
                ),
              ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x8C141412),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: DSColors.neutral0,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lightbox extends StatelessWidget {
  const _Lightbox({required this.output, required this.image, required this.heatmap});

  final ModelPrediction output;
  final SelectedImage image;
  final Uint8List? heatmap;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DSColors.neutral0,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${output.model} · ${(output.weight * 100).round()}%',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: DSColors.neutral900,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '${output.predictedClass} · ${(output.confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: DSColors.neutral500,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _Thumb(label: 'Original', bytes: image.bytes, radius: 14)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Thumb(
                      label: 'Attention',
                      bytes: heatmap,
                      unavailable: heatmap == null,
                      radius: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Grad-CAM on the final conv layer · calibrated softmax.',
                style: DSText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Footnote ──────────────────────────────────────────────────────────────────

class _Footnote extends StatelessWidget {
  const _Footnote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5,
          height: 1.55,
          color: DSColors.neutral500,
        ),
      ),
    );
  }
}

// ── Shared DS primitives (inlined per self-contained screen) ──────────────────

class _DSCard extends StatelessWidget {
  const _DSCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(DSSpacing.cardPad),
      decoration: BoxDecoration(
        color: DSColors.neutral0,
        border: Border.all(color: DSColors.neutral100, width: DSBorders.width),
        borderRadius: BorderRadius.circular(DSRadius.card),
      ),
      child: child,
    );
  }
}

class _LabelUp extends StatelessWidget {
  const _LabelUp(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: DSText.labelUp);
}

class _ScreenTop extends StatelessWidget {
  const _ScreenTop({required this.title, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBtn(icon: Icons.chevron_left, onTap: onBack),
        Expanded(
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: DSColors.neutral900,
              ),
            ),
          ),
        ),
        trailing ?? const SizedBox(width: 36, height: 36),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DSColors.neutral0,
      shape: const CircleBorder(
        side: BorderSide(color: DSColors.neutral100, width: DSBorders.width),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: DSColors.neutral700),
        ),
      ),
    );
  }
}

class _DSButton extends StatelessWidget {
  const _DSButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? DSColors.neutral0 : DSColors.neutral900;
    return Material(
      color: primary ? DSColors.primary500 : DSColors.neutral0,
      borderRadius: BorderRadius.circular(DSRadius.btn),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DSRadius.btn),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DSRadius.btn),
            border: primary
                ? null
                : Border.all(color: DSColors.neutral300, width: DSBorders.width),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DisclaimerRibbon extends StatelessWidget {
  const _DisclaimerRibbon({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DSColors.neutral50,
        border: Border.all(color: DSColors.neutral100, width: DSBorders.width),
        borderRadius: BorderRadius.circular(DSRadius.btn),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: DSColors.neutral500,
        ),
      ),
    );
  }
}
