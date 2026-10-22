import 'package:capstone_app/widgets/document_office_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_interactions_test.dart' show testApp, loadAppTestFonts, captureUi;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
  });
  test('readable dates use 12-hour time at midnight, noon and afternoon', () {
    expect(formatDocumentDate('2026-10-21T00:05:00'),
        'October 21, 2026 · 12:05 AM');
    expect(formatDocumentDate('2026-10-21T12:05:00'),
        'October 21, 2026 · 12:05 PM');
    expect(formatDocumentDate('2026-10-21T13:57:00'),
        'October 21, 2026 · 1:57 PM');
  });
  testWidgets(
      'small screen with double-sized text retains summaries and deduplicates dates',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(
        const Scaffold(
            body: SingleChildScrollView(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: DocumentOfficeSummary(request: {
                      'workflow_version': 2,
                      'status': 'pending',
                      'identity_evidence_method': 'in_person',
                      'created_at': '2026-10-21T13:57:00',
                      'updated_at': '2026-10-21T13:57:00'
                    })))),
        textScale: 2));
    expect(find.text('ID and address review pending'), findsOneWidget);
    expect(find.text('Collection not yet confirmed'), findsOneWidget);
    expect(find.text('Not yet settled at the office'), findsNothing);
    await captureUi(tester, 'document-large-text-summary');
    expect(find.text('Request dates'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('last updated appears only for later valid timestamps',
      (tester) async {
    for (final timestamp in [
      '2026-10-21T13:57:00',
      '2026-10-21T12:57:00',
      'invalid',
      null,
      '2026-10-21T14:57:00'
    ]) {
      await tester.pumpWidget(testApp(Scaffold(
          body: DocumentLastUpdated(request: {
        'created_at': '2026-10-21T13:57:00',
        'updated_at': timestamp,
      }))));
      expect(find.textContaining('Last updated'),
          timestamp == '2026-10-21T14:57:00' ? findsOneWidget : findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
    }
  });
}
