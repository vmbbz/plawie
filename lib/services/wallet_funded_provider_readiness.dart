import 'ai_payment_provider_catalog.dart';
import 'base_service.dart';
import 'dynamic_model_catalog.dart';
import 'native_bridge.dart';
import 'paid_provider_gateway_coordinator.dart';
import 'provider_balance_service.dart';

enum PaidProviderTransportState {
  stopped,
  healthy,
  unhealthy,
}

enum WalletFundedProviderState {
  catalogUnavailable,
  walletRequired,
  walletRecoveryRequired,
  authenticationUnavailable,
  hardwareSecurityRequired,
  baseMainnetRequired,
  transportUnavailable,
  balanceUnknown,
  balanceDepleted,
  balanceLow,
  ready,
  paymentPerRequest,
}

enum WalletFundedProviderAction {
  none,
  openBase,
  fundWallet,
  switchToMainnet,
  refreshBalance,
  topUpVenice,
  restartGateway,
  refreshModels,
}

class WalletFundedProviderEnvironment {
  const WalletFundedProviderEnvironment({
    required this.walletStatus,
    required this.isBaseMainnet,
    required this.transportState,
  });

  final SecureWalletStatus walletStatus;
  final bool isBaseMainnet;
  final PaidProviderTransportState transportState;
}

class WalletFundedProviderReadiness {
  const WalletFundedProviderReadiness({
    required this.providerId,
    required this.state,
    required this.canSelectModels,
    required this.title,
    required this.detail,
    required this.catalogLabel,
    required this.transportLabel,
    required this.primaryAction,
    required this.primaryActionLabel,
    this.balanceRefreshedAt,
  });

  final String providerId;
  final WalletFundedProviderState state;
  final bool canSelectModels;
  final String title;
  final String detail;
  final String catalogLabel;
  final String transportLabel;
  final WalletFundedProviderAction primaryAction;
  final String primaryActionLabel;
  final DateTime? balanceRefreshedAt;

  bool get needsAttention =>
      !canSelectModels ||
      state == WalletFundedProviderState.balanceLow ||
      state == WalletFundedProviderState.paymentPerRequest;
}

typedef WalletFundedEnvironmentReader = Future<WalletFundedProviderEnvironment>
    Function();
typedef CachedProviderBalanceReader = ProviderBalanceSnapshot? Function(
  String providerId,
);

/// Composes non-secret, read-only observations for every wallet-funded model
/// surface. Loading this service never authenticates, signs, tops up, or spends.
/// Provider balances are cached observations and expire after fifteen minutes.
class WalletFundedProviderReadinessService {
  WalletFundedProviderReadinessService({
    WalletFundedEnvironmentReader? environmentReader,
    CachedProviderBalanceReader? balanceReader,
    DateTime Function()? clock,
  })  : _environmentReader = environmentReader,
        _balanceReader = balanceReader,
        _clock = clock ?? DateTime.now;

  static const Duration balanceFreshness = Duration(minutes: 15);

  final WalletFundedEnvironmentReader? _environmentReader;
  final CachedProviderBalanceReader? _balanceReader;
  final DateTime Function() _clock;

  Future<Map<String, WalletFundedProviderReadiness>> inspect(
    DynamicCatalogSnapshot snapshot,
  ) async {
    final walletProviders = snapshot.providers
        .where((provider) => AiPaymentProviderCatalog.byId(provider.id) != null)
        .toList(growable: false);
    if (walletProviders.isEmpty) {
      return const <String, WalletFundedProviderReadiness>{};
    }

    final environment = await (_environmentReader ?? _readProduction)();
    final balanceReader =
        _balanceReader ?? ProviderBalanceService.instance.cached;
    final now = _clock().toUtc();
    return <String, WalletFundedProviderReadiness>{
      for (final provider in walletProviders)
        provider.id: evaluate(
          provider: provider,
          walletStatus: environment.walletStatus,
          isBaseMainnet: environment.isBaseMainnet,
          transportState: environment.transportState,
          balance: balanceReader(provider.id),
          now: now,
        ),
    };
  }

