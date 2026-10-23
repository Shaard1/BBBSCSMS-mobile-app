import 'package:capstone_app/screens/auth/basic_register_screen.dart';
import 'package:capstone_app/screens/auth/login_screen.dart';
import 'package:capstone_app/screens/auth/register_screen.dart';
import 'package:capstone_app/screens/auth/register_verification_screen.dart';
import 'package:capstone_app/screens/admin/add_resident_screen.dart';
import 'package:capstone_app/screens/residents/edit_profile_screen.dart';
import 'package:capstone_app/screens/residents/privacy_security_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_interactions_test.dart' show testApp, loadAppTestFonts, captureUi;

class _MemoryStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
  @override
  Future<void> removeItem({required String key}) async {}
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppTestFonts();
    await Supabase.initialize(
        url: 'http://127.0.0.1:9',
        publishableKey: 'synthetic-test-key',
        authOptions: FlutterAuthClientOptions(
            persistSession: false,
            localStorage: const EmptyLocalStorage(),
            pkceAsyncStorage: _MemoryStorage()));
  });
  tearDownAll(() => Supabase.instance.dispose());

  Future<void> open(WidgetTester tester, Widget screen,
      {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(screen, textScale: scale));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String label) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'signup scrolls back to the first invalid field and preserves typed values',
      (tester) async {
    await open(tester, const BasicRegisterScreen(), scale: 1.6);
    final name = find.widgetWithText(TextFormField, 'Full name');
    await tester.enterText(name, 'Synthetic resident');
    await submit(tester, 'Create test account');
    expect(
        find
            .text('Enter a Philippine mobile number, such as 09XXXXXXXXX.')
            .hitTestable(),
        findsOneWidget);
    final phone = tester.widget<TextField>(find.descendant(
        of: find.widgetWithText(TextFormField, 'Mobile number'),
        matching: find.byType(TextField)));
    expect(phone.focusNode!.hasFocus, isTrue);
    expect(tester.widget<TextFormField>(name).controller!.text,
        'Synthetic resident');
    expect(find.text('Confirm your password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureUi(tester, 'signup-field-errors');
  });

  testWidgets('login identifies both missing fields and focuses email',
      (tester) async {
    await open(tester, const LoginScreen());
    await submit(tester, 'Login');
    expect(
        find.text('Enter your email address.').hitTestable(), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .hasFocus,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile keeps optional address empty and reveals invalid phone',
      (tester) async {
    await open(
        tester,
        const EditProfileScreen(
            fullName: 'Synthetic resident',
            address: '',
            contactNumber: '',
            profileImageUrl: ''));
    await submit(tester, 'Save Changes');
    expect(find.text('Enter a valid Philippine mobile number.').hitTestable(),
        findsOneWidget);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.controller!.text, 'Synthetic resident');
    expect(fields[1].decoration!.errorText, isNull);
    expect(fields[2].focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password changes reveal errors without making a server request',
      (tester) async {
    await open(tester, const PrivacySecurityScreen());
    await submit(tester, 'Update Password');
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.decoration!.errorText, isNotNull);
    expect(fields.first.focusNode!.hasFocus, isTrue);
    expect(find.text('Confirm your new password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('office add-resident form shows individual required errors',
      (tester) async {
    await open(tester, const AddResidentScreen());
    await submit(tester, 'Save');
    expect(find.text('Enter the resident’s full name.').hitTestable(),
        findsOneWidget);
    expect(find.text('Choose a birthdate.'), findsOneWidget);
    expect(find.text('Enter the residential address.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('previous registration scrolls to its first missing input',
      (tester) async {
    await open(tester, const RegisterScreen());
    final button = find.byType(ElevatedButton).last;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Please enter your full name.').hitTestable(),
        findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .hasFocus,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'previous ID verification identifies the required selection first',
      (tester) async {
    var submitted = false;
    await open(tester, RegisterVerificationScreen(onSubmitRegistration: (
        {required idType, required frontIdImage, required backIdImage}) async {
      submitted = true;
      return null;
    }));
    await submit(tester, 'Complete Registration');
    expect(find.text('Choose your ID type.').hitTestable(), findsOneWidget);
    expect(submitted, isFalse);
    expect(tester.takeException(), isNull);
  });
}
