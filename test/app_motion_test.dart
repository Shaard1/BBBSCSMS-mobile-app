import 'package:capstone_app/core/app_interactions.dart';
import 'package:capstone_app/widgets/app_tap_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_interactions_test.dart' show testApp, loadAppTestFonts;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
  });
  for (final reduce in [false, true]) {
    testWidgets(
        'press feedback keeps actions immediate and reduced motion is $reduce',
        (tester) async {
      var taps = 0;
      AnimationStyle? style;
      await tester
          .pumpWidget(testApp(Scaffold(body: Builder(builder: (context) {
        style = appMotionStyle(context);
        return Center(
            child: AppTapSurface(
                label: 'Test action',
                onTap: () => taps++,
                child: const SizedBox(
                    width: 180, height: 60, child: Text('Action'))));
      })), reduceMotion: reduce));
      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(AppTapSurface)));
      await tester.pump(const Duration(milliseconds: 120));
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.duration,
          reduce ? Duration.zero : const Duration(milliseconds: 100));
      expect(scale.scale, reduce ? 1 : lessThan(1));
      expect(style?.duration,
          reduce ? Duration.zero : const Duration(milliseconds: 180));
      await gesture.up();
      expect(taps, 1);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
