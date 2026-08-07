import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/external_wallet_session_service.dart';
import 'package:clawa/services/bridge/external_wallet_transport_router.dart';
import 'package:clawa/services/bridge/reown_evm_wallet_adapter.dart';
import 'package:clawa/services/bridge/reown_solana_fallback_adapter.dart';
import 'package:clawa/services/bridge/solana_mwa_wallet_adapter.dart';

void main() {
  const ethereum = BridgeChain(
    id: BridgeConstants.ethereumChainId,
    key: 'eth',
    name: 'Ethereum',
    type: BridgeChainType.evm,
    nativeTokenSymbol: 'ETH',
  );
  const base = BridgeChain(
    id: BridgeConstants.baseChainId,
    key: 'bas',
    name: 'Base',
    type: BridgeChainType.evm,
    nativeTokenSymbol: 'ETH',
  );
  const solana = BridgeChain(
    id: BridgeConstants.solanaChainId,
    key: 'sol',
    name: 'Solana',
    type: BridgeChainType.svm,
    nativeTokenSymbol: 'SOL',
  );

  group('ExternalWalletTransportRouter', () {
    test('reports disabled features and Base Account honestly', () async {
      final router = ExternalWalletTransportRouter(
        adapters: const <ExternalWalletAdapter>[],
        reownEvmEnabled: false,
        solanaMwaEnabled: false,
        reownSolanaFallbackEnabled: false,
        baseAccountMwpEnabled: false,
      );

      final evm = await router.discover(base);
      final svm = await router.discover(solana);

      expect(
        evm,
        contains(
          isA<ExternalWalletOption>()
              .having((item) => item.transport, 'transport',
                  ExternalWalletTransport.reownEvm)
              .having((item) => item.available, 'available', isFalse),
        ),
      );
      expect(
        evm,
        contains(
          isA<ExternalWalletOption>()
              .having((item) => item.transport, 'transport',
                  ExternalWalletTransport.baseAccountMwp)
              .having((item) => item.available, 'available', isFalse)
              .having((item) => item.reason, 'reason', contains('not enabled')),
        ),
      );
      expect(
        svm.single.reason,
        contains('Mobile Wallet Adapter is disabled'),
      );
      expect(
        () => router.connect(
          base,
          transport: ExternalWalletTransport.baseAccountMwp,
        ),
        throwsA(_walletError('wallet_transport_unavailable')),
      );
    });

    test('routes any EVM wallet by protocol, never by display label', () async {
      final adapter = _FakeAdapter(
        transport: ExternalWalletTransport.reownEvm,
        optionLabel: 'Uniswap Wallet',
        identity: _evmIdentity(label: 'Unexpected Wallet Name'),
      );
      final router = ExternalWalletTransportRouter(
        adapters: <ExternalWalletAdapter>[adapter],
        reownEvmEnabled: true,
      );

      final identity = await router.connect(ethereum);

      expect(identity.walletLabel, 'Unexpected Wallet Name');
      expect(adapter.connectCount, 1);
      expect(adapter.lastChain, ethereum);
    });

    test('rejects a connected identity on the wrong chain', () async {
      final adapter = _FakeAdapter(
        transport: ExternalWalletTransport.reownEvm,
        identity: _evmIdentity(chainId: BridgeConstants.baseChainId),
      );
      final router = ExternalWalletTransportRouter(
        adapters: <ExternalWalletAdapter>[adapter],
        reownEvmEnabled: true,
      );

      expect(
        () => router.connect(ethereum),
        throwsA(_walletError('wallet_chain_mismatch')),
      );
    });

    test('selects native MWA first when it is available', () async {
      final mwa = _FakeAdapter(
        transport: ExternalWalletTransport.solanaMwa,
        identity: _solanaIdentity(ExternalWalletTransport.solanaMwa),
      );
      final phantom = _FakeAdapter(
        transport: ExternalWalletTransport.reownSolanaPhantom,
        identity: _solanaIdentity(ExternalWalletTransport.reownSolanaPhantom),
      );
      final router = ExternalWalletTransportRouter(
        adapters: <ExternalWalletAdapter>[mwa, phantom],
        solanaMwaEnabled: true,
        reownSolanaFallbackEnabled: true,
      );

      final options = await router.discover(solana);
      final identity = await router.connect(solana);

      expect(options.map((item) => item.transport),
          <ExternalWalletTransport>[ExternalWalletTransport.solanaMwa]);
      expect(identity.transport, ExternalWalletTransport.solanaMwa);
      expect(mwa.connectCount, 1);
      expect(phantom.discoverCount, 0);
    });

    test('requires discovery and explicit selection for a Solana fallback',
        () async {
      final mwa = _FakeAdapter(
        transport: ExternalWalletTransport.solanaMwa,
        available: false,
        unavailableReason: 'No MWA-compatible wallet responded.',
        identity: _solanaIdentity(ExternalWalletTransport.solanaMwa),
      );
      final phantom = _FakeAdapter(
        transport: ExternalWalletTransport.reownSolanaPhantom,
        identity: _solanaIdentity(ExternalWalletTransport.reownSolanaPhantom),
      );
      final router = ExternalWalletTransportRouter(
        adapters: <ExternalWalletAdapter>[mwa, phantom],
        solanaMwaEnabled: true,
        reownSolanaFallbackEnabled: true,
      );

      expect(
        () => router.connect(
          solana,
          transport: ExternalWalletTransport.reownSolanaPhantom,
        ),
        throwsA(_walletError('wallet_fallback_requires_discovery')),
      );

      final options = await router.discover(solana);
      expect(options.map((item) => item.transport), <ExternalWalletTransport>[
        ExternalWalletTransport.solanaMwa,
        ExternalWalletTransport.reownSolanaPhantom,
      ]);
      expect(
        () => router.connect(solana),
        throwsA(_walletError('wallet_fallback_requires_selection')),
      );

      final identity = await router.connect(
        solana,
        transport: ExternalWalletTransport.reownSolanaPhantom,
      );
      expect(identity.transport, ExternalWalletTransport.reownSolanaPhantom);
      expect(phantom.connectCount, 1);
    });

    test('exposes explicit fallbacks after the MWA chooser finds no wallet',
        () async {
      final mwa = _FakeAdapter(
        transport: ExternalWalletTransport.solanaMwa,
        identity: _solanaIdentity(ExternalWalletTransport.solanaMwa),
        connectError:
            const ExternalWalletException('wallet_transport_unavailable'),
      );
      final phantom = _FakeAdapter(
        transport: ExternalWalletTransport.reownSolanaPhantom,
        identity: _solanaIdentity(ExternalWalletTransport.reownSolanaPhantom),
      );
      final router = ExternalWalletTransportRouter(
        adapters: <ExternalWalletAdapter>[mwa, phantom],
        solanaMwaEnabled: true,
        reownSolanaFallbackEnabled: true,
      );

      expect((await router.discover(solana)).single.available, isTrue);
      await expectLater(
        router.connect(solana),
        throwsA(_walletError('wallet_transport_unavailable')),
      );

      final afterFailure = await router.discover(solana);
      expect(afterFailure.first.available, isFalse);
      expect(
          afterFailure.map((item) => item.transport), <ExternalWalletTransport>[
        ExternalWalletTransport.solanaMwa,
        ExternalWalletTransport.reownSolanaPhantom,
      ]);
    });

    test('rejects fallback identities without sign-only approval', () async {
      final mwa = _FakeAdapter(
        transport: ExternalWalletTransport.solanaMwa,
        available: false,
        identity: _solanaIdentity(ExternalWalletTransport.solanaMwa),
      );
      final solflare = _FakeAdapter(
        transport: ExternalWalletTransport.reownSolanaSolflare,
        identity: ExternalWalletIdentity(
          transport: ExternalWalletTransport.reownSolanaSolflare,
          walletLabel: 'Solflare',
          publicAddress: '11111111111111111111111111111111',
          chainId: BridgeConstants.solanaChainId,
          chainType: BridgeChainType.svm,
          approvedMethods: const <String>{'solana_signAndSendTransaction'},
          approvedFeatures: const <String>{},
        ),
      );
      final router = ExternalWalletTransportRouter(
        adapters: <ExternalWalletAdapter>[mwa, solflare],
        solanaMwaEnabled: true,
        reownSolanaFallbackEnabled: true,
      );
      await router.discover(solana);

      expect(
        () => router.connect(
          solana,
          transport: ExternalWalletTransport.reownSolanaSolflare,
        ),
        throwsA(_walletError('wallet_method_not_approved')),
      );
    });

    test('delegates only to the adapter selected during connect', () async {
      final adapter = _FakeAdapter(
        transport: ExternalWalletTransport.reownEvm,
        identity: _evmIdentity(),
        evmHash: '0xsubmitted',
      );
      final router = ExternalWalletTransportRouter(
        adapters: <ExternalWalletAdapter>[adapter],
        reownEvmEnabled: true,
      );
      await router.connect(ethereum);

      final hash = await router.sendEvmTransaction(
        const EvmBridgeExecutionPayload(
          chainId: BridgeConstants.ethereumChainId,
          from: '0x1111111111111111111111111111111111111111',
          to: '0x2222222222222222222222222222222222222222',
          valueHex: '0x0',
          dataHex: '0x',
          gasLimitHex: '0x5208',
          approvalAddress: null,
        ),
      );

      expect(hash, '0xsubmitted');
      expect(adapter.evmSendCount, 1);
    });
  });

  group('production adapter contracts', () {
    test('native MWA maps public capabilities and preserves signed bytes',
        () async {
      final platform = _FakeMwaPlatform(
        authorization: <String, Object>{
          'walletLabel': 'MWA wallet',
          'address': '11111111111111111111111111111111',
          'chainId': BridgeConstants.solanaChainId,
          'chainType': 'svm',
          'features': <String>['solana:signTransactions'],
          'methods': <String>['signTransactions', 'signAndSendTransactions'],
        },
        submission: <String, Object>{
          'mode': 'signOnly',
          'signedTransactionBytes': Uint8List.fromList(<int>[1, 2, 3]),
        },
      );
      final adapter = SolanaMwaWalletAdapter(
        platform: platform,
        supportedPlatform: true,
      );

      final option = await adapter.discover(solana);
      final identity = await adapter.connect(solana);
      final result = await adapter.submitSolanaTransaction(
        const SolanaBridgeExecutionPayload(
          from: '11111111111111111111111111111111',
          base64Transaction: 'AQ==',
        ),
      );

      expect(option.available, isTrue);
      expect(identity.approvedMethods, contains('solana_signTransaction'));
      expect(result, isA<SignedSolanaTransaction>());
      expect(
        (result as SignedSolanaTransaction).signedTransaction,
        <int>[1, 2, 3],
      );
      expect(platform.lastTransaction, 'AQ==');
    });

    test('native MWA rejects malformed tagged responses', () async {
      final adapter = SolanaMwaWalletAdapter(
        platform: _FakeMwaPlatform(
          authorization: <String, Object>{
            'walletLabel': 'MWA wallet',
            'address': '11111111111111111111111111111111',
            'chainId': BridgeConstants.solanaChainId,
            'chainType': 'svm',
            'features': <String>[],
            'methods': <String>['signAndSendTransactions'],
          },
          submission: <String, Object>{
            'mode': 'signOnly',
            'signatureBase58': 'not-signed-bytes',
          },
        ),
        supportedPlatform: true,
      );
      await adapter.connect(solana);

      expect(
        () => adapter.submitSolanaTransaction(
          const SolanaBridgeExecutionPayload(
            from: '11111111111111111111111111111111',
            base64Transaction: 'AQ==',
          ),
        ),
        throwsA(_walletError('wallet_response_invalid')),
      );
    });

    test('Reown EVM adapter sends one exact protocol request', () async {
      final client = _FakeReownEvmClient(
        session: const ReownPublicSession(
          walletLabel: 'Trust Wallet',
          publicAddress: '0x1111111111111111111111111111111111111111',
          approvedChains: <String>{'eip155:1'},
          approvedAccounts: <String>{
            'eip155:1:0x1111111111111111111111111111111111111111',
          },
          approvedMethods: <String>{'eth_sendTransaction'},
        ),
      );
      final adapter = ReownEvmWalletAdapter(
        client: client,
        releaseConfigured: true,
      );
      await adapter.connect(ethereum);

      final hash = await adapter.sendEvmTransaction(
        const EvmBridgeExecutionPayload(
          chainId: BridgeConstants.ethereumChainId,
          from: '0x1111111111111111111111111111111111111111',
          to: '0x2222222222222222222222222222222222222222',
          valueHex: '0x1',
          dataHex: '0xabcdef',
          gasLimitHex: '0x5208',
          approvalAddress: null,
        ),
      );

      expect(hash, '0x${List<String>.filled(32, '12').join()}');
      expect(client.requestCount, 1);
      expect(client.lastChainId, 'eip155:1');
      expect(client.lastTransaction, <String, String>{
        'from': '0x1111111111111111111111111111111111111111',
        'to': '0x2222222222222222222222222222222222222222',
        'value': '0x1',
        'data': '0xabcdef',
        'gas': '0x5208',
      });
    });

    test('Reown EVM requires account approval on the exact chain', () async {
      final adapter = ReownEvmWalletAdapter(
        client: _FakeReownEvmClient(
          session: const ReownPublicSession(
            walletLabel: 'Wallet',
            publicAddress: '0x1111111111111111111111111111111111111111',
            approvedChains: <String>{'eip155:1'},
            approvedAccounts: <String>{
              'eip155:1:0x2222222222222222222222222222222222222222',
            },
            approvedMethods: <String>{'eth_sendTransaction'},
          ),
        ),
        releaseConfigured: true,
      );

      expect(
        () => adapter.connect(ethereum),
        throwsA(_walletError('wallet_account_mismatch')),
      );
    });

    test('bounded Reown fallback decodes the signed transaction exactly once',
        () async {
      final client = _FakeReownSolanaClient(
        session: const ReownSolanaPublicSession(
          transport: ExternalWalletTransport.reownSolanaPhantom,
          walletLabel: 'Phantom',
          publicAddress: '11111111111111111111111111111111',
          approvedChains: <String>{ReownSolanaFallbackAdapter.mainnetChainId},
          approvedAccounts: <String>{
            '${ReownSolanaFallbackAdapter.mainnetChainId}:'
                '11111111111111111111111111111111',
          },
          approvedMethods: <String>{'solana_signTransaction'},
        ),
        response: <String, Object>{'transaction': 'Ldp'},
      );
      final adapter = ReownSolanaFallbackAdapter(
        transport: ExternalWalletTransport.reownSolanaPhantom,
        client: client,
        releaseConfigured: true,
      );
      await adapter.connect(solana);

      final result = await adapter.submitSolanaTransaction(
        const SolanaBridgeExecutionPayload(
          from: '11111111111111111111111111111111',
          base64Transaction: 'AQID',
        ),
      );

      expect(result, isA<SignedSolanaTransaction>());
      expect(
        (result as SignedSolanaTransaction).signedTransaction,
        <int>[1, 2, 3],
      );
      expect(client.lastBase64Transaction, 'AQID');
      expect(client.requestCount, 1);
    });

    test('bounded Reown fallback rejects a non-transaction response', () async {
      final adapter = ReownSolanaFallbackAdapter(
        transport: ExternalWalletTransport.reownSolanaSolflare,
        client: _FakeReownSolanaClient(
          session: const ReownSolanaPublicSession(
            transport: ExternalWalletTransport.reownSolanaSolflare,
            walletLabel: 'Solflare',
            publicAddress: '11111111111111111111111111111111',
            approvedChains: <String>{
              ReownSolanaFallbackAdapter.mainnetChainId,
            },
            approvedAccounts: <String>{
              '${ReownSolanaFallbackAdapter.mainnetChainId}:'
                  '11111111111111111111111111111111',
            },
            approvedMethods: <String>{'solana_signTransaction'},
          ),
          response: <String, Object>{'signature': 'Ldp'},
        ),
        releaseConfigured: true,
      );
      await adapter.connect(solana);

      expect(
        () => adapter.submitSolanaTransaction(
          const SolanaBridgeExecutionPayload(
            from: '11111111111111111111111111111111',
            base64Transaction: 'AQID',
          ),
        ),
        throwsA(_walletError('wallet_response_invalid')),
      );
    });
  });
}

