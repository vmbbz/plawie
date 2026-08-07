import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/evm_bridge_rpc_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const owner = '0x1111111111111111111111111111111111111111';
  const token = '0x2222222222222222222222222222222222222222';
  const spender = '0x3333333333333333333333333333333333333333';
  const destination = '0x4444444444444444444444444444444444444444';
  const transactionHash =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('encodes exact finite approval and Base USDC transfer calldata', () {
    final service = EvmBridgeRpcService(transport: _FakeRpcTransport());

    expect(
      service.encodeExactApproval(spender, BigInt.from(1000000)),
      '0x095ea7b3'
      '000000000000000000000000${spender.substring(2).toLowerCase()}'
      '00000000000000000000000000000000000000000000000000000000000f4240',
    );
    expect(
      service.encodeExactTransfer(destination, BigInt.from(1000000)),
      '0xa9059cbb'
      '000000000000000000000000${destination.substring(2).toLowerCase()}'
      '00000000000000000000000000000000000000000000000000000000000f4240',
    );
  });

  test('rejects maximum allowance and malformed values', () {
    final service = EvmBridgeRpcService(transport: _FakeRpcTransport());
    final maximum = (BigInt.one << 256) - BigInt.one;

    expect(
      () => service.encodeExactApproval(spender, maximum),
      throwsA(_rpcCode('maximum_allowance_rejected')),
    );
    expect(
      () => service.encodeExactApproval('0x1234', BigInt.one),
      throwsA(_rpcCode('invalid_evm_address')),
    );
    expect(
      () => service.encodeExactTransfer(destination, BigInt.from(-1)),
      throwsA(_rpcCode('invalid_uint256')),
    );
  });

  test('reads a strict 32-byte allowance from the shipped chain RPC', () async {
    final transport = _FakeRpcTransport()
      ..responses.add(
        _response(
          result:
              '0x00000000000000000000000000000000000000000000000000000000000f4240',
        ),
      );
    final service = EvmBridgeRpcService(
      transport: transport,
      requestIdFactory: () => 17,
    );

    final value = await service.allowance(
      chainId: BridgeConstants.ethereumChainId,
      tokenAddress: token,
      owner: owner,
      spender: spender,
    );

    expect(value, BigInt.from(1000000));
    expect(transport.uris.single, Uri.parse(evmSourceRpcUrls[1]!));
    expect(transport.maxBytes.single, 64 * 1024);
    expect(transport.bodies.single, <String, Object?>{
      'jsonrpc': '2.0',
      'id': 17,
      'method': 'eth_call',
      'params': <Object?>[
        <String, Object?>{
          'to': token,
          'data': '0xdd62ed3e'
              '000000000000000000000000${owner.substring(2)}'
              '000000000000000000000000${spender.substring(2)}',
        },
        'latest',
      ],
    });
  });

  test('rejects malformed eth_call words and unshipped RPC policy', () async {
    final transport = _FakeRpcTransport()
      ..responses.add(_response(result: '0x01'));
    final service = EvmBridgeRpcService(
      transport: transport,
      requestIdFactory: () => 17,
    );

    await expectLater(
      service.allowance(
        chainId: 1,
        tokenAddress: token,
        owner: owner,
        spender: spender,
      ),
      throwsA(_rpcCode('invalid_eth_call_word')),
    );
    expect(
      () => EvmBridgeRpcService(
        transport: _FakeRpcTransport(),
        rpcUrls: const <int, String>{1: 'https://evil.example'},
      ),
      throwsA(_rpcCode('rpc_policy_mismatch')),
    );
  });

  test('estimates gas with strict lower and upper bounds', () async {
    final transport = _FakeRpcTransport()
      ..responses.add(_response(result: '0x186a0'));
    final service = EvmBridgeRpcService(
      transport: transport,
      requestIdFactory: () => 17,
    );
    final payload = _payload(owner: owner, to: spender);

    expect(await service.estimateGas(payload), BigInt.from(100000));
    expect(
      (transport.bodies.single['params'] as List<Object?>).single,
      <String, Object?>{
        'from': owner,
        'to': spender,
        'value': '0x0',
        'data': '0x',
      },
    );
  });

  test('rejects unsafe gas estimates', () async {
    for (final result in <String>['0x5207', '0x4c4b41']) {
      final transport = _FakeRpcTransport()
        ..responses.add(_response(result: result));
      final service = EvmBridgeRpcService(
        transport: transport,
        requestIdFactory: () => 17,
      );
      await expectLater(
        service.estimateGas(_payload(owner: owner, to: spender)),
        throwsA(_rpcCode('gas_estimate_out_of_bounds')),
      );
    }
  });

  test('maps pending and successful receipts without resubmission', () async {
    final transport = _FakeRpcTransport()
      ..responses.add(_response(result: null))
      ..responses.add(
        _response(result: <String, Object?>{
          'transactionHash': transactionHash,
          'status': '0x1',
          'blockNumber': '0x10',
        }),
      );
    final service = EvmBridgeRpcService(
      transport: transport,
      requestIdFactory: () => 17,
    );

    final pending = await service.waitForReceipt(
      chainId: 1,
      transactionHash: transactionHash,
    );
    final succeeded = await service.waitForReceipt(
      chainId: 1,
      transactionHash: transactionHash,
    );

    expect(pending.status, EvmReceiptStatus.pending);
    expect(succeeded.status, EvmReceiptStatus.succeeded);
    expect(transport.bodies, hasLength(2));
    expect(
      transport.bodies.every(
        (body) => body['method'] == 'eth_getTransactionReceipt',
      ),
      isTrue,
    );
  });

  test('maps a reverted receipt and validates its transaction hash', () async {
    final transport = _FakeRpcTransport()
      ..responses.add(
        _response(result: <String, Object?>{
          'transactionHash': transactionHash,
          'status': '0x0',
          'blockNumber': '0x11',
        }),
      );
    final service = EvmBridgeRpcService(
      transport: transport,
      requestIdFactory: () => 17,
    );

    final receipt = await service.waitForReceipt(
      chainId: 1,
      transactionHash: transactionHash,
    );

    expect(receipt.status, EvmReceiptStatus.reverted);
    expect(receipt.blockNumber, BigInt.from(17));
  });

  test('surfaces rate limits and clamps retry-after', () async {
    final transport = _FakeRpcTransport()
      ..responses.add(
        const EvmRpcRawResponse(
          statusCode: 429,
          headers: <String, String>{'retry-after': '999'},
          json: <String, Object?>{},
        ),
      );
    final service = EvmBridgeRpcService(
      transport: transport,
      requestIdFactory: () => 17,
    );

    await expectLater(
      service.waitForReceipt(chainId: 1, transactionHash: transactionHash),
      throwsA(
        isA<EvmRpcException>()
            .having((error) => error.code, 'code', 'rate_limited')
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 60),
            ),
      ),
    );
  });

  test('surfaces bounded transport timeout without retrying', () async {
    final transport = _FakeRpcTransport()
      ..error = const EvmRpcException('timeout');
    final service = EvmBridgeRpcService(
      transport: transport,
      requestIdFactory: () => 17,
    );

    await expectLater(
      service.waitForReceipt(chainId: 1, transactionHash: transactionHash),
      throwsA(_rpcCode('timeout')),
    );
    expect(transport.bodies, hasLength(1));
  });
}

Matcher _rpcCode(String code) =>
    isA<EvmRpcException>().having((error) => error.code, 'code', code);

EvmBridgeExecutionPayload _payload({
  required String owner,
  required String to,
}) =>
    EvmBridgeExecutionPayload(
      chainId: 1,
      from: owner,
      to: to,
      valueHex: '0x0',
      dataHex: '0x',
      gasLimitHex: '0x0',
      approvalAddress: null,
    );

EvmRpcRawResponse _response({required Object? result}) => EvmRpcRawResponse(
      statusCode: 200,
      headers: const <String, String>{'content-type': 'application/json'},
      json: <String, Object?>{
        'jsonrpc': '2.0',
        'id': 17,
        'result': result,
      },
    );

final class _FakeRpcTransport implements EvmRpcTransport {
  final List<EvmRpcRawResponse> responses = <EvmRpcRawResponse>[];
  final List<Uri> uris = <Uri>[];
  final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];
  final List<int> maxBytes = <int>[];
  EvmRpcException? error;

  @override
  Future<EvmRpcRawResponse> postJson(
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
