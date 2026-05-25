import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/ensemble_result.dart';
import '../models/prediction_result.dart';
import '../models/selected_image.dart';
import '../services/prediction_api.dart';
import '../theme/design_tokens.dart';
import 'result_screen.dart';
import 'safety_about_screen.dart';

/// Redesigned analysis-setup screen — mockup Screen 2 (data-screen-key="classify").
/// Visual-only rewrite: all state (URL, mock mode, analysis mode, loading,
/// error), the `_analyze()` API call, and navigation to ResultScreen are
/// preserved exactly from the prior implementation.
class ClassificationScreen extends StatefulWidget {
  const ClassificationScreen({super.key, required this.selectedImage});

  final SelectedImage selectedImage;

  @override
  State<ClassificationScreen> createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  late final TextEditingController _apiUrlController;
  bool _mockMode = false;
  bool _ensembleMode = true;
  bool _isLoading = false;
  bool _connectionExpanded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(
      text: kIsWeb ? 'http://127.0.0.1:8126' : 'http://10.0.2.2:8126',
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final apiUrl = _mockMode ? null : _apiUrlController.text;

    try {
      if (_ensembleMode) {
        final result = _mockMode
            ? EnsembleResult.mock
            : await PredictionApi(baseUrl: apiUrl!).predictEnsemble(
                widget.selectedImage,
              );
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultScreen.ensemble(
              selectedImage: widget.selectedImage,
              result: result,
              apiBaseUrl: apiUrl,
            ),
          ),
        );
      } else {
        final result = _mockMode
            ? PredictionResult.mock
            : await PredictionApi(baseUrl: apiUrl!).predict(
                widget.selectedImage,
              );
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultScreen.single(
              selectedImage: widget.selectedImage,
              result: result,
              apiBaseUrl: apiUrl,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SafetyAboutScreen()),
    );
  }

  String get _connectionSummary {
    final raw = _apiUrlController.text.replaceFirst(RegExp(r'^https?://'), '');
    return '$raw · Mock mode ${_mockMode ? 'on' : 'off'}';
  }

  @override
  Widget build(BuildContext context) {
    final kb = (widget.selectedImage.bytes.lengthInBytes / 1024).round();
    return Scaffold(
      backgroundColor: DSColors.neutral0,
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _isLoading ? 0.6 : 1,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: _isLoading,
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
                    title: 'Analysis Setup',
                    onBack: () => Navigator.of(context).pop(),
                    trailing: _IconBtn(
                      icon: Icons.info_outline,
                      onTap: _openAbout,
                    ),
                  ),
                  const SizedBox(height: DSSpacing.s4),
                  // Card 1 — selected image preview
                  _DSCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _LabelUp('SELECTED IMAGE'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                widget.selectedImage.bytes,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.selectedImage.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: DSColors.neutral900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$kb KB · Just now',
                                    style: DSText.caption,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: DSColors.primary700,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 36),
                              ),
                              child: const Text(
                                'Change',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DSSpacing.cardGap),
                  // Card 2 — image quality guidance
                  _DSCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: DSColors.info50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline,
                              size: 14, color: DSColors.info500),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LabelUp('IMAGE QUALITY'),
                              SizedBox(height: 6),
                              Text(
                                'Center the lesion, fill ~60% of the frame, '
                                'avoid glare and hair. Dermatoscopic crops give '
                                'the most reliable predictions.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13.5,
                                  height: 1.55,
                                  color: DSColors.neutral700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DSSpacing.cardGap),
                  // Card 3 — analysis mode
                  _DSCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _LabelUp('ANALYSIS MODE'),
                            Text('Choose one', style: DSText.caption),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SegmentedMode(
                          ensembleMode: _ensembleMode,
                          onChanged: (v) => setState(() {
                            _ensembleMode = v;
                            _error = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: DSColors.neutral50,
                            borderRadius: BorderRadius.circular(DSRadius.input),
                          ),
                          child: Text(
                            _ensembleMode
                                ? 'Runs ResNet50 v1 · DenseNet121 · '
                                    'EfficientNet-B0 · MobileNetV3 Small in '
                                    'parallel, weighted 38 / 37 / 20 / 5%. '
                                    'Slower but provides agreement and per-model '
                                    'attention.'
                                : 'Uses ResNet50 v2 (focal loss + balanced '
                                    'sampler). Test mel recall 73.4%, F1 70.08%. '
                                    'Faster, no inter-model agreement signal.',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              height: 1.55,
                              color: DSColors.neutral700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DSSpacing.cardGap),
                  // Card 4 — backend connection (collapsible)
                  _ConnectionCard(
                    controller: _apiUrlController,
                    mockMode: _mockMode,
                    expanded: _connectionExpanded,
                    summary: _connectionSummary,
                    onToggleExpand: () => setState(
                        () => _connectionExpanded = !_connectionExpanded),
                    onMockChanged: (v) => setState(() {
                      _mockMode = v;
                      _error = null;
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: DSSpacing.cardGap),
                    _ErrorCard(message: _error!),
                  ],
                  const SizedBox(height: DSSpacing.s5),
                  // Run Analysis CTA
                  _DSButton(
                    label: _isLoading ? 'Analysing…' : 'Run Analysis',
                    primary: true,
                    trailingIcon: _isLoading ? null : Icons.chevron_right,
                    loading: _isLoading,
                    onTap: _isLoading ? null : _analyze,
                  ),
                  const SizedBox(height: DSSpacing.s4),
                  const _DisclaimerRibbon(
                    text: 'For educational use only. Not a medical device.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Segmented mode control ────────────────────────────────────────────────────

class _SegmentedMode extends StatelessWidget {
  const _SegmentedMode({required this.ensembleMode, required this.onChanged});

  final bool ensembleMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DSColors.neutral100,
        borderRadius: BorderRadius.circular(DSRadius.input),
      ),
      child: Row(
        children: [
          _seg('Single Model', selected: !ensembleMode, onTap: () => onChanged(false)),
          _seg('4-Model Ensemble', selected: ensembleMode, onTap: () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _seg(String label, {required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? DSColors.neutral0 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? DSColors.neutral100 : Colors.transparent,
              width: DSBorders.width,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? DSColors.neutral900 : DSColors.neutral500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Backend connection (collapsible) ──────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.controller,
    required this.mockMode,
    required this.expanded,
    required this.summary,
    required this.onToggleExpand,
    required this.onMockChanged,
  });

  final TextEditingController controller;
  final bool mockMode;
  final bool expanded;
  final String summary;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onMockChanged;

  @override
  Widget build(BuildContext context) {
    return _DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleExpand,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LabelUp('BACKEND CONNECTION'),
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: DSColors.neutral700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.keyboard_arrow_down,
                      size: 20, color: DSColors.neutral500),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BACKEND URL',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: DSColors.neutral500,
                      )),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    enabled: !mockMode,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: DSColors.neutral900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: DSColors.neutral50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DSRadius.input),
                        borderSide: const BorderSide(color: DSColors.neutral100),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DSRadius.input),
                        borderSide: const BorderSide(color: DSColors.neutral100),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DSRadius.input),
                        borderSide: const BorderSide(color: DSColors.primary500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mock mode',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: DSColors.neutral900,
                                )),
                            SizedBox(height: 2),
                            Text('Return canned predictions for UI testing.',
                                style: DSText.caption),
                          ],
                        ),
                      ),
                      Switch(
                        value: mockMode,
                        onChanged: onMockChanged,
                        activeThumbColor: DSColors.neutral0,
                        activeTrackColor: DSColors.primary500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DSSpacing.s4),
      decoration: BoxDecoration(
        color: DSColors.stateUrgent50,
        border: Border.all(color: DSColors.stateUrgent500, width: DSBorders.width),
        borderRadius: BorderRadius.circular(DSRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: DSColors.stateUrgent500),
          const SizedBox(width: DSSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Analysis failed',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: DSColors.stateUrgent900,
                    )),
                const SizedBox(height: 2),
                Text(message,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      height: 1.4,
                      color: DSColors.stateUrgent900,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared DS primitives (inlined per self-contained screen) ──────────────────

class _DSCard extends StatelessWidget {
  const _DSCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DSSpacing.cardPad),
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
    this.trailingIcon,
    this.loading = false,
  });

  final String label;
  final bool primary;
  final VoidCallback? onTap;
  final IconData? trailingIcon;
  final bool loading;

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: DSColors.neutral0),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
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
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 16, color: fg),
              ],
            ],
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
