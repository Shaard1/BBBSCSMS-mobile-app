import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_dashboard_screen.dart';
import 'residents/resident_dashboard_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /* ---------------- VARIABLES ---------------- */

  String fullName = "";
  String role = "";
  String? errorMessage;
  bool isLoading = true;

  /* ---------------- INIT STATE ---------------- */

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /* ---------------- LOAD PROFILE ---------------- */

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        setState(() {
          errorMessage = "Please log in to continue.";
          isLoading = false;
        });
        return;
      }

      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        setState(() {
          errorMessage = AuthService.missingProfileMessage;
          isLoading = false;
        });
        return;
      }

      setState(() {
        fullName = data['full_name'] ?? '';
        role = data['role'] ?? '';
        errorMessage = null;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage =
            "We could not load your profile right now. Please try again or contact the barangay admin.";
        isLoading = false;
      });
    }
  }

  /* ---------------- UI BUILD ---------------- */

  @override
  Widget build(BuildContext context) {
    /* ---------------- LOADING STATE ---------------- */

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: _StartupLoadingDots(),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    /* ---------------- ROLE SAFETY CHECK ---------------- */

    if (role.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text("No role assigned."),
        ),
      );
    }

    /* ---------------- ROLE ROUTING ---------------- */

    if (role == 'admin') {
      return const AdminDashboardScreen();
    } else if (role == 'resident') {
      return ResidentDashboardScreen(
        name: fullName,
      );
    } else {
      return const Scaffold(
        body: Center(
          child: Text("Invalid role."),
        ),
      );
    }
  }
}

class _StartupLoadingDots extends StatefulWidget {
  const _StartupLoadingDots();

  @override
  State<_StartupLoadingDots> createState() => _StartupLoadingDotsState();
}

class _StartupLoadingDotsState extends State<_StartupLoadingDots> {
  static const Color _brandBlue = Color(0xFF0F84D7);

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
                ? _brandBlue.withValues(alpha: 0.9)
                : const Color(0xFFD9EBFF),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
