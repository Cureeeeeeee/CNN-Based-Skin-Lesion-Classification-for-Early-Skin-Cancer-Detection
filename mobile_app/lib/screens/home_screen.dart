import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/selected_image.dart';
import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/disclaimer_ribbon.dart';
import 'classification_screen.dart';
import 'safety_about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  SelectedImage? _selectedImage;
  String? _pickerError;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 92);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = SelectedImage(file: file, bytes: bytes);
        _pickerError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pickerError = source == ImageSource.camera
            ? 'Camera unavailable in this environment. Use gallery instead.'
            : 'Could not load image: $error';
      });
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _pickerError = null;
    });
  }

  void _continue() {
    final image = _selectedImage;
    if (image == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassificationScreen(selectedImage: image),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SafetyAboutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Lesion Analysis'),
        actions: [
          IconButton(
            tooltip: 'About this system',
            icon: const Icon(Icons.info_outline),
            onPressed: _openAbout,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            const _SystemIdentity(),
            const SizedBox(height: AppSpacing.xl),
            const _ScopeCard(),
            const SizedBox(height: AppSpacing.md),
            _ImageSourceCard(
              image: _selectedImage,
              onCamera: () => _pickImage(ImageSource.camera),
              onGallery: () => _pickImage(ImageSource.gallery),
              onClear: _clearImage,
              error: _pickerError,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _selectedImage == null ? null : _continue,
              child: const Text('Continue to Analysis'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DisclaimerRibbon(),
    );
  }
}

class _SystemIdentity extends StatelessWidget {
  const _SystemIdentity();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brandAccentSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.biotech_outlined,
            color: AppColors.brandPrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Research-Grade Diagnostic-Support Prototype',
                style: AppText.title,
              ),
              SizedBox(height: 4),
              Text(
                '4-model ensemble · HAM10000 · v1.0',
                style: AppText.mono,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard();

  @override
  Widget build(BuildContext context) {
    return const StandardCard(
      child: Text(
        'This prototype uses deep-learning models trained on dermoscopy '
        'images to suggest possible lesion categories. Results are intended '
        'to support clinical and research review — not to provide a '
        'diagnosis or replace evaluation by a qualified healthcare '
        'professional.',
        style: AppText.body,
      ),
    );
  }
}

class _ImageSourceCard extends StatelessWidget {
  const _ImageSourceCard({
    required this.image,
    required this.onCamera,
    required this.onGallery,
    required this.onClear,
    required this.error,
  });

  final SelectedImage? image;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onClear;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            label: 'Load Lesion Image',
            icon: Icons.image_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          AspectRatio(
            aspectRatio: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: image == null
                  ? const _EmptyImagePlaceholder()
                  : Image.memory(image!.bytes, fit: BoxFit.cover),
            ),
          ),
          if (image != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    image!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (image == null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGallery,
                    icon: const Icon(Icons.collections_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Change image'),
              ),
            ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InlineMessage(message: error!),
          ],
        ],
      ),
    );
  }
}

class _EmptyImagePlaceholder extends StatelessWidget {
  const _EmptyImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_search_outlined,
              size: 36,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'No image loaded',
              style: AppText.captionMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.indetBg,
        border: Border.all(color: AppColors.indetBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: AppColors.indetAccent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppText.caption.copyWith(color: AppColors.indetText),
            ),
          ),
        ],
      ),
    );
  }
}
