import 'dart:convert';

import 'package:clawa/services/bridge/bridge_http_client.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/lifi_bridge_service.dart';
import 'package:clawa/services/bridge/lifi_transaction_validator.dart';
import 'package:flutter_test/flutter_test.dart';

const source = '0x1111111111111111111111111111111111111111';
const destination = '0x2222222222222222222222222222222222222222';
const sourceToken = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const bridgeContract = '0x3333333333333333333333333333333333333333';
const approval = '0x4444444444444444444444444444444444444444';

void main() {
  final now = DateTime.utc(2026, 8, 7, 12);

  BridgeFundingRequest request({
    BridgeChain? chain,
    BridgeToken? token,
    String sourceAddress = source,
    String baseAddress = destination,
  }) =>
      BridgeFundingRequest(
        method: BridgeFundingMethod.connectedWallet,
        sourceChain: chain ?? ethereum,
        sourceToken: token ?? ethereumUsdc,
        amount: '1',
        amountUnits: '1000000',
        baseDestinationAddress: baseAddress,
        sourceAddress: sourceAddress,
      );

  BridgeExecutableQuote evmQuote({
    BridgeFundingRequest? requested,
    String connectedSource = source,
    int destinationChainId = BridgeConstants.baseChainId,
    BridgeToken destinationToken = baseUsdc,
    DateTime? expiresAt,
    EvmBridgeExecutionPayload? payload,
    String minimumOutputUnits = '990000',
  }) {
    final actualRequest = requested ?? request();
    return BridgeExecutableQuote(
      estimate: BridgeEstimate(
        provider: 'lifi',
        quoteId: 'quote-1',
        request: actualRequest,
        minimumOutputUnits: minimumOutputUnits,
        minimumOutputDisplay: '0.99',
        routeTool: 'Across',
        quotedAt: now,
        expiresAt: expiresAt ?? now.add(const Duration(minutes: 1)),
        approvalAddress: approval,
      ),
      connectedSourceAddress: connectedSource,
      destinationChainId: destinationChainId,
      destinationToken: destinationToken,
      payload: payload ??
          const EvmBridgeExecutionPayload(
            chainId: BridgeConstants.ethereumChainId,
            from: source,
            to: bridgeContract,
            valueHex: '0x0',
            dataHex: '0xdeadbeef',
            gasLimitHex: '0x5208',
            approvalAddress: approval,
          ),
      fingerprint: 'fingerprint',
    );
  }

  test('executable LI.FI service retains EVM payload but estimate does not',
      () async {
    final transport = _QuoteFixtureTransport();
    final service = LifiBridgeService(transport: transport, clock: () => now);

    final estimate = await service.estimate(request());
    final executable = await service.executableQuote(
      request(),
      connectedSourceAddress: source,
    );

    expect(estimate.approvalAddress, approval);
    expect(estimate.toString(), isNot(contains('deadbeef')));
    expect(executable.payload, isA<EvmBridgeExecutionPayload>());
    expect(
      (executable.payload as EvmBridgeExecutionPayload).dataHex,
      '0xdeadbeef',
    );
  });

  test('executable LI.FI service retains only the bounded Solana payload',
      () async {
    final transport = _QuoteFixtureTransport(solana: true);
    final service = LifiBridgeService(transport: transport, clock: () => now);
    final solanaRequest = request(
      chain: solana,
      token: solanaToken,
      sourceAddress: solanaAddress,
    ).copyWithForTest(amountUnits: '1000000000');

    final estimate = await service.estimate(solanaRequest);
    final executable = await service.executableQuote(
      solanaRequest,
      connectedSourceAddress: solanaAddress,
    );

    expect(estimate.toString(), isNot(contains(transport.solanaPayload)));
    expect(executable.payload, isA<SolanaBridgeExecutionPayload>());
    expect(
      (executable.payload as SolanaBridgeExecutionPayload).base64Transaction,
      transport.solanaPayload,
    );
  });

  test('LI.FI parsing rejects non-finite slippage and fractional integers',
      () async {
    final hostileTransports = <_QuoteFixtureTransport>[
      _QuoteFixtureTransport(slippage: 'NaN'),
      _QuoteFixtureTransport(actionFromChainId: 1.5),
      _QuoteFixtureTransport(sourceTokenDecimals: 6.5),
    ];

    for (final transport in hostileTransports) {
      final service = LifiBridgeService(transport: transport, clock: () => now);
      await expectLater(
        service.executableQuote(
          request(),
          connectedSourceAddress: source,
        ),
        throwsA(isA<BridgeValidationException>()),
      );
    }
  });

  test('validator accepts the exact reviewed EVM quote', () {
    expect(
      () => const LifiTransactionValidator().validate(
        evmQuote(),
        request: request(),
        connectedAddress: source,
        baseAddress: destination,
        now: now,
      ),
      returnsNormally,
    );
  });

  test('rejects changed request, destination token, amount, and expiry', () {
    final validator = const LifiTransactionValidator();
    final hostile = <BridgeExecutableQuote>[
      evmQuote(connectedSource: '0x9999999999999999999999999999999999999999'),
      evmQuote(destinationChainId: 1),
      evmQuote(
        destinationToken: const BridgeToken(
          chainId: 8453,
          address: '0x9999999999999999999999999999999999999999',
          symbol: 'USDC',
          decimals: 6,
          solverDepositable: false,
        ),
      ),
      evmQuote(
        destinationToken: const BridgeToken(
          chainId: 8453,
          address: BridgeConstants.baseUsdc,
          symbol: 'USDC',
          decimals: 18,
          solverDepositable: false,
        ),
      ),
      evmQuote(requested: request().copyWithForTest(amountUnits: '2')),
      evmQuote(expiresAt: now.add(const Duration(seconds: 29))),
      evmQuote(minimumOutputUnits: '0'),
    ];
    for (final quote in hostile) {
      expect(
        () => validator.validate(
          quote,
          request: request(),
          connectedAddress: source,
          baseAddress: destination,
          now: now,
        ),
        throwsA(isA<BridgeValidationException>()),
      );
    }
  });

  test('rejects malformed EVM fields, approval mismatch, and oversized data',
      () {
    final validator = const LifiTransactionValidator();
    final payloads = <EvmBridgeExecutionPayload>[
      const EvmBridgeExecutionPayload(
        chainId: 2,
        from: source,
        to: bridgeContract,
        valueHex: '0x0',
        dataHex: '0x00',
        gasLimitHex: '0x1',
        approvalAddress: approval,
      ),
      const EvmBridgeExecutionPayload(
        chainId: 1,
        from: '0x9999999999999999999999999999999999999999',
        to: bridgeContract,
        valueHex: '0x0',
        dataHex: '0x00',
        gasLimitHex: '0x1',
        approvalAddress: approval,
      ),
      const EvmBridgeExecutionPayload(
        chainId: 1,
        from: source,
        to: 'not-an-address',
        valueHex: 'zero',
        dataHex: '0x0',
        gasLimitHex: 'gas',
        approvalAddress: approval,
      ),
      const EvmBridgeExecutionPayload(
        chainId: 1,
        from: source,
        to: bridgeContract,
        valueHex: '0x0',
        dataHex: '0x00',
        gasLimitHex: '0x1',
        approvalAddress: bridgeContract,
      ),
      EvmBridgeExecutionPayload(
        chainId: 1,
        from: source,
        to: bridgeContract,
        valueHex: '0x0',
        dataHex: '0x${'aa' * (256 * 1024 + 1)}',
        gasLimitHex: '0x1',
        approvalAddress: approval,
      ),
    ];
    for (final payload in payloads) {
      expect(
        () => validator.validate(
          evmQuote(payload: payload),
          request: request(),
          connectedAddress: source,
          baseAddress: destination,
          now: now,
        ),
        throwsA(isA<BridgeValidationException>()),
      );
    }
  });

  test('Solana validation is exact-case and bounded to one transaction', () {
    final bytes = List<int>.generate(64, (index) => index);
    final solanaRequest = request(
      chain: solana,
      token: solanaToken,
      sourceAddress: solanaAddress,
    );
    final quote = BridgeExecutableQuote(
      estimate: BridgeEstimate(
        provider: 'lifi',
        quoteId: 'sol-1',
        request: solanaRequest,
        minimumOutputUnits: '900000',
        minimumOutputDisplay: '0.9',
        routeTool: 'Mayan',
        quotedAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
      ),
      connectedSourceAddress: solanaAddress,
      destinationChainId: 8453,
      destinationToken: baseUsdc,
      payload: SolanaBridgeExecutionPayload(
        from: solanaAddress,
        base64Transaction: base64Encode(bytes),
      ),
      fingerprint: 'sol-fingerprint',
    );
    const validator = LifiTransactionValidator();

    expect(
      () => validator.validate(
        quote,
        request: solanaRequest,
        connectedAddress: solanaAddress,
        baseAddress: destination,
        now: now,
      ),
      returnsNormally,
    );
    expect(
      () => validator.validate(
        quote,
        request: solanaRequest,
        connectedAddress: solanaAddress.toLowerCase(),
        baseAddress: destination,
        now: now,
      ),
      throwsA(isA<BridgeValidationException>()),
    );
    final oversized = BridgeExecutableQuote(
      estimate: quote.estimate,
      connectedSourceAddress: quote.connectedSourceAddress,
      destinationChainId: quote.destinationChainId,
      destinationToken: quote.destinationToken,
      payload: SolanaBridgeExecutionPayload(
        from: solanaAddress,
        base64Transaction: base64Encode(List<int>.filled(1233, 1)),
      ),
      fingerprint: quote.fingerprint,
    );
    expect(
      () => validator.validate(
        oversized,
        request: solanaRequest,
        connectedAddress: solanaAddress,
        baseAddress: destination,
        now: now,
      ),
      throwsA(isA<BridgeValidationException>()),
    );
    final malformed = BridgeExecutableQuote(
      estimate: quote.estimate,
      connectedSourceAddress: quote.connectedSourceAddress,
      destinationChainId: quote.destinationChainId,
      destinationToken: quote.destinationToken,
      payload: const SolanaBridgeExecutionPayload(
        from: solanaAddress,
        base64Transaction: 'not-base64!',
      ),
      fingerprint: quote.fingerprint,
    );
    expect(
      () => validator.validate(
        malformed,
        request: solanaRequest,
        connectedAddress: solanaAddress,
        baseAddress: destination,
        now: now,
      ),
      throwsA(isA<BridgeValidationException>()),
    );
  });
}

