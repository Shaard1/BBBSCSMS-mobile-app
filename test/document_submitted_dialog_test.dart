import 'package:capstone_app/widgets/document_submitted_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_interactions_test.dart' show testApp, captureUi, loadAppTestFonts;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
  });
  for (final scale in [1.0, 1.6]) {
    testWidgets('submission confirmation is readable and actionable at $scale',
        (tester) async {
      tester.view.physicalSize =
          scale == 1 ? const Size(390, 844) : const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(testApp(
          Scaffold(
              body: DocumentSubmittedDialog(
                  documentTitle: 'Certificate of Indigency',
                  onViewRequests: () => opened = true)),
          textScale: scale));
      await tester.pumpAndSettle();
      expect(find.text('Awaiting staff review'), findsOneWidget);
      expect(find.text('Certificate of Indigency'), findsOneWidget);
      await captureUi(tester, 'document-submitted-$scale');
      await tester.ensureVisible(find.text('View my requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View my requests'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
