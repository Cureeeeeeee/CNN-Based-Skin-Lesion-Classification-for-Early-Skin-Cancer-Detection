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
    final topCandidate = result.topCandidates.first;
    final confidence = result.confidence.clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            _PredictionHero(
              candidate: topCandidate,
              confidence: confidence,
              isMock: result.isMock,
            ),
            const SizedBox(height: 14),
            Card(
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 1.22,
                child: Image.memory(selectedImage.bytes, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            _TopPredictionsCard(candidates: result.topCandidates),
            const SizedBox(height: 14),
            const _DisclaimerCard(),
            const SizedBox(height: 14),
            const _FutureExplanationCard(),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ModelComparisonScreen(),
                ),
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
      ),
    );
  }
}

class _PredictionHero extends StatelessWidget {
  const _PredictionHero({
    required this.candidate,
    required this.confidence,
    required this.isMock,
  });

  final PredictionCandidate candidate;
  final double confidence;
  final bool isMock;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Prediction',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isMock)
                  const Chip(
                    avatar: Icon(Icons.science_outlined, size: 16),
                    label: Text('Mock mode'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                candidate.displayText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFFB91C1C),
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: confidence,
                backgroundColor: const Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPredictionsCard extends StatelessWidget {
  const _TopPredictionsCard({required this.candidates});

  final List<PredictionCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top-3 Predictions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < candidates.length; i++)
              _CandidateTile(index: i + 1, candidate: candidates[i]),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.index, required this.candidate});

  final int index;
  final PredictionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final value = candidate.confidence.clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  candidate.displayText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(value * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: value,
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFFFFFBEB),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This result is for educational demonstration only and is not a medical diagnosis. Please consult a healthcare professional for clinical evaluation.',
                style: TextStyle(color: Color(0xFF92400E), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureExplanationCard extends StatelessWidget {
  const _FutureExplanationCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.visibility_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Grad-CAM visual explanation is planned as a future extension.',
                style: TextStyle(color: Color(0xFF475569), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
