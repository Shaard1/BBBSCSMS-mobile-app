import 'dart:convert';

import 'package:capstone_app/core/supabase_config.dart';
import 'package:capstone_app/services/private_file_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryAuthStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
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
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var deny = false;
  final base = SupabaseConfig.supabaseUrl;
  final locator = '$base/storage/v1/object/public/resident-files/owner/id.jpg';

  setUpAll(() async {
    await Supabase.initialize(
      url: base,
      publishableKey: 'synthetic-test-key',
      authOptions: FlutterAuthClientOptions(
        persistSession: false,
        autoRefreshToken: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (deny) {
          return http.Response('{"message":"denied"}', 403,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
            jsonEncode({
              'signedURL':
                  '/object/sign/resident-files/owner/id.jpg?token=fixture',
            }),
            200,
            headers: {'content-type': 'application/json'});
      }),
    );
  });
  setUp(() {
    requests.clear();
    deny = false;
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  test('signs duplicate private locators once without mutating stored records',
      () async {
    final original = [
      {
        'id_image': locator,
        'image_urls': jsonEncode([locator])
      }
    ];
    final result = await PrivateFileService.resolveRecords(original);
    expect(requests.length, 1);
    expect(requests.single.url.path,
        '/storage/v1/object/sign/resident-files/owner/id.jpg');
    expect(result.single['id_image'], contains('token=fixture'));
    expect(result.single['image_urls'], [result.single['id_image']]);
    expect(original.single['id_image'], locator);
    expect(original.single['image_urls'], jsonEncode([locator]));
  });
  test('denied private evidence does not fall back to a public URL', () async {
    deny = true;
    final result = await PrivateFileService.resolveRecords([
      {'image_url': locator}
    ]);
    expect(result.single['image_url'], '');
  });
  test('public announcement and external fixture URLs are unchanged', () async {
    final original = [
      {
        'image_url':
            '$base/storage/v1/object/public/announcement-files/poster.jpg'
      },
      {'image_url': 'https://example.test/poster.jpg'},
    ];
    expect(await PrivateFileService.resolveRecords(original), original);
    expect(requests, isEmpty);
  });
}
