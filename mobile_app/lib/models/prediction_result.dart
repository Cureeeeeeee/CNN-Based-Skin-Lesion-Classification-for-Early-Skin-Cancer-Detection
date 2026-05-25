class PredictionCandidate {
  const PredictionCandidate({
    required this.className,
    required this.displayLabel,
    required this.confidence,
  });

  final String className;
  final String displayLabel;
  final double confidence;

  factory PredictionCandidate.fromJson(Map<String, dynamic> json) {
    final className = (json['label'] ?? json['class']) as String;
    return PredictionCandidate(
      className: className,
      displayLabel:
          (json['display_label'] as String?) ?? displayNameFor(className),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  String get displayText => '${className.toUpperCase()} - $displayLabel';

  static String displayNameFor(String className) {
    switch (className) {
      case 'akiec':
        return 'Actinic keratoses and intraepithelial carcinoma';
      case 'bcc':
        return 'Basal cell carcinoma';
      case 'bkl':
        return 'Benign keratosis-like lesions';
      case 'df':
        return 'Dermatofibroma';
      case 'mel':
        return 'Melanoma';
      case 'nv':
        return 'Melanocytic nevi';
      case 'vasc':
        return 'Vascular lesions';
      default:
        return className;
    }
  }
}

class PredictionResult {
  const PredictionResult({
    required this.model,
    required this.predictedClass,
    required this.confidence,
    required this.topCandidates,
    required this.disclaimer,
    required this.isMock,
    this.calibrated = false,
    this.temperature = 1.0,
  });

  final String model;
  final String predictedClass;
  final double confidence;
  final List<PredictionCandidate> topCandidates;
  final String disclaimer;
  final bool isMock;
  // Post-hoc temperature calibration (see docs/calibration_report.md).
  // True when the backend applied a fitted temperature to logits; false
  // when the model is running uncalibrated (no calibration.json present).
  final bool calibrated;
  final double temperature;

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final rawCandidates =
        (json['predictions'] ?? json['top_candidates']) as List<dynamic>;
    final candidates = rawCandidates
        .map((item) =>
            PredictionCandidate.fromJson(item as Map<String, dynamic>))
        .toList();

    return PredictionResult(
      model: (json['model'] as String?) ?? 'Unknown',
      predictedClass:
          (json['predicted_class'] as String?) ?? candidates.first.className,
      confidence: (json['confidence'] as num?)?.toDouble() ??
          candidates.first.confidence,
      topCandidates: candidates,
      disclaimer: (json['disclaimer'] as String?) ??
          'This result is for educational demonstration only and is not a medical diagnosis.',
      isMock: false,
      calibrated: (json['calibrated'] as bool?) ?? false,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static const mock = PredictionResult(
    model: 'ResNet50 mock',
    predictedClass: 'mel',
    confidence: 0.874,
    topCandidates: [
      PredictionCandidate(
        className: 'mel',
        displayLabel: 'Melanoma',
        confidence: 0.874,
      ),
      PredictionCandidate(
        className: 'bcc',
        displayLabel: 'Basal cell carcinoma',
        confidence: 0.085,
      ),
      PredictionCandidate(
        className: 'nv',
        displayLabel: 'Melanocytic nevi',
        confidence: 0.021,
      ),
    ],
    disclaimer:
        'This result is for educational demonstration only and is not a medical diagnosis.',
    isMock: true,
    calibrated: true,
    temperature: 1.539,
  );
}
