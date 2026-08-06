import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/native_bridge.dart';
import 'package:clawa/services/venice_wallet_auth_service.dart';

void main() {
  const address = '0x857b06519E91e3A54538791bDbb0E22373e36b66';
  final now = DateTime.utc(2026, 8, 6, 12);

  test('creates a fresh exact SIWE envelope for every inference request',
      () async {
    final nonces = <String>['AbCdEf123456', 'ZyXwVu987654'];
    final signedRequests = <Map<String, dynamic>>[];
    final service = VeniceWalletAuthService(
      clock: () => now,
      nonceFactory: () => nonces.removeAt(0),
      walletStatus: () async => _healthy(address),
      signer: (request) async {
        signedRequests.add(Map<String, dynamic>.from(request));
        return {
          'payer': address,
          'signature': '0x${'a' * 130}',
          'message': _message(address, request),
        };
      },
    );
    final uri = Uri.parse('https://api.venice.ai/api/v1/chat/completions');

    final first = await service.authorize('POST', uri);
    final second = await service.authorize('POST', uri);

    expect(first, isNot(second));
    expect(signedRequests, hasLength(2));
    expect(signedRequests[0]['method'], 'POST');
    expect(signedRequests[0]['uri'], uri.toString());
    expect(signedRequests[0]['nonce'], 'AbCdEf123456');
    expect(signedRequests[1]['nonce'], 'ZyXwVu987654');
    final envelope = jsonDecode(utf8.decode(base64Decode(first)));
    expect(envelope['address'], address);
    expect(envelope['message'], contains('URI: $uri'));
    expect(envelope['signature'], '0x${'a' * 130}');
    expect(envelope['timestamp'], now.millisecondsSinceEpoch);
    expect(envelope['chainId'], 8453);
  });

  test('supports exact models and balance routes but keeps responses disabled',
      () async {
    final seen = <String>[];
    final service = VeniceWalletAuthService(
      clock: () => now,
      nonceFactory: () => 'AbCdEf123456',
      walletStatus: () async => _healthy(address),
      signer: (request) async {
        seen.add('${request['method']} ${request['uri']}');
        return {
          'payer': address,
          'signature': '0x${'b' * 130}',
          'message': _message(address, request),
        };
      },
    );

    await service.authorize(
      'GET',
      Uri.parse('https://api.venice.ai/api/v1/models'),
    );
    await service.authorize(
      'GET',
      Uri.parse('https://api.venice.ai/api/v1/x402/balance/$address'),
    );
    await expectLater(
      service.authorize(
        'POST',
        Uri.parse('https://api.venice.ai/api/v1/responses'),
      ),
      throwsA(isA<VeniceWalletAuthException>()),
    );

    expect(seen, hasLength(2));
  });

  test('rejects unhealthy wallets and untrusted routes before signing',
      () async {
    var signerCalled = false;
    final absent = VeniceWalletAuthService(
      walletStatus: () async => SecureWalletStatus.absent(),
      signer: (_) async {
        signerCalled = true;
        return {};
      },
    );
    await expectLater(
      absent.authorize(
        'POST',
        Uri.parse('https://api.venice.ai/api/v1/chat/completions'),
      ),
      throwsA(
        isA<VeniceWalletAuthException>().having(
          (error) => error.code,
          'code',
          'wallet_not_ready',
        ),
      ),
    );

    final healthy = VeniceWalletAuthService(
      walletStatus: () async => _healthy(address),
      signer: (_) async {
        signerCalled = true;
        return {};
      },
    );
    for (final entry in <(String, Uri)>[
      ('POST', Uri.parse('http://api.venice.ai/api/v1/chat/completions')),
      ('POST', Uri.parse('https://evil.example/api/v1/chat/completions')),
      ('GET', Uri.parse('https://api.venice.ai/api/v1/models?type=text')),
      ('PUT', Uri.parse('https://api.venice.ai/api/v1/chat/completions')),
    ]) {
      await expectLater(
        healthy.authorize(entry.$1, entry.$2),
        throwsA(isA<VeniceWalletAuthException>()),
      );
    }
    expect(signerCalled, isFalse);
  });

  test('rejects a mismatched payer, message, or signature from native code',
      () async {
    Future<void> expectRejected(Map<String, dynamic> signed) async {
      final service = VeniceWalletAuthService(
        clock: () => now,
        nonceFactory: () => 'AbCdEf123456',
        walletStatus: () async => _healthy(address),
        signer: (_) async => signed,
      );
      await expectLater(
        service.authorize(
          'GET',
          Uri.parse('https://api.venice.ai/api/v1/models'),
        ),
        throwsA(
          isA<VeniceWalletAuthException>().having(
            (error) => error.code,
            'code',
            'invalid_native_identity',
          ),
        ),
      );
    }

    await expectRejected({
      'payer': '0x1111111111111111111111111111111111111111',
      'message': 'wrong',
      'signature': '0x${'a' * 130}',
    });
    await expectRejected({
      'payer': address,
      'message': 'wrong',
      'signature': '0x${'a' * 130}',
    });
    await expectRejected({
      'payer': address,
      'message': _message(address, {
        'uri': 'https://api.venice.ai/api/v1/models',
        'nonce': 'AbCdEf123456',
        'issuedAt': '2026-08-06T12:00:00Z',
        'expirationTime': '2026-08-06T12:05:00Z',
      }),
      'signature': 'not-a-signature',
    });
  });
}

SecureWalletStatus _healthy(String address) => SecureWalletStatus(
      state: SecureWalletState.healthy,
      address: address,
      securityLevel: 'Trusted Environment',
      authenticationMode: 'deviceCredential',
      errorCode: '',
      envelopeIntegrity: 'verified',
      authenticationAvailable: true,
      hardwareBacked: true,
      verificationPending: false,
      verificationCode: '',
    );

String _message(String address, Map<String, dynamic> request) =>
    'api.venice.ai wants you to sign in with your Ethereum account:\n'
    '$address\n\n'
    'Sign in to Venice AI\n\n'
    'URI: ${request['uri']}\n'
    'Version: 1\n'
    'Chain ID: 8453\n'
    'Nonce: ${request['nonce']}\n'
    'Issued At: ${request['issuedAt']}\n'
    'Expiration Time: ${request['expirationTime']}';
