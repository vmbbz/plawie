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
    expect(find.text('BASE MAINNET'), findsOneWidget);
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

    await tester.tap(find.text('Simulate safe mainnet proof'));
    await tester.pumpAndSettle();

    expect(controller.prepareCalls, 1);
    expect(controller.reviewCalls, 0);
    expect(find.text('Ready for human review'), findsOneWidget);
    expect(find.text('Review & authorize'), findsOneWidget);
    expect(find.text('0 ETH'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('verified receipts expose explorer and proof metadata',
      (tester) async {
    await _pump(
      tester,
      KeeperHubAgentWalletCard(
        personalWalletAddress: personal,
        controller: _FakeController(_completedSnapshot()),
      ),
    );

    expect(find.text('Verified on-chain'), findsOneWidget);
    expect(
        find.text('Sponsored · block 49,896,836 · gas 80,521'), findsOneWidget);
    expect(find.byTooltip('Open transaction in BaseScan'), findsOneWidget);
    expect(find.byTooltip('Copy transaction hash'), findsOneWidget);
  });

  testWidgets('requires destructive confirmation before remote revocation',
      (tester) async {
    final controller = _FakeController(_ready());
    await _pump(
      tester,
      KeeperHubAgentWalletCard(
        personalWalletAddress: personal,
        controller: controller,
      ),
    );

    await tester.tap(find.text('Revoke Plawie access'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke Plawie access?'), findsOneWidget);
    expect(find.textContaining('does not delete'), findsOneWidget);
    expect(controller.revokeCalls, 0);

    await tester.tap(find.text('Authenticate & revoke'));
    await tester.pumpAndSettle();

    expect(controller.revokeCalls, 1);
    expect(find.text('Connect Agent Wallet'), findsOneWidget);
  });

  testWidgets('shows an honest recoverable state for uncertain revocation',
      (tester) async {
    final snapshot = _ready();
    final connection = snapshot.connection!;
    await _pump(
      tester,
      KeeperHubAgentWalletCard(
        personalWalletAddress: personal,
        controller: _FakeController(
          KeeperHubWalletSnapshot(
            connection: connection.copyWith(
              phase: KeeperHubConnectionPhase.revocationUnknown,
            ),
            activeExecution: snapshot.activeExecution,
            receipts: snapshot.receipts,
          ),
        ),
      ),
    );

    expect(find.text('REVOKE ?'), findsOneWidget);
    expect(find.textContaining('credential is still secured'), findsOneWidget);
    expect(find.text('Re-check connection status'), findsOneWidget);
    expect(find.text('Revoke Plawie access'), findsOneWidget);
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
      'chainId': 8453,
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

KeeperHubWalletSnapshot _completedSnapshot() {
  final completedAt = DateTime.utc(2026, 8, 13, 1, 3, 43);
  final record = KeeperHubExecutionRecord(
    intentId: 'kh_99dc92c349164d77b5895bdaf195117e',
    taskId: 'mobile-proof:1786582973457728:test',
    phase: KeeperHubExecutionPhase.completed,
    personalWalletAddress: '0x1111111111111111111111111111111111111111',
    agentWalletAddress: '0x2222222222222222222222222222222222222222',
    reason: 'Prove human-governed Agent Wallet execution.',
    transfer: const <String, dynamic>{
      'chainId': 8453,
      'recipientAddress': '0x2222222222222222222222222222222222222222',
      'amount': '0',
    },
    executionId: '59ja3y71gxctnet4zprd8',
    remoteStatus: 'completed',
    sponsored: true,
    transactionHash:
        '0xdcf1a13c3e83ded25c8104e5aa654ff300f381269a506a83b69fd9fd73117b04',
    transactionLink:
        'https://basescan.org/tx/0xdcf1a13c3e83ded25c8104e5aa654ff300f381269a506a83b69fd9fd73117b04',
    receipts: <KeeperHubVerifiedReceipt>[
      KeeperHubVerifiedReceipt(
        hash:
            '0xdcf1a13c3e83ded25c8104e5aa654ff300f381269a506a83b69fd9fd73117b04',
        chainId: 8453,
        verified: true,
        receiptStatus: 'success',
        blockNumber: 49896836,
        gasUsed: '80521',
        verifiedAt: DateTime.utc(2026, 8, 13, 1, 3, 41),
      ),
    ],
    createdAt: DateTime.utc(2026, 8, 13, 1, 2, 53),
    updatedAt: completedAt,
  );
  return KeeperHubWalletSnapshot(
    connection: _connection(),
    activeExecution: null,
    receipts: <KeeperHubExecutionRecord>[record],
  );
}

class _FakeController implements KeeperHubWalletController {
  _FakeController(this.snapshot);

  KeeperHubWalletSnapshot snapshot;
  int connectCalls = 0;
  int prepareCalls = 0;
  int reviewCalls = 0;
  int revokeCalls = 0;

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
  Future<KeeperHubWalletSnapshot> revoke({
    void Function(KeeperHubOnboardingProgress progress)? onProgress,
  }) async {
    revokeCalls += 1;
    return snapshot = _empty();
  }

  @override
  void close() {}
}
