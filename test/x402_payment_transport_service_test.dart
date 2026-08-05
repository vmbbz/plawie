import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clawa/services/ai_payment_provider_catalog.dart';
import 'package:clawa/services/x402_payment_service.dart';
import 'package:clawa/services/x402_payment_transport_service.dart';

void main() {
  final now = DateTime.utc(2026, 8, 5, 12);
  final provider = AiPaymentProviderCatalog.byId('venice')!;
  const payer = '0x1111111111111111111111111111111111111111';

  test('requires visible approval and retries the exact request only once',
      () async {
    var calls = 0;
    final store = _MemoryReceiptStore();
    final client = MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url, provider.topUpEndpoint);
      expect(request.bodyBytes, isEmpty);
      if (calls == 1) {
        expect(request.headers, isNot(contains('X-402-Payment')));
        return http.Response('', 402, headers: {
          'PAYMENT-REQUIRED': _challenge(provider.topUpEndpoint!),
        });
      }
      expect(request.headers['X-402-Payment'], isNotEmpty);
      final payment = jsonDecode(utf8.decode(base64Decode(
        request.headers['X-402-Payment']!,
      ))) as Map<String, dynamic>;
      expect(payment['x402Version'], 2);
      expect(payment['payload']['authorization']['from'], payer);
      return http.Response('', 200, headers: {
        'PAYMENT-RESPONSE': base64Encode(utf8.encode(jsonEncode({
          'transaction': '0x${'a' * 64}',
        }))),
      });
    });
    final approval = X402PaymentApprovalService(clock: () => now);
    final service = X402PaymentTransportService(
      client: client,
      approvalService: approval,
      receiptStore: store,
      clock: () => now,
      signer: (authorization) async {
        expect(authorization['host'], 'api.venice.ai');
        expect(authorization['chainId'], 8453);
        expect(authorization['from'], payer);
        expect(authorization['value'], '5000000');
        return <String, dynamic>{
          'signature': '0x${'b' * 130}',
          'payer': payer,
        };
      },
    );

    final prepared = await service.prepareTopUp(provider);
    expect(calls, 1);
    expect(prepared.amountUsd, 5);
    final receipt = await service.approveAndSubmit(
      prepared,
      walletAddress: payer,
    );

    expect(calls, 2);
    expect(receipt.state, X402PaymentState.settled);
    expect(receipt.transactionHash, '0x${'a' * 64}');
    expect(store.receipts, hasLength(1));
    expect(jsonEncode(receipt.toJson()), isNot(contains('signature')));
  });

  test('never follows a redirect or signs without a 402 challenge', () async {
    var signerCalled = false;
    final service = X402PaymentTransportService(
      client: MockClient((request) async => http.Response('', 302, headers: {
            'location': 'https://evil.example/top-up',
          })),
      receiptStore: _MemoryReceiptStore(),
      signer: (_) async {
        signerCalled = true;
        return <String, dynamic>{};
      },
    );

    await expectLater(
      service.prepareTopUp(provider),
      throwsA(isA<X402TransportException>()),
    );
    expect(signerCalled, isFalse);
  });

  test('a rejected settlement is terminal and is not retried again', () async {
    var calls = 0;
    final store = _MemoryReceiptStore();
    final service = X402PaymentTransportService(
      client: MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response('', 402, headers: {
            'payment-required': _challenge(provider.topUpEndpoint!),
          });
        }
        return http.Response('', 400);
      }),
      approvalService: X402PaymentApprovalService(clock: () => now),
      receiptStore: store,
      clock: () => now,
      signer: (_) async => <String, dynamic>{
        'signature': '0x${'b' * 130}',
        'payer': payer,
      },
    );

    final prepared = await service.prepareTopUp(provider);
    final receipt = await service.approveAndSubmit(
      prepared,
      walletAddress: payer,
    );

    expect(calls, 2);
    expect(receipt.state, X402PaymentState.failed);
    expect(receipt.errorCode, 'SETTLEMENT_HTTP_400');
  });
}

String _challenge(Uri endpoint) {
  return base64Encode(utf8.encode(jsonEncode(<String, dynamic>{
    'x402Version': 2,
    'resource': <String, dynamic>{
      'url': endpoint.toString(),
      'description': 'Venice x402 top-up',
      'mimeType': 'application/json',
    },
    'accepts': <Map<String, dynamic>>[
      <String, dynamic>{
        'scheme': 'exact',
        'network': X402PaymentPolicy.network,
        'amount': '5000000',
        'asset': X402PaymentPolicy.usdc,
        'payTo': '0x2222222222222222222222222222222222222222',
        'maxTimeoutSeconds': 300,
        'extra': <String, dynamic>{
          'assetTransferMethod': 'eip3009',
          'name': 'USD Coin',
          'version': '2',
        },
      },
    ],
  })));
}

class _MemoryReceiptStore extends X402PaymentReceiptStore {
  final List<X402PaymentReceipt> receipts = <X402PaymentReceipt>[];

  @override
  Future<void> append(X402PaymentReceipt receipt) async {
    receipts.insert(0, receipt);
  }

  @override
  Future<List<X402PaymentReceipt>> read() async =>
      List<X402PaymentReceipt>.unmodifiable(receipts);
}