ExternalWalletIdentity _evmIdentity({
  String label = 'Wallet',
  int chainId = BridgeConstants.ethereumChainId,
}) =>
    ExternalWalletIdentity(
      transport: ExternalWalletTransport.reownEvm,
      walletLabel: label,
      publicAddress: '0x1111111111111111111111111111111111111111',
      chainId: chainId,
      chainType: BridgeChainType.evm,
      approvedMethods: const <String>{'eth_sendTransaction'},
      approvedFeatures: const <String>{},
    );

ExternalWalletIdentity _solanaIdentity(ExternalWalletTransport transport) =>
    ExternalWalletIdentity(
      transport: transport,
      walletLabel: 'Solana wallet',
      publicAddress: '11111111111111111111111111111111',
      chainId: BridgeConstants.solanaChainId,
      chainType: BridgeChainType.svm,
      approvedMethods: const <String>{'solana_signTransaction'},
      approvedFeatures: const <String>{'signTransactions'},
    );

Matcher _walletError(String code) =>
    isA<ExternalWalletException>().having((error) => error.code, 'code', code);

final class _FakeAdapter implements ExternalWalletAdapter {
  _FakeAdapter({
    required this.transport,
    required this.identity,
    this.optionLabel = 'Wallet',
    this.available = true,
    this.unavailableReason,
    this.evmHash = '0xhash',
    this.connectError,
  });

