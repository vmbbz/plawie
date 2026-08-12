import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:clawa/services/native_bridge.dart';
import 'package:clawa/services/paid_provider_approval_broker.dart';
import 'package:clawa/services/paid_provider_http_client.dart';
import 'package:clawa/services/paid_provider_proxy_models.dart';
import 'package:clawa/services/blockrun_paid_provider_proxy_handler.dart';
import 'package:clawa/services/paid_provider_turn_authorization_service.dart';
import 'package:clawa/services/x402_payment_service.dart';
import 'package:clawa/services/x402_payment_transport_service.dart';

void main() {
  const payer = '0x1111111111111111111111111111111111111111';
  const model = 'blockrun/openai/gpt-5.5';
  final now = DateTime.utc(2026, 8, 6, 12);
  final turns = PaidProviderTurnAuthorizationService.instance;

  setUp(() {
    turns.markAppForeground();
    turns.authorizeForegroundUserTurn(
      conversationId: 'conversation-a',
      provider: PaidProviderId.blockrun,
      modelId: model,
    );
  });

  tearDown(turns.markAppBackground);

  test('relays a free BlockRun response without opening payment UI', () async {
    var calls = 0;
    final broker = PaidProviderApprovalBroker(clock: () => now);
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((request) async {
        calls++;
        expect(request.headers, isNot(contains('payment-signature')));
        return _jsonResponse(HttpStatus.ok, '{"free":true}');
      })),
      approvals: broker,
      receiptStore: _MemoryReceiptStore(),
      clock: () => now,
    );

    final response = await handler(_chatRequest(model));
    expect(response.statusCode, HttpStatus.ok);
    expect(await _body(response), '{"free":true}');
    expect(calls, 1);

    handler.close();
    await broker.close();
  });

  test('a 402 cannot sign when no foreground approval UI is listening',
      () async {
    var calls = 0;
    var signerCalled = false;
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        calls++;
        return _paymentRequired();
      })),
      approvals: broker,
      receiptStore: _MemoryReceiptStore(),
      signer: (_) async {
        signerCalled = true;
        return <String, dynamic>{};
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );

    await expectLater(
      handler(_chatRequest(model)),
      throwsA(
        isA<PaidProviderProxyException>().having(
          (error) => error.code,
          'code',
          'approval_ui_unavailable',
        ),
      ),
    );
    expect(calls, 1);
    expect(signerCalled, isFalse);

    handler.close();
    await broker.close();
  });

  test('visible approval signs and retries the exact body once', () async {
    final bodies = <List<int>>[];
    final headers = <Map<String, String>>[];
    var calls = 0;
    final store = _MemoryReceiptStore();
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      expect(approval.modelId, model);
      expect(approval.amountUnits, '2000');
      expect(approval.resource.toString(),
          'https://blockrun.ai/api/v1/chat/completions');
      broker.approve(approval.intentId);
    });
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((request) async {
        calls++;
        bodies.add(await request.finalize().toBytes());
        headers.add(Map<String, String>.from(request.headers));
        if (calls == 1) return _paymentRequired();
        return _jsonResponse(
          HttpStatus.ok,
          '{"choices":[{"message":{"content":"paid"}}]}',
          headers: {'x-payment-receipt': '0x${'a' * 64}'},
        );
      })),
      approvals: broker,
      receiptStore: store,
      signer: (authorization) async {
        expect(authorization['host'], 'blockrun.ai');
        expect(authorization['chainId'], 8453);
        expect(authorization['from'], payer);
        expect(authorization['value'], '2000');
        return <String, dynamic>{
          'signature': '0x${'b' * 130}',
          'payer': payer,
        };
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );

    final response = await handler(_chatRequest(model));
    expect(store.receipts, hasLength(1),
        reason: 'receipt is durable before model bytes reach Gateway');
    expect(await _body(response), contains('"paid"'));

    expect(calls, 2);
    expect(bodies[1], bodies[0]);
    expect(headers[0], isNot(contains('payment-signature')));
    final paymentHeader = headers[1]['payment-signature'];
    expect(paymentHeader, isNotEmpty);
    final payment = jsonDecode(
      utf8.decode(base64Decode(paymentHeader!)),
    ) as Map<String, dynamic>;
    expect(payment['x402Version'], 2);
    expect(payment['payload']['authorization']['from'], payer);
    expect(payment['payload']['authorization']['value'], '2000');
    expect(payment['payload']['authorization']['validAfter'], isA<String>());
    expect(payment['payload']['authorization']['validBefore'], isA<String>());
    expect(payment['extensions']['bazaar']['info'], 'preserved');
    expect(
      payment['extensions']['builder-code']['info']['s'],
      <String>['blockrun'],
    );

    final receipt = store.receipts.single;
    expect(receipt.state, X402PaymentState.settled);
    expect(receipt.transactionHash, '0x${'a' * 64}');
    expect(receipt.providerId, 'blockrun');
    expect(receipt.modelId, model);
    expect(receipt.requestFingerprint, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(receipt.paidRetryConsumed, isTrue);
    final encodedReceipt = jsonEncode(receipt.toJson());
    expect(encodedReceipt, isNot(contains('signature')));
    expect(encodedReceipt, isNot(contains('messages')));
    expect(encodedReceipt, isNot(contains('paid"')));

    await subscription.cancel();
    handler.close();
    await broker.close();
  });

  test('approval snapshots request bytes against later mutation', () async {
    final originalRequest = _chatRequest(model);
    final mutableBytes = List<int>.from(originalRequest.exactJsonBodyBytes!);
    final request = PaidProviderProxyRequest(
      provider: originalRequest.provider,
      route: originalRequest.route,
      gatewayModelId: originalRequest.gatewayModelId,
      jsonBody: originalRequest.jsonBody,
      exactJsonBodyBytes: mutableBytes,
    );
    final originalBytes = List<int>.from(mutableBytes);
    final bodies = <List<int>>[];
    var calls = 0;
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      mutableBytes[mutableBytes.length - 1] = 0x20;
      broker.approve(approval.intentId);
    });
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((request) async {
        calls++;
        bodies.add(await request.finalize().toBytes());
        if (calls == 1) return _paymentRequired();
        return _jsonResponse(
          HttpStatus.ok,
          '{"choices":[]}',
          headers: {'x-payment-receipt': '0x${'a' * 64}'},
        );
      })),
      approvals: broker,
      receiptStore: _MemoryReceiptStore(),
      signer: (_) async => <String, dynamic>{
        'signature': '0x${'b' * 130}',
        'payer': payer,
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );

    final response = await handler(request);
    await _body(response);

    expect(bodies, hasLength(2));
    expect(bodies[0], originalBytes);
    expect(bodies[1], originalBytes);

    await subscription.cancel();
    handler.close();
    await broker.close();
  });

  test('cancellation never unlocks, signs, or retries', () async {
    var calls = 0;
    var signerCalled = false;
    final store = _MemoryReceiptStore();
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      broker.cancel(approval.intentId);
    });
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        calls++;
        return _paymentRequired();
      })),
      approvals: broker,
      receiptStore: store,
      signer: (_) async {
        signerCalled = true;
        return <String, dynamic>{};
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );

    await expectLater(
      handler(_chatRequest(model)),
      throwsA(
        isA<PaidProviderProxyException>().having(
          (error) => error.code,
          'code',
          'payment_cancelled',
        ),
      ),
    );
    expect(calls, 1);
    expect(signerCalled, isFalse);
    expect(store.receipts.single.state, X402PaymentState.rejected);

    await subscription.cancel();
    handler.close();
    await broker.close();
  });

  test('rejects a mismatched challenge before payment UI or signing', () async {
    var approvalEvents = 0;
    var signerCalled = false;
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((_) => approvalEvents++);
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        return _paymentRequired(
          resource: 'https://blockrun.ai/api/v1/models',
        );
      })),
      approvals: broker,
      receiptStore: _MemoryReceiptStore(),
      signer: (_) async {
        signerCalled = true;
        return <String, dynamic>{};
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );

    await expectLater(
      handler(_chatRequest(model)),
      throwsA(isA<PaidProviderProxyException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(approvalEvents, 0);
    expect(signerCalled, isFalse);

    await subscription.cancel();
    handler.close();
    await broker.close();
  });

  test('wallet failure and signer failure never perform a paid retry',
      () async {
    for (final signerFails in <bool>[false, true]) {
      turns.authorizeForegroundUserTurn(
        conversationId: 'conversation-a',
        provider: PaidProviderId.blockrun,
        modelId: model,
      );
      var calls = 0;
      final broker = PaidProviderApprovalBroker(clock: () => now)
        ..markAppForeground();
      final subscription = broker.approvals.listen((approval) {
        broker.approve(approval.intentId);
      });
      final handler = BlockRunPaidProviderProxyHandler(
        httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
          calls++;
          return _paymentRequired();
        })),
        approvals: broker,
        receiptStore: _MemoryReceiptStore(),
        walletStatus: () async =>
            signerFails ? _healthy(payer) : SecureWalletStatus.absent(),
        signer: (_) async {
          throw StateError('device authentication cancelled');
        },
        clock: () => now,
      );

      await expectLater(
        handler(_chatRequest(model)),
        throwsA(isA<PaidProviderProxyException>()),
      );
      expect(calls, 1);

      await subscription.cancel();
      handler.close();
      await broker.close();
    }
  });

  test('a second 402 is terminal and never triggers a third request', () async {
    var calls = 0;
    final store = _MemoryReceiptStore();
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      broker.approve(approval.intentId);
    });
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        calls++;
        return _paymentRequired();
      })),
      approvals: broker,
      receiptStore: store,
      signer: (_) async => <String, dynamic>{
        'signature': '0x${'b' * 130}',
        'payer': payer,
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );

    await expectLater(
      handler(_chatRequest(model)),
      throwsA(
        isA<PaidProviderProxyException>()
            .having(
              (error) => error.code,
              'code',
              'paid_retry_rejected',
            )
            .having(
              (error) => error.statusCode,
              'statusCode',
              HttpStatus.badRequest,
            ),
      ),
    );
    expect(calls, 2);
    expect(store.receipts.single.state, X402PaymentState.failed);
    expect(store.receipts.single.paidRetryConsumed, isTrue);

    await subscription.cancel();
    handler.close();
    await broker.close();
  });

  test('a changed Gateway retry cannot open a second approval for one message',
      () async {
    var calls = 0;
    var approvals = 0;
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      approvals++;
      broker.approve(approval.intentId);
    });
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        calls++;
        return _paymentRequired();
      })),
      approvals: broker,
      receiptStore: _MemoryReceiptStore(),
      signer: (_) async => <String, dynamic>{
        'signature': '0x${'b' * 130}',
        'payer': payer,
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );

    await expectLater(
      handler(_chatRequest(model)),
      throwsA(
        isA<PaidProviderProxyException>().having(
          (error) => error.code,
          'code',
          'paid_retry_rejected',
        ),
      ),
    );
    await expectLater(
      handler(_chatRequest(model, prompt: 'hello retry metadata changed')),
      throwsA(
        isA<PaidProviderProxyException>().having(
          (error) => error.code,
          'code',
          'foreground_payment_limit_reached',
        ),
      ),
    );
    expect(calls, 2, reason: 'the changed retry must stop before upstream');
    expect(approvals, 1, reason: 'one visible message has one approval');

    await subscription.cancel();
    handler.close();
    await broker.close();
  });

  test('a paid success without a settlement receipt requires recovery',
      () async {
    var calls = 0;
    final store = _MemoryReceiptStore();
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      broker.approve(approval.intentId);
    });
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        calls++;
        if (calls == 1) return _paymentRequired();
        return _jsonResponse(HttpStatus.ok, '{"choices":[]}');
      })),
      approvals: broker,
      receiptStore: store,
      signer: (_) async => <String, dynamic>{
        'signature': '0x${'b' * 130}',
        'payer': payer,
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );
    final request = _chatRequest(model);

    final response = await handler(request);
    await _body(response);
    expect(store.receipts.single.state, X402PaymentState.uncertain);
    expect(store.receipts.single.errorCode, 'PAYMENT_RECEIPT_MISSING');

    await expectLater(
      handler(request),
      throwsA(
        isA<PaidProviderProxyException>().having(
          (error) => error.code,
          'code',
          'payment_recovery_required',
        ),
      ),
    );
    expect(calls, 2);

    await subscription.cancel();
    handler.close();
    await broker.close();
  });

  test('network loss after signing records uncertainty and blocks replay',
      () async {
    var calls = 0;
    final store = _MemoryReceiptStore();
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      broker.approve(approval.intentId);
    });
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        calls++;
        if (calls == 1) return _paymentRequired();
        throw const SocketException('connection lost');
      })),
      approvals: broker,
      receiptStore: store,
      signer: (_) async => <String, dynamic>{
        'signature': '0x${'b' * 130}',
        'payer': payer,
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );
    final request = _chatRequest(model);

    await expectLater(
      handler(request),
      throwsA(isA<PaidProviderProxyException>()),
    );
    expect(store.receipts.single.state, X402PaymentState.uncertain);
    expect(calls, 2);

    await expectLater(
      handler(request),
      throwsA(
        isA<PaidProviderProxyException>().having(
          (error) => error.code,
          'code',
          'payment_recovery_required',
        ),
      ),
    );
    expect(calls, 2, reason: 'a consumed fingerprint is never sent again');

    await subscription.cancel();
    handler.close();
    await broker.close();
  });

  test('receipt read or pending write failure blocks before signing', () async {
    for (final failRead in <bool>[true, false]) {
      var calls = 0;
      var signerCalled = false;
      final broker = PaidProviderApprovalBroker(clock: () => now)
        ..markAppForeground();
      final subscription = broker.approvals.listen((approval) {
        broker.approve(approval.intentId);
      });
      final handler = BlockRunPaidProviderProxyHandler(
        httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
          calls++;
          return _paymentRequired();
        })),
        approvals: broker,
        receiptStore: _FailingReceiptStore(
          failRead: failRead,
          failAppendAt: failRead ? null : 1,
        ),
        signer: (_) async {
          signerCalled = true;
          return <String, dynamic>{};
        },
        walletStatus: () async => _healthy(payer),
        clock: () => now,
      );

      await expectLater(
        handler(_chatRequest(model)),
        throwsA(
          isA<PaidProviderProxyException>().having(
            (error) => error.code,
            'code',
            'payment_receipts_unavailable',
          ),
        ),
      );
      expect(calls, failRead ? 0 : 1);
      expect(signerCalled, isFalse);

      await subscription.cancel();
      handler.close();
      await broker.close();
    }
  });

  test('submitted receipt is durable before the paid retry is sent', () async {
    var calls = 0;
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      broker.approve(approval.intentId);
    });
    final handler = BlockRunPaidProviderProxyHandler(
      httpClient: PaidProviderHttpClient(client: _FakeClient((_) async {
        calls++;
        return _paymentRequired();
      })),
      approvals: broker,
      receiptStore: _FailingReceiptStore(failAppendAt: 2),
      signer: (_) async => <String, dynamic>{
        'signature': '0x${'b' * 130}',
        'payer': payer,
      },
      walletStatus: () async => _healthy(payer),
      clock: () => now,
    );

    await expectLater(
      handler(_chatRequest(model)),
      throwsA(
        isA<PaidProviderProxyException>().having(
          (error) => error.code,
          'code',
          'payment_receipts_unavailable',
        ),
      ),
    );
    expect(calls, 1, reason: 'no paid retry crosses the network');

    await subscription.cancel();
    handler.close();
    await broker.close();
  });
}

