import 'dart:async';

import 'package:flutter/services.dart';
import 'package:reown_appkit/reown_appkit.dart';

import 'bridge_models.dart';
import 'external_wallet_session_service.dart';

const reownProjectId = String.fromEnvironment('REOWN_PROJECT_ID');
const plawieDappUrl = String.fromEnvironment('PLAWIE_DAPP_URL');
const walletRedirect = 'plawie://wallet-callback';

bool get reownReleaseConfigured {
  final dappUri = Uri.tryParse(plawieDappUrl);
  return reownProjectId.trim().isNotEmpty &&
      dappUri != null &&
      dappUri.scheme == 'https' &&
      dappUri.host.isNotEmpty;
}

final class ReownPublicSession {
  const ReownPublicSession({
    required this.walletLabel,
    required this.publicAddress,
    required this.approvedChains,
    required this.approvedAccounts,
    required this.approvedMethods,
  });

  final String walletLabel;
  final String publicAddress;
  final Set<String> approvedChains;
  final Set<String> approvedAccounts;
  final Set<String> approvedMethods;
}

abstract interface class ReownEvmClient {
  Future<void> initialize();

  Future<ReownPublicSession> connect(int chainId);

  Future<Object?> sendTransaction({
    required String chainId,
    required Map<String, String> transaction,
  });

  Future<void> disconnect();
}

final class ReownClientException implements Exception {
  const ReownClientException(this.code);

  final String code;
}

final class ReownWalletLinkDispatcher {
  ReownWalletLinkDispatcher({
    MethodChannel methods = const MethodChannel(
      'com.openclaw.plawie/wallet_links_control',
    ),
    EventChannel events = const EventChannel(
      'com.openclaw.plawie/wallet_links',
    ),
  })  : _methods = methods,
        _events = events;

  final MethodChannel _methods;
  final EventChannel _events;
  StreamSubscription<Object?>? _subscription;
  Future<bool> Function(String link)? _dispatch;

  Future<void> start(Future<bool> Function(String link) dispatch) async {
    if (_subscription != null) return;
    _dispatch = dispatch;
    _subscription = _events.receiveBroadcastStream().listen((event) {
      if (event is String) {
        final handler = _dispatch;
        if (handler != null) {
          unawaited(handler(event).catchError((Object _) => false));
        }
      }
    });
    final initial = await _methods.invokeMethod<String>('initialLink');
    if (initial != null) {
      try {
        await dispatch(initial);
      } catch (_) {
        // A malformed or stale callback is ignored without exposing its URI.
      }
    }
  }

  Future<void> dispose() async {
    _dispatch = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}

final class ReownEvmWalletAdapter implements ExternalWalletAdapter {
  ReownEvmWalletAdapter({
    required ReownEvmClient client,
    bool? releaseConfigured,
  })  : _client = client,
        _releaseConfigured = releaseConfigured ?? reownReleaseConfigured;

  final ReownEvmClient _client;
  final bool _releaseConfigured;
  ExternalWalletIdentity? _identity;

  @override
  ExternalWalletTransport get transport => ExternalWalletTransport.reownEvm;

  @override
  Future<ExternalWalletOption> discover(BridgeChain chain) async {
    if (chain.type != BridgeChainType.evm) {
      return const ExternalWalletOption(
        transport: ExternalWalletTransport.reownEvm,
        label: 'Compatible EVM wallet',
        available: false,
        reason: 'This connector supports EVM chains only.',
      );
    }
    if (!_releaseConfigured) {
      return const ExternalWalletOption(
        transport: ExternalWalletTransport.reownEvm,
        label: 'Compatible EVM wallet',
        available: false,
        reason: 'External wallet support is not configured in this build.',
      );
    }
    try {
      await _client.initialize();
      return const ExternalWalletOption(
        transport: ExternalWalletTransport.reownEvm,
        label: 'Compatible EVM wallet',
        available: true,
      );
    } catch (_) {
      return const ExternalWalletOption(
        transport: ExternalWalletTransport.reownEvm,
        label: 'Compatible EVM wallet',
        available: false,
        reason: 'The wallet catalog could not be initialized.',
      );
    }
  }

