import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Redesigned About & Safety screen — mockup Screen 5 (data-screen-key="about").
/// Static, visual-only rewrite: identity, intended use, NOT-intended-for,
/// datasets, per-model calibration temperatures, Grad-CAM caveat, and the
/// License & Attribution card.
class SafetyAboutScreen extends StatelessWidget {
  const SafetyAboutScreen({super.key});

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
              _ScreenTop(
                title: 'About & Safety',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: DSSpacing.s4),
              // System identity
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelUp('SYSTEM IDENTITY'),
                    SizedBox(height: 8),
                    _IdRow('Project', 'DermaSense', first: true),
                    _IdRow('Version', 'v0.2.1 · May 2026'),
                    _IdRow('Backend', 'Multi-model CNN ensemble (PyTorch)'),
                    _IdRow('Author', 'Jiahao Liu — MSc thesis, 2026'),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // Intended use
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelUp('INTENDED USE'),
                    SizedBox(height: 10),
                    Text(
                      'An academic prototype for studying calibration, '
                      'ensembling, and saliency in deep dermatoscopic '
                      'classifiers. Findings are illustrative — to be '
                      'interpreted alongside, never in place of, a qualified '
                      "clinician's assessment.",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        height: 1.6,
                        color: DSColors.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // NOT intended for (urgent tint)
              const _TintCard(
                bg: DSColors.stateUrgent50,
                border: Color(0xFFF3D2D2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NOT INTENDED FOR',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: DSColors.stateUrgent500,
                        )),
                    SizedBox(height: 8),
                    _Bullet('Clinical diagnosis or treatment decisions.'),
                    _Bullet('Screening of the general public.'),
                    _Bullet('Use on non-dermatoscopic phone-camera photos.'),
                    _Bullet('Commercial deployment of the trained weights.'),
                    _Bullet('Any clinical setting in any jurisdiction.'),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // Datasets
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelUp('DATASETS'),
                    SizedBox(height: 8),
                    _IdRow('Training', 'HAM10000 (10,015 images, 7 classes)',
                        first: true),
                    _IdRow('External validation',
                        'ISIC 2019 — HAM-disjoint subset (4,353 images)'),
                    SizedBox(height: 10),
                    Text(
                      'HAM10000 is a Vienna / Queensland multi-source '
                      'dermatoscopic dataset; ISIC 2019 expands it with '
                      'Hospital Clínic de Barcelona images. Both are licensed '
                      'CC BY-NC 4.0.',
                      style: DSText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // Calibration temperatures
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: _LabelUp('PER-MODEL CALIBRATION TEMPERATURES')),
                        SizedBox(width: 8),
                        Text('Lower T = more confident', style: DSText.caption),
                      ],
                    ),
                    SizedBox(height: 10),
                    _TempTable(),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // Grad-CAM
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelUp('GRAD-CAM OVERLAYS'),
                    SizedBox(height: 10),
                    Text(
                      'Attention maps are computed on the final convolutional '
                      'layer using Grad-CAM. They show which image regions most '
                      'influenced the predicted class — they are not a clinical '
                      'region-of-interest annotation and should not be '
                      'interpreted as such.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        height: 1.6,
                        color: DSColors.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // License & attribution
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('License & Attribution',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: DSColors.neutral900,
                        )),
                    SizedBox(height: 12),
                    _LicenseRow(
                      tag: 'MIT',
                      tagBg: DSColors.info50,
                      tagFg: DSColors.info500,
                      lead: 'Application code. ',
                      rest: 'Copyright © 2026 Jiahao Liu. Released under the '
                          'MIT License — see LICENSE in the repository.',
                      first: true,
                    ),
                    _LicenseRow(
                      tag: 'CC BY-NC 4.0',
                      tagBg: DSColors.stateWatch50,
                      tagFg: DSColors.stateWatch500,
                      lead: 'Trained weights. ',
                      rest: 'Derivative of the HAM10000 dataset; redistributed '
                          'for non-commercial use only. Attribution to the '
                          'dataset authors is required.',
                    ),
                    _Citation(
                      label: 'HAM10000 CITATION',
                      text: 'Tschandl P., Rosendahl C. & Kittler H. The HAM10000 '
                          'dataset, a large collection of multi-source '
                          'dermatoscopic images of common pigmented skin '
                          'lesions. Scientific Data 5, 180161 (2018). '
                          'doi:10.1038/sdata.2018.161',
                    ),
                    _Citation(
                      label: 'ISIC 2019 ATTRIBUTION',
                      text: 'External-validation imagery sourced from the '
                          'International Skin Imaging Collaboration (ISIC 2019), '
                          'Hospital Clínic de Barcelona contribution. '
                          'Distributed under CC BY-NC 4.0.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.s4),
              const _DisclaimerRibbon(
                text: 'Not a medical device. CC BY-NC 4.0 · © 2026 Jiahao Liu.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Key/value identity row ────────────────────────────────────────────────────

class _IdRow extends StatelessWidget {
  const _IdRow(this.k, this.v, {this.first = false});

  final String k;
  final String v;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: first ? 6 : 12, bottom: 6),
      decoration: first
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: DSColors.neutral100)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: DSColors.neutral500,
              )),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: DSColors.neutral900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Urgent bullet ─────────────────────────────────────────────────────────────

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 9),
            child: SizedBox(
              width: 4,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DSColors.stateUrgent500,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  height: 1.5,
                  color: DSColors.stateUrgent900,
                )),
          ),
        ],
      ),
    );
  }
}

