import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/prediction_result.dart';

class PredictionApi {
  const PredictionApi({required this.baseUrl});

  final String baseUrl;

  Future<Map<String, dynamic>> health() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    if (response.statusCode != 200) {
      throw Exception('Backend health check failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<PredictionResult> predict(File imageFile) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/predict'));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception('Prediction failed: ${response.statusCode} ${response.body}');
    }

    return PredictionResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

