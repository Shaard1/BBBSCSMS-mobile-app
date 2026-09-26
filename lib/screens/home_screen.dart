import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_dashboard_screen.dart';
import 'residents/resident_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../widgets/app_launch_view.dart';

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
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
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
        if (!mounted) return;
        setState(() {
          errorMessage = AuthService.missingProfileMessage;
          isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        fullName = data['full_name'] ?? '';
        role = data['role'] ?? '';
        errorMessage = null;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      return const AppLaunchView();
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: _loadProfile,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again')),
              TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Back to login')),
            ]),
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