// ── Per-model calibration temperatures table ──────────────────────────────────

class _TempTable extends StatelessWidget {
  const _TempTable();

  static const _rows = <List<String>>[
    ['ResNet50 v2', 'Single', '0.898'],
    ['ResNet50', 'Ensemble v1', '1.539'],
    ['DenseNet121', 'Ensemble v1', '1.689'],
    ['EfficientNet-B0', 'Ensemble v1', '2.027'],
    ['MobileNetV3 Sm', 'Ensemble v1', '1.655'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // header
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: DSColors.neutral100)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: _Th('MODEL', TextAlign.left)),
              Expanded(flex: 3, child: _Th('ROLE', TextAlign.left)),
              Expanded(flex: 1, child: _Th('T', TextAlign.right)),
            ],
          ),
        ),
        for (var i = 0; i < _rows.length; i++)
          _TempRow(data: _rows[i], deployed: i == 0, last: i == _rows.length - 1),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text, this.align);
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: DSColors.neutral500,
        ),
      );
}

class _TempRow extends StatelessWidget {
  const _TempRow({required this.data, required this.deployed, required this.last});

  final List<String> data;
  final bool deployed;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final nameColor = deployed ? DSColors.primary700 : DSColors.neutral900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: deployed ? DSColors.primary50 : null,
        borderRadius: deployed ? BorderRadius.circular(8) : null,
        border: last || deployed
            ? null
            : const Border(bottom: BorderSide(color: DSColors.neutral100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(data[0],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: deployed ? FontWeight.w600 : FontWeight.w500,
                        color: nameColor,
                      )),
                ),
                if (deployed) ...[
                  const SizedBox(width: 6),
                  const _MiniChip('DEPLOYED'),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(data[1],
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: DSColors.neutral500,
                )),
          ),
          Expanded(
            flex: 1,
            child: Text(data[2],
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DSColors.neutral900,
                  fontFeatures: [FontFeature.tabularFigures()],
                )),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: DSColors.neutral0,
        borderRadius: BorderRadius.circular(DSRadius.pill),
        border: Border.all(color: DSColors.primary100, width: DSBorders.width),
      ),
      child: Text(label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: DSColors.primary700,
          )),
    );
  }
}

// ── License row + citation ────────────────────────────────────────────────────

class _LicenseRow extends StatelessWidget {
  const _LicenseRow({
    required this.tag,
    required this.tagBg,
    required this.tagFg,
    required this.lead,
    required this.rest,
    this.first = false,
  });

  final String tag;
  final Color tagBg;
  final Color tagFg;
  final String lead;
  final String rest;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: first ? 4 : 12, bottom: 12),
      decoration: first
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: DSColors.neutral100)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(tag,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: tagFg,
                    )),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: lead,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                    color: DSColors.neutral900,
                  ),
                ),
                TextSpan(
                  text: rest,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.55,
                    color: DSColors.neutral700,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Citation extends StatelessWidget {
  const _Citation({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: DSColors.neutral50,
        borderRadius: BorderRadius.circular(DSRadius.input),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: DSColors.neutral500,
              )),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.6,
                color: DSColors.neutral700,
              )),
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

/// Tinted card variant (e.g. the urgent "NOT INTENDED FOR" card).
class _TintCard extends StatelessWidget {
  const _TintCard({required this.bg, required this.border, required this.child});

  final Color bg;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DSSpacing.cardPad),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: DSBorders.width),
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
  const _ScreenTop({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

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
        const SizedBox(width: 36, height: 36),
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
