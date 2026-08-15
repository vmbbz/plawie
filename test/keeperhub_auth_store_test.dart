import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/keeperhub/keeperhub_auth_store.dart';
import 'package:clawa/services/keeperhub/keeperhub_models.dart';

void main() {
  test('stores credential and redacted metadata only in the secure backend',
      () async {
    final backend = _MemorySecrets();
    final store = KeeperHubAuthStore(secrets: backend);
    final record = _record();
    const apiKey = 'kh_this-is-a-returned-once-secret';

    await store.save(apiKey: apiKey, record: record);
    final stored = await store.read();

    expect(stored?.apiKey, apiKey);
    expect(stored?.record.agentWalletAddress, record.agentWalletAddress);
    final metadata = backend.values.values.singleWhere(
      (value) => value.startsWith('{'),
    );
    expect(metadata, isNot(contains(apiKey)));
    expect(jsonDecode(metadata), isNot(contains('apiKey')));
    expect(record.toAgentJson(), isNot(contains('apiKey')));
    expect(record.toAgentJson()['mayApproveOrExecute'], isFalse);
  });

  test('fails closed when only half of the credential record exists', () async {
    final backend = _MemorySecrets()
      ..values['plawie.keeperhub.org-api-key.v1'] = 'kh_secret-value';
    final store = KeeperHubAuthStore(secrets: backend);

    await expectLater(
      store.read(),
      throwsA(
        isA<KeeperHubException>().having(
          (error) => error.code,
          'code',
          'credential_store_incomplete',
        ),
      ),
    );
  });

  test('rolls back both entries when metadata commit fails', () async {
    final backend = _MemorySecrets(failOnWrite: 2);
    final store = KeeperHubAuthStore(secrets: backend);

    await expectLater(
      store.save(apiKey: 'kh_returned-once-secret', record: _record()),
      throwsStateError,
    );
    expect(backend.values, isEmpty);
  });
}

KeeperHubConnectionRecord _record() => KeeperHubConnectionRecord(
      personalWalletAddress: '0x1111111111111111111111111111111111111111',
      apiKeyId: 'key_123',
      apiKeyPrefix: 'kh_returned-',
      agentWalletAddress: '0x2222222222222222222222222222222222222222',
      createdAt: DateTime.utc(2026, 8, 10, 12),
      lastVerifiedAt: DateTime.utc(2026, 8, 10, 12, 1),
      phase: KeeperHubConnectionPhase.ready,
    );

class _MemorySecrets implements KeeperHubSecretBackend {
  _MemorySecrets({this.failOnWrite});

  final int? failOnWrite;
  final Map<String, String> values = <String, String>{};
  int _writes = 0;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    _writes += 1;
    if (_writes == failOnWrite) throw StateError('simulated write failure');
    values[key] = value;
  }
}