PaidProviderProxyRequest _chatRequest(
  String model, {
  String prompt = 'hello',
}) {
  final body = <String, dynamic>{
    'model': model.substring('blockrun/'.length),
    'messages': [
      {'role': 'user', 'content': prompt},
    ],
    'tools': [
      {
        'type': 'function',
        'function': {'name': 'device.status'}
      },
    ],
    'stream': false,
  };
  return PaidProviderProxyRequest(
    provider: PaidProviderId.blockrun,
    route: PaidProviderProxyRoute.blockrunChatCompletions,
    gatewayModelId: model,
    jsonBody: body,
    exactJsonBodyBytes: utf8.encode(jsonEncode(body)),
  );
}

http.StreamedResponse _paymentRequired({
  String resource = 'https://blockrun.ai/api/v1/chat/completions',
}) =>
    _jsonResponse(
      HttpStatus.paymentRequired,
      '{"error":"Payment Required"}',
      headers: {'x-payment-required': _challenge(resource)},
    );

http.StreamedResponse _jsonResponse(
  int status,
  String body, {
  Map<String, String> headers = const <String, String>{},
}) =>
    http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      status,
      headers: {'content-type': 'application/json', ...headers},
    );

String _challenge(String resource) =>
    base64Encode(utf8.encode(jsonEncode(<String, dynamic>{
      'x402Version': 2,
      'resource': <String, dynamic>{
        'url': resource,
        'description': 'BlockRun chat completion',
        'mimeType': 'application/json',
      },
      'accepts': <Map<String, dynamic>>[
        <String, dynamic>{
          'scheme': 'exact',
          'network': X402PaymentPolicy.network,
          'amount': '2000',
          'asset': X402PaymentPolicy.usdc,
          'payTo': '0x2222222222222222222222222222222222222222',
          'maxTimeoutSeconds': 300,
          'extra': <String, dynamic>{
            'name': 'USD Coin',
            'version': '2',
          },
        },
      ],
      'extensions': <String, dynamic>{
        'bazaar': <String, dynamic>{'info': 'preserved'},
      },
    })));

