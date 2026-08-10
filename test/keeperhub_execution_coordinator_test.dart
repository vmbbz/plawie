import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clawa/services/keeperhub/keeperhub_api_client.dart';
import 'package:clawa/services/keeperhub/keeperhub_approval_broker.dart';
import 'package:clawa/services/keeperhub/keeperhub_auth_store.dart';
import 'package:clawa/services/keeperhub/keeperhub_execution_coordinator.dart';
import 'package:clawa/services/keeperhub/keeperhub_execution_models.dart';
import 'package:clawa/services/keeperhub/keeperhub_models.dart';
import 'package:clawa/services/keeperhub/keeperhub_receipt_store.dart';

void main() {
  const personal = '0x1111111111111111111111111111111111111111';
  const agent = '0x2222222222222222222222222222222222222222';
  const transactionHash =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final now = DateTime.utc(2026, 8, 10, 12);

  test('simulates, visibly approves, attests, submits once, and verifies proof',
      () async {
    final authStore = await _readyAuthStore(now, personal, agent);
    final persistence = _MemoryReceiptPersistence();
    final broker = KeeperHubApprovalBroker(clock: () => now)
      ..markAppForeground();
    final approvalSubscription = broker.approvals.listen((approval) {
      broker.approve(approval.intentId);
    });
    var executeCalls = 0;
    String? submittedIdempotency;
    final api = KeeperHubApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/execute/transfer' &&
            jsonDecode(request.body)['simulate'] == true) {
          return _json(200, _successfulSimulation(agent));
        }
        if (request.url.path == '/api/execute/transfer') {
          executeCalls += 1;
          submittedIdempotency = request.headers['idempotency-key'];
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, <String, dynamic>{
            'chainId': 84532,
            'recipientAddress': agent,
            'amount': '0',
          });
          return _json(202, <String, dynamic>{
            'executionId': 'direct_123',
            'status': 'completed',
          });
        }
        if (request.url.path == '/api/execute/direct_123/status') {
          return _json(200, _completedStatus(transactionHash));
        }
        fail('Unexpected request ${request.method} ${request.url}');
      }),
    );
    final coordinator = KeeperHubExecutionCoordinator(
      api: api,
      authStore: authStore,
      receiptStore: KeeperHubReceiptStore(persistence: persistence),
      approvalBroker: broker,
      clock: () => now,
      delay: (_) async {},
      maxPollAttempts: 2,
      attester: (execution) async => <String, dynamic>{
        'walletAddress': personal,
        'intentId': execution['intentId'],
        'simulationFingerprint': execution['simulationFingerprint'],
        'idempotencyKey': execution['idempotencyKey'],
        'attestationDigest': '0x${'c' * 64}',
        'signature': 'discarded-by-coordinator',
      },
    );

    final prepared = await coordinator.prepareProof(
      taskId: 'hackathon-demo-2026-08-10',
      reason: 'Prove safe Agent Wallet execution.',
    );
    expect(prepared.phase, KeeperHubExecutionPhase.awaitingApproval);
    expect(prepared.simulationFingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));

    final completed = await coordinator.reviewAndExecute(prepared.intentId);

    expect(completed.phase, KeeperHubExecutionPhase.completed);
    expect(completed.executionId, 'direct_123');
    expect(completed.transactionHash, transactionHash);
    expect(completed.receipts.single.verified, isTrue);
    expect(completed.toAgentJson()['receiptVerified'], isTrue);
    expect(completed.toJson(), isNot(contains('signature')));
    expect(executeCalls, 1);
    expect(submittedIdempotency, prepared.idempotencyKey);
    await approvalSubscription.cancel();
    await broker.close();
    coordinator.close();
  });

  test('replays exact persisted work key after ambiguous submission', () async {
    final authStore = await _readyAuthStore(now, personal, agent);
    final persistence = _MemoryReceiptPersistence();
    final broker = KeeperHubApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      broker.approve(approval.intentId);
    });
    var executeCalls = 0;
    final submittedKeys = <String?>[];
    final submittedBodies = <String>[];
    final api = KeeperHubApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/execute/transfer' &&
            jsonDecode(request.body)['simulate'] == true) {
          return _json(200, _successfulSimulation(agent));
        }
        if (request.url.path == '/api/execute/transfer') {
          executeCalls += 1;
          submittedKeys.add(request.headers['idempotency-key']);
          submittedBodies.add(request.body);
          if (executeCalls == 1) {
            throw http.ClientException('simulated network loss');
          }
          return _json(202, <String, dynamic>{
            'executionId': 'direct_123',
            'status': 'completed',
            'idempotentReplay': true,
          });
        }
        if (request.url.path == '/api/execute/direct_123/status') {
          return _json(200, _completedStatus(transactionHash));
        }
        fail('Unexpected request ${request.url}');
      }),
    );
    final coordinator = KeeperHubExecutionCoordinator(
      api: api,
      authStore: authStore,
      receiptStore: KeeperHubReceiptStore(persistence: persistence),
      approvalBroker: broker,
      clock: () => now,
      delay: (_) async {},
      maxPollAttempts: 2,
      attester: (execution) async => <String, dynamic>{
        'walletAddress': personal,
        'intentId': execution['intentId'],
        'simulationFingerprint': execution['simulationFingerprint'],
        'idempotencyKey': execution['idempotencyKey'],
        'attestationDigest': '0x${'c' * 64}',
      },
    );

    final prepared = await coordinator.prepareProof(
      taskId: 'interruption-proof-2026-08-10',
      reason: 'Prove idempotent recovery.',
    );
    final ambiguous = await coordinator.reviewAndExecute(prepared.intentId);
    expect(ambiguous.phase, KeeperHubExecutionPhase.outcomeUnknown);

    final recovered = await coordinator.resumeActive();

    expect(recovered?.phase, KeeperHubExecutionPhase.completed);
    expect(executeCalls, 2);
    expect(submittedKeys.toSet(), hasLength(1));
    expect(submittedBodies.toSet(), hasLength(1));
    await subscription.cancel();
    await broker.close();
    coordinator.close();
  });

  test('polls an existing execution ID instead of resubmitting it', () async {
    final authStore = await _readyAuthStore(now, personal, agent);
    final persistence = _MemoryReceiptPersistence();
    final broker = KeeperHubApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      broker.approve(approval.intentId);
    });
    var executeCalls = 0;
    var statusCalls = 0;
    final api = KeeperHubApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/execute/transfer' &&
            jsonDecode(request.body)['simulate'] == true) {
          return _json(200, _successfulSimulation(agent));
        }
        if (request.url.path == '/api/execute/transfer') {
          executeCalls += 1;
          return _json(202, <String, dynamic>{
            'executionId': 'direct_123',
            'status': 'pending',
          });
        }
        if (request.url.path == '/api/execute/direct_123/status') {
          statusCalls += 1;
          if (statusCalls == 1) {
            throw http.ClientException('temporary status outage');
          }
          return _json(200, _completedStatus(transactionHash));
        }
        fail('Unexpected request ${request.url}');
      }),
    );
    final coordinator = KeeperHubExecutionCoordinator(
      api: api,
      authStore: authStore,
      receiptStore: KeeperHubReceiptStore(persistence: persistence),
      approvalBroker: broker,
      clock: () => now,
      delay: (_) async {},
      maxPollAttempts: 2,
      attester: (execution) async => <String, dynamic>{
        'walletAddress': personal,
        'intentId': execution['intentId'],
        'simulationFingerprint': execution['simulationFingerprint'],
        'idempotencyKey': execution['idempotencyKey'],
        'attestationDigest': '0x${'c' * 64}',
      },
    );

    final prepared = await coordinator.prepareProof(
      taskId: 'status-recovery-2026-08-10',
      reason: 'Reconcile an existing execution without resubmission.',
    );
    final unknown = await coordinator.reviewAndExecute(prepared.intentId);
    expect(unknown.phase, KeeperHubExecutionPhase.outcomeUnknown);
    expect(unknown.executionId, 'direct_123');

    final recovered = await coordinator.resumeActive();

    expect(recovered?.phase, KeeperHubExecutionPhase.completed);
    expect(executeCalls, 1);
    expect(statusCalls, 2);
    await subscription.cancel();
    await broker.close();
    coordinator.close();
  });

  test('records a reverting simulation and never requests approval or submit',
      () async {
    final authStore = await _readyAuthStore(now, personal, agent);
    final persistence = _MemoryReceiptPersistence();
    var requests = 0;
    final api = KeeperHubApiClient(
      client: MockClient((request) async {
        requests += 1;
        return _json(400, <String, dynamic>{
          'success': false,
          'status': 'simulated',
          'from': agent,
          'to': agent,
          'value': '0',
          'wouldRevert': true,
          'code': 'proof_reverted',
          'revertReason': 'Deliberate test failure',
        });
      }),
    );
    final coordinator = KeeperHubExecutionCoordinator(
      api: api,
      authStore: authStore,
      receiptStore: KeeperHubReceiptStore(persistence: persistence),
      clock: () => now,
    );

    await expectLater(
      coordinator.prepareProof(
        taskId: 'deliberate-failure-2026-08-10',
        reason: 'Show fail-closed simulation.',
      ),
      throwsA(
        isA<KeeperHubException>().having(
          (error) => error.code,
          'code',
          'proof_reverted',
        ),
      ),
    );
    final records = await coordinator.receiptStore.read();
    expect(records.single.phase, KeeperHubExecutionPhase.simulationFailed);
    expect(requests, 1);
    coordinator.close();
  });

  test('does not trust completion whose receipt hash differs from status',
      () async {
    final authStore = await _readyAuthStore(now, personal, agent);
    final persistence = _MemoryReceiptPersistence();
    final broker = KeeperHubApprovalBroker(clock: () => now)
      ..markAppForeground();
    final subscription = broker.approvals.listen((approval) {
      broker.approve(approval.intentId);
    });
    final api = KeeperHubApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/execute/transfer' &&
            jsonDecode(request.body)['simulate'] == true) {
          return _json(200, _successfulSimulation(agent));
        }
        if (request.url.path == '/api/execute/transfer') {
          return _json(202, <String, dynamic>{
            'executionId': 'direct_123',
            'status': 'completed',
          });
        }
        if (request.url.path == '/api/execute/direct_123/status') {
          final status = _completedStatus(transactionHash);
          status['receipts'] = <Map<String, dynamic>>[
            <String, dynamic>{
              ...(status['receipts'] as List).single as Map,
              'hash': '0x${'b' * 64}',
            },
          ];
          return _json(200, status);
        }
        fail('Unexpected request ${request.url}');
      }),
    );
    final coordinator = KeeperHubExecutionCoordinator(
      api: api,
      authStore: authStore,
      receiptStore: KeeperHubReceiptStore(persistence: persistence),
      approvalBroker: broker,
      clock: () => now,
      delay: (_) async {},
      maxPollAttempts: 1,
      attester: (execution) async => <String, dynamic>{
        'walletAddress': personal,
        'intentId': execution['intentId'],
        'simulationFingerprint': execution['simulationFingerprint'],
        'idempotencyKey': execution['idempotencyKey'],
        'attestationDigest': '0x${'c' * 64}',
      },
    );

    final prepared = await coordinator.prepareProof(
      taskId: 'mismatched-receipt-2026-08-10',
      reason: 'Reject a mismatched completion receipt.',
    );
    final result = await coordinator.reviewAndExecute(prepared.intentId);

    expect(result.phase, KeeperHubExecutionPhase.outcomeUnknown);
    expect(result.errorCode, 'receipt_not_verified');
    await subscription.cancel();
    await broker.close();
    coordinator.close();
  });
}

