import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appchoferes_mobile/main.dart';

void main() {
  testWidgets('App loads and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AppChoferesApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
