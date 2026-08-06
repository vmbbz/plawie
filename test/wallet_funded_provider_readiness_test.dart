import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/dynamic_model_catalog.dart';
import 'package:clawa/services/model_provider_catalog.dart';
import 'package:clawa/services/native_bridge.dart';
import 'package:clawa/services/provider_balance_service.dart';
import 'package:clawa/services/wallet_funded_provider_readiness.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  test('Venice requires a healthy hardware-backed wallet before selection', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('venice'),
      walletStatus: SecureWalletStatus.absent(),
      isBaseMainnet: true,
      transportState: PaidProviderTransportState.stopped,
      balance: null,
      now: now,
    );

    expect(result.state, WalletFundedProviderState.walletRequired);
    expect(result.canSelectModels, isFalse);
    expect(result.primaryAction, WalletFundedProviderAction.openBase);
    expect(result.primaryActionLabel, 'Create or import wallet');
    expect(result.catalogLabel, 'Live catalog');
    expect(result.transportLabel, 'Transport starts on selection');
  });

  test('software-backed wallet is not payment-ready', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('blockrun'),
      walletStatus: _healthyWallet(hardwareBacked: false),
      isBaseMainnet: true,
      transportState: PaidProviderTransportState.stopped,
      balance: null,
      now: now,
    );

    expect(result.state, WalletFundedProviderState.hardwareSecurityRequired);
    expect(result.canSelectModels, isFalse);
    expect(result.detail, contains('hardware-backed'));
  });

  test('wallet-funded providers require the Base page to use mainnet', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('blockrun'),
      walletStatus: _healthyWallet(),
      isBaseMainnet: false,
      transportState: PaidProviderTransportState.healthy,
      balance: null,
      now: now,
    );

    expect(result.state, WalletFundedProviderState.baseMainnetRequired);
    expect(result.canSelectModels, isFalse);
    expect(result.primaryAction, WalletFundedProviderAction.switchToMainnet);
  });

  test('Venice does not become ready from wallet existence alone', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('venice'),
      walletStatus: _healthyWallet(),
      isBaseMainnet: true,
      transportState: PaidProviderTransportState.stopped,
      balance: null,
      now: now,
    );

    expect(result.state, WalletFundedProviderState.balanceUnknown);
    expect(result.canSelectModels, isFalse);
    expect(result.primaryAction, WalletFundedProviderAction.refreshBalance);
    expect(result.primaryActionLabel, 'Check Venice balance');
  });

  test('stale Venice balance must be refreshed before model selection', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('venice'),
      walletStatus: _healthyWallet(),
      isBaseMainnet: true,
      transportState: PaidProviderTransportState.healthy,
      balance: _balance(
        state: ProviderBalanceState.available,
        remainingUsd: 4,
        refreshedAt: now.subtract(const Duration(minutes: 16)),
      ),
      now: now,
    );

    expect(result.state, WalletFundedProviderState.balanceUnknown);
    expect(result.canSelectModels, isFalse);
    expect(result.detail, contains('stale'));
  });

  test('depleted Venice balance exposes top-up without claiming readiness', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('venice'),
      walletStatus: _healthyWallet(),
      isBaseMainnet: true,
      transportState: PaidProviderTransportState.healthy,
      balance: _balance(
        state: ProviderBalanceState.depleted,
        remainingUsd: 0,
        canConsume: false,
        refreshedAt: now,
      ),
      now: now,
    );

    expect(result.state, WalletFundedProviderState.balanceDepleted);
    expect(result.canSelectModels, isFalse);
    expect(result.primaryAction, WalletFundedProviderAction.topUpVenice);
    expect(result.primaryActionLabel, 'Top up Venice');
  });

  test('low Venice balance stays selectable but remains visibly low', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('venice'),
      walletStatus: _healthyWallet(),
      isBaseMainnet: true,
      transportState: PaidProviderTransportState.healthy,
      balance: _balance(
        state: ProviderBalanceState.low,
        remainingUsd: 0.4,
        canConsume: true,
        refreshedAt: now,
      ),
      now: now,
    );

    expect(result.state, WalletFundedProviderState.balanceLow);
    expect(result.canSelectModels, isTrue);
    expect(result.primaryAction, WalletFundedProviderAction.topUpVenice);
    expect(result.title, isNot(contains('Funded')));
  });

  test('BlockRun is selectable and described only as payment per request', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('blockrun'),
      walletStatus: _healthyWallet(),
      isBaseMainnet: true,
      transportState: PaidProviderTransportState.stopped,
      balance: null,
      now: now,
    );

    expect(result.state, WalletFundedProviderState.paymentPerRequest);
    expect(result.canSelectModels, isTrue);
    expect(result.title, 'Payment per request');
    expect(result.primaryAction, WalletFundedProviderAction.fundWallet);
    expect('${result.title} ${result.detail}'.toLowerCase(),
        isNot(contains('funded')));
  });

  test('unhealthy running transport is a visible selection blocker', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('blockrun'),
      walletStatus: _healthyWallet(),
      isBaseMainnet: true,
      transportState: PaidProviderTransportState.unhealthy,
      balance: null,
      now: now,
    );

    expect(result.state, WalletFundedProviderState.transportUnavailable);
    expect(result.canSelectModels, isFalse);
    expect(result.primaryAction, WalletFundedProviderAction.restartGateway);
  });

  test('informational fallback model never makes a provider selectable', () {
    final result = WalletFundedProviderReadinessService.evaluate(
      provider: _provider('venice', live: false),
      walletStatus: _healthyWallet(),
      isBaseMainnet: true,
      transportState: PaidProviderTransportState.stopped,
      balance: _balance(
        state: ProviderBalanceState.available,
        remainingUsd: 5,
        canConsume: true,
        refreshedAt: now,
      ),
      now: now,
    );

    expect(result.state, WalletFundedProviderState.catalogUnavailable);
    expect(result.canSelectModels, isFalse);
    expect(result.primaryAction, WalletFundedProviderAction.refreshModels);
  });
}

