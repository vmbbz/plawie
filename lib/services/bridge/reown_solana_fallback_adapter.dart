import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:reown_appkit/modal/services/phantom_service/utils/phantom_utils.dart';
import 'package:reown_appkit/modal/services/solflare_service/utils/solflare_utils.dart';
import 'package:reown_appkit/reown_appkit.dart';

import 'bridge_models.dart';
import 'external_wallet_session_service.dart';
import 'reown_evm_wallet_adapter.dart';

final class ReownSolanaPublicSession {
  const ReownSolanaPublicSession({
    required this.transport,
    required this.walletLabel,
    required this.publicAddress,
    required this.approvedChains,
    required this.approvedAccounts,
    required this.approvedMethods,
  });

  final ExternalWalletTransport transport;
  final String walletLabel;
  final String publicAddress;
  final Set<String> approvedChains;
  final Set<String> approvedAccounts;
  final Set<String> approvedMethods;
}

abstract interface class ReownSolanaClient {
  Future<void> initialize();

  Future<ReownSolanaPublicSession> connect(
    ExternalWalletTransport transport,
  );

  Future<Object?> signTransaction({
    required ExternalWalletTransport transport,
    required String base64Transaction,
  });

  Future<void> disconnect();
}

final class ReownSolanaFallbackAdapter implements ExternalWalletAdapter {
  ReownSolanaFallbackAdapter({
    required ExternalWalletTransport transport,
    required ReownSolanaClient client,
    bool? releaseConfigured,
  })  : assert(
          transport == ExternalWalletTransport.reownSolanaPhantom ||
              transport == ExternalWalletTransport.reownSolanaSolflare,
        ),
        _transport = transport,
        _client = client,
        _releaseConfigured = releaseConfigured ?? reownReleaseConfigured;

  static const String mainnetChainId =
      'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp';

  final ExternalWalletTransport _transport;
  final ReownSolanaClient _client;
  final bool _releaseConfigured;
  ExternalWalletIdentity? _identity;

  @override
  ExternalWalletTransport get transport => _transport;

  @override
  Future<ExternalWalletOption> discover(BridgeChain chain) async {
    final label = _labelFor(_transport);
    if (!_releaseConfigured ||
        chain.type != BridgeChainType.svm ||
        chain.id != BridgeConstants.solanaChainId) {
      return ExternalWalletOption(
        transport: _transport,
        label: label,
        available: false,
        reason: !_releaseConfigured
            ? 'The bounded Solana fallback is not configured in this build.'
            : 'The bounded fallback supports Solana mainnet only.',
      );
    }
    try {
      await _client.initialize();
      return ExternalWalletOption(
        transport: _transport,
        label: label,
        available: true,
      );
    } catch (_) {
      return ExternalWalletOption(
        transport: _transport,
        label: label,
        available: false,
        reason: 'The bounded wallet fallback could not be initialized.',
      );
    }
  }

  @override
  Future<ExternalWalletIdentity> connect(BridgeChain chain) async {
    if (!_releaseConfigured ||
        chain.type != BridgeChainType.svm ||
        chain.id != BridgeConstants.solanaChainId) {
      throw const ExternalWalletException('wallet_transport_unavailable');
    }
    final session = await _guardFallback(() async {
      await _client.initialize();
      return _client.connect(_transport);
    });
    if (session.transport != _transport) {
      throw const ExternalWalletException('wallet_transport_mismatch');
    }
    if (!session.approvedChains.contains(mainnetChainId)) {
      throw const ExternalWalletException('wallet_chain_mismatch');
    }
    if (!session.approvedMethods.contains('solana_signTransaction')) {
      throw const ExternalWalletException('wallet_method_not_approved');
    }
    if (!RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$')
        .hasMatch(session.publicAddress)) {
      throw const ExternalWalletException('wallet_account_invalid');
    }
    if (!session.approvedAccounts
        .contains('$mainnetChainId:${session.publicAddress}')) {
      throw const ExternalWalletException('wallet_account_mismatch');
    }
    final identity = ExternalWalletIdentity(
      transport: _transport,
      walletLabel: session.walletLabel.trim().isEmpty
          ? _labelFor(_transport)
          : session.walletLabel.trim(),
      publicAddress: session.publicAddress,
      chainId: BridgeConstants.solanaChainId,
      chainType: BridgeChainType.svm,
      approvedMethods: const <String>{'solana_signTransaction'},
      approvedFeatures: const <String>{'boundedSignOnlyFallback'},
    );
    _identity = identity;
    return identity;
  }

