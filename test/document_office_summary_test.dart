import 'package:capstone_app/services/document_application_validation.dart';
import 'package:capstone_app/widgets/document_office_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_interactions_test.dart' show testApp, captureUi, loadAppTestFonts;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
  });
  test('application fields reject impossible dates and arbitrary civil status',
      () {
    for (final dob in ['131231', '2026-02-30', '2027-01-01', '1899-12-31']) {
      expect(
          DocumentApplicationValidation.validate(
              birthdate: dob,
              civilStatus: 'Single',
              now: DateTime(2026, 10, 22)),
          isNotNull);
    }
    expect(
        DocumentApplicationValidation.validate(
            birthdate: '2024-02-29', civilStatus: 'Married'),
        isNull);
    expect(
        DocumentApplicationValidation.validate(birthdate: '', civilStatus: ''),
        isNull);
    expect(
        DocumentApplicationValidation.validate(
            birthdate: '', civilStatus: 'asdasd'),
        isNotNull);
  });
  for (final status in ['rejected', 'completed']) {
    testWidgets(
        '$status has appropriate guidance and conditional owner details',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp(Scaffold(
          body: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: DocumentOfficeSummary(request: {
                    'workflow_version': 2,
                    'status': status,
                    'rejection_reason': 'Synthetic missing requirement',
                    'office_payment_status': 'no_fee',
                    'office_no_fee_reason': 'Free service',
                    'office_receipt_reference': 'STALE RECEIPT',
                    'collected_by': 'STALE NAME',
                    'pickup_confirmed': false,
                    'created_at': '2026-10-22T01:00:00Z'
                  }))))));
      await tester.pumpAndSettle();
      expect(
          find.textContaining(
              'Collect the document at the office after approval'),
          findsNothing);
      if (status == 'rejected') {
        expect(find.text('Reason for rejection'), findsOneWidget);
      }
      await captureUi(tester, 'document-owner-$status');
      await tester.tap(find.text('Office payment and collection'));
      await tester.pumpAndSettle();
      expect(find.text('No fee required'), findsOneWidget);
      expect(find.text('STALE RECEIPT'), findsNothing);
      expect(find.text('STALE NAME'), findsNothing);
      expect(find.text('Not confirmed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
