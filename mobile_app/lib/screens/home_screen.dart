import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/selected_image.dart';
import '../theme/design_tokens.dart';
import 'classification_screen.dart';
import 'safety_about_screen.dart';

/// Redesigned landing screen — mirrors Screen 1 of
/// docs/ui_redesign/mockup_stage2_reference.html.
///
/// A welcome/landing surface: brand row, value proposition, a three-step
/// guide, and the primary "Start Analysis" CTA. Image acquisition stays on
/// this screen (the existing navigation contract — ClassificationScreen
/// requires a SelectedImage): "Start Analysis" opens a camera/gallery sheet,
/// then pushes the (unchanged) ClassificationScreen with the picked image.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _pickerError;

  Future<void> _startAnalysis() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: DSColors.neutral0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DSRadius.card)),
      ),
      builder: (_) => const _SourceSheet(),
    );
    if (source == null) return;
    await _pickAndContinue(source);
  }

  Future<void> _pickAndContinue(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 92);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _pickerError = null);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClassificationScreen(
            selectedImage: SelectedImage(file: file, bytes: bytes),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pickerError = source == ImageSource.camera
            ? 'Camera unavailable in this environment. Use gallery instead.'
            : 'Could not load image: $error';
      });
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
              const _BrandRow(),
              const SizedBox(height: 30), // brand bottom 18 + welcome top 12
              // ── Welcome ──
              const Text('WELCOME', style: DSText.labelUp),
              const SizedBox(height: 8),
              const Text(
                'AI-assisted skin lesion classification.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  height: 1.15,
                  color: DSColors.neutral900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Capture or upload a dermatoscopic image, choose an analysis '
                'mode, and review a calibrated probability with attention '
                'overlay. Findings are illustrative — not a diagnosis.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.55,
                  color: DSColors.neutral700,
                ),
              ),
              const SizedBox(height: 24),
              // ── 3-step guide ──
              const _StepCard(
                number: '1',
                title: 'Select an image',
                description: 'Camera or gallery. Use a clear, well-lit '
                    'dermatoscopic crop centered on the lesion.',
              ),
              const SizedBox(height: 12),
              const _StepCard(
                number: '2',
                title: 'Choose analysis mode',
                description: 'Single model for speed, or the 4-model ensemble '
                    'for an inter-model agreement signal.',
              ),
              const SizedBox(height: 12),
              const _StepCard(
                number: '3',
                title: 'Review the result',
                description: 'Calibrated confidence, Top-3 differential, and '
                    'Grad-CAM attention. Discuss findings with a clinician.',
              ),
              const SizedBox(height: 24),
              // ── Primary CTA ──
              _DSButton(
                label: 'Start Analysis',
                primary: true,
                trailingIcon: Icons.arrow_forward,
                onTap: _startAnalysis,
              ),
              if (_pickerError != null) ...[
                const SizedBox(height: 10),
                _InlineMessage(message: _pickerError!),
              ],
              const SizedBox(height: 8),
              // ── Secondary CTA ──
              _DSButton(
                label: 'About & safety information',
                primary: false,
                onTap: _openAbout,
              ),
              const SizedBox(height: 16),
              // ── Disclaimer ribbon ──
              const _DisclaimerRibbon(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Brand row ───────────────────────────────────────────────────────────────

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LogoMark(),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'DermaSense',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: DSColors.neutral900,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'v0.2.1',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: DSColors.neutral500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1),
              Text(
                'Skin lesion classification assistant',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: DSColors.neutral500,
                ),
              ),
            ],
          ),
        ),
        _Chip(label: 'Academic'),
      ],
    );
  }
}

/// 36×36 rounded-square mark with a white ring-arc (a gapped lens), matching
/// the mockup's `.logo` + `::after` (inset 7px circle, 2px white border with a
/// transparent side, rotated -30°). Drawn with CustomPaint — no asset/dep.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: DSColors.primary500,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(painter: _LogoArcPainter()),
        ),
      ),
    );
  }
}

class _LogoArcPainter extends CustomPainter {
  const _LogoArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DSColors.neutral0
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2,
    );
    const gap = 1.4; // radians (~80° opening, on the right after rotation)
    const rotation = -30 * math.pi / 180;
    canvas.drawArc(rect, rotation + gap / 2, 2 * math.pi - gap, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DSColors.info50,
        borderRadius: BorderRadius.circular(DSRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: DSColors.info500,
        ),
      ),
    );
  }
}

// ── Step card ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DSColors.neutral0,
        border: Border.all(color: DSColors.neutral100, width: DSBorders.width),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DSColors.primary50,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DSColors.primary700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DSColors.neutral900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: DSColors.neutral500,
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

// ── Buttons ─────────────────────────────────────────────────────────────────

class _DSButton extends StatelessWidget {
  const _DSButton({
    required this.label,
    required this.primary,
    required this.onTap,
    this.trailingIcon,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;
  final IconData? trailingIcon;

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

// ── Image-source bottom sheet ─────────────────────────────────────────────────

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DSSpacing.pageHPadding,
          DSSpacing.s4,
          DSSpacing.pageHPadding,
          DSSpacing.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SELECT AN IMAGE', style: DSText.labelUp),
            const SizedBox(height: 12),
            _SourceTile(
              icon: Icons.photo_camera_outlined,
              label: 'Camera',
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
            _SourceTile(
              icon: Icons.collections_outlined,
              label: 'Gallery',
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DSColors.neutral0,
      borderRadius: BorderRadius.circular(DSRadius.input),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DSRadius.input),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border:
                Border.all(color: DSColors.neutral300, width: DSBorders.width),
            borderRadius: BorderRadius.circular(DSRadius.input),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: DSColors.primary700),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: DSColors.neutral900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inline error message ──────────────────────────────────────────────────────

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DSColors.stateWatch50,
        border: Border.all(color: DSColors.stateWatch500, width: DSBorders.width),
        borderRadius: BorderRadius.circular(DSRadius.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: DSColors.stateWatch500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                height: 1.4,
                color: DSColors.neutral700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Disclaimer ribbon ─────────────────────────────────────────────────────────

class _DisclaimerRibbon extends StatelessWidget {
  const _DisclaimerRibbon();

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
      child: const Text(
        'For educational use only. Not a medical device. Always consult a '
        'qualified clinician for diagnosis and treatment.',
        textAlign: TextAlign.center,
        style: TextStyle(
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
