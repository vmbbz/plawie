import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/external_wallet_session_service.dart';

void main() {
  const ethereum = BridgeChain(
    id: BridgeConstants.ethereumChainId,
    key: 'eth',
    name: 'Ethereum',
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
  const evmAddress = '0x1111111111111111111111111111111111111111';

  group('RoutedExternalWalletSessionService', () {
    test('keeps exported identity free of SDK session and operation material',
        () async {
      final transport = _FakeSessionTransport(
        identity: const ExternalWalletIdentity(
          transport: ExternalWalletTransport.reownEvm,
          walletLabel: 'Any compatible wallet',
          publicAddress: evmAddress,
          chainId: BridgeConstants.ethereumChainId,
          chainType: BridgeChainType.evm,
          approvedMethods: <String>{'eth_sendTransaction'},
          approvedFeatures: <String>{},
        ),
      );
      final service = RoutedExternalWalletSessionService(transport: transport);

      final identity = await service.connect(ethereum);
      final encoded = identity.toSafeJson().toString().toLowerCase();

      expect(encoded, contains('any compatible wallet'));
      expect(encoded, isNot(contains('topic')));
      expect(encoded, isNot(contains('session')));
      expect(encoded, isNot(contains('authorization')));
      expect(encoded, isNot(contains('callback')));
      expect(encoded, isNot(contains('operation')));
      expect(encoded, isNot(contains('secret')));
    });

    test('rejects an EVM payload for a different account or chain', () async {
      final transport = _FakeSessionTransport(
        identity: const ExternalWalletIdentity(
          transport: ExternalWalletTransport.reownEvm,
          walletLabel: 'Wallet',
          publicAddress: evmAddress,
          chainId: BridgeConstants.ethereumChainId,
          chainType: BridgeChainType.evm,
          approvedMethods: <String>{'eth_sendTransaction'},
          approvedFeatures: <String>{},
        ),
      );
      final service = RoutedExternalWalletSessionService(transport: transport);
      await service.connect(ethereum);

      expect(
        () => service.sendEvmTransaction(
          _evmPayload(
            from: '0x2222222222222222222222222222222222222222',
          ),
        ),
        throwsA(_walletError('wallet_account_mismatch')),
      );
      expect(
        () => service.sendEvmTransaction(
          _evmPayload(chainId: BridgeConstants.baseChainId),
        ),
        throwsA(_walletError('wallet_chain_mismatch')),
      );
      expect(transport.evmSendCount, 0);
    });

    test('requires the approved method before submitting', () async {
      final transport = _FakeSessionTransport(
        identity: const ExternalWalletIdentity(
          transport: ExternalWalletTransport.reownEvm,
          walletLabel: 'Wallet',
          publicAddress: evmAddress,
          chainId: BridgeConstants.ethereumChainId,
          chainType: BridgeChainType.evm,
          approvedMethods: <String>{},
          approvedFeatures: <String>{},
        ),
      );
      final service = RoutedExternalWalletSessionService(transport: transport);
      await service.connect(ethereum);

      expect(
        () => service.sendEvmTransaction(_evmPayload()),
        throwsA(_walletError('wallet_method_not_approved')),
      );
      expect(transport.evmSendCount, 0);
    });

    test('allows only one pending request and consumes its result once',
        () async {
      final completion = Completer<String>();
      final transport = _FakeSessionTransport(
        identity: const ExternalWalletIdentity(
          transport: ExternalWalletTransport.reownEvm,
          walletLabel: 'Wallet',
          publicAddress: evmAddress,
          chainId: BridgeConstants.ethereumChainId,
          chainType: BridgeChainType.evm,
          approvedMethods: <String>{'eth_sendTransaction'},
          approvedFeatures: <String>{},
        ),
        evmCompletion: completion,
      );
      final service = RoutedExternalWalletSessionService(
        transport: transport,
        operationIdFactory: () => '00112233445566778899aabbccddeeff',
      );
      await service.connect(ethereum);

      final first = service.sendEvmTransaction(_evmPayload());
      await Future<void>.delayed(Duration.zero);
      expect(
        () => service.sendEvmTransaction(_evmPayload()),
        throwsA(_walletError('wallet_operation_in_progress')),
      );

      completion.complete('0xabc');
      expect(await first, '0xabc');
      expect(transport.evmSendCount, 1);

      transport.evmCompletion = Completer<String>()..complete('0xdef');
      expect(await service.sendEvmTransaction(_evmPayload()), '0xdef');
      expect(transport.evmSendCount, 2);
    });

    test('rejects a callback that arrives after operation expiry', () async {
      var now = DateTime.utc(2026, 8, 7, 12);
      final completion = Completer<String>();
      final transport = _FakeSessionTransport(
        identity: const ExternalWalletIdentity(
          transport: ExternalWalletTransport.reownEvm,
          walletLabel: 'Wallet',
          publicAddress: evmAddress,
          chainId: BridgeConstants.ethereumChainId,
          chainType: BridgeChainType.evm,
          approvedMethods: <String>{'eth_sendTransaction'},
          approvedFeatures: <String>{},
        ),
        evmCompletion: completion,
      );
      final service = RoutedExternalWalletSessionService(
        transport: transport,
        clock: () => now,
      );
      await service.connect(ethereum);

      final pending = service.sendEvmTransaction(_evmPayload());
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(minutes: 11));
      completion.complete('0xlate');

      expect(pending, throwsA(_walletError('wallet_operation_expired')));
    });

    test('disconnect invalidates an in-flight callback', () async {
      final completion = Completer<String>();
      final transport = _FakeSessionTransport(
        identity: const ExternalWalletIdentity(
          transport: ExternalWalletTransport.reownEvm,
          walletLabel: 'Wallet',
          publicAddress: evmAddress,
          chainId: BridgeConstants.ethereumChainId,
          chainType: BridgeChainType.evm,
          approvedMethods: <String>{'eth_sendTransaction'},
          approvedFeatures: <String>{},
        ),
        evmCompletion: completion,
      );
      final service = RoutedExternalWalletSessionService(transport: transport);
      await service.connect(ethereum);

      final pending = service.sendEvmTransaction(_evmPayload());
      await Future<void>.delayed(Duration.zero);
      await service.disconnect();
      completion.complete('0xstale');

      expect(pending, throwsA(_walletError('wallet_operation_invalidated')));
      expect(service.identity, isNull);
      expect(transport.disconnectCount, 1);
    });

    test('preserves an explicit user rejection', () async {
      final transport = _FakeSessionTransport(
        identity: const ExternalWalletIdentity(
          transport: ExternalWalletTransport.solanaMwa,
          walletLabel: 'Solana wallet',
          publicAddress: '11111111111111111111111111111111',
          chainId: BridgeConstants.solanaChainId,
          chainType: BridgeChainType.svm,
          approvedMethods: <String>{'solana_signTransaction'},
          approvedFeatures: <String>{'signTransactions'},
        ),
        solanaError: const ExternalWalletException('wallet_user_rejected'),
      );
      final service = RoutedExternalWalletSessionService(transport: transport);
      await service.connect(solana);

      expect(
        () => service.submitSolanaTransaction(
          const SolanaBridgeExecutionPayload(
            from: '11111111111111111111111111111111',
            base64Transaction: 'AQ==',
          ),
        ),
        throwsA(_walletError('wallet_user_rejected')),
      );
    });
  });
}

