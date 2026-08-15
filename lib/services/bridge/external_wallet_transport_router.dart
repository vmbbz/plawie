import 'bridge_models.dart';
import 'external_wallet_session_service.dart';

final class ExternalWalletTransportRouter
    implements ExternalWalletSessionTransport {
  ExternalWalletTransportRouter({
    required Iterable<ExternalWalletAdapter> adapters,
    this.reownEvmEnabled = BridgeFeatureConfig.reownEvmWalletsEnabled,
    this.solanaMwaEnabled = BridgeFeatureConfig.solanaMwaWalletsEnabled,
    this.reownSolanaFallbackEnabled =
        BridgeFeatureConfig.reownSolanaFallbackEnabled,
    this.baseAccountMwpEnabled = BridgeFeatureConfig.baseAccountMwpEnabled,
  }) : _adapters = <ExternalWalletTransport, ExternalWalletAdapter>{
          for (final adapter in adapters) adapter.transport: adapter,
        };

  final Map<ExternalWalletTransport, ExternalWalletAdapter> _adapters;
  final bool reownEvmEnabled;
  final bool solanaMwaEnabled;
  final bool reownSolanaFallbackEnabled;
  final bool baseAccountMwpEnabled;

  final Map<int, bool> _mwaUnavailableAfterDiscovery = <int, bool>{};
  ExternalWalletAdapter? _connectedAdapter;
  ExternalWalletIdentity? _connectedIdentity;

  @override
  Future<List<ExternalWalletOption>> discover(BridgeChain chain) async {
    return switch (chain.type) {
      BridgeChainType.evm => _discoverEvm(chain),
      BridgeChainType.svm => _discoverSolana(chain),
    };
  }

  Future<List<ExternalWalletOption>> _discoverEvm(BridgeChain chain) async {
    final result = <ExternalWalletOption>[];
    result.add(await _discoverBounded(
      chain,
      ExternalWalletTransport.reownEvm,
      enabled: reownEvmEnabled,
      disabledReason: 'Compatible EVM wallets are disabled in this release.',
      missingReason: 'The EVM wallet connector is unavailable.',
      label: 'Compatible EVM wallet',
    ));
    if (chain.id == BridgeConstants.baseChainId) {
      result.add(await _discoverBounded(
        chain,
        ExternalWalletTransport.baseAccountMwp,
        enabled: baseAccountMwpEnabled,
        disabledReason: 'Base Account support is not enabled in this release.',
        missingReason: 'Base Account support is not available yet.',
        label: 'Base Account',
      ));
    }
    return List<ExternalWalletOption>.unmodifiable(result);
  }

  Future<List<ExternalWalletOption>> _discoverSolana(BridgeChain chain) async {
    final previouslyUnavailable =
        _mwaUnavailableAfterDiscovery[chain.id] == true;
    final mwa = previouslyUnavailable
        ? const ExternalWalletOption(
            transport: ExternalWalletTransport.solanaMwa,
            label: 'Android Solana wallet',
            available: false,
            reason: 'No MWA-compatible wallet answered the last request. '
                'Retry MWA or choose an explicit fallback.',
          )
        : await _discoverBounded(
            chain,
            ExternalWalletTransport.solanaMwa,
            enabled: solanaMwaEnabled,
            disabledReason:
                'Mobile Wallet Adapter is disabled in this release.',
            missingReason: 'Mobile Wallet Adapter is unavailable.',
            label: 'Android Solana wallet',
          );
    final result = <ExternalWalletOption>[mwa];
    _mwaUnavailableAfterDiscovery[chain.id] = !mwa.available;

    if (!mwa.available && reownSolanaFallbackEnabled) {
      for (final transport in const <ExternalWalletTransport>[
        ExternalWalletTransport.reownSolanaPhantom,
        ExternalWalletTransport.reownSolanaSolflare,
      ]) {
        final adapter = _adapters[transport];
        if (adapter == null) continue;
        result.add(await _guardDiscovery(
          adapter,
          chain,
          label: transport == ExternalWalletTransport.reownSolanaPhantom
              ? 'Phantom compatibility fallback'
              : 'Solflare compatibility fallback',
        ));
      }
    }
    return List<ExternalWalletOption>.unmodifiable(result);
  }

  Future<ExternalWalletOption> _discoverBounded(
    BridgeChain chain,
    ExternalWalletTransport transport, {
    required bool enabled,
    required String disabledReason,
    required String missingReason,
    required String label,
  }) async {
    if (!enabled) {
      return ExternalWalletOption(
        transport: transport,
        label: label,
        available: false,
        reason: disabledReason,
      );
    }
    final adapter = _adapters[transport];
    if (adapter == null) {
      return ExternalWalletOption(
        transport: transport,
        label: label,
        available: false,
        reason: missingReason,
      );
    }
    return _guardDiscovery(adapter, chain, label: label);
  }

  Future<ExternalWalletOption> _guardDiscovery(
    ExternalWalletAdapter adapter,
    BridgeChain chain, {
    required String label,
  }) async {
    try {
      return await adapter.discover(chain);
    } catch (_) {
      return ExternalWalletOption(
        transport: adapter.transport,
        label: label,
        available: false,
        reason: 'Wallet discovery failed. Try again before connecting.',
      );
    }
  }

  @override
  Future<ExternalWalletIdentity> connect(
    BridgeChain chain, {
    ExternalWalletTransport? transport,
  }) async {
    if (_connectedAdapter != null) {
      throw const ExternalWalletException('wallet_already_connected');
    }
    final selected = _selectTransport(chain, transport);
    final adapter = _adapters[selected];
    if (adapter == null || !_isEnabled(selected)) {
      throw const ExternalWalletException('wallet_transport_unavailable');
    }

    ExternalWalletIdentity identity;
    try {
      identity = await adapter.connect(chain);
      _validateIdentity(identity, chain, selected);
    } on ExternalWalletException catch (error) {
      if (selected == ExternalWalletTransport.solanaMwa &&
          error.code == 'wallet_transport_unavailable') {
        _mwaUnavailableAfterDiscovery[chain.id] = true;
      }
      await _safeDisconnect(adapter);
      rethrow;
    } catch (_) {
      await _safeDisconnect(adapter);
      throw const ExternalWalletException('wallet_connect_failed');
    }
    _connectedAdapter = adapter;
    _connectedIdentity = identity;
    if (selected == ExternalWalletTransport.solanaMwa) {
      _mwaUnavailableAfterDiscovery[chain.id] = false;
    }
    return identity;
  }

  ExternalWalletTransport _selectTransport(
    BridgeChain chain,
    ExternalWalletTransport? requested,
  ) {
    if (chain.type == BridgeChainType.evm) {
      final selected = requested ?? ExternalWalletTransport.reownEvm;
      if (selected == ExternalWalletTransport.baseAccountMwp &&
          (!baseAccountMwpEnabled || !_adapters.containsKey(selected))) {
        throw const ExternalWalletException('wallet_transport_unavailable');
      }
      if (selected != ExternalWalletTransport.reownEvm &&
          selected != ExternalWalletTransport.baseAccountMwp) {
        throw const ExternalWalletException('wallet_transport_chain_mismatch');
      }
      return selected;
    }

    if (requested == null) {
      if (_mwaUnavailableAfterDiscovery[chain.id] == true) {
        throw const ExternalWalletException(
          'wallet_fallback_requires_selection',
        );
      }
      return ExternalWalletTransport.solanaMwa;
    }
    if (requested == ExternalWalletTransport.solanaMwa) return requested;
    if (!_solanaFallbacks.contains(requested)) {
      throw const ExternalWalletException('wallet_transport_chain_mismatch');
    }
    if (_mwaUnavailableAfterDiscovery[chain.id] != true) {
      throw const ExternalWalletException(
        'wallet_fallback_requires_discovery',
      );
    }
    if (!reownSolanaFallbackEnabled) {
      throw const ExternalWalletException('wallet_transport_unavailable');
    }
    return requested;
  }

  bool _isEnabled(ExternalWalletTransport transport) => switch (transport) {
        ExternalWalletTransport.reownEvm => reownEvmEnabled,
        ExternalWalletTransport.solanaMwa => solanaMwaEnabled,
        ExternalWalletTransport.reownSolanaPhantom ||
        ExternalWalletTransport.reownSolanaSolflare =>
          reownSolanaFallbackEnabled,
        ExternalWalletTransport.baseAccountMwp => baseAccountMwpEnabled,
      };

  @override
  Future<void> disconnect() async {
    final adapter = _connectedAdapter;
    _connectedAdapter = null;
    _connectedIdentity = null;
    if (adapter == null) return;
    try {
      await adapter.disconnect();
    } on ExternalWalletException {
      rethrow;
    } catch (_) {
      throw const ExternalWalletException('wallet_disconnect_failed');
    }
  }

  @override
  Future<String> sendEvmTransaction(
    EvmBridgeExecutionPayload payload,
  ) async {
    final adapter = _requireConnected(BridgeChainType.evm);
    final identity = _connectedIdentity!;
    if (payload.chainId != identity.chainId) {
      throw const ExternalWalletException('wallet_chain_mismatch');
    }
    if (!_sameEvm(identity.publicAddress, payload.from)) {
      throw const ExternalWalletException('wallet_account_mismatch');
    }
    return adapter.sendEvmTransaction(payload);
  }

  @override
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  ) async {
    final adapter = _requireConnected(BridgeChainType.svm);
    final identity = _connectedIdentity!;
    if (identity.publicAddress != payload.from) {
      throw const ExternalWalletException('wallet_account_mismatch');
    }
    return adapter.submitSolanaTransaction(payload);
  }

  ExternalWalletAdapter _requireConnected(BridgeChainType type) {
    final adapter = _connectedAdapter;
    final identity = _connectedIdentity;
    if (adapter == null || identity == null) {
      throw const ExternalWalletException('wallet_not_connected');
    }
    if (identity.chainType != type) {
      throw const ExternalWalletException('wallet_chain_type_mismatch');
    }
    return adapter;
  }
}

