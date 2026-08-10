import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/keeperhub/keeperhub_execution_models.dart';
import 'package:clawa/services/keeperhub/keeperhub_models.dart';
import 'package:clawa/services/keeperhub/keeperhub_wallet_controller.dart';
import 'package:clawa/widgets/keeperhub_agent_wallet_card.dart';

void main() {
  const personal = '0x1111111111111111111111111111111111111111';

  testWidgets('requires explicit consent before connecting a managed wallet',
      (tester) async {
    final controller = _FakeController(_empty());
    await _pump(
      tester,
      KeeperHubAgentWalletCard(
        personalWalletAddress: personal,
        controller: controller,
      ),
    );

    expect(find.text('Connect Agent Wallet'), findsOneWidget);
    expect(controller.connectCalls, 0);

    await tester.tap(find.text('Connect Agent Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Create Agent Execution Wallet?'), findsOneWidget);
    expect(find.textContaining('organization credential'), findsOneWidget);
    expect(controller.connectCalls, 0);

    await tester.tap(find.text('Connect securely'));
    await tester.pumpAndSettle();

    expect(controller.connectCalls, 1);
    expect(find.text('KEEPERHUB-MANAGED'), findsOneWidget);
    expect(find.text('BASE SEPOLIA'), findsOneWidget);
    expect(find.text('0x222222…222222'), findsOneWidget);
  });

  testWidgets('prepares a proof without executing and exposes review next',
      (tester) async {
    final controller = _FakeController(_ready());
    await _pump(
      tester,
      KeeperHubAgentWalletCard(
        personalWalletAddress: personal,
        controller: controller,
      ),
    );

    await tester.tap(find.text('Simulate safe testnet proof'));
    await tester.pumpAndSettle();

    expect(controller.prepareCalls, 1);
    expect(controller.reviewCalls, 0);
    expect(find.text('Ready for human review'), findsOneWidget);
    expect(find.text('Review & authorize'), findsOneWidget);
    expect(find.text('0 ETH'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

KeeperHubWalletSnapshot _empty() => const KeeperHubWalletSnapshot(
      connection: null,
      activeExecution: null,
      receipts: <KeeperHubExecutionRecord>[],
    );

KeeperHubConnectionRecord _connection() => KeeperHubConnectionRecord(
      personalWalletAddress: '0x1111111111111111111111111111111111111111',
      apiKeyId: 'key_123',
      apiKeyPrefix: 'kh_redacted',
      agentWalletAddress: '0x2222222222222222222222222222222222222222',
      createdAt: DateTime.utc(2026, 8, 10),
      lastVerifiedAt: DateTime.utc(2026, 8, 10),
      phase: KeeperHubConnectionPhase.ready,
    );

KeeperHubWalletSnapshot _ready({KeeperHubExecutionRecord? active}) =>
    KeeperHubWalletSnapshot(
      connection: _connection(),
      activeExecution: active,
      receipts: active == null
          ? const <KeeperHubExecutionRecord>[]
          : <KeeperHubExecutionRecord>[active],
    );

KeeperHubExecutionRecord _prepared() {
  final now = DateTime.utc(2026, 8, 10, 12);
  return KeeperHubExecutionRecord(
    intentId: 'kh_intent_12345678',
    taskId: 'mobile-proof:123:test',
    phase: KeeperHubExecutionPhase.awaitingApproval,
    personalWalletAddress: '0x1111111111111111111111111111111111111111',
    agentWalletAddress: '0x2222222222222222222222222222222222222222',
    reason: 'Prove human-governed Agent Wallet execution.',
    transfer: const <String, dynamic>{
      'chainId': 84532,
      'recipientAddress': '0x2222222222222222222222222222222222222222',
      'amount': '0',
    },
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
    approvalExpiresAt: now.add(const Duration(minutes: 5)),
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeController implements KeeperHubWalletController {
  _FakeController(this.snapshot);

  KeeperHubWalletSnapshot snapshot;
  int connectCalls = 0;
  int prepareCalls = 0;
  int reviewCalls = 0;

  @override
  Future<KeeperHubWalletSnapshot> load() async => snapshot;

  @override
  Future<KeeperHubWalletSnapshot> connect({
    required String personalWalletAddress,
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  }) async {
    connectCalls += 1;
    onProgress?.call(
      const KeeperHubOnboardingProgress(
        KeeperHubOnboardingStage.ready,
        'Agent Execution Wallet connected.',
      ),
    );
    return snapshot = _ready();
  }

  @override
  Future<KeeperHubWalletSnapshot> prepareProof() async {
    prepareCalls += 1;
    return snapshot = _ready(active: _prepared());
  }

  @override
  Future<KeeperHubWalletSnapshot> reviewAndExecute(String intentId) async {
    reviewCalls += 1;
    return snapshot;
  }

  @override
  Future<KeeperHubWalletSnapshot> discardPrepared(String intentId) async =>
      snapshot = _ready();

  @override
  Future<KeeperHubWalletSnapshot> resumeActive() async => snapshot;

  @override
  void close() {}
}
