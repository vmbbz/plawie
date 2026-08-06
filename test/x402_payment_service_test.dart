import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/x402_payment_service.dart';

void main() {
  final policy = X402PaymentPolicy(
    allowedHosts: <String>{'api.example.test'},
  );
  var now = DateTime.utc(2026, 8, 5, 12);

  setUp(() {
    now = DateTime.utc(2026, 8, 5, 12);
  });

  test(
      'parses a base64 x402 v2 challenge and selects only the allowlisted kind',
      () {
    final challenge = X402PaymentChallenge.fromHeader(
      _encodedChallenge(
        accepts: <Map<String, dynamic>>[
          _requirement(network: 'eip155:84532'),
          _requirement(),
        ],
      ),
      policy: policy,
    );

    expect(challenge.x402Version, 2);
    expect(challenge.resourceUrl.toString(), 'https://api.example.test/data');
    expect(challenge.requirement.network, X402PaymentPolicy.network);
    expect(challenge.requirement.asset, X402PaymentPolicy.usdc);
    expect(challenge.requirement.assetTransferMethod, 'eip3009');
    expect(challenge.challengeHash, isNotEmpty);
  });

  test('rejects unsupported network, asset, host, amount, and scheme', () {
    for (final changed in <Map<String, dynamic>>[
      _requirement(network: 'eip155:84532'),
      _requirement(asset: '0x0000000000000000000000000000000000000001'),
      _requirement(amount: '5000001'),
      _requirement(scheme: 'upto'),
      _requirement(extra: <String, dynamic>{'assetTransferMethod': 'permit2'}),
    ]) {
      expect(
        () => X402PaymentChallenge.fromHeader(
          _encodedChallenge(accepts: <Map<String, dynamic>>[changed]),
          policy: policy,
        ),
        throwsA(isA<X402PaymentPolicyException>()),
      );
    }

    expect(
      () => X402PaymentChallenge.fromHeader(
        _encodedChallenge(resourceUrl: 'https://evil.example/data'),
        policy: policy,
      ),
      throwsA(isA<X402PaymentPolicyException>()),
    );
  });

  test('rejects wrong version, payee, timeout, and token-domain metadata', () {
    expect(
      () => X402PaymentChallenge.fromHeader(
        _encodedChallenge(x402Version: 1),
        policy: policy,
      ),
      throwsA(isA<X402PaymentPolicyException>()),
    );
    for (final changed in <Map<String, dynamic>>[
      _requirement(payTo: 'not-an-address'),
      _requirement(timeout: 301),
      _requirement(timeout: 0),
      _requirement(extra: <String, dynamic>{
        'name': '',
        'version': '2',
      }),
      _requirement(extra: <String, dynamic>{
        'name': 'USD Coin',
        'version': '',
      }),
    ]) {
      expect(
        () => X402PaymentChallenge.fromHeader(
          _encodedChallenge(accepts: <Map<String, dynamic>>[changed]),
          policy: policy,
        ),
        throwsA(isA<X402PaymentPolicyException>()),
      );
    }
  });

  test('approval is bound to the exact request and cannot be replayed', () {
    final service = X402PaymentApprovalService(clock: () => now);
    final challenge = X402PaymentChallenge.fromHeader(
      _encodedChallenge(),
      policy: policy,
    );
    final intent = service.createIntent(
      challenge: challenge,
      requestMethod: 'post',
      requestUrl: Uri.parse('https://api.example.test/data'),
      requestBody: utf8.encode('{"prompt":"hello"}'),
    );

    expect(intent.state, X402PaymentState.awaitingHumanApproval);
    expect(intent.paymentNonce, matches(RegExp(r'^0x[a-f0-9]{64}$')));
    expect(
      () => service.approve(
        intent.intentId,
        source: PaymentApprovalSource.chatText,
      ),
      throwsA(isA<X402PaymentPolicyException>()),
    );

    final ticket = service.approve(
      intent.intentId,
      source: PaymentApprovalSource.visibleUi,
    );
    expect(service.activeIntent?.state, X402PaymentState.awaitingWalletUnlock);
    final claimed = service.claimForSigning(ticket);
    expect(claimed.state, X402PaymentState.signing);
    expect(
      () => service.claimForSigning(ticket),
      throwsA(isA<X402PaymentPolicyException>()),
    );
  });

  test('expiry invalidates approval before a signer can claim it', () {
    final service = X402PaymentApprovalService(clock: () => now);
    final challenge = X402PaymentChallenge.fromHeader(
      _encodedChallenge(timeout: 30),
      policy: policy,
    );
    final intent = service.createIntent(
      challenge: challenge,
      requestMethod: 'GET',
      requestUrl: Uri.parse('https://api.example.test/data'),
      requestBody: const <int>[],
    );
    final ticket = service.approve(
      intent.intentId,
      source: PaymentApprovalSource.visibleUi,
    );
    now = now.add(const Duration(seconds: 31));

    expect(
      () => service.claimForSigning(ticket),
      throwsA(isA<X402PaymentPolicyException>()),
    );
    expect(service.lastTerminalIntent?.state, X402PaymentState.expired);
    expect(service.activeIntent, isNull);
  });

  test('receipt contains no signature or private key material', () {
    final service = X402PaymentApprovalService(clock: () => now);
    final challenge = X402PaymentChallenge.fromHeader(
      _encodedChallenge(),
      policy: policy,
    );
    final intent = service.createIntent(
      challenge: challenge,
      requestMethod: 'GET',
      requestUrl: Uri.parse('https://api.example.test/data'),
      requestBody: const <int>[],
    );
    final ticket = service.approve(
      intent.intentId,
      source: PaymentApprovalSource.visibleUi,
    );
    service.claimForSigning(ticket);
    final receipt = service.recordReceipt(
      intentId: intent.intentId,
      state: X402PaymentState.settled,
      transactionHash: '0x${'a' * 64}',
      payer: '0x1111111111111111111111111111111111111111',
      requestFingerprint: 'f' * 64,
      modelId: 'blockrun/openai/gpt-5.5',
      paidRetryConsumed: true,
    );
    final encoded = jsonEncode(receipt.toJson());

    expect(encoded, contains('transactionHash'));
    expect(encoded, contains('requestFingerprint'));
    expect(encoded, contains('paidRetryConsumed'));
    expect(encoded, isNot(contains('signature')));
    expect(encoded, isNot(contains('privateKey')));
  });

  test('older receipts remain readable without inference replay fields', () {
    final receipt = X402PaymentReceipt.fromJson(<String, dynamic>{
      'intentId': 'legacy',
      'state': 'settled',
      'recordedAt': now.toIso8601String(),
    });

    expect(receipt.requestFingerprint, isNull);
    expect(receipt.modelId, isNull);
    expect(receipt.paidRetryConsumed, isFalse);
  });
}

String _encodedChallenge({
  String resourceUrl = 'https://api.example.test/data',
  List<Map<String, dynamic>>? accepts,
  int timeout = 60,
  int x402Version = 2,
}) {
  final body = <String, dynamic>{
    'x402Version': x402Version,
    'resource': <String, dynamic>{
      'url': resourceUrl,
      'description': 'Test paid resource',
    },
    'accepts':
        accepts ?? <Map<String, dynamic>>[_requirement(timeout: timeout)],
  };
  return base64Encode(utf8.encode(jsonEncode(body)));
}

Map<String, dynamic> _requirement({
  String scheme = 'exact',
  String network = X402PaymentPolicy.network,
  String amount = '10000',
  String asset = X402PaymentPolicy.usdc,
  String payTo = '0x2222222222222222222222222222222222222222',
  int timeout = 60,
  Map<String, dynamic>? extra,
}) {
  return <String, dynamic>{
    'scheme': scheme,
    'network': network,
    'amount': amount,
    'asset': asset,
    'payTo': payTo,
    'maxTimeoutSeconds': timeout,
    'extra': extra ??
        <String, dynamic>{
          'assetTransferMethod': 'eip3009',
          'name': 'USD Coin',
          'version': '2',
        },
  };
}
