import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clawa/services/runtime_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates runtime credentials before removing plaintext preferences',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      RuntimeCredentialStore.legacyGatewayTokenKey: 'gateway-secret',
      RuntimeCredentialStore.legacyNodeGatewayTokenKey: 'remote-secret',
      RuntimeCredentialStore.legacyNodeDeviceTokenKey: 'node-device-secret',
      RuntimeCredentialStore.legacyOperatorDeviceTokenKey:
          'operator-device-secret',
      RuntimeCredentialStore.legacyOperatorPrivateKey: 'operator-private',
      RuntimeCredentialStore.legacyNodePrivateKey: 'node-private',
      'openclaw_device_ed25519_public': 'public-value',
    });
    final preferences = await SharedPreferences.getInstance();
    final backend = InMemoryRuntimeCredentialBackend();
    final store = RuntimeCredentialStore(backend: backend);

    await store.init(preferences);

    expect(store.gatewayToken, 'gateway-secret');
    expect(store.nodeGatewayToken, 'remote-secret');
    expect(store.nodeDeviceToken, 'node-device-secret');
    expect(store.operatorDeviceToken, 'operator-device-secret');
    expect(store.devicePrivateKey(node: false), 'operator-private');
    expect(store.devicePrivateKey(node: true), 'node-private');
    expect(backend.values, hasLength(6));

    for (final key in <String>[
      RuntimeCredentialStore.legacyGatewayTokenKey,
      RuntimeCredentialStore.legacyNodeGatewayTokenKey,
      RuntimeCredentialStore.legacyNodeDeviceTokenKey,
      RuntimeCredentialStore.legacyOperatorDeviceTokenKey,
      RuntimeCredentialStore.legacyOperatorPrivateKey,
      RuntimeCredentialStore.legacyNodePrivateKey,
    ]) {
      expect(preferences.containsKey(key), isFalse, reason: key);
    }
    expect(
      preferences.getString('openclaw_device_ed25519_public'),
      'public-value',
    );
  });

  test('updates the synchronous cache and deletes secure values explicitly',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final backend = InMemoryRuntimeCredentialBackend();
    final store = RuntimeCredentialStore(backend: backend);
    await store.init(preferences);

    final write = store.setGatewayToken('new-gateway-secret');
    expect(store.gatewayToken, 'new-gateway-secret');
    await write;
    expect(backend.values.values, contains('new-gateway-secret'));

    await store.setGatewayToken(null);
    expect(store.gatewayToken, isEmpty);
    expect(backend.values.values, isNot(contains('new-gateway-secret')));
  });
}
