import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/keeperhub/keeperhub_execution_models.dart';
import 'package:clawa/services/keeperhub/keeperhub_models.dart';
import 'package:clawa/services/keeperhub/keeperhub_receipt_store.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10, 12);

  test('persists one active execution and enforces immutable request fields',
      () async {
    final persistence = _MemoryPersistence();
    final store = KeeperHubReceiptStore(persistence: persistence);
    final proposed = _record(now);
    await store.upsert(proposed);
    expect((await store.active())?.intentId, proposed.intentId);

    final reviewed = proposed.copyWith(
      phase: KeeperHubExecutionPhase.awaitingApproval,
      simulation: _simulation(),
      simulationFingerprint: 'a' * 64,
      idempotencyKey: 'b' * 64,
      approvalExpiresAt: now.add(const Duration(minutes: 5)),
    );
    await store.upsert(reviewed);
    await expectLater(
      store.upsert(
        KeeperHubExecutionRecord(
          intentId: reviewed.intentId,
          taskId: reviewed.taskId,
          phase: reviewed.phase,
          personalWalletAddress: reviewed.personalWalletAddress,
          agentWalletAddress: reviewed.agentWalletAddress,
          reason: reviewed.reason,
          transfer: <String, dynamic>{
            ...reviewed.transfer,
            'amount': '1',
          },
          simulation: reviewed.simulation,
          simulationFingerprint: reviewed.simulationFingerprint,
          idempotencyKey: reviewed.idempotencyKey,
          approvalExpiresAt: reviewed.approvalExpiresAt,
          createdAt: reviewed.createdAt,
          updatedAt: reviewed.updatedAt,
        ),
      ),
      throwsA(
        isA<KeeperHubException>().having(
          (error) => error.code,
          'code',
          'execution_record_mutated',
        ),
      ),
    );
  });

  test('does not allow skipping review or creating a second active intent',
      () async {
    final store = KeeperHubReceiptStore(persistence: _MemoryPersistence());
    final proposed = _record(now);
    await store.upsert(proposed);

    await expectLater(
      store.upsert(
        proposed.copyWith(phase: KeeperHubExecutionPhase.submitting),
      ),
      throwsA(isA<KeeperHubException>()),
    );
    await expectLater(
      store.upsert(_record(now, intentId: 'kh_second_12345678')),
      throwsA(isA<KeeperHubException>()),
    );
  });

  test('quarantines a persisted proof body changed outside the app', () async {
    final persistence = _MemoryPersistence();
    final record = _record(now);
    final tampered = record.toJson();
    tampered['transfer'] = <String, dynamic>{
      'chainId': 84532,
      'recipientAddress': record.agentWalletAddress,
      'amount': '1',
    };
    persistence.receipts = <String>[jsonEncode(tampered)];

    final store = KeeperHubReceiptStore(persistence: persistence);

    expect(await store.read(), isEmpty);
    expect(await store.active(), isNull);
  });
}

KeeperHubExecutionRecord _record(
  DateTime now, {
  String intentId = 'kh_intent_12345678',
}) =>
    KeeperHubExecutionRecord(
      intentId: intentId,
      taskId: 'demo-2026-08-10',
      phase: KeeperHubExecutionPhase.proposed,
      personalWalletAddress: '0x1111111111111111111111111111111111111111',
      agentWalletAddress: '0x2222222222222222222222222222222222222222',
      reason: 'Prove the Agent Wallet path.',
      transfer: const <String, dynamic>{
        'chainId': 84532,
        'recipientAddress': '0x2222222222222222222222222222222222222222',
        'amount': '0',
      },
      createdAt: now,
      updatedAt: now,
    );

KeeperHubSimulation _simulation() => const KeeperHubSimulation(
      success: true,
      from: '0x2222222222222222222222222222222222222222',
      to: '0x2222222222222222222222222222222222222222',
      valueWei: '0',
      gasEstimate: '21000',
      wouldRevert: false,
    );

class _MemoryPersistence implements KeeperHubReceiptPersistence {
  List<String> receipts = <String>[];

  @override
  Future<List<String>> readReceipts() async => List<String>.from(receipts);

  @override
  Future<bool> writeReceipts(List<String> receipts) async {
    this.receipts = List<String>.from(receipts);
    return true;
  }
}