extension on BridgeFundingRequest {
  BridgeFundingRequest copyWithForTest({String? amountUnits}) =>
      BridgeFundingRequest(
        method: method,
        sourceChain: sourceChain,
        sourceToken: this.sourceToken,
        amount: amount,
        amountUnits: amountUnits ?? this.amountUnits,
        baseDestinationAddress: baseDestinationAddress,
        sourceAddress: sourceAddress,
        refundAddress: refundAddress,
        selfCustodyConfirmed: selfCustodyConfirmed,
      );
}

final class _QuoteFixtureTransport implements BridgeHttpTransport {
  _QuoteFixtureTransport({
    this.solana = false,
    this.slippage,
    this.actionFromChainId,
    this.sourceTokenDecimals,
  });

  final bool solana;
  final Object? slippage;
  final num? actionFromChainId;
  final num? sourceTokenDecimals;

  int get _sourceChainId =>
      solana ? BridgeConstants.solanaChainId : BridgeConstants.ethereumChainId;
  String get _sourceTokenAddress =>
      solana ? solanaToken.address : ethereumUsdc.address;
  String get _sourceTokenSymbol => solana ? 'SOL' : 'USDC';
  num get _sourceDecimals => sourceTokenDecimals ?? (solana ? 9 : 6);
  String get solanaPayload =>
      base64Encode(List<int>.generate(64, (index) => index));