  static Future<WalletFundedProviderEnvironment> _readProduction() async {
    final base = BaseService();
    await base.initialize();
    final coordinator = PaidProviderGatewayCoordinator.instance;
    final health = await coordinator.inspectHealth();
    return WalletFundedProviderEnvironment(
      walletStatus: base.walletStatus,
      isBaseMainnet: !base.useSepolia,
      transportState: health == null
          ? PaidProviderTransportState.stopped
          : health
              ? PaidProviderTransportState.healthy
              : PaidProviderTransportState.unhealthy,
    );
  }

  static WalletFundedProviderReadiness evaluate({
    required DynamicProviderRecord provider,
    required SecureWalletStatus walletStatus,
    required bool isBaseMainnet,
    required PaidProviderTransportState transportState,
    required ProviderBalanceSnapshot? balance,
    required DateTime now,
  }) {
    final option = AiPaymentProviderCatalog.byId(provider.id);
    if (option == null) {
      throw ArgumentError.value(
        provider.id,
        'provider',
        'Provider is not wallet-funded.',
      );
    }
    final catalogLabel = _catalogLabel(provider.catalogState);
    final transportLabel = switch (transportState) {
      PaidProviderTransportState.stopped => 'Transport starts on selection',
      PaidProviderTransportState.healthy => 'Transport healthy',
      PaidProviderTransportState.unhealthy => 'Transport needs restart',
    };

    WalletFundedProviderReadiness result({
      required WalletFundedProviderState state,
      required bool canSelect,
      required String title,
      required String detail,
      required WalletFundedProviderAction action,
      required String actionLabel,
      DateTime? balanceRefreshedAt,
    }) {
      return WalletFundedProviderReadiness(
        providerId: provider.id,
        state: state,
        canSelectModels: canSelect,
        title: title,
        detail: detail,
        catalogLabel: catalogLabel,
        transportLabel: transportLabel,
        primaryAction: action,
        primaryActionLabel: actionLabel,
        balanceRefreshedAt: balanceRefreshedAt,
      );
    }

    if (walletStatus.state == SecureWalletState.absent) {
      return result(
        state: WalletFundedProviderState.walletRequired,
        canSelect: false,
        title: 'Base wallet required',
        detail:
            'Create or import the app-owned Base wallet before using this provider.',
        action: WalletFundedProviderAction.openBase,
        actionLabel: 'Create or import wallet',
      );
    }

    if (!walletStatus.isConnected) {
      return result(
        state: WalletFundedProviderState.walletRecoveryRequired,
        canSelect: false,
        title: 'Wallet needs attention',
        detail:
            'Open Base to complete migration, recovery, or the active wallet operation.',
        action: WalletFundedProviderAction.openBase,
        actionLabel: 'Manage wallet',
      );
    }

    if (!walletStatus.authenticationAvailable) {
      return result(
        state: WalletFundedProviderState.authenticationUnavailable,
        canSelect: false,
        title: 'Device authentication unavailable',
        detail:
            'Set up a supported device credential or biometric before wallet payments.',
        action: WalletFundedProviderAction.openBase,
        actionLabel: 'Manage wallet',
      );
    }

    if (!walletStatus.hardwareBacked) {
      return result(
        state: WalletFundedProviderState.hardwareSecurityRequired,
        canSelect: false,
        title: 'Hardware security required',
        detail:
            'Mainnet x402 signing requires a hardware-backed Android Keystore key.',
        action: WalletFundedProviderAction.openBase,
        actionLabel: 'Review wallet security',
      );
    }

    if (!isBaseMainnet) {
      return result(
        state: WalletFundedProviderState.baseMainnetRequired,
        canSelect: false,
        title: 'Switch to Base Mainnet',
        detail: 'Wallet-funded AI payments do not use Base Sepolia.',
        action: WalletFundedProviderAction.switchToMainnet,
        actionLabel: 'Switch to Mainnet',
      );
    }

    final hasLiveModels = provider.models.any((model) => model.liveAvailable);
    if (!hasLiveModels ||
        provider.catalogState == DynamicProviderCatalogState.offlineFallback ||
        provider.catalogState == DynamicProviderCatalogState.unavailable) {
      return result(
        state: WalletFundedProviderState.catalogUnavailable,
        canSelect: false,
        title: 'Live models unavailable',
        detail: provider.errorMessage ??
            'Refresh this provider before selecting a model.',
        action: WalletFundedProviderAction.refreshModels,
        actionLabel: 'Refresh models',
      );
    }

    if (transportState == PaidProviderTransportState.unhealthy) {
      return result(
        state: WalletFundedProviderState.transportUnavailable,
        canSelect: false,
        title: 'Provider transport needs restart',
        detail:
            'The private loopback transport failed its authenticated health check.',
        action: WalletFundedProviderAction.restartGateway,
        actionLabel: 'Restart Gateway',
      );
    }

    if (option.fundingMode == AiPaymentFundingMode.perRequest) {
      return result(
        state: WalletFundedProviderState.paymentPerRequest,
        canSelect: true,
        title: 'Payment per request',
        detail:
            'No prepaid balance exists. A valid paid request shows its exact Base USDC approval separately.',
        action: WalletFundedProviderAction.fundWallet,
        actionLabel: 'Fund wallet',
      );
    }

    final refreshedAt = balance?.refreshedAt.toUtc();
    final balanceIsStale = refreshedAt != null &&
        now.toUtc().difference(refreshedAt) > balanceFreshness;
    if (balance == null || balanceIsStale) {
      return result(
        state: WalletFundedProviderState.balanceUnknown,
        canSelect: false,
        title: 'Venice balance needs checking',
        detail: balanceIsStale
            ? 'The cached Venice balance is stale and must be refreshed with user authentication.'
            : 'Check the wallet-linked Venice balance before selecting a model.',
        action: WalletFundedProviderAction.refreshBalance,
        actionLabel: 'Check Venice balance',
        balanceRefreshedAt: refreshedAt,
      );
    }

    final depleted = balance.state == ProviderBalanceState.depleted ||
        balance.canConsume == false ||
        (balance.remainingUsd != null && balance.remainingUsd! <= 0);
    if (depleted) {
      return result(
        state: WalletFundedProviderState.balanceDepleted,
        canSelect: false,
        title: 'Venice top-up required',
        detail: balance.summary,
        action: WalletFundedProviderAction.topUpVenice,
        actionLabel: 'Top up Venice',
        balanceRefreshedAt: refreshedAt,
      );
    }

    if (balance.state == ProviderBalanceState.low &&
        balance.canConsume != false) {
      return result(
        state: WalletFundedProviderState.balanceLow,
        canSelect: true,
        title: 'Low prepaid balance',
        detail: balance.summary,
        action: WalletFundedProviderAction.topUpVenice,
        actionLabel: 'Top up Venice',
        balanceRefreshedAt: refreshedAt,
      );
    }

    if (balance.state == ProviderBalanceState.available &&
        balance.canConsume != false) {
      return result(
        state: WalletFundedProviderState.ready,
        canSelect: true,
        title: 'Prepaid balance ready',
        detail: balance.summary,
        action: WalletFundedProviderAction.openBase,
        actionLabel: 'Manage',
        balanceRefreshedAt: refreshedAt,
      );
    }

    return result(
      state: WalletFundedProviderState.balanceUnknown,
      canSelect: false,
      title: 'Venice balance unavailable',
      detail: balance.summary,
      action: WalletFundedProviderAction.refreshBalance,
      actionLabel: 'Check Venice balance',
      balanceRefreshedAt: refreshedAt,
    );
  }

  static String _catalogLabel(DynamicProviderCatalogState state) =>
      switch (state) {
        DynamicProviderCatalogState.fresh => 'Live catalog',
        DynamicProviderCatalogState.stale => 'Cached catalog',
        DynamicProviderCatalogState.offlineFallback => 'Offline fallback',
        DynamicProviderCatalogState.unavailable => 'Catalog unavailable',
      };
}
