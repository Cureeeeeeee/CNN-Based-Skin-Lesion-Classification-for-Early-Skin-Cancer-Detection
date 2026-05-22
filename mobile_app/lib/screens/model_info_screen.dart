import 'package:flutter/material.dart';

class ModelInfoScreen extends StatelessWidget {
  const ModelInfoScreen({super.key});

  static const rows = [
    ('ResNet50', '80.22%', '69.03%'),
    ('DenseNet121', '79.64%', '68.96%'),
    ('EfficientNet-B0', '77.45%', '64.77%'),
    ('MobileNetV3 Small', '67.76%', '57.26%'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Model',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('ResNet50'),
                const SizedBox(height: 4),
                const Text(
                    'Selected by highest test accuracy and macro F1-score.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Model')),
                  DataColumn(label: Text('Acc')),
                  DataColumn(label: Text('Macro F1')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(row.$1)),
                        DataCell(Text(row.$2)),
                        DataCell(Text(row.$3)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'This result is for educational demonstration only and is not a medical diagnosis.'),
          ),
        ),
      ],
    );
  }
}
