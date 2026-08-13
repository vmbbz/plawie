import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/paid_provider_approval_broker.dart';
import 'package:clawa/services/paid_provider_proxy_models.dart';
import 'package:clawa/services/paid_provider_turn_authorization_service.dart';
import 'package:clawa/widgets/paid_provider_approval_dialog.dart';

void main() {
  testWidgets('shows the exact bounded payment and approves once',
      (tester) async {
    final broker = PaidProviderApprovalBroker();
    final turns = PaidProviderTurnAuthorizationService();
    final secureStates = <bool>[];
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => PaidProviderApprovalHost(
        navigatorKey: navigatorKey,
        broker: broker,
        turnAuthorization: turns,
        setSensitiveUiVisible: (visible) async {
          secureStates.add(visible);
        },
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('Chat')),
    ));
    await tester.pump();

    final decision = broker.requestApproval(_pending());
    await tester.pumpAndSettle();

    expect(find.text('Approve exact AI payment'), findsOneWidget);
    expect(find.text('0.002000 USDC'), findsOneWidget);
    expect(find.text('BlockRun'), findsOneWidget);
    expect(find.text('blockrun/openai/gpt-5.5'), findsOneWidget);
    expect(find.text('Base Mainnet'), findsOneWidget);
    expect(find.text('Pay for one BlockRun model request.'), findsOneWidget);
    expect(find.text('0x1111111111111111111111111111111111111111'),
        findsOneWidget);
    expect(secureStates, <bool>[true]);

    await tester.tap(find.text('Approve & unlock'));
    await tester.pumpAndSettle();

    expect(await decision, PaidProviderApprovalDecision.approved);
    expect(secureStates, <bool>[true, false]);
    expect(find.text('Approve exact AI payment'), findsNothing);
    await broker.close();
  });

  testWidgets('backgrounding closes and cancels the visible approval',
      (tester) async {
    final broker = PaidProviderApprovalBroker();
    final turns = PaidProviderTurnAuthorizationService();
    final secureStates = <bool>[];
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => PaidProviderApprovalHost(
        navigatorKey: navigatorKey,
        broker: broker,
        turnAuthorization: turns,
        setSensitiveUiVisible: (visible) async {
          secureStates.add(visible);
        },
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('Chat')),
    ));
    await tester.pump();

    final decision = broker.requestApproval(_pending());
    await tester.pumpAndSettle();
    expect(find.text('Approve exact AI payment'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(await decision, PaidProviderApprovalDecision.appBackgrounded);
    expect(turns.isAppForeground, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Approve exact AI payment'), findsNothing);
    expect(secureStates, <bool>[true, false]);
    await broker.close();
  });

  testWidgets('biometric inactive state preserves only the bounded turn lease',
      (tester) async {
    final broker = PaidProviderApprovalBroker();
    final turns = PaidProviderTurnAuthorizationService(
      leaseIdFactory: () => 'lease-biometric',
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => PaidProviderApprovalHost(
        navigatorKey: navigatorKey,
        broker: broker,
        turnAuthorization: turns,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('Chat')),
    ));
    await tester.pump();

    turns.authorizeForegroundUserTurn(
      conversationId: 'conversation-a',
      provider: PaidProviderId.venice,
      modelId: 'venice/model-a',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(turns.isAppForeground, isFalse);
    expect(turns.activeLease?.leaseId, 'lease-biometric');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(turns.isAppForeground, isTrue);
    expect(
      turns
          .consumeForProxy(
            provider: PaidProviderId.venice,
            gatewayModelId: 'venice/model-a',
          )
          .remainingProxyCalls,
      7,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(turns.activeLease, isNull);

    await broker.close();
  });

  testWidgets('reject completes the exact intent without approval',
      (tester) async {
    final broker = PaidProviderApprovalBroker();
    final secureStates = <bool>[];
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => PaidProviderApprovalHost(
        navigatorKey: navigatorKey,
        broker: broker,
        turnAuthorization: PaidProviderTurnAuthorizationService(),
        setSensitiveUiVisible: (visible) async {
          secureStates.add(visible);
        },
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('Chat')),
    ));
    await tester.pump();

    final decision = broker.requestApproval(_pending());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    expect(await decision, PaidProviderApprovalDecision.cancelled);
    expect(secureStates, <bool>[true, false]);
    expect(find.text('Approve exact AI payment'), findsNothing);
    await broker.close();
  });

  testWidgets('secure-surface failure cancels without showing approval',
      (tester) async {
    final broker = PaidProviderApprovalBroker();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => PaidProviderApprovalHost(
        navigatorKey: navigatorKey,
        broker: broker,
        turnAuthorization: PaidProviderTurnAuthorizationService(),
        setSensitiveUiVisible: (_) async {
          throw StateError('secure surface unavailable');
        },
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('Chat')),
    ));
    await tester.pump();

    final decision = broker.requestApproval(_pending());
    await tester.pumpAndSettle();

    expect(await decision, PaidProviderApprovalDecision.cancelled);
    expect(find.text('Approve exact AI payment'), findsNothing);
    await broker.close();
  });
}

PendingPaidProviderApproval _pending() {
  final now = DateTime.now().toUtc();
  return PendingPaidProviderApproval(
    intentId: 'intent-1',
    provider: PaidProviderId.blockrun,
    modelId: 'blockrun/openai/gpt-5.5',
    amountUnits: '2000',
    asset: 'USDC',
    network: 'Base Mainnet',
    payTo: '0x1111111111111111111111111111111111111111',
    resource: Uri.parse('https://blockrun.ai/api/v1/chat/completions'),
    expiresAt: now.add(const Duration(minutes: 2)),
    requestFingerprint: 'abc123def456',
    reason: 'Pay for one BlockRun model request.',
  );
}
