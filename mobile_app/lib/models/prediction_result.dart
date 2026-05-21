class PredictionCandidate {
  const PredictionCandidate({
    required this.className,
    required this.confidence,
  });

  final String className;
  final double confidence;

  factory PredictionCandidate.fromJson(Map<String, dynamic> json) {
    return PredictionCandidate(
      className: json['class'] as String,
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
  });

  final String model;
  final String predictedClass;
  final double confidence;
  final List<PredictionCandidate> topCandidates;
  final String disclaimer;

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final candidates = (json['top_candidates'] as List<dynamic>)
        .map((item) => PredictionCandidate.fromJson(item as Map<String, dynamic>))
        .toList();

    return PredictionResult(
      model: (json['model'] as String?) ?? 'Unknown',
      predictedClass: json['predicted_class'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      topCandidates: candidates,
      disclaimer: (json['disclaimer'] as String?) ?? 'Research prototype only.',
    );
  }
}

