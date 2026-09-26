import 'dart:async';

import 'package:capstone_app/main.dart';
import 'package:capstone_app/core/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:capstone_app/screens/auth/login_screen.dart';
import 'package:capstone_app/screens/auth/register_screen.dart';
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
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
    // MyApp's route table creates AuthService during widget mounting. The
    // production entry point initializes Supabase before runApp, so mirror
    // that boundary here without making any network requests or using data.
    await SupabaseConfig.initialize(
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        persistSession: false,
        pkceAsyncStorage: _MemoryPkceStorage(),
      ),
    );
  });

  testWidgets('mobile app builds its MaterialApp shell', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('startup waits for initialization and the logo presentation',
      (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(MyApp(initialize: () => initialization.future));
    expect(find.text('BancaoConnect'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LoginScreen), findsNothing);
    initialization.complete();
    await tester.pump();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('BancaoConnect'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup failure has a retry without exposing technical errors',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MyApp(initialize: () async {
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
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('File a Report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
