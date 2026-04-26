import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppIntroScreen extends StatefulWidget {
  const AppIntroScreen({super.key});

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen> {
  static const Color _brandBlue = Color(0xFF0F84D7);
  static const Color _pageBackground = Color(0xFFF8FAFC);

  Timer? _routeTimer;

  @override
  void initState() {
    super.initState();

    _routeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final hasSession = Supabase.instance.client.auth.currentUser != null;
      Navigator.pushReplacementNamed(context, hasSession ? '/home' : '/login');
    });
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: Center(
          child: _StartupLoadingDots(),
        ),
      ),
    );
  }
}

class _StartupLoadingDots extends StatefulWidget {
  const _StartupLoadingDots();

  @override
  State<_StartupLoadingDots> createState() => _StartupLoadingDotsState();
}

class _StartupLoadingDotsState extends State<_StartupLoadingDots> {
  Timer? _timer;
  int _activeDot = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (timer) {
      if (!mounted) return;
      setState(() {
        _activeDot = (_activeDot + 1) % 3;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == _activeDot;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: index == 2 ? 0 : 10),
          width: isActive ? 12 : 11,
          height: isActive ? 12 : 11,
          decoration: BoxDecoration(
            color: isActive
                ? _AppIntroScreenState._brandBlue.withValues(alpha: 0.9)
                : const Color(0xFFD9EBFF),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
