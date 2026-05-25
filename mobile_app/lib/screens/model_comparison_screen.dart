import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Redesigned model-performance screen — mockup Screen 4 (data-screen-key="models").
/// Visual-only rewrite. All numbers are the same v1/v2 data carried since the
/// UI-2 commit; the confusion matrix is the real row-normalized ResNet50 v2
/// matrix baked from runs/resnet50_v2/test_metrics.json (a Flutter build cannot
/// read runs/ at runtime, so it is embedded as a const).
class ModelComparisonScreen extends StatelessWidget {
  const ModelComparisonScreen({super.key});

  // ── Model summary (HAM10000 test split) ──
  static const _summary = <_SummaryRowData>[
    _SummaryRowData('ResNet50', 80.2, 69.0, 38, isDefault: true),
    _SummaryRowData('DenseNet121', 79.6, 69.0, 37),
    _SummaryRowData('EfficientNet-B0', 77.5, 64.8, 20),
    _SummaryRowData('MobileNetV3 Sm', 67.8, 57.3, 5),
  ];

  // Per-class recall (%). v1 columns RN50/DN121/ENB0/MN3; v2 = deployed
  // single-model (all 7 classes now provided; v2 kept nullable for schema
  // stability + a defensive render-path null guard).
  // Source: runs_v2/resnet50_v2_focal_plus_sampler/test_metrics.json.
  static const _recall = <_RecallRowData>[
    _RecallRowData('mel', [55, 59, 57, 57], 73.40),
    _RecallRowData('bcc', [87, 85, 69, 87], 82.42),
    _RecallRowData('akiec', [60, 60, 69, 58], 69.23),
    _RecallRowData('bkl', [66, 75, 63, 47], 65.83),
    _RecallRowData('df', [80, 68, 72, 72], 72.00),
    _RecallRowData('nv', [87, 84, 84, 71], 79.60),
    _RecallRowData('vasc', [96, 96, 93, 100], 92.59),
  ];

  // Real row-normalized confusion matrix (%), rows = true, cols = predicted.
  // Source: runs/resnet50_v2/test_metrics.json (ResNet50 v2, HAM10000 test).
  static const _cmClasses = ['akiec', 'bcc', 'bkl', 'df', 'mel', 'nv', 'vasc'];
  static const _cm = <List<int>>[
    [69, 17, 6, 0, 8, 0, 0],
    [3, 82, 3, 1, 8, 0, 2],
    [8, 5, 66, 1, 18, 4, 0],
    [4, 4, 4, 72, 8, 8, 0],
    [1, 4, 6, 1, 73, 12, 3],
    [1, 2, 4, 0, 13, 80, 1],
    [0, 0, 0, 0, 0, 7, 93],
  ];

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
                title: 'Model Performance',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: DSSpacing.s4),
              // Intro
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelUp('TEST SET EVALUATION'),
                    SizedBox(height: 8),
                    Text(
                      'All numbers below are measured on the HAM10000 held-out '
                      'test split. External-validation drop is reported '
                      'separately under Known Limitations.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        height: 1.55,
                        color: DSColors.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // Model summary
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _LabelUp('MODEL SUMMARY'),
                        Text('4 models · ensemble', style: DSText.caption),
                      ],
                    ),
                    SizedBox(height: 10),
                    _SummaryTable(rows: _summary),
                    SizedBox(height: 12),
                    _NoteBlock(
                      'Single-model /predict uses ResNet50 v2 (focal loss + '
                      'balanced sampler): test mel recall 73.40%, F1 70.08%. '
                      'The 4-model ensemble continues to use v1 ResNet50 for '
                      'stability.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // Per-class recall
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _LabelUp('PER-CLASS RECALL'),
                        Text('⚠ < 70%', style: DSText.caption),
                      ],
                    ),
                    SizedBox(height: 10),
                    _RecallTable(rows: _recall),
                    SizedBox(height: 12),
                    _NoteBlock(
                      'Bold = v2 retraining target (mel, bcc, akiec). v2 used '
                      'focal loss + balanced sampler; non-target classes '
                      '(bkl, df, nv, vasc) are shown for completeness. Full v1 '
                      'vs v2 comparison and macro metrics in '
                      'runs_v2/SUMMARY.md.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // Confusion matrix
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _LabelUp('CONFUSION MATRIX'),
                        Text('Row-normalized', style: DSText.caption),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ResNet50 v2 · HAM10000 test split · rows = true, '
                      'cols = predicted.',
                      style: DSText.caption,
                    ),
                    SizedBox(height: 14),
                    _ConfusionHeatmap(matrix: _cm, classes: _cmClasses),
                    SizedBox(height: 12),
                    _HeatLegend(),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.cardGap),
              // Known limitations
              const _DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _LabelUp('KNOWN LIMITATIONS'),
                        Text('Read carefully', style: DSText.caption),
                      ],
                    ),
                    SizedBox(height: 10),
                    _Limitation(
                      'External validation drop. ',
                      'v2 single-model mel recall falls from 73.40% (HAM10000) '
                      'to 37.09% on ISIC 2019 (4,353 HAM-disjoint images). '
                      'v1 ensemble F1 drops 74.10% → 41.24%.',
                    ),
                    _Limitation(
                      'Strong in-distribution numbers do not generalize. ',
                      'Calibration confidence is reliable only on data '
                      'resembling the HAM10000 distribution.',
                    ),
                    _Limitation(
                      'Class imbalance. ',
                      'nv is over-represented in training; rare classes '
                      '(df, vasc) inherit lower-confidence boundaries.',
                    ),
                    _Limitation(
                      'Camera / lighting drift. ',
                      'Phone-camera shots without dermatoscopic contact differ '
                      'materially from the training distribution.',
                    ),
                    _Limitation(
                      'Not a clinical device. ',
                      'All output is illustrative; do not act on it without '
                      'clinician review.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DSSpacing.s4),
              const _DisclaimerRibbon(
                text: 'Performance numbers reflect a retrospective test split, '
                    'not prospective clinical use.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _SummaryRowData {
  const _SummaryRowData(this.model, this.acc, this.f1, this.weight,
      {this.isDefault = false});
  final String model;
  final double acc;
  final double f1;
  final int weight;
  final bool isDefault;
}

class _RecallRowData {
  const _RecallRowData(this.code, this.v1, this.v2);
  final String code;
  final List<int> v1; // RN50, DN121, ENB0, MN3
  final double? v2; // null = not measured (dash)
}

// ── Summary table ─────────────────────────────────────────────────────────────

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.rows});

  final List<_SummaryRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _tableHeader(const ['Model', 'ACC', 'F1', 'WT'], leadingFlex: 3),
        for (var i = 0; i < rows.length; i++)
          Container(
            decoration: BoxDecoration(
              border: i == rows.length - 1
                  ? null
                  : const Border(
                      bottom: BorderSide(color: DSColors.neutral100)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(rows[i].model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: DSColors.neutral700,
                            )),
                      ),
                      if (rows[i].isDefault) ...[
                        const SizedBox(width: 6),
                        const _MiniChip('DEFAULT'),
                      ],
                    ],
                  ),
                ),
                _numCell(rows[i].acc.toStringAsFixed(1)),
                _numCell(rows[i].f1.toStringAsFixed(1)),
                _numCell('${rows[i].weight}%'),
              ],
            ),
          ),
      ],
    );
  }
}

