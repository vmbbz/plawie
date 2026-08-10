import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clawa/services/keeperhub/keeperhub_api_client.dart';
import 'package:clawa/services/keeperhub/keeperhub_auth_store.dart';
import 'package:clawa/services/keeperhub/keeperhub_headless_onboarding_service.dart';
import 'package:clawa/services/keeperhub/keeperhub_models.dart';

void main() {
  const personal = '0x1111111111111111111111111111111111111111';
  const agent = '0x2222222222222222222222222222222222222222';
  const challenge = 'KeeperHub action confirmation\n\n'
      'Action: org_api_key_manage\n'
      'Nonce: 1a45b746114d0bdf9a5bec04335fd78b';
  final now = DateTime.utc(2026, 8, 10, 12);
  final signature = '0x${List<String>.filled(65, '11').join()}';

  test('onboards through bounded SIWE, step-up, provisioning, and key probe',
      () async {
    final backend = _MemorySecrets();
    final stages = <KeeperHubOnboardingStage>[];
    var call = 0;
    var keySignerCalls = 0;
    final api = KeeperHubApiClient(
      client: MockClient((request) async {
        call += 1;
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        switch (call) {
          case 1:
            expect(request.url.path, '/api/auth/siwe/nonce');
            expect(body, <String, dynamic>{
              'walletAddress': personal,
              'chainId': 1,
            });
            return _json(
              200,
              <String, dynamic>{'nonce': 'AbCdEf123456'},
              cookie: 'session=one; Path=/; Secure; HttpOnly',
            );
          case 2:
            expect(request.url.path, '/api/auth/siwe/verify');
            expect(request.headers['cookie'], 'session=one');
            expect(body['walletAddress'], personal);
            expect(body['signature'], signature);
            return _json(200, <String, dynamic>{'ok': true});
          case 3:
            expect(request.url.path, '/api/keys');
            expect(body['name'], startsWith('plawie-android-'));
            expect(body, isNot(contains('signature')));
            return _json(401, <String, dynamic>{
              'code': 'signature_required',
              'challenge': challenge,
              'required': <String>['wallet'],
            });
          case 4:
            expect(body['signature'], signature);
            return _json(
              201,
              <String, dynamic>{
                'id': 'key_123',
                'key': 'kh_returned-once-secret-value',
              },
              requestId: 'create-request',
            );
          case 5:
            expect(request.url.path, '/api/user');
            return _json(200, <String, dynamic>{'walletAddress': null});
          case 6:
            expect(request.url.path, '/api/user');
            return _json(
              200,
              <String, dynamic>{'walletAddress': agent},
            );
          case 7:
            expect(request.url.path, '/api/keys');
            expect(
              request.headers['authorization'],
              'Bearer kh_returned-once-secret-value',
            );
            expect(request.headers, isNot(contains('cookie')));
            return _json(
              200,
              <String, dynamic>{'keys': <Object>[]},
              requestId: 'verify-request',
            );
          default:
            fail('Unexpected request $call: ${request.url}');
        }
      }),
    );
    final service = KeeperHubHeadlessOnboardingService(
      api: api,
      authStore: KeeperHubAuthStore(secrets: backend),
      clock: () => now,
      delay: (_) async {},
      agentWalletPollAttempts: 2,
      signSiwe: ({required nonce, required issuedAt}) async {
        expect(nonce, 'AbCdEf123456');
        expect(issuedAt, now);
        return <String, dynamic>{
          'walletAddress': personal,
          'message': _siweMessage(personal, nonce, issuedAt),
          'signature': signature,
        };
      },
      signKeyChallenge: ({required challenge, required operation}) async {
        keySignerCalls += 1;
        expect(challenge, contains('org_api_key_manage'));
        expect(operation, 'create');
        return <String, dynamic>{
          'walletAddress': personal,
          'message': challenge,
          'signature': signature,
        };
      },
    );

    final record = await service.connect(
      personalWalletAddress: personal,
      onProgress: (progress) => stages.add(progress.stage),
    );

    expect(record.phase, KeeperHubConnectionPhase.ready);
    expect(record.agentWalletAddress, agent);
    expect(record.personalWalletAddress, personal);
    expect(record.lastRequestId, 'verify-request');
    expect(keySignerCalls, 1);
    expect(stages.last, KeeperHubOnboardingStage.ready);
    final stored = await KeeperHubAuthStore(secrets: backend).read();
    expect(stored?.apiKey, 'kh_returned-once-secret-value');
    expect(stored?.record.phase, KeeperHubConnectionPhase.ready);
    expect(
      backend.values.values.where((value) => value.contains('session=one')),
      isEmpty,
    );
    service.close();
  });

  test('does not sign or store an unexpected step-up response', () async {
    final backend = _MemorySecrets();
    var keySignerCalls = 0;
    var call = 0;
    final api = KeeperHubApiClient(
      client: MockClient((request) async {
        call += 1;
        if (call == 1) {
          return _json(200, <String, dynamic>{'nonce': 'AbCdEf123456'});
        }
        if (call == 2) return _json(200, <String, dynamic>{'ok': true});
        return _json(403, <String, dynamic>{'code': 'not_admin_or_owner'});
      }),
    );
    final service = KeeperHubHeadlessOnboardingService(
      api: api,
      authStore: KeeperHubAuthStore(secrets: backend),
      clock: () => now,
      signSiwe: ({required nonce, required issuedAt}) async =>
          <String, dynamic>{
        'walletAddress': personal,
        'message': _siweMessage(personal, nonce, issuedAt),
        'signature': signature,
      },
      signKeyChallenge: ({required challenge, required operation}) async {
        keySignerCalls += 1;
        return <String, dynamic>{};
      },
    );

    await expectLater(
      service.connect(personalWalletAddress: personal),
      throwsA(
        isA<KeeperHubException>().having(
          (error) => error.code,
          'code',
          'not_admin_or_owner',
        ),
      ),
    );
    expect(keySignerCalls, 0);
    expect(backend.values, isEmpty);
    service.close();
  });

  test('retains provisioning credential when remote wallet is still pending',
      () async {
    final backend = _MemorySecrets();
    var call = 0;
    final api = KeeperHubApiClient(
      client: MockClient((_) async {
        call += 1;
        if (call == 1) {
          return _json(200, <String, dynamic>{'nonce': 'AbCdEf123456'});
        }
        if (call == 2) return _json(200, <String, dynamic>{'ok': true});
        if (call == 3) {
          return _json(401, <String, dynamic>{
            'code': 'signature_required',
            'challenge': challenge,
            'required': <String>['wallet'],
          });
        }
        if (call == 4) {
          return _json(201, <String, dynamic>{
            'id': 'key_123',
            'key': 'kh_returned-once-secret-value',
          });
        }
        return _json(200, <String, dynamic>{'walletAddress': null});
      }),
    );
    final service = KeeperHubHeadlessOnboardingService(
      api: api,
      authStore: KeeperHubAuthStore(secrets: backend),
      clock: () => now,
      delay: (_) async {},
      agentWalletPollAttempts: 2,
      signSiwe: ({required nonce, required issuedAt}) async =>
          <String, dynamic>{
        'walletAddress': personal,
        'message': _siweMessage(personal, nonce, issuedAt),
        'signature': signature,
      },
      signKeyChallenge: ({required challenge, required operation}) async =>
          <String, dynamic>{
        'walletAddress': personal,
        'message': challenge,
        'signature': signature,
      },
    );

    await expectLater(
      service.connect(personalWalletAddress: personal),
      throwsA(
        isA<KeeperHubException>().having(
          (error) => error.code,
          'code',
          'agent_wallet_pending',
        ),
      ),
    );
    final stored = await KeeperHubAuthStore(secrets: backend).read();
    expect(stored?.apiKey, 'kh_returned-once-secret-value');
    expect(stored?.record.phase, KeeperHubConnectionPhase.provisioning);
    service.close();
  });

  test('resumes a secured provisioning record after process restart', () async {
    final backend = _MemorySecrets();
    final store = KeeperHubAuthStore(secrets: backend);
    await store.save(
      apiKey: 'kh_returned-once-secret-value',
      record: KeeperHubConnectionRecord(
        personalWalletAddress: personal,
        apiKeyId: 'key_123',
        apiKeyPrefix: 'kh_returned-',
        createdAt: now,
        phase: KeeperHubConnectionPhase.provisioning,
      ),
    );
    var call = 0;
    var keySignerCalls = 0;
    final api = KeeperHubApiClient(
      client: MockClient((request) async {
        call += 1;
        if (call == 1) {
          expect(request.url.path, '/api/keys');
          expect(request.headers['authorization'], isNotNull);
          return _json(200, <String, dynamic>{'keys': <Object>[]});
        }
        if (call == 2) {
          expect(request.url.path, '/api/auth/siwe/nonce');
          return _json(200, <String, dynamic>{'nonce': 'AbCdEf123456'});
        }
        if (call == 3) {
          expect(request.url.path, '/api/auth/siwe/verify');
          return _json(200, <String, dynamic>{'ok': true});
        }
        if (call == 4) {
          expect(request.url.path, '/api/user');
          return _json(200, <String, dynamic>{'walletAddress': agent});
        }
        fail('Unexpected recovery request $call');
      }),
    );
    final service = KeeperHubHeadlessOnboardingService(
      api: api,
      authStore: store,
      clock: () => now,
      agentWalletPollAttempts: 1,
      signSiwe: ({required nonce, required issuedAt}) async =>
          <String, dynamic>{
        'walletAddress': personal,
        'message': _siweMessage(personal, nonce, issuedAt),
        'signature': signature,
      },
      signKeyChallenge: ({required challenge, required operation}) async {
        keySignerCalls += 1;
        return <String, dynamic>{};
      },
    );

    final recovered = await service.connect(personalWalletAddress: personal);

    expect(recovered.phase, KeeperHubConnectionPhase.ready);
    expect(recovered.agentWalletAddress, agent);
    expect(keySignerCalls, 0);
    expect((await store.read())?.record.agentWalletAddress, agent);
    service.close();
  });
}

http.Response _json(
  int status,
  Map<String, dynamic> body, {
  String? cookie,
  String? requestId,
}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{
        if (cookie != null) 'set-cookie': cookie,
        if (requestId != null) 'x-request-id': requestId,
      },
    );

String _siweMessage(String wallet, String nonce, DateTime issuedAt) =>
    'app.keeperhub.com wants you to sign in with your Ethereum account:\n'
    '$wallet\n\n'
    'Sign in to KeeperHub\n\n'
    'URI: https://app.keeperhub.com\n'
    'Version: 1\n'
    'Chain ID: 1\n'
    'Nonce: $nonce\n'
    'Issued At: ${issuedAt.toUtc().toIso8601String()}';

class _MemorySecrets implements KeeperHubSecretBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