  @override
  Future<void> disconnect() async {
    _identity = null;
    await _guardFallback<void>(_client.disconnect);
  }

  @override
  Future<String> sendEvmTransaction(
    EvmBridgeExecutionPayload payload,
  ) =>
      Future<String>.error(
        const ExternalWalletException('wallet_transport_chain_mismatch'),
      );

  @override
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  ) async {
    final identity = _identity;
    if (identity == null) {
      throw const ExternalWalletException('wallet_not_connected');
    }
    if (payload.from != identity.publicAddress) {
      throw const ExternalWalletException('wallet_account_mismatch');
    }
    _validateCanonicalBase64(payload.base64Transaction);
    final raw = await _guardFallback<Object?>(() => _client.signTransaction(
          transport: _transport,
          base64Transaction: payload.base64Transaction,
        ));
    if (raw is! Map || raw.length != 1 || raw['transaction'] is! String) {
      throw const ExternalWalletException('wallet_response_invalid');
    }
    final signed = _decodeBase58(raw['transaction'] as String);
    if (signed.isEmpty || signed.length > 1232) {
      throw const ExternalWalletException('wallet_response_invalid');
    }
    return SignedSolanaTransaction(signed);
  }
}

final class ReownAppKitSolanaClient implements ReownSolanaClient {
  ReownAppKitSolanaClient({
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
    if (!_modal.status.isInitialized) await _modal.init();
    await _linkDispatcher.start(_modal.dispatchEnvelope);
    _initialized = true;
  }

  @override
  Future<ReownSolanaPublicSession> connect(
    ExternalWalletTransport transport,
  ) async {
    _requireBoundedTransport(transport);
    final current = _modal.session;
    if (_modal.isConnected &&
        current != null &&
        _sessionTransport(current) == transport) {
      return _snapshot(current, transport);
    }
    if (_modal.isConnected) await _modal.disconnect();

    final network = ReownAppKitModalNetworks.getNetworkInfo(
      NetworkUtils.solana,
      ReownSolanaFallbackAdapter.mainnetChainId,
    );
    if (network == null || network.isTestNetwork) {
      throw const ReownClientException('wallet_chain_unsupported');
    }
    await _modal.selectChain(network);
    _modal.selectWallet(ReownAppKitModalWalletInfo(
      listing: transport == ExternalWalletTransport.reownSolanaPhantom
          ? PhantomUtils.defaultListingData
          : SolflareUtils.defaultListingData,
      installed: true,
    ));

    final completer = Completer<ReownSolanaPublicSession>();
    void onConnect(ModalConnect? event) {
      if (completer.isCompleted || event == null) return;
      if (_sessionTransport(event.session) != transport) {
        completer.completeError(
          const ReownClientException('wallet_transport_mismatch'),
        );
        return;
      }
      completer.complete(_snapshot(event.session, transport));
    }

    void onError(ModalError? event) {
      if (completer.isCompleted || event == null) return;
      final text = '${event.message} ${event.description ?? ''}'.toLowerCase();
      completer.completeError(ReownClientException(
        text.contains('reject') ||
                text.contains('declin') ||
                text.contains('cancel')
            ? 'wallet_user_rejected'
            : event is WalletNotInstalled
                ? 'wallet_transport_unavailable'
                : 'wallet_connect_failed',
      ));
    }

    _modal.onModalConnect.subscribe(onConnect);
    _modal.onModalError.subscribe(onError);
    unawaited(_modal.connectSelectedWallet().catchError((Object _) {
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
  Future<Object?> signTransaction({
    required ExternalWalletTransport transport,
    required String base64Transaction,
  }) {
    _requireBoundedTransport(transport);
    final session = _modal.session;
    if (session == null || _sessionTransport(session) != transport) {
      throw const ReownClientException('wallet_not_connected');
    }
    return _modal.request(
      topic: session.topic,
      chainId: ReownSolanaFallbackAdapter.mainnetChainId,
      request: SessionRequestParams(
        method: 'solana_signTransaction',
        params: <String, String>{'transaction': base64Transaction},
      ),
    );
  }

  @override
  Future<void> disconnect() => _modal.disconnect();

  ReownSolanaPublicSession _snapshot(
    ReownAppKitModalSession session,
    ExternalWalletTransport transport,
  ) {
    final address = session.getAddress(NetworkUtils.solana) ?? '';
    final chains = session.getApprovedChains(namespace: NetworkUtils.solana) ??
        const <String>[];
    final methods =
        session.getApprovedMethods(namespace: NetworkUtils.solana) ??
            const <String>[];
    final accounts =
        session.getAccounts(namespace: NetworkUtils.solana) ?? const <String>[];
    return ReownSolanaPublicSession(
      transport: transport,
      walletLabel: session.connectedWalletName ?? _labelFor(transport),
      publicAddress: address,
      approvedChains: Set<String>.unmodifiable(chains),
      approvedAccounts: Set<String>.unmodifiable(accounts),
      approvedMethods: Set<String>.unmodifiable(methods),
    );
  }
}

Future<T> _guardFallback<T>(Future<T> Function() operation) async {
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

ExternalWalletTransport? _sessionTransport(ReownAppKitModalSession session) {
  if (session.sessionService.isPhantom) {
    return ExternalWalletTransport.reownSolanaPhantom;
  }
  if (session.sessionService.isSolflare) {
    return ExternalWalletTransport.reownSolanaSolflare;
  }
  return null;
}

void _requireBoundedTransport(ExternalWalletTransport transport) {
  if (transport != ExternalWalletTransport.reownSolanaPhantom &&
      transport != ExternalWalletTransport.reownSolanaSolflare) {
    throw const ReownClientException('wallet_transport_unavailable');
  }
}

String _labelFor(ExternalWalletTransport transport) =>
    transport == ExternalWalletTransport.reownSolanaPhantom
        ? 'Phantom compatibility fallback'
        : 'Solflare compatibility fallback';

void _validateCanonicalBase64(String encoded) {
  Uint8List bytes;
  try {
    bytes = base64Decode(encoded);
  } on FormatException {
    throw const ExternalWalletException('wallet_payload_invalid');
  }
  if (bytes.isEmpty || bytes.length > 1232 || base64Encode(bytes) != encoded) {
    throw const ExternalWalletException('wallet_payload_invalid');
  }
}

Uint8List _decodeBase58(String encoded) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  if (encoded.isEmpty ||
      !RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$').hasMatch(encoded)) {
    return Uint8List(0);
  }
  var value = BigInt.zero;
  for (final codeUnit in encoded.codeUnits) {
    final digit = alphabet.indexOf(String.fromCharCode(codeUnit));
    if (digit < 0) return Uint8List(0);
    value = value * BigInt.from(58) + BigInt.from(digit);
  }
  final body = <int>[];
  while (value > BigInt.zero) {
    body.add((value & BigInt.from(255)).toInt());
    value >>= 8;
  }
  final leadingZeros =
      encoded.length - encoded.replaceFirst(RegExp(r'^1+'), '').length;
  return Uint8List.fromList(<int>[
    ...List<int>.filled(leadingZeros, 0),
    ...body.reversed,
  ]);
}
