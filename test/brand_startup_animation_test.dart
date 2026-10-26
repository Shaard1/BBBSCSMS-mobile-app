import 'dart:async';
import 'dart:ui' as ui;

import 'package:capstone_app/widgets/brand_startup_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_interactions_test.dart' show testApp, captureUi;

void main() {
  setUpAll(() async {
    await (FontLoader('PublicSansBrand')
          ..addFont(rootBundle.load('assets/fonts/PublicSans-Black.ttf')))
        .load();
  });

  testWidgets('slow first frame cannot consume the animation behind launch',
      (tester) async {
    final firstFrame = Completer<void>();
    var completions = 0;
    await tester.pumpWidget(testApp(BrandStartupAnimation(
      firstFrameReady: firstFrame.future,
      onCompleted: () => completions++,
    )));
    await tester.pump(const Duration(seconds: 6));
    expect(completions, 0);
    expect(find.text('BancaoConnect'), findsNothing);
    firstFrame.complete();
    // Deliver the engine-ready future, then establish the ticker's first frame.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(completions, 0);
    await tester.pump(const Duration(milliseconds: 920));
    expect(completions, 1);
    expect(find.text('BancaoConnect'), findsOneWidget);
  });

  testWidgets('background time does not consume the remaining animation',
      (tester) async {
    var completions = 0;
    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await tester.pumpWidget(testApp(BrandStartupAnimation(
      firstFrameReady: Future<void>.value(),
      onCompleted: () => completions++,
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));
    expect(completions, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(completions, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(completions, 1);
  });

  testWidgets('plays once, finishes after 1.8 seconds and stays still',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(testApp(BrandStartupAnimation(
        firstFrameReady: Future<void>.value(),
        onCompleted: () => completions++)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(completions, 0);
    await tester.pump(const Duration(milliseconds: 900));
    // Deliver the final vsync when the exact duration falls between frames.
    await tester.pump(const Duration(milliseconds: 20));
    expect(completions, 1);
    expect(find.text('BancaoConnect'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(completions, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows the final logo without a timed wait',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(testApp(
        BrandStartupAnimation(
            firstFrameReady: Future<void>.value(),
            onCompleted: () => completions++),
        reduceMotion: true));
    await tester.pump();
    expect(completions, 1);
    expect(find.text('BancaoConnect'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await captureUi(tester, 'startup-reduced-motion');
  });

  testWidgets('disposal cancels motion without calling the completion callback',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(testApp(BrandStartupAnimation(
        firstFrameReady: Future<void>.value(),
        onCompleted: () => completions++)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(completions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabling reduced motion during playback finishes only once',
      (tester) async {
    var completions = 0;
    Widget screen(bool reduced) => testApp(
        BrandStartupAnimation(
            firstFrameReady: Future<void>.value(),
            onCompleted: () => completions++),
        reduceMotion: reduced);
    await tester.pumpWidget(screen(false));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpWidget(screen(true));
    await tester.pump();
    expect(completions, 1);
    await tester.pumpWidget(screen(false));
    await tester.pump(const Duration(seconds: 2));
    expect(completions, 1);
  });

  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
  ]) {
    testWidgets('blue opening covers the screen and layout fits $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp(
          BrandStartupAnimation(
              firstFrameReady: Future<void>.value(), onCompleted: () {}),
          textScale: 1.8));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = data!.buffer.asUint8List();
        for (final point in [
          Offset.zero,
          Offset(size.width - 1, 0),
          Offset(0, size.height - 1),
          Offset(size.width - 1, size.height - 1),
        ]) {
          final pixel =
              (point.dy.toInt() * size.width.toInt() + point.dx.toInt()) * 4;
          expect(bytes.sublist(pixel, pixel + 4), [0, 107, 182, 255]);
        }
        image.dispose();
      });
      await tester.pump();
      var previous = 0;
      for (final ms in [300, 600, 900, 1200, 1500, 1800]) {
        await tester.pump(Duration(milliseconds: ms - previous));
        previous = ms;
        expect(tester.takeException(), isNull);
        if (size.width == 390) {
          await captureUi(tester, 'startup-motion-$ms');
        }
      }
      expect(find.text('BancaoConnect'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }
}
