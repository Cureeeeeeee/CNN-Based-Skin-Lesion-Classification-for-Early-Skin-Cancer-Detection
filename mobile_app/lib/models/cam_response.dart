import 'dart:convert';
import 'dart:typed_data';

/// Response from `POST /predict-cam`.
///
/// Carries the model's prediction metadata plus a pre-rendered overlay
/// PNG (base64 in transport, [Uint8List] in memory). The overlay is
/// already colour-blended server-side so the client just decodes and
/// displays — no client-side colourmap maths.
///
/// Backend produces this only for the single-model (ResNet50) path.
/// Ensemble-mode Grad-CAM is out of scope for Phase B.
class CamResponse {
  const CamResponse({
    required this.model,
    required this.predictedClass,
    required this.displayLabel,
    required this.confidence,
    required this.calibrated,
    required this.temperature,
    required this.method,
    required this.targetLayer,
    required this.imageSize,
    required this.heatmapBytes,
    required this.disclaimer,
  });

  final String model;
  final String predictedClass;
  final String displayLabel;
  final double confidence;
  final bool calibrated;
  final double temperature;
  final String method;
  final String targetLayer;
  final int imageSize;
  final Uint8List heatmapBytes;
  final String disclaimer;

  factory CamResponse.fromJson(Map<String, dynamic> json) {
    final b64 = json['heatmap_png_b64'] as String;
    return CamResponse(
      model: (json['model'] as String?) ?? 'Unknown',
      predictedClass: json['predicted_class'] as String,
      displayLabel: (json['display_label'] as String?) ?? json['predicted_class'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      calibrated: (json['calibrated'] as bool?) ?? false,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 1.0,
      method: (json['method'] as String?) ?? 'grad-cam',
      targetLayer: (json['target_layer'] as String?) ?? 'unknown',
      imageSize: (json['image_size'] as num?)?.toInt() ?? 224,
      heatmapBytes: base64Decode(b64),
      disclaimer: (json['disclaimer'] as String?) ?? '',
    );
  }
}
