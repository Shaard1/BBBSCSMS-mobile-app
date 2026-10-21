import 'package:capstone_app/screens/auth/basic_register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signup collects basic fields and explains deferred verification',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BasicRegisterScreen()));
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mobile number'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email (required for this test)'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(
        find.widgetWithText(TextFormField, 'Confirm password'), findsOneWidget);
    expect(find.textContaining('SMS is not connected'), findsOneWidget);
    expect(find.text('Birthdate'), findsNothing);
    expect(find.text('Civil status'), findsNothing);
    expect(find.text('ID type'), findsNothing);
    expect(find.text('Complete Registration'), findsNothing);
  });
}
