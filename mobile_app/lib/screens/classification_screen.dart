import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/ensemble_result.dart';
import '../models/prediction_result.dart';
import '../models/selected_image.dart';
import '../services/prediction_api.dart';
import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/disclaimer_ribbon.dart';
import 'result_screen.dart';
import 'safety_about_screen.dart';

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
      text: kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Setup'),
        actions: [
          IconButton(
            tooltip: 'About this system',
            icon: const Icon(Icons.info_outline),
            onPressed: _openAbout,
          ),
        ],
      ),
      body: Column(
        children: [
          _ContextStrip(
            image: widget.selectedImage,
            onChange: _isLoading ? null : () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: AnimatedOpacity(
              opacity: _isLoading ? 0.5 : 1,
              duration: const Duration(milliseconds: 150),
              child: IgnorePointer(
                ignoring: _isLoading,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: [
                    const _ImageQualityCard(),
                    const SizedBox(height: AppSpacing.md),
                    _ModeCard(
                      ensembleMode: _ensembleMode,
                      onChanged: (v) => setState(() {
                        _ensembleMode = v;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ConnectionCard(
                      controller: _apiUrlController,
                      mockMode: _mockMode,
                      expanded: _connectionExpanded,
                      onToggleExpand: () => setState(
                          () => _connectionExpanded = !_connectionExpanded),
                      onMockChanged: (v) => setState(() {
                        _mockMode = v;
                        _error = null;
                      }),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ErrorCard(message: _error!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _isLoading ? null : _analyze,
                      child: _isLoading
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.textOnBrand,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text('Analysing…'),
                              ],
                            )
                          : Text(
                              _ensembleMode
                                  ? 'Run 4-Model Ensemble Analysis'
                                  : 'Run Single-Model Analysis',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading) _LoadingIndicator(ensembleMode: _ensembleMode),
        ],
      ),
      bottomNavigationBar: const DisclaimerRibbon(),
    );
  }
}

// ── Context strip ─────────────────────────────────────────────────────────────

class _ContextStrip extends StatelessWidget {
  const _ContextStrip({required this.image, required this.onChange});

  final SelectedImage image;
  final VoidCallback? onChange;

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
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.memory(
              image.bytes,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selected image',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  image.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

// ── Image quality card ────────────────────────────────────────────────────────

class _ImageQualityCard extends StatelessWidget {
  const _ImageQualityCard();

  @override
  Widget build(BuildContext context) {
    return const StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            label: 'Image Quality Guidance',
            icon: Icons.info_outline,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'For best results: focus on a single lesion that fills the frame, '
            'use even lighting, and avoid hair or markers obscuring the area. '
            'Phone-camera images may produce less reliable predictions than '
            'dermoscopic photographs.',
            style: AppText.bodyMuted,
          ),
        ],
      ),
    );
  }
}

// ── Mode card ─────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.ensembleMode, required this.onChanged});

  final bool ensembleMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            label: 'Analysis Mode',
            icon: Icons.tune_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Single Model'),
                  icon: Icon(Icons.memory_outlined, size: 16),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('4-Model Ensemble'),
                  icon: Icon(Icons.account_tree_outlined, size: 16),
                ),
              ],
              selected: {ensembleMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            ensembleMode
                ? 'Runs ResNet50, DenseNet121, EfficientNet-B0 and MobileNetV3 '
                    'Small, then combines their outputs by weighted average. '
                    'Provides a model-agreement signal for additional safety '
                    'context.'
                : 'Uses ResNet50 only (test accuracy 80.2%, macro F1 69.0%). '
                    'Faster, but no agreement signal.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

// ── Connection card (collapsible) ─────────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.controller,
    required this.mockMode,
    required this.expanded,
    required this.onToggleExpand,
    required this.onMockChanged,
  });

  final TextEditingController controller;
  final bool mockMode;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onMockChanged;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Backend Connection',
                      style: AppText.subtitle,
                    ),
                  ),
                  _ModeBadge(mockMode: mockMode),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    enabled: !mockMode,
                    decoration: const InputDecoration(
                      labelText: 'FastAPI base URL',
                      helperText:
                          'Web: 127.0.0.1 · Emulator: 10.0.2.2 · Phone: PC LAN IP',
                      prefixIcon: Icon(Icons.dns_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mock mode', style: AppText.subtitle),
                            SizedBox(height: 2),
                            Text(
                              'Returns deterministic mock data without '
                              'contacting the backend.',
                              style: AppText.captionMuted,
                            ),
                          ],
                        ),
                      ),
                      Switch(value: mockMode, onChanged: onMockChanged),
                    ],
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

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mockMode});

  final bool mockMode;

  @override
  Widget build(BuildContext context) {
    final bg = mockMode ? AppColors.indetBadgeBg : AppColors.brandAccentSoft;
    final fg = mockMode ? AppColors.indetText : AppColors.brandPrimaryDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        mockMode ? 'MOCK' : 'API',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.6,
        ),
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
    return StatusCard(
      background: AppColors.reviewBg,
      accent: AppColors.reviewAccent,
      border: AppColors.reviewBorder,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 18,
            color: AppColors.reviewAccent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analysis failed',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.reviewText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.reviewText,
                    fontSize: 12.5,
                    height: 1.4,
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

// ── Loading indicator ─────────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({required this.ensembleMode});

  final bool ensembleMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              ensembleMode
                  ? 'Running 4 models in sequence…'
                  : 'Running ResNet50…',
              style: AppText.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
