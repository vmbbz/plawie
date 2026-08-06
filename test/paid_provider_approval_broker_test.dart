import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/paid_provider_approval_broker.dart';
import 'package:clawa/services/paid_provider_proxy_models.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  test('refuses background and listenerless payment requests immediately',
      () async {
    final broker = PaidProviderApprovalBroker(clock: () => now);
    final pending = _pending(now);

    await expectLater(
      broker.requestApproval(pending),
      throwsA(
        isA<PaidProviderApprovalException>().having(
          (error) => error.code,
          'code',
          'approval_ui_unavailable',
        ),
      ),
    );

    broker.markAppForeground();
    await expectLater(
      broker.requestApproval(pending),
      throwsA(
        isA<PaidProviderApprovalException>().having(
          (error) => error.code,
          'code',
          'approval_ui_unavailable',
        ),
      ),
    );
    await broker.close();
  });

  test('publishes exact redacted intent and accepts only its visible decision',
      () async {
    final broker = PaidProviderApprovalBroker(clock: () => now)
      ..markAppForeground();
    final seen = <PendingPaidProviderApproval>[];
    final subscription = broker.approvals.listen((approval) {
      seen.add(approval);
      expect(
        () => broker.approve('another-intent'),
        throwsA(isA<PaidProviderApprovalException>()),
      );
      broker.approve(approval.intentId);
    });

    final result = await broker.requestApproval(_pending(now));

    expect(result, PaidProviderApprovalDecision.approved);
    expect(seen, hasLength(1));
    expect(seen.single.provider, PaidProviderId.blockrun);
    expect(seen.single.modelId, 'blockrun/openai/gpt-5.5');
    expect(seen.single.amountUnits, '2000');
    expect(seen.single.requestFingerprint, 'a' * 64);
    expect(seen.single.toAgentJson()['mayApproveOrSpend'], isFalse);
    expect(seen.single.toAgentJson(), isNot(contains('signature')));
    await subscription.cancel();
    await broker.close();
  });

  test('cancel, app background, expiry, and concurrency are terminal',
      () async {
    var current = now;
    final broker = PaidProviderApprovalBroker(clock: () => current)
      ..markAppForeground();
    final events = <PendingPaidProviderApproval>[];
    final subscription = broker.approvals.listen(events.add);

    final cancelledFuture = broker.requestApproval(_pending(current));
    await _spinUntil(() => events.isNotEmpty);
    broker.cancel(events.removeAt(0).intentId);
    expect(
      await cancelledFuture,
      PaidProviderApprovalDecision.cancelled,
    );

    final backgroundFuture = broker.requestApproval(
      _pending(current, intentId: 'intent-background'),
    );
    await _spinUntil(() => events.isNotEmpty);
    broker.markAppBackground();
    expect(
      await backgroundFuture,
      PaidProviderApprovalDecision.appBackgrounded,
    );

    broker.markAppForeground();
    final expiring = _pending(
      current,
      intentId: 'intent-expiring',
      expiresAt: current.add(const Duration(milliseconds: 30)),
    );
    final expiryFuture = broker.requestApproval(expiring);
    await _spinUntil(() => events.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    current = current.add(const Duration(seconds: 1));
    expect(await expiryFuture, PaidProviderApprovalDecision.expired);

    final first = broker.requestApproval(
      _pending(current, intentId: 'intent-first'),
    );
    await _spinUntil(() => events.length >= 2);
    await expectLater(
      broker.requestApproval(_pending(current, intentId: 'intent-second')),
      throwsA(
        isA<PaidProviderApprovalException>().having(
          (error) => error.code,
          'code',
          'approval_busy',
        ),
      ),
    );
    broker.cancel('intent-first');
    expect(await first, PaidProviderApprovalDecision.cancelled);

    await subscription.cancel();
    await broker.close();
  });
}

PendingPaidProviderApproval _pending(
  DateTime now, {
  String intentId = 'intent-a',
  DateTime? expiresAt,
}) =>
    PendingPaidProviderApproval(
      intentId: intentId,
      provider: PaidProviderId.blockrun,
      modelId: 'blockrun/openai/gpt-5.5',
      amountUnits: '2000',
      asset: 'USDC',
      network: 'Base Mainnet',
      payTo: '0x2222222222222222222222222222222222222222',
      resource: Uri.parse('https://blockrun.ai/api/v1/chat/completions'),
      expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
      requestFingerprint: 'a' * 64,
      reason: 'Pay for one BlockRun model request.',
    );

Future<void> _spinUntil(bool Function() condition) async {
  for (var index = 0; index < 50 && !condition(); index++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}
