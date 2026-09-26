import 'dart:io';
import 'dart:ui' as ui;

import 'package:capstone_app/core/app_interactions.dart';
import 'package:capstone_app/core/app_theme.dart';
import 'package:capstone_app/widgets/app_launch_view.dart';
import 'package:capstone_app/widgets/app_selection_field.dart';
import 'package:capstone_app/widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> loadAppTestFonts() async {
  for (final family in ['Inter', 'Roboto']) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    await loader.load();
  }
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
}

Future<void> captureUi(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Widget testApp(Widget child,
        {double textScale = 1, bool reduceMotion = false}) =>
    RepaintBoundary(
      key: const ValueKey('capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        scrollBehavior: const AppScrollBehavior(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: child,
      ),
    );

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
  });
  tearDown(TopToast.dismiss);

  testWidgets('picker keeps form in place and commits only a chosen option',
      (tester) async {
    String? selected;
    await tester.pumpWidget(testApp(Scaffold(
        body: StatefulBuilder(
      builder: (context, setState) => Column(children: [
        AppSelectionField(
            label: 'Civil status',
            value: selected,
            options: const ['Single', 'Married', 'Widowed'],
            onSelected: (value) => setState(() => selected = value)),
        const Text('Next field'),
      ]),
    ))));
    final fieldPosition = tester.getTopLeft(find.text('Next field'));
    await tester.tap(find.text('Civil status'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Next field')), fieldPosition);
    await tester.tap(find.text('Married'));
    await tester.pumpAndSettle();
    expect(selected, 'Married');
    await tester.tap(find.text('Married'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Married'))
            .selected,
        isTrue);
    await tester.tap(find.byTooltip('Close choices'));
    await tester.pumpAndSettle();
    expect(selected, 'Married');
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker scrolls at large text sizes on a small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(testApp(
        Scaffold(
            body: AppSelectionField(
          label: 'Choose an issue category',
          options: const [
            'Road Damage',
            'Garbage Collection',
            'Broken Streetlight',
            'Drainage Issue',
            'Noise Complaint',
            'Others'
          ],
          onSelected: (value) => selected = value,
        )),
        textScale: 1.8));
    await tester.tap(find.text('Choose an issue category'));
    await tester.pumpAndSettle();
    await captureUi(tester, 'category-picker-large-text');
    for (var i = 0;
        i < 8 && find.text('Others').hitTestable().evaluate().isEmpty;
        i++) {
      await tester.dragFrom(const Offset(160, 520), const Offset(0, -150));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Others'));
    await tester.pumpAndSettle();
    expect(selected, 'Others');
    expect(tester.takeException(), isNull);
  });

  testWidgets('launch presents both brands and honors reduced motion',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(const AppLaunchView(), reduceMotion: true));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(find.text('BancaoConnect'), findsOneWidget);
    expect(
        find.bySemanticsLabel('Barangay Bancao-Bancao seal'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await captureUi(tester, 'launch');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging a form dismisses its keyboard focus', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(testApp(Scaffold(
        body: ListView(children: [
      TextField(focusNode: focus),
      const SizedBox(height: 1500),
    ]))));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('messages can be dismissed before their timer ends',
      (tester) async {
    await tester.pumpWidget(testApp(Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                onPressed: () => TopToast.show(context, 'Saved successfully'),
                child: const Text('Save'))))));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved successfully'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss message'));
    await tester.pumpAndSettle();
    expect(find.text('Saved successfully'), findsNothing);
  });
}
