import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/keeperhub/keeperhub_approval_broker.dart';
import 'package:clawa/services/keeperhub/keeperhub_execution_models.dart';
import 'package:clawa/services/sensitive_approval_surface.dart';
import 'package:clawa/widgets/keeperhub_execution_review_dialog.dart';

void main() {
  testWidgets('shows custody, exact proof details, and approves once',
      (tester) async {
    final broker = KeeperHubApprovalBroker();
    final secureStates = <bool>[];
    final surface = SensitiveApprovalSurface(
      setVisible: (visible) async => secureStates.add(visible),
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => KeeperHubExecutionApprovalHost(
          navigatorKey: navigatorKey,
          broker: broker,
          approvalSurface: surface,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: Text('Wallet')),
      ),
    );
    await tester.pump();

    final decision = broker.requestApproval(_pending());
    await tester.pumpAndSettle();

    expect(find.text('Authorize Agent Wallet proof'), findsOneWidget);
    expect(find.text('Zero-value self-transfer'), findsOneWidget);
    expect(find.text('0 ETH'), findsOneWidget);
    expect(find.text('Base Sepolia · chain 84532'), findsOneWidget);
    expect(find.textContaining('KeeperHub manages'), findsOneWidget);
    expect(
      find.text('0x2222222222222222222222222222222222222222'),
      findsOneWidget,
    );
    expect(secureStates, <bool>[true]);

    await tester.tap(find.text('Continue to device auth'));
    await tester.pumpAndSettle();

    expect(await decision, KeeperHubApprovalDecision.approved);
    expect(secureStates, <bool>[true, false]);
    await broker.close();
  });

  testWidgets('cancel closes without authorizing', (tester) async {
    final broker = KeeperHubApprovalBroker();
    final navigatorKey = GlobalKey<NavigatorState>();
    final surface = SensitiveApprovalSurface(setVisible: (_) async {});
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => KeeperHubExecutionApprovalHost(
          navigatorKey: navigatorKey,
          broker: broker,
          approvalSurface: surface,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: Text('Wallet')),
      ),
    );
    await tester.pump();

    final decision = broker.requestApproval(_pending());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await decision, KeeperHubApprovalDecision.cancelled);
    expect(find.text('Authorize Agent Wallet proof'), findsNothing);
    await broker.close();
  });

  test('secure approval surface is exclusive across operation types', () async {
    final states = <bool>[];
    final surface = SensitiveApprovalSurface(
      setVisible: (visible) async => states.add(visible),
    );

    expect(await surface.acquire('paid:intent-1'), isTrue);
    expect(await surface.acquire('keeperhub:intent-2'), isFalse);
    await surface.release('keeperhub:intent-2');
    expect(surface.activeOwner, 'paid:intent-1');
    await surface.release('paid:intent-1');

    expect(surface.activeOwner, isNull);
    expect(states, <bool>[true, false]);
  });
}

PendingKeeperHubApproval _pending() => PendingKeeperHubApproval(
      intentId: 'kh_intent_12345678',
      personalWalletAddress: '0x1111111111111111111111111111111111111111',
      agentWalletAddress: '0x2222222222222222222222222222222222222222',
      chainId: 84532,
      amount: '0 ETH',
      reason: 'Prove human-governed Agent Wallet execution.',
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
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 2)),
    );