Widget _tableHeader(List<String> labels, {int leadingFlex = 2}) {
  return Container(
    padding: const EdgeInsets.only(bottom: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: DSColors.neutral100)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            flex: i == 0 ? leadingFlex : 1,
            child: Text(
              labels[i],
              textAlign: i == 0 ? TextAlign.left : TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: DSColors.neutral500,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _numCell(String text, {bool muted = false}) {
  return Expanded(
    child: Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: muted ? DSColors.neutral300 : DSColors.neutral900,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: DSColors.primary50,
        borderRadius: BorderRadius.circular(DSRadius.pill),
      ),
      child: Text(label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: DSColors.primary700,
          )),
    );
  }
}

// ── Per-class recall table ────────────────────────────────────────────────────

class _RecallTable extends StatelessWidget {
  const _RecallTable({required this.rows});

  final List<_RecallRowData> rows;

  // Deployed-v2 column emphasis tint, applied uniformly to the RN50 v2 header
  // cell + all 7 data cells so the column reads as one highlighted band.
  // (The mockup's .v2-col uses --neutral-50; this screen uses the stronger
  // primary-50 emphasis. Warn cells <70% keep this tint and signal via text
  // colour only; the dash sits on top of the tint with a muted text colour.)
  static const Color _v2Tint = DSColors.primary50;
  // v2 retraining targets (focal loss + balanced sampler) get bold emphasis;
  // non-targets are shown muted for completeness.
  static const Set<String> _v2PrimaryTargets = {'mel', 'bcc', 'akiec'};
  static const List<String> _headers = [
    'Class', 'RN50 v1', 'DN121', 'ENB0', 'MN3', 'RN50 v2',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(
          last: false,
          cells: [
            for (var i = 0; i < _headers.length; i++)
              _headerCell(_headers[i],
                  first: i == 0, isV2: i == _headers.length - 1),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          _row(
            last: r == rows.length - 1,
            cells: [
              _classCell(rows[r].code),
              for (final v in rows[r].v1) _recallCell(v.toDouble()),
              _v2DataCell(rows[r].code, rows[r].v2),
            ],
          ),
      ],
    );
  }

