import 'package:capstone_app/screens/residents/document_evidence_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_interactions_test.dart' show testApp, captureUi, loadAppTestFonts;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
  });

  Future<void> open(WidgetTester tester,
      {Size size = const Size(390, 844), double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(
        const DocumentEvidenceScreen(requesterName: 'Synthetic resident'),
        textScale: scale));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 150,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('requirements-list')),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
  }

  testWidgets('visible choices, private evidence explanation and fixed action',
      (tester) async {
    await open(tester);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Prepare your documents'), findsOneWidget);
    expect(find.textContaining('Staff may still ask to inspect originals'),
        findsOneWidget);
    final button = find.byKey(const ValueKey('continue-submission'));
    final initial = tester.getRect(button);
    await captureUi(tester, 'document-requirements-self');
    await reveal(tester, 'section-residency');
    expect(find.text('Proof of address'), findsOneWidget);
    expect(tester.getRect(button), initial);
    expect(find.text('Choose photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'representative requirements and missing-upload error stay understandable',
      (tester) async {
    await open(tester);
    await reveal(tester, 'capacity-representative');
    await tester.tap(find.byKey(const ValueKey('capacity-representative')));
    await tester.pumpAndSettle();
    await reveal(tester, 'section-authorization');
    expect(find.text('Permission to apply for someone else'), findsOneWidget);
    await reveal(tester, 'authorization-upload');
    await tester.tap(find.byKey(const ValueKey('authorization-upload')));
    await tester.pumpAndSettle();
    await reveal(tester, 'choose-authorization');
    expect(
        find.text('JPEG, PNG or WebP · Up to 10 MB per photo'), findsOneWidget);
    await captureUi(tester, 'document-requirements-representative');
    await tester.tap(find.byKey(const ValueKey('continue-submission')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Choose the required image').hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone with large text keeps action above keyboard',
      (tester) async {
    await open(tester, size: const Size(320, 568), scale: 1.6);
    await reveal(tester, 'identity-upload');
    await tester.tap(find.byKey(const ValueKey('identity-upload')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextField), 100,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('requirements-list')),
                matching: find.byType(Scrollable))
            .first);
    await tester.enterText(find.byType(TextField), 'Sample document');
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('continue-submission'));
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(568 - 220));
    expect(button.hitTestable(), findsOneWidget);
    await captureUi(tester, 'document-requirements-keyboard-large-text');
    expect(tester.takeException(), isNull);
  });
}
