import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_super_app/main.dart';

void main() {
  testWidgets('About screen displays app title and owner', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: InAppAboutScreen()));
    expect(find.text('Offline Office SuperApp'), findsOneWidget);
    expect(find.textContaining('Nandani Kumari'), findsWidgets);
  });
}
