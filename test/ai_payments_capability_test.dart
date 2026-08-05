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
    expect(permissions['bridge'], isFalse);
    expect(frame.payload!['maximumSinglePaymentUsd'], 5);
  });
}
