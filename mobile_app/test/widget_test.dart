import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skin_lesion_mobile/main.dart';

void main() {
  testWidgets('home screen renders identity, scope, source controls',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SkinLesionApp());
    await tester.pumpAndSettle();

    // AppBar title
    expect(find.text('Skin Lesion Analysis'), findsOneWidget);

    // System identity block
    expect(
      find.text('Research-Grade Diagnostic-Support Prototype'),
      findsOneWidget,
    );

    // Image source card and its actions
    expect(find.text('Load Lesion Image'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    // Primary CTA (disabled until an image is selected, but text present)
    expect(find.text('Continue to Analysis'), findsOneWidget);

    // Persistent disclaimer ribbon
    expect(
      find.text(
        'Not a medical diagnosis. For research and educational use.',
      ),
      findsOneWidget,
    );
  });
}
