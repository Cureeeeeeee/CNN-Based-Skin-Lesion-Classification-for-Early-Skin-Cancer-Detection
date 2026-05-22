import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/selected_image.dart';
import 'classification_screen.dart';
import 'model_comparison_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  SelectedImage? _selectedImage;
  String? _message;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 92);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedImage = SelectedImage(file: file, bytes: bytes);
        _message = null;
      });
    } catch (error) {
      setState(() {
        _message = source == ImageSource.camera
            ? 'Camera is unavailable in this environment. Please use Upload Image.'
            : 'Image selection failed: $error';
      });
    }
  }

  void _openClassification() {
    final image = _selectedImage;
    if (image == null) {
      setState(() => _message = 'Please select an image first.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassificationScreen(selectedImage: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Lesion Classification'),
        actions: [
          IconButton(
            tooltip: 'Model comparison',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ModelComparisonScreen()),
            ),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _HeroPanel(),
          const SizedBox(height: 18),
          _ImagePreviewCard(selectedImage: _selectedImage),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take Photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload Image'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openClassification,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Analyze'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            _InfoCard(message: _message!),
          ],
          const SizedBox(height: 16),
          const _DisclaimerCard(),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Skin Lesion Classification',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI-based skin lesion screening support. This is for educational demonstration only.',
              style: TextStyle(color: Color(0xFF475569), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewCard extends StatelessWidget {
  const _ImagePreviewCard({required this.selectedImage});

  final SelectedImage? selectedImage;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1,
        child: selectedImage == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_search_rounded, size: 56),
                    SizedBox(height: 10),
                    Text('No image selected'),
                  ],
                ),
              )
            : Image.memory(selectedImage!.bytes, fit: BoxFit.cover),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'This app is not a medical diagnosis tool. Please consult a healthcare professional for clinical evaluation.',
          style: TextStyle(color: Color(0xFF475569)),
        ),
      ),
    );
  }
}
