import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clawa/services/model_provider_catalog.dart';
import 'package:clawa/services/preferences_service.dart';
import 'package:clawa/services/provider_setup_service.dart';

void main() {
  late PreferencesService preferences;
  late InMemoryProviderSecretBackend secrets;
  late ProviderSetupService service;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = PreferencesService();
    await preferences.init();
  });

  setUp(() async {
    secrets = InMemoryProviderSecretBackend();
    service = ProviderSetupService(
      preferences: preferences,
      secrets: secrets,
    );
    await service.clearPending();
    preferences.legacyPendingApiKey = null;
    preferences.lastProviderSetupReceiptId = null;
  });

  test('stages API keys only in the secure backend', () async {
    final staged = await service.stage(
      providerId: 'openrouter',
      modelId: 'openrouter/auto',
      apiKey: 'sk-or-secret-value',
    );

    expect(preferences.legacyPendingApiKey, isNull);
    expect(preferences.pendingApiKeyReference, staged.secretReference);
    expect(secrets.values.values, contains('sk-or-secret-value'));
    expect(
      preferences.pendingApiKeyReference,
      isNot('sk-or-secret-value'),
    );

    final loaded = await service.readPending();
    expect(loaded?.setupId, staged.setupId);
    expect(await service.readPendingApiKey(loaded!), 'sk-or-secret-value');
  });

  test('replacing provider setup removes the old pending secret', () async {
    final first = await service.stage(
      providerId: 'openrouter',
      modelId: 'openrouter/auto',
      apiKey: 'first-secret',
    );
    final firstReference = first.secretReference!;

    final second = await service.stage(
      providerId: 'google',
      modelId: 'google/gemini-3.1-pro-preview',
      apiKey: 'second-secret',
    );

    expect(secrets.values.containsKey(firstReference), isFalse);
    expect(secrets.values.values, contains('second-secret'));
    expect(secrets.values.values, isNot(contains('first-secret')));
    expect((await service.readPending())?.providerId, 'google');
    expect(second.setupId, isNot(first.setupId));
  });

  test('completion records a receipt and clears the pending secret', () async {
    final staged = await service.stage(
      providerId: 'openrouter',
      modelId: 'openrouter/auto',
      apiKey: 'one-time-secret',
    );
    await service.markApplying(staged);

    final receipt = await service.complete(staged);

    expect(receipt, isNotEmpty);
    expect(preferences.lastProviderSetupReceiptId, receipt);
    expect(await service.readPending(), isNull);
    expect(secrets.values, isEmpty);
  });

  test('migrates a legacy pending key and derives its safe model', () async {
    preferences.pendingProvider = 'openrouter';
    preferences.legacyPendingApiKey = 'legacy-secret';

    final loaded = await service.readPending();

    expect(loaded, isNotNull);
    expect(loaded!.modelId,
        ModelProviderCatalog.setupSafeModelForProvider('openrouter'));
    expect(preferences.legacyPendingApiKey, isNull);
    expect(await service.readPendingApiKey(loaded), 'legacy-secret');
    expect(secrets.values.values, contains('legacy-secret'));
  });

  test('cancelling setup removes a legacy plaintext key as well', () async {
    preferences.pendingProvider = 'openrouter';
    preferences.legacyPendingApiKey = 'legacy-secret';

    await service.clearPending();

    expect(preferences.legacyPendingApiKey, isNull);
    expect(secrets.values, isEmpty);
    expect(await service.readPending(), isNull);
  });

  test('does not read a secret after the pending setup is replaced', () async {
    final first = await service.stage(
      providerId: 'openrouter',
      modelId: 'openrouter/auto',
      apiKey: 'first-secret',
    );
    await service.stage(
      providerId: 'google',
      modelId: 'google/gemini-3.1-pro-preview',
      apiKey: 'second-secret',
    );

    await expectLater(
      service.readPendingApiKey(first),
      throwsA(isA<StateError>()),
    );
  });
}
