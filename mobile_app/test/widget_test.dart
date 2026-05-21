import 'package:flutter_test/flutter_test.dart';
import 'package:skin_lesion_mobile/main.dart';

void main() {
  testWidgets('renders skin lesion app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SkinLesionApp());

    expect(find.text('Skin Lesion Analysis'), findsOneWidget);
    expect(find.text('Analyze'), findsOneWidget);
    expect(find.text('Models'), findsOneWidget);
  });
}