const _solanaFallbacks = <ExternalWalletTransport>{
  ExternalWalletTransport.reownSolanaPhantom,
  ExternalWalletTransport.reownSolanaSolflare,
};

void _validateIdentity(
  ExternalWalletIdentity identity,
  BridgeChain chain,
  ExternalWalletTransport selected,
) {
  if (identity.transport != selected) {
    throw const ExternalWalletException('wallet_transport_mismatch');
  }
  if (identity.chainId != chain.id || identity.chainType != chain.type) {
    throw const ExternalWalletException('wallet_chain_mismatch');
  }
  final validAddress = switch (chain.type) {
    BridgeChainType.evm =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(identity.publicAddress),
    BridgeChainType.svm =>
      RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(identity.publicAddress),
  };
  if (!validAddress) {
    throw const ExternalWalletException('wallet_account_invalid');
  }
  if (chain.type == BridgeChainType.evm &&
      !identity.approvedMethods.contains('eth_sendTransaction')) {
    throw const ExternalWalletException('wallet_method_not_approved');
  }
  if (_solanaFallbacks.contains(selected) &&
      !identity.approvedMethods.contains('solana_signTransaction')) {
    throw const ExternalWalletException('wallet_method_not_approved');
  }
  if (selected == ExternalWalletTransport.solanaMwa &&
      !identity.approvedMethods.contains('solana_signTransaction') &&
      !identity.approvedMethods.contains('solana_signAndSendTransaction')) {
    throw const ExternalWalletException('wallet_method_not_approved');
  }
}

Future<void> _safeDisconnect(ExternalWalletAdapter adapter) async {
  try {
    await adapter.disconnect();
  } catch (_) {
    // The original validation/connect failure is the actionable result.
  }
}

bool _sameEvm(String left, String right) =>
    left.toLowerCase() == right.toLowerCase();
