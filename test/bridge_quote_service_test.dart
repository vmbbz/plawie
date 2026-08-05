import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clawa/services/bridge_quote_service.dart';

void main() {
  const sourceAddress = '0x1111111111111111111111111111111111111111';
  const destinationAddress = '0x2222222222222222222222222222222222222222';
  const robinhoodNative = '0x0000000000000000000000000000000000000000';
  const baseUsdc = BridgeQuoteService.baseUsdcContract;
  final now = DateTime.utc(2026, 8, 5, 12);

  test('runtime-verifies and quotes Robinhood Chain to Base', () async {
    final paths = <String>[];
    final service = BridgeQuoteService(
      clock: () => now,
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.url.host, 'li.quest');
        if (request.url.path == '/v1/chains') {
          return http.Response(
              jsonEncode({
                'chains': [
                  {'id': 4663, 'name': 'Robinhood Chain', 'mainnet': true},
                  {'id': 8453, 'name': 'Base', 'mainnet': true},
                ],
              }),
              200);
        }
        if (request.url.path == '/v1/token') {
          final chain = request.url.queryParameters['chain'];
          return chain == '4663'
              ? http.Response(
                  jsonEncode({
                    'address': robinhoodNative,
                    'chainId': 4663,
                    'symbol': 'ETH',
                    'decimals': 18,
                  }),
                  200,
                )
              : http.Response(
                  jsonEncode({
                    'address': baseUsdc,
                    'chainId': 8453,
                    'symbol': 'USDC',
                    'decimals': 6,
                  }),
                  200,
                );
        }
        if (request.url.path == '/v1/connections') {
          return http.Response(
              jsonEncode({
                'connections': [
                  {
                    'fromChainId': 4663,
                    'toChainId': 8453,
                    'fromTokens': [
                      {'address': robinhoodNative, 'chainId': 4663},
                    ],
                    'toTokens': [
                      {'address': baseUsdc, 'chainId': 8453},
                    ],
                  },
                ],
              }),
              200);
        }
        expect(request.url.queryParameters['fromChain'], '4663');
        expect(request.url.queryParameters['toChain'], '8453');
        expect(request.url.queryParameters['fromToken'], robinhoodNative);
        expect(request.url.queryParameters['toToken'], baseUsdc);
        expect(request.url.queryParameters.containsKey('order'), isFalse);
        return http.Response(
            jsonEncode({
              'id': 'quote-robinhood-base',
              'tool': 'across',
              'toolDetails': {'name': 'Across'},
              'action': {
                'fromChainId': 4663,
                'toChainId': 8453,
                'fromAddress': sourceAddress,
                'toAddress': destinationAddress,
                'fromAmount': '10000000000000000',
                'fromToken': {
                  'address': robinhoodNative,
                  'chainId': 4663,
                  'symbol': 'ETH',
                  'decimals': 18,
                },
                'toToken': {
                  'address': baseUsdc,
                  'chainId': 8453,
                  'symbol': 'USDC',
                  'decimals': 6,
                },
              },
              'estimate': {
                'toAmountMin': '24100000',
                'executionDuration': 45,
                'feeCosts': [
                  {'amountUSD': '0.12'},
                ],
                'gasCosts': [
                  {'amountUSD': '0.03'},
                ],
              },
              'transactionRequest': {
                'to': '0x3333333333333333333333333333333333333333',
                'data': '0xdeadbeef',
              },
            }),
            200);
      }),
    );

    final quote = await service.quoteToBaseUsdc(BridgeQuoteRequest(
      sourceChain: BridgeQuoteService.sourceChains
          .singleWhere((chain) => chain.id == 4663),
      sourceToken: 'ETH',
      amount: '0.01',
      sourceAddress: sourceAddress,
      baseDestinationAddress: destinationAddress,
    ));

    expect(paths, [
      '/v1/chains',
      '/v1/token',
      '/v1/token',
      '/v1/connections',
      '/v1/quote',
    ]);
    expect(quote.routeTool, 'Across');
    expect(quote.destinationAmountMinimum, '24.1');
    expect(quote.estimatedFeesUsd, closeTo(0.15, 0.00001));
    expect(quote.toAgentJson()['mayApproveOrSign'], isFalse);
    expect(quote.toAgentJson().toString(), isNot(contains('deadbeef')));
  });

  test('Solana requires a base58 source address', () async {
    final service = BridgeQuoteService(
      client: MockClient((_) async => http.Response('', 500)),
    );
    final solana = BridgeQuoteService.sourceChains
        .singleWhere((chain) => chain.id == BridgeQuoteService.solanaChainId);

    await expectLater(
      service.quoteToBaseUsdc(BridgeQuoteRequest(
        sourceChain: solana,
        sourceToken: 'SOL',
        amount: '1',
        sourceAddress: sourceAddress,
        baseDestinationAddress: destinationAddress,
      )),
      throwsA(isA<BridgeQuoteException>()),
    );
  });

  test('a connection mismatch blocks quote execution', () async {
    final service = BridgeQuoteService(
      client: MockClient((request) async {
        if (request.url.path == '/v1/chains') {
          return http.Response(
              jsonEncode({
                'chains': [
                  {'id': 1, 'mainnet': true},
                  {'id': 8453, 'mainnet': true},
                ],
              }),
              200);
        }
        if (request.url.path == '/v1/token') {
          final chain = request.url.queryParameters['chain'];
          return chain == '1'
              ? http.Response(
                  jsonEncode({
                    'address': robinhoodNative,
                    'chainId': 1,
                    'symbol': 'ETH',
                    'decimals': 18,
                  }),
                  200,
                )
              : http.Response(
                  jsonEncode({
                    'address': baseUsdc,
                    'chainId': 8453,
                    'symbol': 'USDC',
                    'decimals': 6,
                  }),
                  200,
                );
        }
        return http.Response(jsonEncode({'connections': []}), 200);
      }),
    );

    await expectLater(
      service.quoteToBaseUsdc(BridgeQuoteRequest(
        sourceChain: BridgeQuoteService.sourceChains.first,
        sourceToken: 'ETH',
        amount: '0.1',
        sourceAddress: sourceAddress,
        baseDestinationAddress: destinationAddress,
      )),
      throwsA(isA<BridgeQuoteException>()),
    );
  });
}
