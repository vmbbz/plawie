import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../base_service.dart';
import '../preferences_service.dart';
import 'bridge_capability_service.dart';
import 'bridge_funding_controller.dart';
import 'bridge_http_client.dart';
import 'bridge_models.dart';
import 'bridge_receipt_store.dart';
import 'evm_bridge_rpc_service.dart';
import 'external_wallet_session_service.dart';
import 'external_wallet_transport_router.dart';
import 'lifi_bridge_service.dart';
import 'lifi_status_service.dart';
import 'relay_deposit_service.dart';
import 'reown_evm_wallet_adapter.dart';
import 'reown_solana_fallback_adapter.dart';
import 'solana_mwa_wallet_adapter.dart';
import 'solana_rpc_broadcaster.dart';

final class BridgeFundingRuntime {
  BridgeFundingRuntime._({
    required this.controller,
    required this.capabilities,
    required BridgeHttpClient bridgeHttp,
    required ExternalWalletSessionService wallet,
    required ReownWalletLinkDispatcher? linkDispatcher,
    required IReownAppKitModal? reownModal,
  })  : _bridgeHttp = bridgeHttp,
        _wallet = wallet,
        _linkDispatcher = linkDispatcher,
        _reownModal = reownModal;

  final BridgeFundingController controller;
  final BridgeCapabilityService capabilities;
  final BridgeHttpClient _bridgeHttp;
  final ExternalWalletSessionService _wallet;
  final ReownWalletLinkDispatcher? _linkDispatcher;
  final IReownAppKitModal? _reownModal;

  static BridgeFundingRuntime create({
    required BuildContext context,
    required PreferencesService preferences,
    required BaseService baseService,
    required bool Function() isForeground,
  }) {
    final bridgeHttp = BridgeHttpClient();
    final receiptStore = BridgeReceiptStore(preferences: preferences);
    final adapters = <ExternalWalletAdapter>[
      SolanaMwaWalletAdapter(),
    ];

    IReownAppKitModal? modal;
    ReownWalletLinkDispatcher? linkDispatcher;
    final needsReown = BridgeFeatureConfig.reownEvmWalletsEnabled ||
        BridgeFeatureConfig.reownSolanaFallbackEnabled;
    if (needsReown && reownReleaseConfigured) {
      final dappUri = Uri.parse(plawieDappUrl);
      modal = ReownAppKitModal(
        context: context,
        projectId: reownProjectId,
        metadata: PairingMetadata(
          name: 'Plawie',
          description: 'Fund the Plawie Base wallet with visible approval.',
          url: dappUri.toString(),
          icons: <String>[
            dappUri.resolve('/favicon.ico').toString(),
          ],
          redirect: Redirect(
            native: walletRedirect,
          ),
        ),
      );
      linkDispatcher = ReownWalletLinkDispatcher();
      adapters.add(
        ReownEvmWalletAdapter(
          client: ReownAppKitEvmClient(
            modal: modal,
            linkDispatcher: linkDispatcher,
          ),
        ),
      );
      if (BridgeFeatureConfig.reownSolanaFallbackEnabled) {
        adapters.addAll(<ExternalWalletAdapter>[
          ReownSolanaFallbackAdapter(
            transport: ExternalWalletTransport.reownSolanaPhantom,
            client: ReownAppKitSolanaClient(
              modal: modal,
              linkDispatcher: linkDispatcher,
            ),
          ),
          ReownSolanaFallbackAdapter(
            transport: ExternalWalletTransport.reownSolanaSolflare,
            client: ReownAppKitSolanaClient(
              modal: modal,
              linkDispatcher: linkDispatcher,
            ),
          ),
        ]);
      }
    }

    final wallet = RoutedExternalWalletSessionService(
      transport: ExternalWalletTransportRouter(adapters: adapters),
    );
    final lifi = LifiBridgeService(transport: bridgeHttp);
    final controller = BridgeFundingController(
      quoteProvider: LifiExecutableQuoteProvider(lifi),
      wallet: wallet,
      receiptStore: receiptStore,
      rpc: EvmBridgeRpcService(),
      solanaRpc: SolanaRpcBroadcasterService(),
      lifiStatus: LifiStatusService(transport: bridgeHttp),
      relay: RelayDepositService(
        transport: bridgeHttp,
        supportedSourceChainIds: const <int>{
          BridgeConstants.ethereumChainId,
          BridgeConstants.solanaChainId,
          BridgeConstants.robinhoodChainId,
        },
      ),
      baseBalance: _BaseBalanceRefreshAdapter(baseService),
      internalBaseAddress: () => baseService.address ?? '',
      isForeground: isForeground,
    );
    return BridgeFundingRuntime._(
      controller: controller,
      capabilities: BridgeCapabilityService(
        transport: bridgeHttp,
        preferences: preferences,
      ),
      bridgeHttp: bridgeHttp,
      wallet: wallet,
      linkDispatcher: linkDispatcher,
      reownModal: modal,
    );
  }

  Future<void> dispose() async {
    try {
      await _wallet.disconnect();
    } catch (_) {
      // Runtime disposal is best effort; no transaction is retried or resent.
    }
    await _linkDispatcher?.dispose();
    await _reownModal?.dispose();
    _bridgeHttp.dispose();
  }
}

final class _BaseBalanceRefreshAdapter implements BaseBalanceRefreshService {
  const _BaseBalanceRefreshAdapter(this._baseService);

  final BaseService _baseService;

  @override
  Future<bool> refresh() async {
    try {
      await _baseService.refreshBaseUsdcBalanceUnitsForPayment();
      return true;
    } catch (_) {
      return false;
    }
  }
}