  @override
  Future<ExternalWalletIdentity> connect(BridgeChain chain) async {
    if (!_releaseConfigured || chain.type != BridgeChainType.evm) {
      throw const ExternalWalletException('wallet_transport_unavailable');
    }
    final session = await _guardReown(() async {
      await _client.initialize();
      return _client.connect(chain.id);
    });
    final caipChain = 'eip155:${chain.id}';
    if (!session.approvedChains.contains(caipChain)) {
      throw const ExternalWalletException('wallet_chain_mismatch');
    }
    if (!session.approvedMethods.contains('eth_sendTransaction')) {
      throw const ExternalWalletException('wallet_method_not_approved');
    }
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(session.publicAddress)) {
      throw const ExternalWalletException('wallet_account_invalid');
    }
    final expectedAccount = '$caipChain:${session.publicAddress}'.toLowerCase();
    if (!session.approvedAccounts
        .any((account) => account.toLowerCase() == expectedAccount)) {
      throw const ExternalWalletException('wallet_account_mismatch');
    }
    final identity = ExternalWalletIdentity(
      transport: transport,
      walletLabel: session.walletLabel.trim().isEmpty
          ? 'Compatible EVM wallet'
          : session.walletLabel.trim(),
      publicAddress: session.publicAddress,
      chainId: chain.id,
      chainType: BridgeChainType.evm,
      approvedMethods: Set<String>.unmodifiable(session.approvedMethods),
      approvedFeatures: const <String>{},
    );
    _identity = identity;
    return identity;
  }

  @override
  Future<void> disconnect() async {
    _identity = null;
    await _guardReown<void>(_client.disconnect);
  }

  @override
  Future<String> sendEvmTransaction(
    EvmBridgeExecutionPayload payload,
  ) async {
    final identity = _identity;
    if (identity == null) {
      throw const ExternalWalletException('wallet_not_connected');
    }
    if (identity.chainId != payload.chainId) {
      throw const ExternalWalletException('wallet_chain_mismatch');
    }
    if (identity.publicAddress.toLowerCase() != payload.from.toLowerCase()) {
      throw const ExternalWalletException('wallet_account_mismatch');
    }
    final response = await _guardReown<Object?>(() => _client.sendTransaction(
          chainId: 'eip155:${payload.chainId}',
          transaction: <String, String>{
            'from': payload.from,
            'to': payload.to,
            'value': payload.valueHex,
            'data': payload.dataHex,
            'gas': payload.gasLimitHex,
          },
        ));
    if (response is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(response)) {
      throw const ExternalWalletException('wallet_response_invalid');
    }
    return response;
  }

  @override
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  ) =>
      Future<SolanaWalletSubmissionResult>.error(
        const ExternalWalletException('wallet_transport_chain_mismatch'),
      );
}

final class ReownAppKitEvmClient implements ReownEvmClient {
  ReownAppKitEvmClient({
    required IReownAppKitModal modal,
    required ReownWalletLinkDispatcher linkDispatcher,
  })  : _modal = modal,
        _linkDispatcher = linkDispatcher;

  static const Duration connectionTimeout = Duration(minutes: 10);

