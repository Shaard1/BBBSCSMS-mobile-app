import 'package:capstone_app/main.dart';
import 'package:capstone_app/core/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
}
