import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/ai_payment_provider_catalog.dart';
import 'package:clawa/services/x402_payment_service.dart';

void main() {
  test('payment catalog is pinned to Base Mainnet USDC policy', () {
    expect(AiPaymentProviderCatalog.network, 'eip155:8453');
    expect(AiPaymentProviderCatalog.network, X402PaymentPolicy.network);
    expect(
      AiPaymentProviderCatalog.usdcContract.toLowerCase(),
      X402PaymentPolicy.usdc,
    );
    expect(X402PaymentPolicy.liveSigningEnabled, isTrue);
  });

  test('Venice is modeled as wallet identity with a prepaid balance', () {
    final venice = AiPaymentProviderCatalog.byId('VENICE');

    expect(venice, isNotNull);
    expect(venice!.connectionMode, AiPaymentConnectionMode.walletIdentity);
    expect(venice.fundingMode, AiPaymentFundingMode.prepaidBalance);
    expect(venice.supportsTopUp, isTrue);
    expect(venice.allowsResourceLessTopUpChallenge, isTrue);
    expect(venice.topUpEndpoint?.host, 'api.venice.ai');
    expect(venice.allowedHosts, <String>{'api.venice.ai'});
    expect(venice.paymentHeaderName, 'X-402-Payment');
    expect(venice.monetizationMode, AiPaymentMonetizationMode.none);
  });

  test('BlockRun is modeled as per-request payment without top-up', () {
    final blockRun = AiPaymentProviderCatalog.byId('blockrun');

    expect(blockRun, isNotNull);
    expect(blockRun!.connectionMode, AiPaymentConnectionMode.walletIdentity);
    expect(blockRun.fundingMode, AiPaymentFundingMode.perRequest);
    expect(blockRun.supportsTopUp, isFalse);
    expect(blockRun.allowsResourceLessTopUpChallenge, isFalse);
    expect(blockRun.topUpEndpoint, isNull);
    expect(blockRun.allowedHosts, <String>{'blockrun.ai'});
    expect(blockRun.monetizationMode, AiPaymentMonetizationMode.none);
  });

  test('unknown provider metadata is not accepted', () {
    expect(AiPaymentProviderCatalog.byId(null), isNull);
    expect(AiPaymentProviderCatalog.byId(''), isNull);
    expect(AiPaymentProviderCatalog.byId('remote-catalog-entry'), isNull);
  });

  test('first setup uses trusted wallet providers without fabricating BYOK',
      () async {
    final setup =
        await File('lib/screens/setup_flow_screen.dart').readAsString();
    final setupService =
        await File('lib/services/provider_setup_service.dart').readAsString();

    expect(setup, contains('...AiPaymentProviderCatalog.providers.map('));
    expect(setup, contains('activeProvider.paymentProviderId != null'));
    expect(
      setup,
      contains('ProviderSetupService().selectWalletFundedProvider('),
    );
    expect(setupService, contains('_preferences.apiProvider = null;'));
    expect(setupService, contains('_preferences.configuredModel = null;'));
    expect(
      setupService,
      contains('_preferences.aiPaymentProvider = provider.id;'),
    );
    expect(setup, isNot(contains("apiKey: 'wallet'")));
  });
}
