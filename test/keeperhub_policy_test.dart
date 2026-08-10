import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/keeperhub/keeperhub_policy.dart';

void main() {
  const wallet = '0x2222222222222222222222222222222222222222';

  test('builds only a zero-value Base Sepolia self-transfer', () {
    expect(
      KeeperHubProofPolicy.transferBody(wallet),
      <String, dynamic>{
        'chainId': 84532,
        'recipientAddress': wallet,
        'amount': '0',
      },
    );
  });

  test('derives stable idempotency from canonical work fields', () {
    final first = KeeperHubProofPolicy.idempotencyKey(
      taskId: 'demo|2026-08-10',
      recipientAddress: wallet,
    );
    final retry = KeeperHubProofPolicy.idempotencyKey(
      taskId: ' demo|2026-08-10 ',
      recipientAddress: wallet.toUpperCase().replaceFirst('0X', '0x'),
    );
    final newWork = KeeperHubProofPolicy.idempotencyKey(
      taskId: 'demo|2026-08-11',
      recipientAddress: wallet,
    );

    expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(retry, first);
    expect(newWork, isNot(first));
  });

  test('rejects any stored transfer outside the exact proof contract', () {
    for (final transfer in <Map<String, dynamic>>[
      <String, dynamic>{
        'chainId': 8453,
        'recipientAddress': wallet,
        'amount': '0',
      },
      <String, dynamic>{
        'chainId': 84532,
        'recipientAddress': wallet,
        'amount': '1',
      },
      <String, dynamic>{
        'chainId': 84532,
        'recipientAddress': wallet,
        'amount': '0',
        'data': '0x',
      },
    ]) {
      expect(
        () => KeeperHubProofPolicy.validateProofTransfer(
          transfer: transfer,
          expectedAgentWallet: wallet,
        ),
        throwsA(anything),
      );
    }
  });
}
