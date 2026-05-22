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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Model Comparison',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ResNet50 was selected as the default deployment model because it achieved the best overall test accuracy and macro F1 among the tested CNN architectures.',
            style: TextStyle(color: Color(0xFF475569), height: 1.4),
          ),
          const SizedBox(height: 18),
          for (final model in models) _ModelMetricCard(metric: model),
        ],
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
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (metric.isDefault)
                  const Chip(
                    label: Text('Default Model'),
                    avatar: Icon(Icons.verified_rounded, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricBar(
              label: 'Test Accuracy',
              value: metric.testAccuracy,
            ),
            const SizedBox(height: 10),
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
            Expanded(child: Text(label)),
            Text('${(value * 100).toStringAsFixed(2)}%'),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(minHeight: 8, value: value),
        ),
      ],
    );
  }
}
