import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_interactions.dart';
import '../../widgets/app_launch_view.dart';
import '../auth/login_screen.dart';
import '../home_screen.dart';

class AppIntroScreen extends StatefulWidget {
  const AppIntroScreen({super.key, this.initialize});

  final Future<void> Function()? initialize;

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen> {
  bool _hasError = false;
  Timer? _presentationTimer;

  @override
  void dispose() {
    _presentationTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Start presentation timing once the branded frame is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    setState(() => _hasError = false);
    try {
      final presentation = Completer<void>();
      _presentationTimer =
          Timer(const Duration(seconds: 2), presentation.complete);
      await Future.wait<void>([
        if (widget.initialize != null) widget.initialize!(),
        presentation.future,
      ]);
      if (!mounted) return;
      final hasSession = Supabase.instance.client.auth.currentUser != null;
      Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
        settings: RouteSettings(name: hasSession ? '/home' : '/login'),
        transitionDuration: appMotionDuration(context, 280),
        pageBuilder: (context, animation, secondaryAnimation) =>
            hasSession ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ));
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) => AppLaunchView(
        errorMessage: _hasError
            ? 'We couldn’t start the app. Please check your connection and try again.'
            : null,
        onRetry: _hasError ? _start : null,
      );
}
