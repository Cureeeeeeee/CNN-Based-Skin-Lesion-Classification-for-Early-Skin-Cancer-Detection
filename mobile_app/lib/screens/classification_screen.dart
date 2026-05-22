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
      appBar: AppBar(title: const Text('Classification')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PreviewCard(image: widget.selectedImage),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prediction Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiUrlController,
                    enabled: !_mockMode,
                    decoration: const InputDecoration(
                      labelText: 'FastAPI base URL',
                      helperText:
                          'Web: 127.0.0.1 | Android emulator: 10.0.2.2 | Phone: PC LAN IP',
                      prefixIcon: Icon(Icons.link_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mock mode'),
                    subtitle: const Text(
                        'Use fixed sample output if the API is unavailable.'),
                    value: _mockMode,
                    onChanged: (value) => setState(() {
                      _mockMode = value;
                      _error = null;
                      _result = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _analyze,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_alt_outlined),
                    label: Text(
                        _isLoading ? 'Analyzing' : 'Analyze with ResNet50'),
                  ),
                ],
              ),
            ),
          ),
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
            aspectRatio: 1.15,
            child: Image.memory(image.bytes, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              image.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isMock
                      ? Icons.science_outlined
                      : Icons.cloud_done_outlined,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.isMock ? 'Mock prediction' : 'API prediction',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Predicted class: ${result.topCandidates.first.displayText}'),
            const SizedBox(height: 8),
            for (final candidate in result.topCandidates)
              _ConfidenceRow(candidate: candidate),
            const SizedBox(height: 10),
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
  const _ConfidenceRow({required this.candidate});

  final PredictionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final value = candidate.confidence.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(candidate.displayText)),
              Text('${(value * 100).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: value),
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
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
