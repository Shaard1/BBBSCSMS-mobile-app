import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'core/supabase_config.dart';
import 'core/app_interactions.dart';
import 'core/app_theme.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin/residents_list_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/residents/resident_dashboard_screen.dart';
import 'screens/intro/app_intro_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(initialize: SupabaseConfig.initialize));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialize});

  final Future<void> Function()? initialize;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const AppScrollBehavior(),
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
        '/intro': (context) => AppIntroScreen(initialize: initialize),
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
