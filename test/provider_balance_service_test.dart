import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clawa/services/ai_payment_provider_catalog.dart';
import 'package:clawa/services/provider_balance_service.dart';

void main() {
  const address = '0x1111111111111111111111111111111111111111';
  final now = DateTime.utc(2026, 8, 5, 12);

  test('reads Venice balance with a bounded short-lived wallet identity',
      () async {
    var signerCalls = 0;
    var networkCalls = 0;
    final service = ProviderBalanceService(
      clock: () => now,
      veniceSigner: (request) async {
        signerCalls++;
        expect(
          request['uri'],
          'https://api.venice.ai/api/v1/x402/balance/$address',
        );
        return <String, dynamic>{
          'payer': address,
          'signature': '0x${'a' * 130}',
          'message': 'bounded EIP-4361 message',
        };
      },
      client: MockClient((request) async {
        networkCalls++;
        expect(request.method, 'GET');
        expect(request.url.host, 'api.venice.ai');
        final encoded = request.headers['X-Sign-In-With-X'];
        expect(encoded, isNotEmpty);
        final identity = jsonDecode(utf8.decode(base64Decode(encoded!)));
        expect(identity['address'], address);
        expect(identity['chainId'], 8453);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'canConsume': true,
            'balanceUsd': '4.25',
            'minimumTopUpUsd': 1,
            'suggestedTopUpUsd': 5,
          }),
          200,
        );
      }),
    );

    final first = await service.refreshWalletProvider(
      provider: AiPaymentProviderCatalog.byId('venice')!,
      walletAddress: address,
    );
    final second = await service.refreshWalletProvider(
      provider: AiPaymentProviderCatalog.byId('venice')!,
      walletAddress: address,
    );

    expect(first.remainingUsd, 4.25);
    expect(first.canConsume, isTrue);
    expect(second.remainingUsd, 4.25);
    expect(signerCalls, 1,
        reason: 'identity is cached in memory for this flow');
    expect(networkCalls, 2);
    expect(first.toAgentJson()['mayApproveOrSpend'], isFalse);
  });

  test('per-request providers never fabricate a prepaid balance', () async {
    var signerCalled = false;
    final service = ProviderBalanceService(
      veniceSigner: (_) async {
        signerCalled = true;
        return <String, dynamic>{};
      },
      client: MockClient((_) async => http.Response('', 500)),
    );

    final snapshot = await service.refreshWalletProvider(
      provider: AiPaymentProviderCatalog.byId('blockrun')!,
      walletAddress: address,
    );

    expect(snapshot.state, ProviderBalanceState.unavailable);
    expect(snapshot.summary, contains('per request'));
    expect(snapshot.remainingUsd, isNull);
    expect(signerCalled, isFalse);
  });

  test('documents admin and dashboard-only balance boundaries', () {
    final statuses = ProviderBalanceService(
      client: MockClient((_) async => http.Response('', 500)),
    ).documentedDashboardOnlyStatuses();

    expect(
      statuses.singleWhere((item) => item.providerId == 'anthropic').state,
      ProviderBalanceState.requiresElevatedCredential,
    );
    expect(
      statuses.singleWhere((item) => item.providerId == 'google').state,
      ProviderBalanceState.dashboardOnly,
    );
  });
}
