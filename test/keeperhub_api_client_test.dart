import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clawa/services/keeperhub/keeperhub_api_client.dart';
import 'package:clawa/services/keeperhub/keeperhub_models.dart';

void main() {
  test('keeps SIWE cookies in memory and replays required trusted Origin',
      () async {
    var call = 0;
    final client = KeeperHubApiClient(
      client: MockClient((request) async {
        call += 1;
        expect(request.url.origin, 'https://app.keeperhub.com');
        expect(request.headers['origin'], 'https://app.keeperhub.com');
        if (call == 1) {
          expect(request.headers, isNot(contains('cookie')));
          return http.Response(
            jsonEncode(<String, String>{'nonce': 'AbCdEf123456'}),
            200,
            headers: <String, String>{
              'set-cookie':
                  'better-auth.session=first; Path=/; Secure; HttpOnly',
            },
          );
        }
        expect(request.headers['cookie'], 'better-auth.session=first');
        return http.Response(
          '{}',
          200,
          headers: <String, String>{
            'set-cookie':
                'better-auth.session=rotated; Path=/; Secure; HttpOnly',
          },
        );
      }),
    );

    await client.requestNonce('0x1111111111111111111111111111111111111111');
    await client.verifySiwe(
      message: 'bounded-message',
      signature: '0x${List<String>.filled(65, '11').join()}',
      walletAddress: '0x1111111111111111111111111111111111111111',
    );
    expect(call, 2);
    client.close();
  });

  test('refuses redirects instead of following an origin change', () async {
    final client = KeeperHubApiClient(
      client: MockClient(
        (_) async => http.Response(
          '',
          302,
          headers: <String, String>{'location': 'https://evil.example'},
        ),
      ),
    );

    await expectLater(
      client.requestNonce('0x1111111111111111111111111111111111111111'),
      throwsA(
        isA<KeeperHubException>().having(
          (error) => error.code,
          'code',
          'unexpected_redirect',
        ),
      ),
    );
    client.close();
  });

  test('API-key validation does not mix in session cookies', () async {
    final client = KeeperHubApiClient(
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer kh_secret-value');
        expect(request.headers, isNot(contains('cookie')));
        expect(request.headers, isNot(contains('origin')));
        return http.Response('[]', 200);
      }),
    );

    final response = await client.validateOrganizationKey('kh_secret-value');
    expect(response.statusCode, 200);
    client.close();
  });

  test('revokes only a validated organization key path with bearer auth',
      () async {
    final client = KeeperHubApiClient(
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/keys/key_123');
        expect(request.headers['authorization'], 'Bearer kh_secret-value');
        expect(request.headers, isNot(contains('cookie')));
        expect(request.headers, isNot(contains('origin')));
        return http.Response('{"success":true}', 200);
      }),
    );

    final response = await client.revokeOrganizationKey(
      apiKey: 'kh_secret-value',
      keyId: 'key_123',
    );

    expect(response.body['success'], isTrue);
    expect(
      () => client.revokeOrganizationKey(
        apiKey: 'kh_secret-value',
        keyId: '../user',
      ),
      throwsA(isA<KeeperHubException>()),
    );
    client.close();
  });
}