  // One table row: equal-width columns (Expanded flex 1) so "RN50 v2" fits on
  // a single line; stretch + inner cell padding keeps the v2 tint continuous
  // from the header through the last row. Bottom hairline drawn over the band.
  Widget _row({required List<Widget> cells, required bool last}) {
    return Container(
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: DSColors.neutral100)),
            ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final cell in cells) Expanded(child: cell)],
        ),
      ),
    );
  }

  Widget _headerCell(String label, {required bool first, required bool isV2}) {
    return Container(
      color: isV2 ? _v2Tint : null,
      padding: EdgeInsets.fromLTRB(isV2 ? 4 : 0, 0, isV2 ? 4 : 0, 8),
      alignment: first ? Alignment.bottomLeft : Alignment.bottomRight,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: first ? TextAlign.left : TextAlign.right,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: isV2 ? DSColors.primary700 : DSColors.neutral500,
        ),
      ),
    );
  }

  Widget _classCell(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.centerLeft,
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: DSColors.neutral700,
        ),
      ),
    );
  }

  Widget _recallCell(double v) {
    final warn = v < 70;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.centerRight,
      child: Text(
        warn ? '⚠ ${v.toStringAsFixed(0)}' : v.toStringAsFixed(0),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: warn ? DSColors.stateWatch500 : DSColors.neutral900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  // RN50 v2 data cell: uniform primary-50 tint (same as the header cell).
  // Style cascade (precedence: warn > primary-target > non-target):
  //   1. value < 70    -> "⚠ XX.XX", amber, bold (w700)
  //   2. primary target -> "XX.XX",   dark,  bold (w700)   [mel, bcc, akiec]
  //   3. non-target     -> "XX.XX",   muted, w500          [df, nv, vasc]
  // The tint never changes (warn is text-only). A null guard remains for
  // schema safety even though all 7 rows now carry a value. Every cell is
  // FittedBox(scaleDown)+single-line so "⚠ 69.23"/"⚠ 65.83" never wrap.
  Widget _v2DataCell(String code, double? v) {
    final bool warn = v != null && v < 70;
    final bool primary = _v2PrimaryTargets.contains(code);

    final String text;
    final Color color;
    final FontWeight weight;
    if (v == null) {
      text = '—';
      color = DSColors.neutral300;
      weight = FontWeight.w500;
    } else if (warn) {
      text = '⚠ ${v.toStringAsFixed(2)}';
      color = DSColors.stateWatch500;
      weight = FontWeight.w700;
    } else if (primary) {
      text = v.toStringAsFixed(2);
      color = DSColors.neutral900;
      weight = FontWeight.w700;
    } else {
      text = v.toStringAsFixed(2);
      color = DSColors.neutral500;
      weight = FontWeight.w500;
    }

    return Container(
      color: _v2Tint,
      padding: const EdgeInsets.fromLTRB(4, 9, 4, 9),
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: weight,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ── Confusion matrix heatmap ──────────────────────────────────────────────────

class _ConfusionHeatmap extends StatelessWidget {
  const _ConfusionHeatmap({required this.matrix, required this.classes});

  final List<List<int>> matrix;
  final List<String> classes;

  static const double _cell = 34;
  static const double _gap = 2;
  static const double _rowLabel = 34;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header: corner + column labels
          Row(
            children: [
              const SizedBox(width: _rowLabel),
              for (final c in classes)
                Container(
                  width: _cell,
                  margin: const EdgeInsets.only(left: _gap),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(c,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: DSColors.neutral500,
                      )),
                ),
            ],
          ),
          for (var r = 0; r < matrix.length; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: _gap),
              child: Row(
                children: [
                  SizedBox(
                    width: _rowLabel,
                    child: Text(classes[r],
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: DSColors.neutral700,
                        )),
                  ),
                  for (final v in matrix[r]) _heatCell(v),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _heatCell(int v) {
    final color = Color.lerp(DSColors.primary100, DSColors.primary700, v / 100)!;
    return Container(
      width: _cell,
      height: 30,
      margin: const EdgeInsets.only(left: _gap),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$v',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: v >= 55 ? DSColors.neutral0 : DSColors.neutral700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('0',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: DSColors.neutral500,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
        Expanded(
          child: Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [DSColors.primary100, DSColors.primary700],
              ),
            ),
          ),
        ),
        const Text('100%',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: DSColors.neutral500,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
      ],
    );
  }
}

// ── Note block & limitation bullet ────────────────────────────────────────────

class _NoteBlock extends StatelessWidget {
  const _NoteBlock(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DSColors.neutral50,
        borderRadius: BorderRadius.circular(DSRadius.input),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          height: 1.55,
          color: DSColors.neutral700,
        ),
      ),
    );
  }
}

class _Limitation extends StatelessWidget {
  const _Limitation(this.lead, this.rest);
  final String lead;
  final String rest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 8),
            child: SizedBox(
              width: 4,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DSColors.neutral500,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: lead,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      height: 1.65,
                      fontWeight: FontWeight.w600,
                      color: DSColors.neutral900,
                    ),
                  ),
                  TextSpan(
                    text: rest,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      height: 1.65,
                      color: DSColors.neutral700,
                    ),
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
