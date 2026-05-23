import 'package:flutter/material.dart';

class ModelComparisonScreen extends StatelessWidget {
  const ModelComparisonScreen({super.key});

  static const models = [
    ModelMetric('MobileNetV3 Small', 0.6776, 0.5726, false),
    ModelMetric('EfficientNet-B0', 0.7745, 0.6477, false),
    ModelMetric('DenseNet121', 0.7964, 0.6896, false),
    ModelMetric('ResNet50', 0.8022, 0.6903, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Comparison')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            const _DefaultModelSummary(),
            const SizedBox(height: 14),
            for (final model in models) _ModelMetricCard(metric: model),
            const SizedBox(height: 2),
            const _SelectionNote(),
          ],
        ),
      ),
    );
  }
}

class ModelMetric {
  const ModelMetric(
    this.name,
    this.testAccuracy,
    this.macroF1,
    this.isDefault,
  );

  final String name;
  final double testAccuracy;
  final double macroF1;
  final bool isDefault;
}

class _DefaultModelSummary extends StatelessWidget {
  const _DefaultModelSummary();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ResNet50 is the default deployment model.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'The comparison uses the same held-out test set and reports test accuracy plus macro F1.',
              style: TextStyle(color: Color(0xFF475569), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelMetricCard extends StatelessWidget {
  const _ModelMetricCard({required this.metric});

  final ModelMetric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    metric.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E293B),
                        ),
                  ),
                ),
                if (metric.isDefault)
                  const Chip(
                    label: Text('Default'),
                    avatar: Icon(Icons.star_rounded, size: 17),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _MetricBar(
              label: 'Test Accuracy',
              value: metric.testAccuracy,
            ),
            const SizedBox(height: 12),
            _MetricBar(
              label: 'Macro F1',
              value: metric.macroF1,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(2)}%',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: value,
            backgroundColor: const Color(0xFFE2E8F0),
          ),
        ),
      ],
    );
  }
}

class _SelectionNote extends StatelessWidget {
  const _SelectionNote();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: Color(0xFFEFF6FF),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'ResNet50 was selected because it achieved the best overall test accuracy and macro F1 among the tested CNN architectures.',
                style: TextStyle(color: Color(0xFF1E3A8A), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
