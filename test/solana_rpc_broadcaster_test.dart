import 'dart:convert';

import 'package:clawa/services/bridge/solana_rpc_broadcaster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/solana_transaction_fixture.dart';

void main() {
  late SolanaTransactionFixture fixture;

  setUp(() async {
    fixture = await SolanaTransactionFixture.create();
  });

  test('broadcasts exact bytes once with bounded mainnet policy', () async {
    final transport = _FakeSolanaRpcTransport()
      ..responses.add(_response(result: fixture.signature));
    final service = SolanaRpcBroadcasterService(
      transport: transport,
      requestIdFactory: () => 41,
    );
    final bytes = fixture.signedTransaction;

    expect(await service.sendTransaction(bytes), fixture.signature);
    expect(transport.uris, <Uri>[solanaMainnetRpcUri]);
    expect(transport.maxBytes, <int>[64 * 1024]);
    expect(transport.bodies.single, <String, Object?>{
      'jsonrpc': '2.0',
      'id': 41,
      'method': 'sendTransaction',
      'params': <Object?>[
        base64Encode(bytes),
        <String, Object?>{
          'encoding': 'base64',
          'skipPreflight': false,
          'preflightCommitment': 'confirmed',
          'maxRetries': 0,
        },
      ],
    });
  });

  test('timeout is ambiguous and is never retried', () async {
    final transport = _FakeSolanaRpcTransport()
      ..error = const SolanaRpcException('timeout', outcomeUnknown: true);
    final service = SolanaRpcBroadcasterService(
      transport: transport,
      requestIdFactory: () => 41,
    );

    await expectLater(
      service.sendTransaction(fixture.signedTransaction),
      throwsA(
        isA<SolanaRpcException>()
            .having((error) => error.code, 'code', 'timeout')
            .having((error) => error.outcomeUnknown, 'outcomeUnknown', isTrue),
      ),
    );
    expect(transport.bodies, hasLength(1));
  });

  test('status lookup is read-only and maps all bounded states', () async {
    final transport = _FakeSolanaRpcTransport()
      ..responses.add(_statusResponse(null))
      ..responses.add(_statusResponse(<String, Object?>{
        'confirmationStatus': 'processed',
        'err': null,
      }))
      ..responses.add(_statusResponse(<String, Object?>{
        'confirmationStatus': 'confirmed',
        'err': null,
      }))
      ..responses.add(_statusResponse(<String, Object?>{
        'confirmationStatus': 'finalized',
        'err': null,
      }))
      ..responses.add(_statusResponse(<String, Object?>{
        'confirmationStatus': 'finalized',
        'err': <String, Object?>{
          'InstructionError': <Object?>[0, 'Custom']
        },
      }));
    final service = SolanaRpcBroadcasterService(
      transport: transport,
      requestIdFactory: () => 41,
    );

    expect((await service.signatureStatus(fixture.signature)).status,
        SolanaSignatureStatus.notFound);
    expect((await service.signatureStatus(fixture.signature)).status,
        SolanaSignatureStatus.processed);
    expect((await service.signatureStatus(fixture.signature)).status,
        SolanaSignatureStatus.confirmed);
    expect((await service.signatureStatus(fixture.signature)).status,
        SolanaSignatureStatus.finalized);
    expect((await service.signatureStatus(fixture.signature)).status,
        SolanaSignatureStatus.failed);
    expect(
      transport.bodies.every(
        (body) => body['method'] == 'getSignatureStatuses',
      ),
      isTrue,
    );
    expect(transport.bodies, hasLength(5));
  });

  test('rejects malformed signatures and response mismatches', () async {
    final transport = _FakeSolanaRpcTransport()
      ..responses.add(_response(result: 'not-the-requested-signature'));
    final service = SolanaRpcBroadcasterService(
      transport: transport,
      requestIdFactory: () => 41,
    );

    await expectLater(
      service.signatureStatus('not-base58'),
      throwsA(_rpcCode('invalid_signature')),
    );
    await expectLater(
      service.sendTransaction(fixture.signedTransaction),
      throwsA(_rpcCode('signature_mismatch')),
    );
  });

  test('HTTP transport rejects redirects and disables automatic replay',
      () async {
    var calls = 0;
    final transport = HttpSolanaRpcTransport(
      client: MockClient((request) async {
        calls += 1;
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
        expect(request.persistentConnection, isFalse);
        return http.Response(
          '',
          302,
          headers: const <String, String>{
            'content-type': 'application/json',
            'location': 'https://evil.example',
          },
        );
      }),
    );

    await expectLater(
      transport.postJson(
        solanaMainnetRpcUri,
        const <String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getSignatureStatuses',
          'params': <Object?>[],
        },
        maxBytes: 64 * 1024,
      ),
      throwsA(_rpcCode('redirect_rejected')),
    );
    expect(calls, 1);
  });

  test('scans at most 200 address signatures and reports complete history',
      () async {
    final since = DateTime.fromMillisecondsSinceEpoch(
      2000 * 1000,
      isUtc: true,
    );
    final transport = _FakeSolanaRpcTransport()
      ..responses.add(
        _response(result: <Object?>[
          <String, Object?>{
            'signature': fixture.signature,
            'slot': 20,
            'blockTime': 2001,
            'err': null,
          },
          <String, Object?>{
            'signature': fixture.signature,
            'slot': 19,
            'blockTime': 1999,
            'err': null,
          },
        ]),
      );
    final service = SolanaRpcBroadcasterService(
      transport: transport,
      requestIdFactory: () => 41,
    );

    final history = await service.signaturesForAddress(
      fixture.signer,
      since: since,
      limit: 200,
    );

    expect(history.complete, isTrue);
    expect(history.truncated, isFalse);
    expect(history.entries, hasLength(1));
    expect(history.entries.single.signature, fixture.signature);
    expect(transport.bodies.single['method'], 'getSignaturesForAddress');
    expect(
      transport.bodies.single['params'],
      <Object?>[
        fixture.signer,
        <String, Object?>{'limit': 200, 'commitment': 'confirmed'},
      ],
    );
  });

  test('fetches canonical base64 transaction bytes without broadcasting',
      () async {
    final transport = _FakeSolanaRpcTransport()
      ..responses.add(
        _response(result: <String, Object?>{
          'slot': 20,
          'transaction': <Object?>[
            base64Encode(fixture.signedTransaction),
            'base64',
          ],
          'meta': <String, Object?>{'err': null},
        }),
      );
    final service = SolanaRpcBroadcasterService(
      transport: transport,
      requestIdFactory: () => 41,
    );

    final fetched = await service.transaction(fixture.signature);

    expect(fetched, isNotNull);
    expect(fetched!.signature, fixture.signature);
    expect(fetched.transactionBytes, fixture.signedTransaction);
    expect(transport.bodies.single['method'], 'getTransaction');
  });

  test('checks blockhash validity through a read-only confirmed request',
      () async {
    final transport = _FakeSolanaRpcTransport()
      ..responses.add(
        _response(result: <String, Object?>{
          'context': <String, Object?>{'slot': 20},
          'value': false,
        }),
      );
    final service = SolanaRpcBroadcasterService(
      transport: transport,
      requestIdFactory: () => 41,
    );

    expect(await service.isBlockhashValid(fixture.blockhash), isFalse);
    expect(transport.bodies.single['method'], 'isBlockhashValid');
    expect(
      transport.bodies.single['params'],
      <Object?>[
        fixture.blockhash,
        <String, Object?>{'commitment': 'confirmed'},
      ],
    );
  });
}

Matcher _rpcCode(String code) =>
    isA<SolanaRpcException>().having((error) => error.code, 'code', code);

SolanaRpcRawResponse _response({required Object? result}) =>
    SolanaRpcRawResponse(
      statusCode: 200,
      headers: const <String, String>{'content-type': 'application/json'},
      json: <String, Object?>{
        'jsonrpc': '2.0',
        'id': 41,
        'result': result,
      },
    );

SolanaRpcRawResponse _statusResponse(Object? status) =>
    _response(result: <String, Object?>{
      'context': <String, Object?>{'slot': 123},
      'value': <Object?>[status],
    });

final class _FakeSolanaRpcTransport implements SolanaRpcTransport {
  final List<SolanaRpcRawResponse> responses = <SolanaRpcRawResponse>[];
  final List<Uri> uris = <Uri>[];
  final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];
  final List<int> maxBytes = <int>[];
  SolanaRpcException? error;

  @override
  Future<SolanaRpcRawResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required int maxBytes,
  }) async {
    uris.add(uri);
    bodies.add(body);
    this.maxBytes.add(maxBytes);
    final failure = error;
    if (failure != null) throw failure;
    return responses.removeAt(0);
  }
}
