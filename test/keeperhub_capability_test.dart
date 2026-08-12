import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clawa/services/capabilities/keeperhub_capability.dart';
import 'package:clawa/services/keeperhub/keeperhub_api_client.dart';
import 'package:clawa/services/keeperhub/keeperhub_auth_store.dart';
import 'package:clawa/services/keeperhub/keeperhub_execution_coordinator.dart';
import 'package:clawa/services/keeperhub/keeperhub_models.dart';
import 'package:clawa/services/keeperhub/keeperhub_receipt_store.dart';

void main() {
  const personal = '0x1111111111111111111111111111111111111111';
  const agent = '0x2222222222222222222222222222222222222222';
  final now = DateTime.utc(2026, 8, 10, 12);

  test('declares read and prepare only with every authority denied', () async {
    final capability = KeeperHubCapability();

    final frame = await capability.handle(
      'keeperhub.capabilities',
      const <String, dynamic>{},
    );

    expect(frame.isOk, isTrue);
    expect(capability.commands, <String>[
      'capabilities',
      'status',
      'receipts',
      'prepare',
    ]);
    final permissions = frame.payload!['agentPermissions'] as Map;
    expect(permissions['readStatus'], isTrue);
    expect(permissions['prepareZeroValueMainnetProof'], isTrue);
    expect(permissions['approve'], isFalse);
    expect(permissions['authenticate'], isFalse);
    expect(permissions['sign'], isFalse);
    expect(permissions['submit'], isFalse);
    expect(permissions['retry'], isFalse);
    expect(permissions['revokeCredential'], isFalse);
    expect(permissions['executeGenericWorkflow'], isFalse);
    expect(permissions['moveNonZeroValue'], isFalse);
    final forbidden = await capability.handle(
      'keeperhub.execute',
      const <String, dynamic>{'amount': '1'},
    );
    expect(forbidden.isOk, isFalse);
    expect(forbidden.error?['code'], 'UNKNOWN_COMMAND');
    capability.close();
  });

  test('prepare simulates and persists but never approves or submits',
      () async {
    final secrets = _MemorySecrets();
    final authStore = KeeperHubAuthStore(secrets: secrets);
    await authStore.save(
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
    var simulateCalls = 0;
    var executeCalls = 0;
    final api = KeeperHubApiClient(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['simulate'] == true) {
          simulateCalls += 1;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'from': agent,
              'to': agent,
              'value': '0',
              'gasEstimate': '21000',
              'wouldRevert': false,
            }),
            200,
          );
        }
        executeCalls += 1;
        return http.Response('{}', 500);
      }),
    );
    final receiptStore = KeeperHubReceiptStore(
      persistence: _MemoryReceipts(),
    );
    final coordinator = KeeperHubExecutionCoordinator(
      api: api,
      authStore: authStore,
      receiptStore: receiptStore,
      clock: () => now,
    );
    final capability = KeeperHubCapability(
      authStore: authStore,
      coordinator: coordinator,
      clock: () => now,
    );

    final status = await capability.handle(
      'keeperhub.status',
      const <String, dynamic>{},
    );
    final encodedStatus = jsonEncode(status.payload);
    expect(encodedStatus, isNot(contains('kh_returned-once')));
    expect(encodedStatus, isNot(contains('key_123')));
    expect(encodedStatus, isNot(contains('credentialPrefix')));

    final frame = await capability.handle(
      'keeperhub.prepare',
      const <String, dynamic>{
        'objective': 'Prepare a safe hackathon proof.',
      },
    );

    expect(frame.isOk, isTrue);
    expect(frame.payload!['submitted'], isFalse);
    expect(frame.payload!['approvalOpened'], isFalse);
    expect(frame.payload!['mayApproveOrExecute'], isFalse);
    expect(frame.payload!['proposal']['phase'], 'awaitingApproval');
    expect(simulateCalls, 1);
    expect(executeCalls, 0);
    expect((await receiptStore.active())?.phase.name, 'awaitingApproval');
    expect(jsonEncode(frame.payload), isNot(contains('kh_returned-once')));
    expect(jsonEncode(frame.payload), isNot(contains('signature')));
    capability.close();
  });
}

class _MemorySecrets implements KeeperHubSecretBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _MemoryReceipts implements KeeperHubReceiptPersistence {
  List<String> receipts = <String>[];

  @override
  Future<List<String>> readReceipts() async => List<String>.from(receipts);

  @override
  Future<bool> writeReceipts(List<String> receipts) async {
    this.receipts = List<String>.from(receipts);
    return true;
  }
}
