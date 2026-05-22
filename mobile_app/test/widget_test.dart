import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skin_lesion_mobile/main.dart';

void main() {
  testWidgets('renders skin lesion app shell', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SkinLesionApp());

    expect(find.text('Skin Lesion Classification'), findsWidgets);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Upload Image'), findsOneWidget);
    expect(find.text('Analyze'), findsOneWidget);
  });
}
