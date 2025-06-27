// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sambandha_app/main.dart';

void main() {
  testWidgets('App starts on LoginPage', (tester) async {
    // 1. build MyApp
    await tester.pumpWidget(const MyApp());

    // 2. verify the LoginPage title is on-screen
    expect(find.text('Create an account'), findsOneWidget);

    // 3. enter an invalid email, tap Continue, expect an error
    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Continue'));
    await tester.pump(); // rebuild after tap

    expect(find.text('Enter a valid email'), findsOneWidget);
  });
}
