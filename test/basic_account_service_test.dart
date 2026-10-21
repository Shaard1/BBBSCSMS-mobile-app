import 'dart:convert';

import 'package:capstone_app/services/basic_account_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('normalizes Philippine numbers without silently truncating digits', () {
    for (final value in [
      '09171234567',
      '+639171234567',
      '639171234567',
      '0917 123 4567'
    ]) {
      expect(BasicAccountService.normalizePhone(value), '+639171234567');
    }
    for (final value in [
      '091712345678',
      '0917123456',
      'abc09171234567',
      '+1 9171234567',
      '',
      '++639171234567'
    ]) {
      expect(BasicAccountService.normalizePhone(value), isNull);
    }
  });

  test('password accepts long passphrases and preserves significant spaces',
      () {
    expect(BasicAccountService.validatePassword('short password'), isNotNull);
    expect(
        BasicAccountService.validatePassword('a long passphrase with spaces '),
        isNull);
    expect(BasicAccountService.validatePassword('a' * 129), isNotNull);
  });

  test('phone verification is not inferred from identity or active status', () {
    final access = BasicAccountAccess.fromJson({
      'account_state': 'active',
      'identity_status': 'verified',
      'phone_verified': false,
      'basic_access': false,
    });
    expect(access.active, isTrue);
    expect(access.phoneVerified, isFalse);
    expect(access.basicAccess, isFalse);
    expect(access.testAccess, isFalse);
  });

  test('registration RPC sends no client-owned approval or verification flags',
      () async {
    late Map<String, dynamic> payload;
    final client = SupabaseClient('https://synthetic.supabase.co', 'fake-key',
        httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/complete_basic_registration');
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode({
            'account_state': 'active',
            'identity_status': 'unverified',
            'phone_verified': false,
            'basic_access': true,
            'test_access': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request);
    }));
    addTearDown(client.dispose);
    final access = await BasicAccountService(client: client)
        .complete(name: ' Test Resident ', phone: '+639171234567');
    expect(payload.keys.toSet(),
        {'p_full_name', 'p_phone', 'p_privacy_version', 'p_terms_version'});
    expect(payload['p_full_name'], 'Test Resident');
    expect(access.phoneVerified, isFalse);
    expect(access.basicAccess, isTrue);
  });

  test('server access errors are propagated rather than allowing a resident in',
      () async {
    final client = SupabaseClient('https://synthetic.supabase.co', 'fake-key',
        httpClient: MockClient((request) async => http.Response(
            '{"code":"42501","message":"denied"}', 403,
            headers: {'content-type': 'application/json'}, request: request)));
    addTearDown(client.dispose);
    await expectLater(BasicAccountService(client: client).access(),
        throwsA(isA<PostgrestException>()));
  });
}
