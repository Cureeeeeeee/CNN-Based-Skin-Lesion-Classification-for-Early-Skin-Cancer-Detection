import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../models/selected_image.dart';
import 'model_comparison_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.selectedImage,
    required this.result,
  });

  final SelectedImage selectedImage;
  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    final confidence = result.confidence.clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Result')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 1.15,
              child: Image.memory(selectedImage.bytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prediction: ${result.predictedClass.toUpperCase()}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(confidence * 100).toStringAsFixed(1)}% confidence',
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                  if (result.isMock) ...[
                    const SizedBox(height: 8),
                    const Chip(
                      label: Text('Mock mode enabled'),
                      avatar: Icon(Icons.science_outlined, size: 18),
                    ),
                  ],
                  const SizedBox(height: 16),
                  for (final candidate in result.topCandidates)
                    _CandidateTile(candidate: candidate),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            color: Color(0xFFFFFBEB),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'This result is for educational demonstration only and is not a medical diagnosis. Please consult a healthcare professional for clinical evaluation.',
                style: TextStyle(color: Color(0xFF92400E), height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Visual explanation placeholder - Grad-CAM planned as future extension.',
                style: TextStyle(color: Color(0xFF475569)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ModelComparisonScreen()),
            ),
            icon: const Icon(Icons.bar_chart_rounded),
            label: const Text('View Models'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Back / Re-analyze'),
          ),
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate});

  final PredictionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final value = candidate.confidence.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  candidate.className.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${(value * 100).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: value,
            ),
          ),
        ],
      ),
    );
  }
}
