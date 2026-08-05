import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/capabilities/ai_payments_capability.dart';

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
    expect(frame.payload!['mode'], 'quote-only-inbound-to-base');
    expect(frame.payload!['agentMayQuote'], isTrue);
    expect(frame.payload!['agentMayApproveOrExecute'], isFalse);
    expect(frame.payload!['internalSignerAcceptsBridgeCalldata'], isFalse);
    final sources = frame.payload!['sources'] as List;
    expect(sources.any((source) => source['id'] == 4663), isTrue);
    expect(sources.any((source) => source['name'] == 'Solana'), isTrue);
  });
}
