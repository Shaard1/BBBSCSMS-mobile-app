import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Configure with:
  /// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
  static const _fallbackSupabaseUrl =
      'https://wbclngfcgyidxgqsfjsv.supabase.co';
  static const _fallbackSupabasePublishableKey =
      'sb_publishable__Md1xg2fBY07aW1qUBhIdw_2sDF-Eed';

  static const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: _fallbackSupabaseUrl);

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: _fallbackSupabasePublishableKey,
    ),
  );

  /// Initialize Supabase
  static Future<void> initialize({
    FlutterAuthClientOptions? authOptions,
  }) async {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw Exception(
        'Missing Supabase configuration. Set SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define or configure fallback values.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: authOptions ?? const FlutterAuthClientOptions(),
    );
  }

  /// Access Supabase Client anywhere in the app
  static SupabaseClient get client => Supabase.instance.client;
}