  @override
  Future<BridgeHttpResponse> getJson(
    Uri uri, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (uri.path == '/v1/chains') {
      return _ok({
        'chains': [
          {'id': _sourceChainId, 'mainnet': true},
          {'id': 8453, 'mainnet': true},
        ],
      });
    }
    if (uri.path == '/v1/token') {
      final chain = int.parse(uri.queryParameters['chain']!);
      return chain == _sourceChainId
          ? _ok({
              'chainId': _sourceChainId,
              'address': _sourceTokenAddress,
              'symbol': _sourceTokenSymbol,
              'decimals': _sourceDecimals,
            })
          : _ok({
              'chainId': 8453,
              'address': BridgeConstants.baseUsdc,
              'symbol': 'USDC',
              'decimals': 6,
            });
    }
    if (uri.path == '/v1/connections') {
      return _ok({
        'connections': [
          {
            'fromChainId': _sourceChainId,
            'toChainId': 8453,
            'fromTokens': [
              {'chainId': _sourceChainId, 'address': _sourceTokenAddress},
            ],
            'toTokens': [
              {'chainId': 8453, 'address': BridgeConstants.baseUsdc},
            ],
          },
        ],
      });
    }
    if (uri.path == '/v1/quote') {
      return _ok({
        'id': 'quote-1',
        'toolDetails': {'name': 'Across'},
        'action': {
          'fromChainId': actionFromChainId ?? _sourceChainId,
          'toChainId': 8453,
          'fromAddress': uri.queryParameters['fromAddress'],
          'toAddress': uri.queryParameters['toAddress'],
          'fromAmount': uri.queryParameters['fromAmount'],
          'fromToken': {
            'chainId': _sourceChainId,
            'address': _sourceTokenAddress,
            'symbol': _sourceTokenSymbol,
            'decimals': _sourceDecimals,
          },
          'toToken': {
            'chainId': 8453,
            'address': BridgeConstants.baseUsdc,
            'symbol': 'USDC',
            'decimals': 6,
          },
        },
        'estimate': {
          'toAmountMin': '990000',
          if (!solana) 'approvalAddress': approval,
          'executionDuration': 30,
          if (slippage != null) 'slippage': slippage,
        },
        'transactionRequest': solana
            ? {'data': solanaPayload}
            : {
                'chainId': 1,
                'from': source,
                'to': bridgeContract,
                'value': '0x0',
                'data': '0xdeadbeef',
                'gasLimit': '0x5208',
              },
      });
    }
    throw StateError('Unexpected request: $uri');
  }

