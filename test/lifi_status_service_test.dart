import 'package:clawa/services/bridge/bridge_http_client.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/lifi_status_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourceHash =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const destinationHash =
      '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('uses only the bounded LI.FI status endpoint', () async {
    final transport = _FakeTransport()..responses.add(_notFound());
    final service = LifiStatusService(transport: transport);

    await service.status(
      sourceTransactionHash: sourceHash,
      sourceChainId: BridgeConstants.ethereumChainId,
      routeTool: 'across',
    );

    expect(transport.uris, hasLength(1));
    final uri = transport.uris.single;
    expect(uri.scheme, 'https');
    expect(uri.host, 'li.quest');
    expect(uri.path, '/v1/status');
    expect(uri.queryParameters, <String, String>{
      'txHash': sourceHash,
      'fromChain': '1',
      'toChain': '8453',
      'bridge': 'across',
    });
  });

  test('maps every supported LI.FI settlement state', () async {
    final cases =
        <({String status, String? substatus, BridgeFundingState state})>[
      (
        status: 'NOT_FOUND',
        substatus: null,
        state: BridgeFundingState.sourcePending,
      ),
      (
        status: 'PENDING',
        substatus: 'WAIT_SOURCE_CONFIRMATIONS',
        state: BridgeFundingState.sourcePending,
      ),
      (
        status: 'PENDING',
        substatus: 'WAIT_DESTINATION_TRANSACTION',
        state: BridgeFundingState.destinationPending,
      ),
      (
        status: 'DONE',
        substatus: 'COMPLETED',
        state: BridgeFundingState.completed,
      ),
      (
        status: 'DONE',
        substatus: 'PARTIAL',
        state: BridgeFundingState.partial,
      ),
      (
        status: 'DONE',
        substatus: 'REFUNDED',
        state: BridgeFundingState.refunded,
      ),
      (
        status: 'FAILED',
        substatus: 'UNKNOWN_ERROR',
        state: BridgeFundingState.failed,
      ),
    ];

    for (final item in cases) {
      final transport = _FakeTransport()
        ..responses.add(
          item.status == 'NOT_FOUND'
              ? _notFound()
              : _statusResponse(
                  status: item.status,
                  substatus: item.substatus!,
                ),
        );
      final observation = await LifiStatusService(transport: transport).status(
        sourceTransactionHash: sourceHash,
        sourceChainId: 1,
        routeTool: 'across',
      );

      expect(observation.state, item.state, reason: '$item');
      expect(observation.providerStatus, item.status);
      expect(observation.providerSubstatus, item.substatus);
      expect(
        observation.destinationTransactionHash,
        item.status == 'NOT_FOUND' ? isNull : destinationHash,
      );
    }
  });

  test('maps a transport timeout to non-terminal source pending', () async {
    final transport = _FakeTransport()
      ..error = const BridgeHttpException('timeout');

    final observation = await LifiStatusService(transport: transport).status(
      sourceTransactionHash: sourceHash,
      sourceChainId: 1,
      routeTool: 'across',
    );

    expect(observation.state, BridgeFundingState.sourcePending);
    expect(observation.providerStatus, 'PENDING');
    expect(observation.providerSubstatus, 'TRANSPORT_TIMEOUT');
  });

  test('maps the live LI.FI 404 transaction-not-found envelope', () async {
    final transport = _FakeTransport()
      ..responses.add(
        const BridgeHttpResponse(
          statusCode: 404,
          headers: <String, String>{},
          json: <String, Object?>{
            'message': 'Transaction hash is not found in any chain.',
            'code': 1003,
          },
        ),
      );

    final observation = await LifiStatusService(transport: transport).status(
      sourceTransactionHash: sourceHash,
      sourceChainId: 1,
      routeTool: 'across',
    );

    expect(observation.state, BridgeFundingState.sourcePending);
    expect(observation.providerStatus, 'NOT_FOUND');
  });

  test('retries once without a rejected legacy display tool label', () async {
    final transport = _FakeTransport()
      ..responses.addAll(<BridgeHttpResponse>[
        const BridgeHttpResponse(
          statusCode: 400,
          headers: <String, String>{},
          json: <String, Object?>{
            'message': 'Unknown bridge tool Eco',
            'code': 1011,
          },
        ),
        _statusResponse(status: 'DONE', substatus: 'COMPLETED'),
      ]);

    final observation = await LifiStatusService(transport: transport).status(
      sourceTransactionHash: sourceHash,
      sourceChainId: 1,
      routeTool: 'Eco',
    );

    expect(observation.state, BridgeFundingState.completed);
    expect(transport.uris, hasLength(2));
    expect(transport.uris.first.queryParameters['bridge'], 'Eco');
    expect(transport.uris.last.queryParameters.containsKey('bridge'), isFalse);
  });

  test('legacy composite route labels use an evidence-bound lookup', () async {
    final transport = _FakeTransport()..responses.add(_notFound());

    await LifiStatusService(transport: transport).status(
      sourceTransactionHash: sourceHash,
      sourceChainId: 1,
      routeTool: 'CCTPv2 + Mayan',
    );

    expect(transport.uris, hasLength(1));
    expect(
        transport.uris.single.queryParameters.containsKey('bridge'), isFalse);
    expect(transport.uris.single.queryParameters['txHash'], sourceHash);
  });

  test('accepts pending source evidence before a destination tx exists',
      () async {
    final response = _statusResponse(
      status: 'PENDING',
      substatus: 'WAIT_SOURCE_CONFIRMATIONS',
      includeReceiving: false,
    );
    final transport = _FakeTransport()..responses.add(response);

    final observation = await LifiStatusService(transport: transport).status(
      sourceTransactionHash: sourceHash,
      sourceChainId: 1,
      routeTool: 'across',
    );

    expect(observation.state, BridgeFundingState.sourcePending);
    expect(observation.destinationTransactionHash, isNull);
  });

  test('surfaces rate limits and clamps Retry-After to 60 seconds', () async {
    final transport = _FakeTransport()
      ..responses.add(
        const BridgeHttpResponse(
          statusCode: 429,
          headers: <String, String>{'retry-after': '999'},
          json: <String, Object?>{},
        ),
      );

    await expectLater(
      LifiStatusService(transport: transport).status(
        sourceTransactionHash: sourceHash,
        sourceChainId: 1,
        routeTool: 'across',
      ),
      throwsA(
        isA<LifiStatusException>()
            .having((error) => error.code, 'code', 'rate_limited')
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 60),
            ),
      ),
    );
  });

  test('rejects malformed JSON and unsupported status combinations', () async {
    for (final response in <BridgeHttpResponse>[
      const BridgeHttpResponse(
        statusCode: 200,
        headers: <String, String>{},
        json: <String, Object?>{'status': 7},
      ),
      _statusResponse(status: 'PENDING', substatus: 'UNRECOGNIZED'),
    ]) {
      final transport = _FakeTransport()..responses.add(response);
      await expectLater(
        LifiStatusService(transport: transport).status(
          sourceTransactionHash: sourceHash,
          sourceChainId: 1,
          routeTool: 'across',
        ),
        throwsA(isA<LifiStatusException>()),
      );
    }
  });

  test('rejects responses for wrong source hashes or chains', () async {
    for (final response in <BridgeHttpResponse>[
      _statusResponse(
        status: 'DONE',
        substatus: 'COMPLETED',
        sourceHash:
            '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      ),
      _statusResponse(
        status: 'DONE',
        substatus: 'COMPLETED',
        sourceChainId: 10,
      ),
      _statusResponse(
        status: 'DONE',
        substatus: 'COMPLETED',
        destinationChainId: 1,
      ),
    ]) {
      final transport = _FakeTransport()..responses.add(response);
      await expectLater(
        LifiStatusService(transport: transport).status(
          sourceTransactionHash: sourceHash,
          sourceChainId: 1,
          routeTool: 'across',
        ),
        throwsA(_statusCode('status_response_mismatch')),
      );
    }
  });

  test('keeps only trusted HTTPS explorer links', () async {
    final transport = _FakeTransport()
      ..responses.add(
        _statusResponse(
          status: 'DONE',
          substatus: 'COMPLETED',
          sourceLink: 'https://etherscan.io/tx/$sourceHash',
          destinationLink: 'https://evil.example/tx/$destinationHash',
          lifiLink: 'https://scan.li.fi/tx/abc',
        ),
      );

    final observation = await LifiStatusService(transport: transport).status(
      sourceTransactionHash: sourceHash,
      sourceChainId: 1,
      routeTool: 'across',
    );

    expect(
      observation.explorerLinks.map((uri) => uri.host),
      <String>['etherscan.io', 'scan.li.fi'],
    );
  });
}