  @override
  final ExternalWalletTransport transport;
  final ExternalWalletIdentity identity;
  final String optionLabel;
  final bool available;
  final String? unavailableReason;
  final String evmHash;
  final ExternalWalletException? connectError;
  int discoverCount = 0;
  int connectCount = 0;
  int evmSendCount = 0;
  BridgeChain? lastChain;

  @override
  Future<ExternalWalletOption> discover(BridgeChain chain) async {
    discoverCount += 1;
    return ExternalWalletOption(
      transport: transport,
      label: optionLabel,
      available: available,
      reason: unavailableReason,
    );
  }

  @override
  Future<ExternalWalletIdentity> connect(BridgeChain chain) async {
    connectCount += 1;
    lastChain = chain;
    if (connectError case final error?) throw error;
    return identity;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> sendEvmTransaction(EvmBridgeExecutionPayload payload) async {
    evmSendCount += 1;
    return evmHash;
  }

  @override
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  ) async =>
      SignedSolanaTransaction(Uint8List.fromList(<int>[1, 2, 3]));
}

final class _FakeMwaPlatform implements SolanaMwaPlatform {
  _FakeMwaPlatform({
    required this.authorization,
    required this.submission,
  });

  final Object? authorization;
  final Object? submission;
  String? lastTransaction;

