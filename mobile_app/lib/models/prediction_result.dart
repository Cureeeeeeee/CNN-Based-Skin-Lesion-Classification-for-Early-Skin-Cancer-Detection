class PredictionCandidate {
  const PredictionCandidate({
    required this.className,
    required this.confidence,
  });

  final String className;
  final double confidence;

  factory PredictionCandidate.fromJson(Map<String, dynamic> json) {
    return PredictionCandidate(
      className: (json['label'] ?? json['class']) as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
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
  });

  final String model;
  final String predictedClass;
  final double confidence;
  final List<PredictionCandidate> topCandidates;
  final String disclaimer;
  final bool isMock;

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
    );
  }

  static const mock = PredictionResult(
    model: 'ResNet50 mock',
    predictedClass: 'mel',
    confidence: 0.874,
    topCandidates: [
      PredictionCandidate(className: 'mel', confidence: 0.874),
      PredictionCandidate(className: 'bcc', confidence: 0.085),
      PredictionCandidate(className: 'nv', confidence: 0.021),
    ],
    disclaimer:
        'This result is for educational demonstration only and is not a medical diagnosis.',
    isMock: true,
  );
}
