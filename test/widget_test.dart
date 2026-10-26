import 'dart:async';
import 'dart:io';

import 'package:capstone_app/main.dart';
import 'package:capstone_app/core/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:capstone_app/screens/auth/login_screen.dart';
import 'package:capstone_app/screens/auth/register_screen.dart';
import 'package:capstone_app/widgets/app_launch_view.dart';
import 'package:capstone_app/widgets/brand_startup_animation.dart';
import 'package:capstone_app/screens/residents/resident_dashboard_screen.dart';
import 'app_interactions_test.dart' show testApp, captureUi, loadAppTestFonts;

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

void main() {
  late BuiltInMapCachingProvider mapCache;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
    // Widget tests have no native path_provider plugin. Give the map an
    // isolated cache instead of asking the platform for its cache directory.
    final buildDirectory = await Directory('build').create(recursive: true);
    final cacheDirectory = await buildDirectory.createTemp('widget-map-cache-');
    mapCache = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: cacheDirectory.absolute.path,
      maxCacheSize: null,
      readOnly: true,
    );
    // Initialize the same boundary used by the intro screen without persisting
    // a session or making authentication requests.
    await SupabaseConfig.initialize(
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        persistSession: false,
        pkceAsyncStorage: _MemoryPkceStorage(),
      ),
    );
  });

  tearDownAll(() => mapCache.destroy(deleteCache: true));

  testWidgets('mobile app builds its MaterialApp shell', (tester) async {
    await tester.pumpWidget(MyApp(firstFrameReady: Future<void>.value()));

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('startup waits for initialization and the logo presentation',
      (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(MyApp(
        firstFrameReady: Future<void>.value(),
        initialize: () => initialization.future));
    expect(find.byType(BrandStartupAnimation), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LoginScreen), findsNothing);
    initialization.complete();
    await tester.pump();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppLaunchView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup failure has a retry without exposing technical errors',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MyApp(
        firstFrameReady: Future<void>.value(),
        initialize: () async {
          attempts++;
          if (attempts == 1) throw StateError('internal connection detail');
        }));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('internal connection detail'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LoginScreen), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('login stays scrollable with a keyboard and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(testApp(const LoginScreen(), textScale: 1.6));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Login'), 120);
    await tester.ensureVisible(find.text('Login'));
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.text('Login')).dy, lessThan(318));
    expect(tester.takeException(), isNull);
    await captureUi(tester, 'login-keyboard-large-text');
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
  });

  testWidgets('registration retains its layout with large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(const RegisterScreen(), textScale: 1.5));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureUi(tester, 'registration');
  });

  testWidgets('dashboard restores Home scroll position after switching tabs',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(testApp(const ResidentDashboardScreen(name: 'Resident')));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    final home = find.byKey(const PageStorageKey('home'));
    await tester.drag(home, const Offset(0, -300));
    await tester.pumpAndSettle();
    double position() => tester
        .state<ScrollableState>(
          find.descendant(of: home, matching: find.byType(Scrollable)).first,
        )
        .position
        .pixels;
    final offset = position();
    expect(offset, greaterThan(0));
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(position(), closeTo(offset, 1));
    await tester.tap(find.text('Services').last);
    await tester.pumpAndSettle();
    await captureUi(tester, 'services');
    await tester.tap(find.text('File a Report'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'Streetlight near the corner');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureUi(tester, 'report-keyboard');
    tester.view.resetViewInsets();
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Services').last);
    await tester.pumpAndSettle();
    expect(find.text('Streetlight near the corner'), findsOneWidget);
    await tester.tap(find.text('Activity').last);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.text('Services').last);
    await tester.pumpAndSettle();
    expect(find.text('Streetlight near the corner'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('File a Report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets(
        'report form validates and keeps draft after photo picker cancellation at $scale',
        (tester) async {
      tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp(
          const ResidentDashboardScreen(name: 'Resident', initialTabIndex: 1),
          textScale: scale));
      await tester.pumpAndSettle();
      await tester.tap(find.text('File a Report'));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsNothing);
      await captureUi(tester, 'new-report-$scale');

      await tester.ensureVisible(find.text('Submit Report'));
      await tester.pumpAndSettle();
      await captureUi(tester, 'new-report-location-$scale');
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();
      expect(find.text('Choose an issue category.'), findsOneWidget);
      expect(
          find.text('Describe the issue you are reporting.'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Issue category')).dy, lessThan(600));
      await tester.tap(find.text('Choose a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Road Damage'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(
          find.byType(TextField).first, 'Road damage near the covered court.');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Choose an issue category.'), findsNothing);
      expect(find.text('Describe the issue you are reporting.'), findsNothing);

      final addPhotos = find.widgetWithText(OutlinedButton, 'Add photos');
      await tester.ensureVisible(addPhotos);
      await tester.tap(addPhotos);
      await tester.pumpAndSettle();
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      await captureUi(tester, 'report-photo-options-$scale');
      await tester.tap(find.byTooltip('Close photo options'));
      await tester.pumpAndSettle();
      expect(find.text('Road damage near the covered court.'), findsOneWidget);
      await tester.ensureVisible(find.text('Submit Report'));
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();
      expect(find.text('Add at least one photo of the issue.'), findsOneWidget);
      expect(tester.getCenter(addPhotos).dy, lessThan(720));
      await tester.ensureVisible(find.text('Choose on map'));
      await tester.tap(find.text('Choose on map'));
      await tester.pumpAndSettle();
      expect(find.byType(MarkerLayer), findsNothing);
      await tester.tap(find.byType(FlutterMap));
      // The map waits briefly to distinguish a tap from double-tap zoom.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(MarkerLayer), findsOneWidget);
      await tester.tap(find.text('Confirm Location'));
      await tester.pumpAndSettle();
      expect(find.text('Location selected'), findsOneWidget);
      expect(find.text('Choose the location of the issue before submitting.'),
          findsNothing);
      final firstCenter = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options
          .initialCenter;
      await tester.ensureVisible(find.text('Change pin on map'));
      await tester.tap(find.text('Change pin on map'));
      await tester.pumpAndSettle();
      await tester.tapAt(
          tester.getCenter(find.byType(FlutterMap)) + const Offset(30, 20));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Location'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FlutterMap>(find.byType(FlutterMap))
              .options
              .initialCenter,
          isNot(firstCenter));
      await tester.ensureVisible(find.text('Submit Report'));
      await captureUi(tester, 'report-selected-location-$scale');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