  @override
  Future<Object?> authorize() async => authorization;

  @override
  Future<void> deauthorize() async {}

  @override
  Future<Object?> submitTransaction(String base64Transaction) async {
    lastTransaction = base64Transaction;
    return submission;
  }
}

final class _FakeReownEvmClient implements ReownEvmClient {
  _FakeReownEvmClient({required this.session});

  final ReownPublicSession session;
  int requestCount = 0;
  String? lastChainId;
  Map<String, String>? lastTransaction;

  @override
  Future<ReownPublicSession> connect(int chainId) async => session;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<Object?> sendTransaction({
    required String chainId,
    required Map<String, String> transaction,
  }) async {
    requestCount += 1;
    lastChainId = chainId;
    lastTransaction = transaction;
    return '0x${List<String>.filled(32, '12').join()}';
  }
}

final class _FakeReownSolanaClient implements ReownSolanaClient {
  _FakeReownSolanaClient({
    required this.session,
    required this.response,
  });

  final ReownSolanaPublicSession session;
  final Object? response;
  int requestCount = 0;
  String? lastBase64Transaction;

  @override
  Future<ReownSolanaPublicSession> connect(
    ExternalWalletTransport transport,
  ) async =>
      session;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<Object?> signTransaction({
    required ExternalWalletTransport transport,
    required String base64Transaction,
  }) async {
    requestCount += 1;
    lastBase64Transaction = base64Transaction;
    return response;
  }
}
