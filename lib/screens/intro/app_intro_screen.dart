import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_interactions.dart';
import '../../widgets/app_launch_view.dart';
import '../../widgets/brand_startup_animation.dart';
import '../auth/login_screen.dart';
import '../home_screen.dart';

class AppIntroScreen extends StatefulWidget {
  const AppIntroScreen({super.key, this.initialize, this.firstFrameReady});

  final Future<void> Function()? initialize;
  final Future<void>? firstFrameReady;

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen> {
  bool _hasError = false;
  int _attempt = 0;
  Completer<void> _presentation = Completer<void>();

  @override
  void dispose() {
    _finishPresentation();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Initialization and the one-shot brand animation share the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    setState(() => _hasError = false);
    try {
      await Future.wait<void>([
        if (widget.initialize != null) widget.initialize!(),
        _presentation.future,
      ], eagerError: true);
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

  void _finishPresentation() {
    if (!_presentation.isCompleted) _presentation.complete();
  }

  void _retry() {
    _finishPresentation();
    _presentation = Completer<void>();
    _attempt++;
    _start();
  }

  @override
  Widget build(BuildContext context) => _hasError
      ? AppLaunchView(
          errorMessage:
              'We couldn’t start the app. Please check your connection and try again.',
          onRetry: _retry,
        )
      : BrandStartupAnimation(
          key: ValueKey(_attempt),
          onCompleted: _finishPresentation,
          firstFrameReady: widget.firstFrameReady,
        );
}
