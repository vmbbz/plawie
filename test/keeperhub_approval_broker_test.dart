import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/keeperhub/keeperhub_approval_broker.dart';
import 'package:clawa/services/keeperhub/keeperhub_execution_models.dart';
import 'package:clawa/services/keeperhub/keeperhub_models.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10, 12);

  test('fails closed without visible foreground UI', () async {
    final broker = KeeperHubApprovalBroker(clock: () => now);
    await expectLater(
      broker.requestApproval(_pending(now)),
      throwsA(
        isA<KeeperHubException>().having(
          (error) => error.code,
          'code',
          'approval_ui_unavailable',
        ),
      ),
    );
    await broker.close();
  });

  test('publishes redacted review and accepts its one visible decision',
      () async {
    final broker = KeeperHubApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      expect(approval.toAgentJson()['mayApproveOrExecute'], isFalse);
      expect(approval.toAgentJson(), isNot(contains('idempotencyKey')));
      broker.approve(approval.intentId);
    });

    expect(
      await broker.requestApproval(_pending(now)),
      KeeperHubApprovalDecision.approved,
    );
    expect(
      () => broker.approve('kh_intent_12345678'),
      throwsA(isA<KeeperHubException>()),
    );
    await subscription.cancel();
    await broker.close();
  });

  test('backgrounding cancels the pending execution', () async {
    final broker = KeeperHubApprovalBroker(clock: () => now)
      ..markAppForeground();
    final events = <PendingKeeperHubApproval>[];
    final subscription = broker.approvals.listen(events.add);
    final decision = broker.requestApproval(_pending(now));
    await _spinUntil(() => events.isNotEmpty);
    broker.markAppBackground();

    expect(await decision, KeeperHubApprovalDecision.appBackgrounded);
    await subscription.cancel();
    await broker.close();
  });
}

PendingKeeperHubApproval _pending(DateTime now) => PendingKeeperHubApproval(
      intentId: 'kh_intent_12345678',
      personalWalletAddress: '0x1111111111111111111111111111111111111111',
      agentWalletAddress: '0x2222222222222222222222222222222222222222',
      chainId: 84532,
      amount: '0 ETH',
      reason: 'Prove the Agent Wallet path.',
      simulation: const KeeperHubSimulation(
        success: true,
        from: '0x2222222222222222222222222222222222222222',
        to: '0x2222222222222222222222222222222222222222',
        valueWei: '0',
        gasEstimate: '21000',
        wouldRevert: false,
      ),
      simulationFingerprint: 'a' * 64,
      idempotencyKey: 'b' * 64,
      expiresAt: now.add(const Duration(minutes: 5)),
    );

Future<void> _spinUntil(bool Function() condition) async {
  for (var index = 0; index < 50 && !condition(); index++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}
