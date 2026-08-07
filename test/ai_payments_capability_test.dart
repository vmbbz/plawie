import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/capabilities/ai_payments_capability.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/bridge_receipt_store.dart';

void main() {
  test('agent payment capability is informational and cannot spend', () async {
    final frame = await AiPaymentsCapability().handle(
      'payments.capabilities',
      const <String, dynamic>{},
    );

    expect(frame.isOk, isTrue);
    final permissions = frame.payload!['agentPermissions'] as Map;
    expect(permissions['readStatus'], isTrue);
    expect(permissions['prepareHumanReview'], isTrue);
    expect(permissions['approve'], isFalse);
    expect(permissions['unlockWallet'], isFalse);
    expect(permissions['sign'], isFalse);
    expect(permissions['broadcast'], isFalse);
    expect(permissions['bridgeQuote'], isTrue);
    expect(permissions['bridgeExecute'], isFalse);
    expect(frame.payload!['maximumSinglePaymentUsd'], 5);
  });

  test('agent bridge capability is quote-only and external-wallet bound',
      () async {
    final frame = await AiPaymentsCapability().handle(
      'bridge.capabilities',
      const <String, dynamic>{},
    );

    expect(frame.isOk, isTrue);
    expect(frame.payload!['mode'], 'agent-read-only-inbound-to-base');
    expect(frame.payload!['agentMayQuote'], isTrue);
    expect(frame.payload!['agentMayApproveOrExecute'], isFalse);
    expect(frame.payload!['internalSignerAcceptsBridgeCalldata'], isFalse);
    final sources = frame.payload!['sources'] as List;
    expect(sources.any((source) => source['id'] == 4663), isTrue);
    expect(sources.any((source) => source['name'] == 'Solana'), isTrue);
  });

  test('agent bridge status and history are bounded redacted reads', () async {
    const fullAddress = '0x1111111111111111111111111111111111111111';
    final persistence = _BridgePersistence();
    final store = BridgeReceiptStore.withPersistence(persistence);
    for (var index = 0; index < 25; index += 1) {
      await store.upsert(_receipt(
        intentId: 'intent-$index',
        state: index == 24
            ? BridgeFundingState.destinationPending
            : BridgeFundingState.completed,
        sourceAddress: fullAddress,
        updatedAt: DateTime.utc(2026, 8, 7).add(Duration(minutes: index)),
      ));
    }
    final capability = AiPaymentsCapability(bridgeReceiptStore: store);

    final status = await capability.handle(
      'bridge.status',
      const <String, dynamic>{},
    );
    final history = await capability.handle(
      'bridge.receipts',
      const <String, dynamic>{},
    );

    expect(status.isOk, isTrue);
    expect(status.payload!['mayApproveOrSpend'], isFalse);
    expect(status.payload!['foregroundApprovalRequired'], isTrue);
    expect(status.payload!['activeReceipt']['intentId'], 'intent-24');
    expect(jsonEncode(status.payload), isNot(contains(fullAddress)));
    expect(history.isOk, isTrue);
    expect(history.payload!['count'], 20);
    expect(history.payload!['totalStored'], 25);
    expect(history.payload!['redacted'], isTrue);
    expect(history.payload!['mayApproveOrSpend'], isFalse);
    expect(jsonEncode(history.payload), isNot(contains(fullAddress)));
  });
}

BridgeFundingReceipt _receipt({
  required String intentId,
  required BridgeFundingState state,
  required String sourceAddress,
  required DateTime updatedAt,
}) =>
    BridgeFundingReceipt(
      schemaVersion: 1,
      intentId: intentId,
      method: BridgeFundingMethod.connectedWallet,
      provider: 'lifi',
      state: state,
      sourceChainId: 1,
      sourceTokenAddress: '0x2222222222222222222222222222222222222222',
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1000000',
      baseDestinationAddress: '0x3333333333333333333333333333333333333333',
      sourceAddress: sourceAddress,
      createdAt: DateTime.utc(2026, 8, 7),
      updatedAt: updatedAt,
    );

final class _BridgePersistence implements BridgeReceiptPersistence {
  String? active;
  List<String> records = <String>[];

  @override
  String? get activeBridgeReceiptJson => active;

  @override
  List<String> get bridgeReceipts => records;

  @override
  Future<bool> setActiveBridgeReceiptJson(String? value) async {
    active = value;
    return true;
  }

  @override
  Future<bool> setBridgeReceipts(List<String> value) async {
    records = List<String>.of(value);
    return true;
  }
}