Future<String> _body(PaidProviderProxyResponse response) async => utf8.decode(
      await response.openBodyStream().fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      ),
    );

SecureWalletStatus _healthy(String address) => SecureWalletStatus(
      state: SecureWalletState.healthy,
      address: address,
      securityLevel: 'strongbox',
      authenticationMode: 'biometric-or-credential',
      errorCode: '',
      envelopeIntegrity: 'verified',
      authenticationAvailable: true,
      hardwareBacked: true,
      verificationPending: false,
      verificationCode: '',
    );

class _MemoryReceiptStore extends X402PaymentReceiptStore {
  final List<X402PaymentReceipt> receipts = <X402PaymentReceipt>[];

  @override
  Future<void> append(X402PaymentReceipt receipt) async {
    receipts.removeWhere((existing) => existing.intentId == receipt.intentId);
    receipts.insert(0, receipt);
  }

  @override
  Future<List<X402PaymentReceipt>> read() async =>
      List<X402PaymentReceipt>.unmodifiable(receipts);
}

class _FailingReceiptStore extends X402PaymentReceiptStore {
  _FailingReceiptStore({this.failRead = false, this.failAppendAt});

  final bool failRead;
  final int? failAppendAt;
  var appendCalls = 0;

  @override
  Future<List<X402PaymentReceipt>> read() async {
    if (failRead) throw StateError('storage unavailable');
    return const <X402PaymentReceipt>[];
  }

  @override
  Future<void> append(X402PaymentReceipt receipt) async {
    appendCalls++;
    if (appendCalls == failAppendAt) throw StateError('storage unavailable');
  }
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._send);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _send;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);
}