EvmBridgeExecutionPayload _evmPayload({
  int chainId = BridgeConstants.ethereumChainId,
  String from = '0x1111111111111111111111111111111111111111',
}) =>
    EvmBridgeExecutionPayload(
      chainId: chainId,
      from: from,
      to: '0x3333333333333333333333333333333333333333',
      valueHex: '0x0',
      dataHex: '0x',
      gasLimitHex: '0x5208',
      approvalAddress: null,
    );

Matcher _walletError(String code) =>
    isA<ExternalWalletException>().having((error) => error.code, 'code', code);

final class _FakeSessionTransport implements ExternalWalletSessionTransport {
  _FakeSessionTransport({
    required this.identity,
    this.evmCompletion,
    this.solanaError,
  });

  final ExternalWalletIdentity identity;
  Completer<String>? evmCompletion;
  final ExternalWalletException? solanaError;
  int evmSendCount = 0;
  int disconnectCount = 0;

  @override
  Future<List<ExternalWalletOption>> discover(BridgeChain chain) async =>
      <ExternalWalletOption>[
        ExternalWalletOption(
          transport: identity.transport,
          label: identity.walletLabel,
          available: true,
        ),
      ];

  @override
  Future<ExternalWalletIdentity> connect(
    BridgeChain chain, {
    ExternalWalletTransport? transport,
  }) async =>
      identity;

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
  }

  @override
  Future<String> sendEvmTransaction(EvmBridgeExecutionPayload payload) {
    evmSendCount += 1;
    return evmCompletion?.future ?? Future<String>.value('0xhash');
  }

  @override
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  ) async {
    if (solanaError case final error?) throw error;
    return SignedSolanaTransaction(Uint8List.fromList(<int>[1]));
  }
}