DynamicProviderRecord _provider(String id, {bool live = true}) {
  return DynamicProviderRecord(
    id: id,
    label: id == 'venice' ? 'Venice' : 'BlockRun',
    authenticationMode: ProviderAuthenticationMode.walletIdentity,
    connectionState: DynamicProviderConnectionState.connected,
    catalogState: live
        ? DynamicProviderCatalogState.fresh
        : DynamicProviderCatalogState.offlineFallback,
    source: live ? 'live' : 'bundled-static',
    lastRefreshedAt: DateTime.utc(2026, 8, 6, 11, 59),
    models: <DynamicModelRecord>[
      DynamicModelRecord(
        id: '$id/${live ? 'model-1' : 'catalog-unavailable'}',
        providerId: id,
        label: live ? 'Model One' : 'Refresh models',
        route: ModelRouteKind.cloud,
        liveAvailable: live,
        unavailableReason: live ? null : 'Refresh required.',
      ),
    ],
  );
}

SecureWalletStatus _healthyWallet({bool hardwareBacked = true}) {
  return SecureWalletStatus(
    state: SecureWalletState.healthy,
    address: '0x1111111111111111111111111111111111111111',
    securityLevel: hardwareBacked ? 'Trusted Environment' : 'software',
    authenticationMode: 'deviceCredentialOrBiometric',
    errorCode: '',
    envelopeIntegrity: 'verified',
    authenticationAvailable: true,
    hardwareBacked: hardwareBacked,
    verificationPending: false,
    verificationCode: '',
  );
}

ProviderBalanceSnapshot _balance({
  required ProviderBalanceState state,
  required DateTime refreshedAt,
  double? remainingUsd,
  bool? canConsume,
}) {
  return ProviderBalanceSnapshot(
    providerId: 'venice',
    providerLabel: 'Venice',
    kind: ProviderBalanceKind.prepaidBalance,
    state: state,
    refreshedAt: refreshedAt,
    summary: 'Balance status',
    remainingUsd: remainingUsd,
    canConsume: canConsume,
  );
}
