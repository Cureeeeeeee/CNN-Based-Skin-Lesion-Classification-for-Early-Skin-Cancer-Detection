import 'prediction_result.dart';

class ModelPrediction {
  const ModelPrediction({
    required this.model,
    required this.weight,
    required this.predictedClass,
    required this.displayLabel,
    required this.confidence,
    required this.topCandidates,
  });

  final String model;
  final double weight;
  final String predictedClass;
  final String displayLabel;
  final double confidence;
  final List<PredictionCandidate> topCandidates;

  factory ModelPrediction.fromJson(Map<String, dynamic> json) {
    final rawList = json['predictions'] as List<dynamic>;
    return ModelPrediction(
      model: json['model'] as String,
      weight: (json['weight'] as num).toDouble(),
      predictedClass: json['predicted_class'] as String,
      displayLabel: (json['display_label'] as String?) ??
          PredictionCandidate.displayNameFor(json['predicted_class'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      topCandidates: rawList
          .map((e) => PredictionCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EnsembleResult {
  const EnsembleResult({
    required this.requestId,
    required this.inferenceTimeMs,
    required this.modelVersion,
    required this.predictedClass,
    required this.displayLabel,
    required this.confidence,
    required this.topCandidates,
    required this.modelOutputs,
    required this.modelsAgree,
    this.agreementNote,
    required this.disclaimer,
  });

  final String requestId;
  final double inferenceTimeMs;
  final String modelVersion;
  final String predictedClass;
  final String displayLabel;
  final double confidence;
  final List<PredictionCandidate> topCandidates;
  final List<ModelPrediction> modelOutputs;
  final bool modelsAgree;
  final String? agreementNote;
  final String disclaimer;

  factory EnsembleResult.fromJson(Map<String, dynamic> json) {
    final ens = json['ensemble'] as Map<String, dynamic>;
    final rawPredictions = ens['predictions'] as List<dynamic>;
    final rawOutputs = json['model_outputs'] as List<dynamic>;
    return EnsembleResult(
      requestId: (json['request_id'] as String?) ?? '',
      inferenceTimeMs:
          (json['inference_time_ms'] as num?)?.toDouble() ?? 0.0,
      modelVersion: (json['model_version'] as String?) ?? 'unknown',
      predictedClass: ens['predicted_class'] as String,
      displayLabel: (ens['display_label'] as String?) ??
          PredictionCandidate.displayNameFor(
              ens['predicted_class'] as String),
      confidence: (ens['confidence'] as num).toDouble(),
      topCandidates: rawPredictions
          .map((e) =>
              PredictionCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      modelOutputs: rawOutputs
          .map((e) =>
              ModelPrediction.fromJson(e as Map<String, dynamic>))
          .toList(),
      modelsAgree: (json['models_agree'] as bool?) ?? true,
      agreementNote: json['agreement_note'] as String?,
      disclaimer: (json['disclaimer'] as String?) ??
          'This result is for research-grade diagnostic-support purposes only'
              ' and is not a medical diagnosis.',
    );
  }

  static const mock = EnsembleResult(
    requestId: 'mock-0000-demo',
    inferenceTimeMs: 201.6,
    modelVersion: 'ensemble-v1-mock',
    predictedClass: 'mel',
    displayLabel: 'Melanoma',
    confidence: 0.742,
    topCandidates: [
      PredictionCandidate(
          className: 'mel',
          displayLabel: 'Melanoma',
          confidence: 0.742),
      PredictionCandidate(
          className: 'bcc',
          displayLabel: 'Basal cell carcinoma',
          confidence: 0.183),
      PredictionCandidate(
          className: 'nv',
          displayLabel: 'Melanocytic nevi',
          confidence: 0.052),
    ],
    modelOutputs: [
      ModelPrediction(
        model: 'ResNet50',
        weight: 0.38,
        predictedClass: 'mel',
        displayLabel: 'Melanoma',
        confidence: 0.784,
        topCandidates: [
          PredictionCandidate(
              className: 'mel',
              displayLabel: 'Melanoma',
              confidence: 0.784),
          PredictionCandidate(
              className: 'bcc',
              displayLabel: 'Basal cell carcinoma',
              confidence: 0.142),
          PredictionCandidate(
              className: 'nv',
              displayLabel: 'Melanocytic nevi',
              confidence: 0.044),
        ],
      ),
      ModelPrediction(
        model: 'DenseNet121',
        weight: 0.37,
        predictedClass: 'mel',
        displayLabel: 'Melanoma',
        confidence: 0.701,
        topCandidates: [
          PredictionCandidate(
              className: 'mel',
              displayLabel: 'Melanoma',
              confidence: 0.701),
          PredictionCandidate(
              className: 'bcc',
              displayLabel: 'Basal cell carcinoma',
              confidence: 0.213),
          PredictionCandidate(
              className: 'nv',
              displayLabel: 'Melanocytic nevi',
              confidence: 0.061),
        ],
      ),
      ModelPrediction(
        model: 'EfficientNet-B0',
        weight: 0.20,
        predictedClass: 'bcc',
        displayLabel: 'Basal cell carcinoma',
        confidence: 0.612,
        topCandidates: [
          PredictionCandidate(
              className: 'bcc',
              displayLabel: 'Basal cell carcinoma',
              confidence: 0.612),
          PredictionCandidate(
              className: 'mel',
              displayLabel: 'Melanoma',
              confidence: 0.298),
          PredictionCandidate(
              className: 'akiec',
              displayLabel:
                  'Actinic keratoses and intraepithelial carcinoma',
              confidence: 0.060),
        ],
      ),
      ModelPrediction(
        model: 'MobileNetV3 Small',
        weight: 0.05,
        predictedClass: 'mel',
        displayLabel: 'Melanoma',
        confidence: 0.543,
        topCandidates: [
          PredictionCandidate(
              className: 'mel',
              displayLabel: 'Melanoma',
              confidence: 0.543),
          PredictionCandidate(
              className: 'bkl',
              displayLabel: 'Benign keratosis-like lesions',
              confidence: 0.244),
          PredictionCandidate(
              className: 'bcc',
              displayLabel: 'Basal cell carcinoma',
              confidence: 0.133),
        ],
      ),
    ],
    modelsAgree: false,
    agreementNote:
        'Models disagree. Top predictions: 3× Melanoma, 1× Basal cell carcinoma.',
    disclaimer:
        'This result is for research-grade diagnostic-support purposes only'
        ' and is not a medical diagnosis.',
  );
}
