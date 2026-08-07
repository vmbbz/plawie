import 'dart:convert';

import 'package:clawa/services/bridge/bridge_funding_strategy.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fullSourceAddress = '0x1111111111111111111111111111111111111111';
  const destinationAddress = '0x2222222222222222222222222222222222222222';
  const tokenAddress = '0x3333333333333333333333333333333333333333';
  const refundAddress = '0x4444444444444444444444444444444444444444';
  const depositAddress = '0x5555555555555555555555555555555555555555';
  const reviewedPayloadHash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final createdAt = DateTime.utc(2026, 8, 7, 10);
  final updatedAt = DateTime.utc(2026, 8, 7, 10, 1);
  final expiresAt = DateTime.utc(2026, 8, 7, 10, 10);

  BridgeFundingReceipt connectedReceipt({
    ExternalWalletTransport? walletTransport = ExternalWalletTransport.reownEvm,
  }) {
    return BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: 'connected-intent',
      method: BridgeFundingMethod.connectedWallet,
      provider: 'lifi',
      state: BridgeFundingState.awaitingExternalWallet,
      sourceChainId: BridgeConstants.ethereumChainId,
      sourceTokenAddress: tokenAddress,
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1000000',
      baseDestinationAddress: destinationAddress,
      sourceAddress: fullSourceAddress,
      providerQuoteId: 'quote-1',
      routeTool: 'Across',
      minimumOutputUnits: '990000',
      walletTransport: walletTransport,
      reviewedPayloadHash: reviewedPayloadHash,
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
    );
  }

  BridgeFundingReceipt relayReceipt() {
    return BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: 'relay-intent',
      method: BridgeFundingMethod.relayDeposit,
      provider: 'relay',
      state: BridgeFundingState.awaitingDeposit,
      sourceChainId: BridgeConstants.ethereumChainId,
      sourceTokenAddress: tokenAddress,
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1000000',
      baseDestinationAddress: destinationAddress,
      refundAddress: refundAddress,
      depositAddress: depositAddress,
      providerRequestId: 'request-1',
      minimumOutputUnits: '995000',
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      depositAddressExposed: true,
    );
  }

  test('connected receipt persists recovery data and redacts agent data', () {
    final receipt = connectedReceipt();
    final localJson = receipt.toJson();
    final agentJson = receipt.toAgentJson();

    expect(localJson['sourceAddress'], fullSourceAddress);
    expect(agentJson['sourceAddress'], '0x1111…1111');
    expect(jsonEncode(agentJson), isNot(contains(fullSourceAddress)));
    expect(jsonEncode(localJson), isNot(contains('transactionRequest')));
    expect(jsonEncode(localJson), isNot(contains('signedTransaction')));
    expect(BridgeFundingReceipt.fromJson(localJson), receipt);
    expect(localJson['walletTransport'], 'reownEvm');
    expect(localJson['reviewedPayloadHash'], reviewedPayloadHash);
    expect(agentJson, isNot(contains('walletTransport')));
    expect(agentJson, isNot(contains('reviewedPayloadHash')));
    expect(agentJson, isNot(contains('sourceBlockhash')));
  });

  test('Relay receipt redacts every persisted address for agents', () {
    final receipt = relayReceipt();
    final localJson = receipt.toJson();
    final agentJson = receipt.toAgentJson();
    final encodedAgentJson = jsonEncode(agentJson);

    expect(localJson['refundAddress'], refundAddress);
    expect(localJson['depositAddress'], depositAddress);
    expect(agentJson['sourceTokenAddress'], '0x3333…3333');
    expect(agentJson['baseDestinationAddress'], '0x2222…2222');
    expect(agentJson['refundAddress'], '0x4444…4444');
    expect(agentJson['depositAddress'], '0x5555…5555');
    expect(encodedAgentJson, isNot(contains(tokenAddress)));
    expect(encodedAgentJson, isNot(contains(destinationAddress)));
    expect(encodedAgentJson, isNot(contains(refundAddress)));
    expect(encodedAgentJson, isNot(contains(depositAddress)));
    expect(BridgeFundingReceipt.fromJson(localJson), receipt);
  });

  test('all bridge release and wallet transport gates default to false', () {
    expect(BridgeFeatureConfig.lifiConnectedEnabled, isFalse);
    expect(BridgeFeatureConfig.relayDepositEnabled, isFalse);
    expect(BridgeFeatureConfig.reownEvmWalletsEnabled, isFalse);
    expect(BridgeFeatureConfig.solanaMwaWalletsEnabled, isFalse);
    expect(BridgeFeatureConfig.reownSolanaFallbackEnabled, isFalse);
    expect(BridgeFeatureConfig.baseAccountMwpEnabled, isFalse);

    final persisted = jsonEncode(connectedReceipt().toJson());
    expect(persisted, isNot(contains('ENABLE_LIFI_CONNECTED_BRIDGE')));
    expect(persisted, isNot(contains('ENABLE_RELAY_DEPOSIT_BRIDGE')));
    expect(persisted, isNot(contains('ENABLE_REOWN_EVM_WALLETS')));
    expect(persisted, isNot(contains('ENABLE_SOLANA_MWA_WALLETS')));
    expect(persisted, isNot(contains('ENABLE_REOWN_SOLANA_FALLBACK')));
    expect(persisted, isNot(contains('ENABLE_BASE_ACCOUNT_MWP')));
  });

  test('wallet transports have stable serialized names', () {
    const expectedNames = <ExternalWalletTransport, String>{
      ExternalWalletTransport.reownEvm: 'reownEvm',
      ExternalWalletTransport.solanaMwa: 'solanaMwa',
      ExternalWalletTransport.reownSolanaPhantom: 'reownSolanaPhantom',
      ExternalWalletTransport.reownSolanaSolflare: 'reownSolanaSolflare',
      ExternalWalletTransport.baseAccountMwp: 'baseAccountMwp',
    };

    for (final entry in expectedNames.entries) {
      final receipt = connectedReceipt(walletTransport: entry.key);
      expect(receipt.toJson()['walletTransport'], entry.value);
      expect(BridgeFundingReceipt.fromJson(receipt.toJson()), receipt);
    }
  });

  test('schema-v1 receipt decodes without inventing a wallet transport', () {
    final legacyJson = connectedReceipt().toJson()
      ..['schemaVersion'] = 1
      ..remove('walletTransport')
      ..remove('reviewedPayloadHash')
      ..remove('sourceBlockhash');

    final migrated = BridgeFundingReceipt.fromJson(legacyJson);

    expect(migrated.schemaVersion, 1);
    expect(migrated.walletTransport, isNull);
    expect(migrated.reviewedPayloadHash, isNull);
    expect(migrated.sourceBlockhash, isNull);
  });

  test('source blockhash is local-only reconciliation evidence', () {
    final receipt = BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: 'solana-intent',
      method: BridgeFundingMethod.connectedWallet,
      provider: 'lifi',
      state: BridgeFundingState.awaitingExternalWallet,
      sourceChainId: BridgeConstants.solanaChainId,
      sourceTokenAddress: 'So11111111111111111111111111111111111111112',
      sourceTokenSymbol: 'SOL',
      sourceAmountUnits: '1000000000',
      baseDestinationAddress: destinationAddress,
      sourceAddress: '11111111111111111111111111111111',
      walletTransport: ExternalWalletTransport.solanaMwa,
      reviewedPayloadHash: reviewedPayloadHash,
      sourceBlockhash: '8opHzTAnfzRpPEx21XtnrVTX28YQuCpAjcn1PczScKh',
      createdAt: createdAt,
      updatedAt: updatedAt,
      submissionOutcomeUnknown: true,
    );

    expect(receipt.toJson()['sourceBlockhash'], isNotEmpty);
    expect(receipt.toAgentJson(), isNot(contains('sourceBlockhash')));
    expect(receipt.toAgentJson(), isNot(contains('reviewedPayloadHash')));
    expect(BridgeFundingReceipt.fromJson(receipt.toJson()), receipt);
  });

  test('immutable bridge contracts use value equality', () {
    BridgeCapabilitySnapshot snapshot() {
      final chain = BridgeChain(
        id: BridgeConstants.ethereumChainId,
        key: 'eth',
        name: 'Ethereum',
        type: BridgeChainType.evm,
        nativeTokenSymbol: 'ETH',
      );
      final token = BridgeToken(
        chainId: BridgeConstants.ethereumChainId,
        address: tokenAddress,
        symbol: 'USDC',
        decimals: 6,
        solverDepositable: true,
      );
      return BridgeCapabilitySnapshot(
        schemaVersion: 1,
        refreshedAt: createdAt,
        connectedChains: <BridgeChain>[chain],
        relayChains: <BridgeChain>[chain],
        connectedTokensByChain: <int, List<BridgeToken>>{
          chain.id: <BridgeToken>[token],
        },
        relayTokensByChain: <int, List<BridgeToken>>{
          chain.id: <BridgeToken>[token],
        },
        availabilityReasons: const <String, String>{'eth': 'available'},
      );
    }

    BridgeExecutableQuote quote() {
      final chain = BridgeChain(
        id: BridgeConstants.ethereumChainId,
        key: 'eth',
        name: 'Ethereum',
        type: BridgeChainType.evm,
        nativeTokenSymbol: 'ETH',
      );
      final token = BridgeToken(
        chainId: BridgeConstants.ethereumChainId,
        address: tokenAddress,
        symbol: 'USDC',
        decimals: 6,
        solverDepositable: true,
      );
      final request = BridgeFundingRequest(
        method: BridgeFundingMethod.connectedWallet,
        sourceChain: chain,
        sourceToken: token,
        amount: '1',
        amountUnits: '1000000',
        baseDestinationAddress: destinationAddress,
        sourceAddress: fullSourceAddress,
        selfCustodyConfirmed: true,
      );
      final estimate = BridgeEstimate(
        provider: 'lifi',
        quoteId: 'quote-1',
        request: request,
        minimumOutputUnits: '990000',
        minimumOutputDisplay: '0.99',
        routeTool: 'Across',
        quotedAt: createdAt,
        expiresAt: expiresAt,
        estimatedDurationSeconds: 60,
        estimatedFeesUsd: 0.01,
      );
      return BridgeExecutableQuote(
        estimate: estimate,
        connectedSourceAddress: fullSourceAddress,
        destinationChainId: BridgeConstants.baseChainId,
        destinationToken: BridgeToken(
          chainId: BridgeConstants.baseChainId,
          address: BridgeConstants.baseUsdc,
          symbol: 'USDC',
          decimals: 6,
          solverDepositable: true,
        ),
        payload: EvmBridgeExecutionPayload(
          chainId: BridgeConstants.ethereumChainId,
          from: fullSourceAddress,
          to: depositAddress,
          valueHex: '0x0',
          dataHex: '0x1234',
          gasLimitHex: '0x5208',
          approvalAddress: null,
        ),
        fingerprint: reviewedPayloadHash,
      );
    }

    RelayDepositInstruction instruction() {
      final chain = BridgeChain(
        id: BridgeConstants.ethereumChainId,
        key: 'eth',
        name: 'Ethereum',
        type: BridgeChainType.evm,
        nativeTokenSymbol: 'ETH',
      );
      final token = BridgeToken(
        chainId: BridgeConstants.ethereumChainId,
        address: tokenAddress,
        symbol: 'USDC',
        decimals: 6,
        solverDepositable: true,
      );
      return RelayDepositInstruction(
        requestId: 'request-1',
        depositAddress: depositAddress,
        request: BridgeFundingRequest(
          method: BridgeFundingMethod.relayDeposit,
          sourceChain: chain,
          sourceToken: token,
          amount: '1',
          amountUnits: '1000000',
          baseDestinationAddress: destinationAddress,
          refundAddress: refundAddress,
          selfCustodyConfirmed: true,
        ),
        minimumOutputUnits: '990000',
        minimumOutputDisplay: '0.99',
        createdAt: createdAt,
        expiresAt: expiresAt,
      );
    }

    final firstObservation = BridgeFundingObservation(
      state: BridgeFundingState.destinationPending,
      providerStatus: 'pending',
      providerSubstatus: 'settling',
      sourceTransactionHash: '0xabc',
      destinationTransactionHash: null,
      actualOutputUnits: null,
      observedAt: updatedAt,
    );
    final secondObservation = BridgeFundingObservation(
      state: BridgeFundingState.destinationPending,
      providerStatus: 'pending',
      providerSubstatus: 'settling',
      sourceTransactionHash: '0xabc',
      destinationTransactionHash: null,
      actualOutputUnits: null,
      observedAt: updatedAt,
    );

    expect(snapshot(), snapshot());
    expect(snapshot().hashCode, snapshot().hashCode);
    expect(quote(), quote());
    expect(quote().hashCode, quote().hashCode);
    expect(instruction(), instruction());
    expect(instruction().hashCode, instruction().hashCode);
    expect(firstObservation, secondObservation);
    expect(firstObservation.hashCode, secondObservation.hashCode);
    expect(
      const SolanaBridgeExecutionPayload(
        from: '11111111111111111111111111111111',
        base64Transaction: 'AQID',
      ),
      const SolanaBridgeExecutionPayload(
        from: '11111111111111111111111111111111',
        base64Transaction: 'AQID',
      ),
    );
  });

  test('validated strategy intents retain only reviewed domain objects', () {
    const chain = BridgeChain(
      id: BridgeConstants.ethereumChainId,
      key: 'eth',
      name: 'Ethereum',
      type: BridgeChainType.evm,
      nativeTokenSymbol: 'ETH',
    );
    const token = BridgeToken(
      chainId: BridgeConstants.ethereumChainId,
      address: tokenAddress,
      symbol: 'USDC',
      decimals: 6,
      solverDepositable: true,
    );
    const request = BridgeFundingRequest(
      method: BridgeFundingMethod.relayDeposit,
      sourceChain: chain,
      sourceToken: token,
      amount: '1',
      amountUnits: '1000000',
      baseDestinationAddress: destinationAddress,
      refundAddress: refundAddress,
      selfCustodyConfirmed: true,
    );
    final instruction = RelayDepositInstruction(
      requestId: 'request-1',
      depositAddress: depositAddress,
      request: request,
      minimumOutputUnits: '990000',
      minimumOutputDisplay: '0.99',
      createdAt: createdAt,
      expiresAt: expiresAt,
    );

    final intent = ValidatedRelayDepositIntent(
      intentId: 'intent-1',
      request: request,
      instruction: instruction,
    );

    expect(intent.intentId, 'intent-1');
    expect(intent.request, request);
    expect(intent.instruction, instruction);
    expect(intent, isA<ValidatedBridgeFundingIntent>());
  });
}
