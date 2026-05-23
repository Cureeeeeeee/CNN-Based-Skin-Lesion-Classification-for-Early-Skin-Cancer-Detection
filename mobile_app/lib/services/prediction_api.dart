import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ensemble_result.dart';
import '../models/prediction_result.dart';
import '../models/selected_image.dart';

class PredictionApi {
  const PredictionApi({required this.baseUrl});

  final String baseUrl;

  String get _cleanBaseUrl => baseUrl.trim().replaceAll(RegExp(r'/$'), '');

  Future<Map<String, dynamic>> health() async {
    final response = await http.get(Uri.parse('$_cleanBaseUrl/health'));
    if (response.statusCode != 200) {
      throw Exception('Backend health check failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<PredictionResult> predict(SelectedImage image) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_cleanBaseUrl/predict'));
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        image.bytes,
        filename: image.name,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception(_formatError(response));
    }

    return PredictionResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<EnsembleResult> predictEnsemble(SelectedImage image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_cleanBaseUrl/predict-ensemble'),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        image.bytes,
        filename: image.name,
      ),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception(_formatError(response));
    }
    return EnsembleResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  String _formatError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is Map<String, dynamic>) {
        return detail['message'] as String? ??
            'Prediction failed: ${response.statusCode}';
      }
      if (detail is String) {
        return detail;
      }
    } catch (_) {
      // Fall through to generic message.
    }
    return 'Prediction failed: ${response.statusCode} ${response.reasonPhrase ?? ''}';
  }
}
