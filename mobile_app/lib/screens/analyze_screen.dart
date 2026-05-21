import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/prediction_result.dart';
import '../services/prediction_api.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  final _picker = ImagePicker();
  final _baseUrlController =
      TextEditingController(text: 'http://10.0.2.2:8000');
  File? _selectedImage;
  PredictionResult? _result;
  bool _isLoading = false;
  bool _mockMode = false;
  String? _error;

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 92);
    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);
      _result = null;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    final image = _selectedImage;
    if (image == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = _mockMode
          ? _mockPrediction()
          : await PredictionApi(baseUrl: _baseUrlController.text.trim())
              .predict(image);
      setState(() => _result = result);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  PredictionResult _mockPrediction() {
    return const PredictionResult(
      model: 'resnet50 mock',
      predictedClass: 'nv',
      confidence: 0.9128,
      topCandidates: [
        PredictionCandidate(className: 'nv', confidence: 0.9128),
        PredictionCandidate(className: 'mel', confidence: 0.0858),
        PredictionCandidate(className: 'bkl', confidence: 0.0013),
      ],
      disclaimer:
          'This result is for educational demonstration only and is not a medical diagnosis.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _baseUrlController,
          enabled: !_mockMode,
          decoration: const InputDecoration(
            labelText: 'Backend URL',
            prefixIcon: Icon(Icons.cloud_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mock prediction mode'),
          subtitle: const Text(
              'Use this if the backend is unavailable during a live demo.'),
          value: _mockMode,
          onChanged: (value) => setState(() {
            _mockMode = value;
            _result = null;
            _error = null;
          }),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFF9FAFB),
            ),
            child: _selectedImage == null
                ? const Center(child: Icon(Icons.image_search, size: 56))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _selectedImage == null || _isLoading ? null : _analyze,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.analytics_outlined),
          label: Text(_isLoading ? 'Analyzing' : 'Analyze'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorPanel(message: _error!),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          _ResultPanel(result: _result!),
        ],
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final PredictionResult result;

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
                const Icon(Icons.verified_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.predictedClass.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Text('${(result.confidence * 100).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Model: ${result.model}'),
            const SizedBox(height: 16),
            for (final candidate in result.topCandidates)
              _CandidateBar(candidate: candidate),
            const SizedBox(height: 12),
            Text(
              result.disclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateBar extends StatelessWidget {
  const _CandidateBar({required this.candidate});

  final PredictionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final percent = candidate.confidence.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(candidate.className)),
              Text('${(percent * 100).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: percent),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFEF2F2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