  final IReownAppKitModal _modal;
  final ReownWalletLinkDispatcher _linkDispatcher;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _registerRobinhoodMainnet();
    if (!_modal.status.isInitialized) await _modal.init();
    await _linkDispatcher.start(_modal.dispatchEnvelope);
    _initialized = true;
  }

  @override
  Future<ReownPublicSession> connect(int chainId) async {
    final network = ReownAppKitModalNetworks.getNetworkInfo(
      NetworkUtils.eip155,
      chainId.toString(),
    );
    if (network == null || network.isTestNetwork) {
      throw const ReownClientException('wallet_chain_unsupported');
    }
    await _modal.selectChain(network);
    if (_modal.isConnected && _modal.session != null) {
      return _snapshot(_modal.session!, chainId);
    }

    final completer = Completer<ReownPublicSession>();
    void onConnect(ModalConnect? event) {
      if (!completer.isCompleted && event != null) {
        completer.complete(_snapshot(event.session, chainId));
      }
    }

    void onError(ModalError? event) {
      if (completer.isCompleted || event == null) return;
      final text = '${event.message} ${event.description ?? ''}'.toLowerCase();
      completer.completeError(ReownClientException(
        text.contains('reject') ||
                text.contains('declin') ||
                text.contains('cancel')
            ? 'wallet_user_rejected'
            : 'wallet_connect_failed',
      ));
    }

    _modal.onModalConnect.subscribe(onConnect);
    _modal.onModalError.subscribe(onError);
    unawaited(_modal.openModalView().then((_) {
      if (!completer.isCompleted && !_modal.isConnected) {
        completer.completeError(
          const ReownClientException('wallet_user_rejected'),
        );
      }
    }).catchError((Object _) {
      if (!completer.isCompleted) {
        completer.completeError(
          const ReownClientException('wallet_connect_failed'),
        );
      }
    }));
    try {
      return await completer.future.timeout(connectionTimeout);
    } on TimeoutException {
      throw const ReownClientException('wallet_operation_expired');
    } finally {
      _modal.onModalConnect.unsubscribe(onConnect);
      _modal.onModalError.unsubscribe(onError);
    }
  }

  @override
  Future<Object?> sendTransaction({
    required String chainId,
    required Map<String, String> transaction,
  }) {
    final session = _modal.session;
    if (session == null) {
      throw const ReownClientException('wallet_not_connected');
    }
    return _modal.request(
      topic: session.topic,
      chainId: chainId,
      request: SessionRequestParams(
        method: 'eth_sendTransaction',
        params: <Object>[transaction],
      ),
    );
  }

  @override
  Future<void> disconnect() => _modal.disconnect();

  ReownPublicSession _snapshot(
    ReownAppKitModalSession session,
    int requestedChainId,
  ) {
    final accounts =
        session.getAccounts(namespace: NetworkUtils.eip155) ?? const <String>[];
    final prefix = 'eip155:$requestedChainId:';
    final exactAccount = accounts.cast<String?>().firstWhere(
          (account) => account?.startsWith(prefix) == true,
          orElse: () => null,
        );
    final address = exactAccount?.substring(prefix.length) ?? '';
    final chains = session.getApprovedChains(namespace: NetworkUtils.eip155) ??
        const <String>[];
    final methods =
        session.getApprovedMethods(namespace: NetworkUtils.eip155) ??
            const <String>[];
    return ReownPublicSession(
      walletLabel: session.connectedWalletName ?? 'Compatible EVM wallet',
      publicAddress: address,
      approvedChains: Set<String>.unmodifiable(chains),
      approvedAccounts: Set<String>.unmodifiable(accounts),
      approvedMethods: Set<String>.unmodifiable(methods),
    );
  }
}

Future<T> _guardReown<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on ReownClientException catch (error) {
    throw ExternalWalletException(error.code);
  } on ExternalWalletException {
    rethrow;
  } catch (_) {
    throw const ExternalWalletException('wallet_request_failed');
  }
}

void _registerRobinhoodMainnet() {
  final existing = ReownAppKitModalNetworks.getNetworkInfo(
    NetworkUtils.eip155,
    BridgeConstants.robinhoodChainId.toString(),
  );
  if (existing != null) return;
  ReownAppKitModalNetworks.addSupportedNetworks(
    NetworkUtils.eip155,
    const <ReownAppKitModalNetworkInfo>[
      ReownAppKitModalNetworkInfo(
        name: 'Robinhood Chain',
        chainId: '4663',
        currency: 'ETH',
        rpcUrl: 'https://rpc.mainnet.chain.robinhood.com',
        explorerUrl: 'https://robinhoodchain.blockscout.com',
      ),
    ],
  );
}