  @override
  Future<BridgeHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) =>
      throw UnimplementedError();

  BridgeHttpResponse _ok(Object json) => BridgeHttpResponse(
        statusCode: 200,
        headers: const <String, String>{},
        json: json,
      );
}

const ethereum = BridgeChain(
  id: 1,
  key: 'eth',
  name: 'Ethereum',
  type: BridgeChainType.evm,
  nativeTokenSymbol: 'ETH',
);
const ethereumUsdc = BridgeToken(
  chainId: 1,
  address: sourceToken,
  symbol: 'USDC',
  decimals: 6,
  solverDepositable: false,
);
const baseUsdc = BridgeToken(
  chainId: 8453,
  address: BridgeConstants.baseUsdc,
  symbol: 'USDC',
  decimals: 6,
  solverDepositable: false,
);
const solana = BridgeChain(
  id: BridgeConstants.solanaChainId,
  key: 'sol',
  name: 'Solana',
  type: BridgeChainType.svm,
  nativeTokenSymbol: 'SOL',
);
const solanaAddress = 'So11111111111111111111111111111111111111112';
const solanaToken = BridgeToken(
  chainId: BridgeConstants.solanaChainId,
  address: solanaAddress,
  symbol: 'SOL',
  decimals: 9,
  solverDepositable: false,
);
