import 'dart:convert';

import '../core/supabase_config.dart';

/// Stored URLs are locators, not authorization. Resolve them when records load;
/// never write the temporary signed URLs back to the database.
class PrivateFileService {
  static const _fields = [
    'id_image',
    'id_image_front',
    'id_image_back',
    'profile_image',
    'profile_image_original',
    'image_url',
    'image_urls',
    'payment_proof_url',
  ];

  static Future<List<Map<String, dynamic>>> resolveRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final pending = <String, Future<String>>{};
    Future<dynamic> resolve(dynamic value) async {
      if (value is List) return Future.wait(value.map(resolve));
      if (value is! String || value.isEmpty) return value;
      if (value.trim().startsWith('[')) {
        try {
          final list = jsonDecode(value);
          if (list is List) return Future.wait(list.map(resolve));
        } on FormatException {/* Continue with locator parsing. */}
      }
      final uri = Uri.tryParse(value);
      final configured = Uri.parse(SupabaseConfig.supabaseUrl);
      if (uri == null || !uri.hasAuthority || uri.origin != configured.origin) {
        return value;
      }
      final segments = uri.pathSegments;
      if (segments.length < 6 ||
          segments[0] != 'storage' ||
          segments[1] != 'v1' ||
          segments[2] != 'object' ||
          !['public', 'sign', 'authenticated'].contains(segments[3]) ||
          !['resident-files', 'report-images'].contains(segments[4])) {
        return value;
      }
      final bucket = segments[4];
      final path = segments.skip(5).join('/');
      if (segments.skip(5).any((part) => part == '.' || part == '..')) {
        return '';
      }
      return pending.putIfAbsent('$bucket/$path', () async {
        try {
          return await SupabaseConfig.client.storage
              .from(bucket)
              .createSignedUrl(path, 3600);
        } catch (_) {
          // Unavailable/unauthorized images must not fall back to public access.
          return '';
        }
      });
    }

    return Future.wait(records.map((record) async {
      final copy = Map<String, dynamic>.from(record);
      await Future.wait(_fields.where(copy.containsKey).map((field) async {
        copy[field] = await resolve(copy[field]);
      }));
      return copy;
    }));
  }
}
