import 'dart:convert';
import 'dart:typed_data';

/// Response from `POST /predict-cam-ensemble` (Phase D.2).
///
/// One [ModelCam] per ensemble model (in `/predict-ensemble` order), each
/// carrying that model's prediction metadata plus a pre-rendered Grad-CAM
/// overlay PNG (base64 in transport, [Uint8List] in memory). A model whose
/// Grad-CAM failed server-side arrives with [heatmapBytes] null and a
/// non-null [error] string — the UI renders "Heatmap unavailable" for it
/// rather than failing the whole breakdown.
class ModelCam {
  const ModelCam({
    required this.model,
    required this.weight,
    required this.targetLayer,
    required this.predictedClass,
    required this.displayLabel,
    required this.confidence,
    required this.calibrated,
    required this.temperature,
    required this.imageSize,
    required this.heatmapBytes,
    required this.error,
  });

  final String model;
  final double weight;
  final String targetLayer;
  final String predictedClass;
  final String displayLabel;
  final double confidence;
  final bool calibrated;
  final double temperature;
  final String imageSize;
  final Uint8List? heatmapBytes;
  final String? error;

  bool get hasHeatmap => heatmapBytes != null;

  factory ModelCam.fromJson(Map<String, dynamic> json) {
    final b64 = json['heatmap_png_b64'] as String?;
    return ModelCam(
      model: (json['model'] as String?) ?? 'Unknown',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      targetLayer: (json['target_layer'] as String?) ?? 'unknown',
      predictedClass: (json['predicted_class'] as String?) ?? '',
      displayLabel: (json['display_label'] as String?) ??
          (json['predicted_class'] as String? ?? ''),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      calibrated: (json['calibrated'] as bool?) ?? false,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 1.0,
      imageSize: (json['image_size'] as String?) ?? '224x224',
      heatmapBytes: (b64 == null || b64.isEmpty) ? null : base64Decode(b64),
      error: json['error'] as String?,
    );
  }
}

class CamEnsembleResponse {
  const CamEnsembleResponse({
    required this.requestId,
    required this.inferenceTimeMs,
    required this.modelVersion,
    required this.predictedClass,
    required this.displayLabel,
    required this.confidence,
    required this.modelCams,
    required this.calibrated,
    required this.disclaimer,
  });

  final String requestId;
  final double inferenceTimeMs;
  final String modelVersion;
  final String predictedClass;
  final String displayLabel;
  final double confidence;
  final List<ModelCam> modelCams;
  final bool calibrated;
  final String disclaimer;

  /// Look up the per-model CAM by its display name (e.g. "ResNet50").
  /// Returns null if no entry matches.
  ModelCam? camFor(String model) {
    for (final cam in modelCams) {
      if (cam.model == model) return cam;
    }
    return null;
  }

  factory CamEnsembleResponse.fromJson(Map<String, dynamic> json) {
    final ens = (json['ensemble'] as Map<String, dynamic>?) ?? const {};
    final rawCams = (json['model_cams'] as List<dynamic>?) ?? const [];
    return CamEnsembleResponse(
      requestId: (json['request_id'] as String?) ?? '',
      inferenceTimeMs: (json['inference_time_ms'] as num?)?.toDouble() ?? 0.0,
      modelVersion: (json['model_version'] as String?) ?? 'unknown',
      predictedClass: (ens['predicted_class'] as String?) ?? '',
      displayLabel: (ens['display_label'] as String?) ?? '',
      confidence: (ens['confidence'] as num?)?.toDouble() ?? 0.0,
      modelCams: rawCams
          .map((e) => ModelCam.fromJson(e as Map<String, dynamic>))
          .toList(),
      calibrated: (json['calibrated'] as bool?) ?? false,
      disclaimer: (json['disclaimer'] as String?) ?? '',
    );
  }
}
