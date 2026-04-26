import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'core/supabase_config.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin/residents_list_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/residents/resident_dashboard_screen.dart';
import 'screens/intro/app_intro_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize Supabase using config file
  await SupabaseConfig.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color _brandBlue = Color(0xFF0B4F94);
  static const Color _accentBlue = Color(0xFF0F84D7);
  static const Color _pageBackground = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: _pageBackground,
        colorScheme: const ColorScheme.light(
          primary: _brandBlue,
          onPrimary: Colors.white,
          secondary: _accentBlue,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1F2937),
          error: Color(0xFFD9534F),
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _pageBackground,
          foregroundColor: _brandBlue,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        canvasColor: _pageBackground,
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _accentBlue,
          circularTrackColor: Color(0xFFD9EBFF),
          linearTrackColor: Color(0xFFD9EBFF),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFD9EBFF),
          surfaceTintColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? _brandBlue
                  : const Color(0xFF64748B),
            );
          }),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _brandBlue,
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _brandBlue,
          selectionColor: Color(0x332B8FD8),
          selectionHandleColor: _brandBlue,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? _brandBlue
                : const Color(0xFFCBD5E1);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? const Color(0xFFD9EBFF)
                : const Color(0xFFE5E7EB);
          }),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? _brandBlue
                : Colors.white;
          }),
          checkColor: WidgetStateProperty.all(Colors.white),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? _brandBlue
                : const Color(0xFF94A3B8);
          }),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],

      /// App starts at intro screen
      initialRoute: '/intro',

      routes: {
        '/intro': (context) => const AppIntroScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/residents': (context) => const ResidentsListScreen(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/my-reports': (context) => const ResidentDashboardScreen(
              name: '',
              initialTabIndex: 2,
            ),
      },
    );
  }
}