Matcher _statusCode(String code) =>
    isA<LifiStatusException>().having((error) => error.code, 'code', code);

BridgeHttpResponse _notFound() => const BridgeHttpResponse(
      statusCode: 200,
      headers: <String, String>{},
      json: <String, Object?>{'status': 'NOT_FOUND'},
    );

BridgeHttpResponse _statusResponse({
  required String status,
  required String substatus,
  String sourceHash =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  int sourceChainId = 1,
  int destinationChainId = 8453,
  String? sourceLink,
  String? destinationLink,
  String? lifiLink,
  bool includeReceiving = true,
}) =>
    BridgeHttpResponse(
      statusCode: 200,
      headers: const <String, String>{},
      json: <String, Object?>{
        'status': status,
        'substatus': substatus,
        'sending': <String, Object?>{
          'txHash': sourceHash,
          'chainId': sourceChainId,
          if (sourceLink != null) 'txLink': sourceLink,
        },
        if (includeReceiving)
          'receiving': <String, Object?>{
            'txHash':
                '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'chainId': destinationChainId,
            'amount': '9900000',
            if (destinationLink != null) 'txLink': destinationLink,
          },
        if (lifiLink != null) 'lifiExplorerLink': lifiLink,
      },
    );

final class _FakeTransport implements BridgeHttpTransport {
  final List<BridgeHttpResponse> responses = <BridgeHttpResponse>[];
  final List<Uri> uris = <Uri>[];
  BridgeHttpException? error;

  @override
  Future<BridgeHttpResponse> getJson(
    Uri uri, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) async {
    uris.add(uri);
    final failure = error;
    if (failure != null) throw failure;
    return responses.removeAt(0);
  }

  @override
  Future<BridgeHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) =>
      throw UnimplementedError();
}
