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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            const _IntroHeader(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.photo_camera_rounded,
                    label: 'Take Photo',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.image_rounded,
                    label: 'Upload Image',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ImagePreviewCard(selectedImage: _selectedImage),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _openClassification,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Analyze'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              _InfoCard(message: _message!),
            ],
            const SizedBox(height: 14),
            const _DisclaimerCard(),
          ],
        ),
      ),
    );
  }
}

class _IntroHeader extends StatelessWidget {
  const _IntroHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: Color(0xFF2563EB),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Skin Lesion Classification',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI-based skin lesion screening support',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'For educational demonstration only. This is not a medical diagnosis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2563EB),
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: const Color(0x332563EB),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Selected Image',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 1.18,
            child: selectedImage == null
                ? const _EmptyImageState()
                : Image.memory(selectedImage!.bytes, fit: BoxFit.cover),
          ),
          if (selectedImage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                selectedImage!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyImageState extends StatelessWidget {
  const _EmptyImageState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_search_rounded,
              size: 52,
              color: Color(0xFF93A4B8),
            ),
            SizedBox(height: 10),
            Text(
              'No image selected',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
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
                'This app is not a medical diagnosis tool. Please consult a healthcare professional for clinical evaluation.',
                style: TextStyle(color: Color(0xFF92400E), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
