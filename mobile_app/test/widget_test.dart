import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skin_lesion_mobile/main.dart';

void main() {
  testWidgets('home screen renders brand, welcome, and start CTA',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SkinLesionApp());
    await tester.pumpAndSettle();

    // Brand identity (redesigned HomeScreen, Stage 1)
    expect(find.text('DermaSense'), findsOneWidget);
    expect(find.text('Academic'), findsOneWidget);

    // Welcome value proposition
    expect(
      find.text('AI-assisted skin lesion classification.'),
      findsOneWidget,
    );

    // Primary CTA + secondary action
    expect(find.text('Start Analysis'), findsOneWidget);
    expect(find.text('About & safety information'), findsOneWidget);

    // Persistent educational-use disclaimer
    expect(
      find.text(
        'For educational use only. Not a medical device. Always consult a '
        'qualified clinician for diagnosis and treatment.',
      ),
      findsOneWidget,
    );
  });
}
