import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../models/selected_image.dart';
import '../services/prediction_api.dart';
import 'result_screen.dart';

class ClassificationScreen extends StatefulWidget {
  const ClassificationScreen({super.key, required this.selectedImage});

  final SelectedImage selectedImage;

  @override
  State<ClassificationScreen> createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  late final TextEditingController _apiUrlController;
  bool _mockMode = false;
  bool _isLoading = false;
  String? _error;
  PredictionResult? _result;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(
      text: kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000',
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = _mockMode
          ? PredictionResult.mock
          : await PredictionApi(baseUrl: _apiUrlController.text)
              .predict(widget.selectedImage);
      setState(() => _result = result);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openResult() {
    final result = _result;
    if (result == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          selectedImage: widget.selectedImage,
          result: result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skin Lesion Classification')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            _PreviewCard(image: widget.selectedImage),
            const SizedBox(height: 14),
            _ControlCard(
              apiUrlController: _apiUrlController,
              mockMode: _mockMode,
              isLoading: _isLoading,
              onMockModeChanged: (value) => setState(() {
                _mockMode = value;
                _error = null;
                _result = null;
              }),
              onAnalyze: _analyze,
            ),
            if (_isLoading) ...[
              const SizedBox(height: 14),
              const _LoadingCard(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorCard(message: _error!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 14),
              _InlineResult(result: _result!, onViewResult: _openResult),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.image});

  final SelectedImage image;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.22,
            child: Image.memory(image.bytes, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.image_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    image.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.apiUrlController,
    required this.mockMode,
    required this.isLoading,
    required this.onMockModeChanged,
    required this.onAnalyze,
  });

  final TextEditingController apiUrlController;
  final bool mockMode;
  final bool isLoading;
  final ValueChanged<bool> onMockModeChanged;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  'Image Classification',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: apiUrlController,
              enabled: !mockMode,
              decoration: const InputDecoration(
                labelText: 'FastAPI base URL',
                helperText:
                    'Web: 127.0.0.1 | Emulator: 10.0.2.2 | Phone: PC LAN IP',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    mockMode ? Icons.science_rounded : Icons.cloud_done,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mockMode ? 'Mock mode' : 'API mode',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          mockMode
                              ? 'Uses fixed fallback predictions.'
                              : 'Calls FastAPI /predict with ResNet50.',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: mockMode, onChanged: onMockModeChanged),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: isLoading ? null : onAnalyze,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.psychology_alt_outlined),
              label: Text(isLoading ? 'Analyzing image' : 'Analyze'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Analyzing image with ResNet50...',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineResult extends StatelessWidget {
  const _InlineResult({required this.result, required this.onViewResult});

  final PredictionResult result;
  final VoidCallback onViewResult;

  @override
  Widget build(BuildContext context) {
    final confidence = result.confidence.clamp(0.0, 1.0).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Icon(
                    result.isMock
                        ? Icons.science_outlined
                        : Icons.cloud_done_outlined,
                    color: const Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.isMock ? 'Mock prediction' : 'API prediction',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              result.topCandidates.first.displayText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB91C1C),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < result.topCandidates.length; i++)
              _ConfidenceRow(index: i + 1, candidate: result.topCandidates[i]),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onViewResult,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('View Full Result'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({required this.index, required this.candidate});

  final int index;
  final PredictionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final value = candidate.confidence.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$index.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              candidate.displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text('${(value * 100).toStringAsFixed(1)}%'),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFEF2F2),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFF7F1D1D)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
