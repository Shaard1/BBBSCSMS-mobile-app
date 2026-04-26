import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Supabase Project URL
  static const supabaseUrl = 'https://ntjvtnnerjevsucjdajp.supabase.co';

  /// Supabase Anon Public Key
  static const supabaseAnonKey =
      'sb_publishable_s5X6pvsR_YCRuSINxFmImA_P3WYNQ6x';

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  /// Access Supabase Client anywhere in the app
  static SupabaseClient get client => Supabase.instance.client;
}