Future<KeeperHubAuthStore> _readyAuthStore(
  DateTime now,
  String personal,
  String agent,
) async {
  final store = KeeperHubAuthStore(secrets: _MemorySecrets());
  await store.save(
    apiKey: 'kh_returned-once-secret-value',
    record: KeeperHubConnectionRecord(
      personalWalletAddress: personal,
      apiKeyId: 'key_123',
      apiKeyPrefix: 'kh_returned-',
      agentWalletAddress: agent,
      createdAt: now,
      lastVerifiedAt: now,
      phase: KeeperHubConnectionPhase.ready,
    ),
  );
  return store;
}

Map<String, dynamic> _successfulSimulation(String agent) => <String, dynamic>{
      'success': true,
      'status': 'simulated',
      'from': agent,
      'to': agent,
      'value': '0',
      'gasEstimate': '21000',
      'wouldRevert': false,
    };

Map<String, dynamic> _completedStatus(String hash) => <String, dynamic>{
      'executionId': 'direct_123',
      'status': 'completed',
      'type': 'transfer',
      'transactionHash': hash,
      'transactionLink': 'https://sepolia.basescan.org/tx/$hash',
      'sponsored': true,
      'receipts': <Map<String, dynamic>>[
        <String, dynamic>{
          'hash': hash,
          'chainId': 84532,
          'verified': true,
          'receiptStatus': 'success',
          'blockNumber': 123,
          'gasUsed': '21000',
          'verifiedAt': '2026-08-10T12:00:15Z',
        },
      ],
    };

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status);

class _MemorySecrets implements KeeperHubSecretBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _MemoryReceiptPersistence implements KeeperHubReceiptPersistence {
  List<String> receipts = <String>[];

  @override
  Future<List<String>> readReceipts() async => List<String>.from(receipts);

  @override
  Future<bool> writeReceipts(List<String> receipts) async {
    this.receipts = List<String>.from(receipts);
    return true;
  }
}
