import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clawa/services/dynamic_model_catalog.dart';
import 'package:clawa/services/model_provider_catalog.dart';
import 'package:clawa/services/preferences_service.dart';

void main() {
  late PreferencesService preferences;
  late DynamicModelCatalogRepository repository;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = PreferencesService();
    await preferences.init();
  });

  setUp(() async {
    repository = DynamicModelCatalogRepository(preferences: preferences);
    await repository.clear();
  });

  test('bundled fallback is namespaced and contains no credentials', () {
    final snapshot = DynamicCatalogSnapshot.bundledFallback(
      now: DateTime.utc(2026, 8, 5),
    );
    final encoded = jsonEncode(snapshot.toJson());

    expect(snapshot.isUsable, isTrue);
    expect(snapshot.providers, isNotEmpty);
    expect(encoded, isNot(contains('apiKey')));
    expect(encoded, isNot(contains('secret')));
    for (final provider in snapshot.providers) {
      for (final model in provider.models) {
        expect(model.id, startsWith('${provider.id}/'));
      }
    }
  });

  test('snapshot round-trips and becomes stale without changing metadata', () {
    final updated = DateTime.utc(2026, 8, 5, 10);
    final snapshot = DynamicCatalogSnapshot.bundledFallback(
      now: updated,
      ttl: const Duration(hours: 1),
    );

    final loaded = DynamicCatalogSnapshot.fromJson(snapshot.toJson());
    final stale =
        loaded.withEffectiveState(updated.add(const Duration(hours: 2)));

    expect(loaded.snapshotId, snapshot.snapshotId);
    expect(loaded.state, DynamicCatalogSnapshotState.fresh);
    expect(stale.state, DynamicCatalogSnapshotState.stale);
    expect(stale.providers.length, snapshot.providers.length);
    expect(stale.expiresAt, snapshot.expiresAt);
  });

  test('repository persists a cache and reports expiry as stale', () async {
    final updated = DateTime.utc(2026, 8, 5, 10);
    await repository.save(DynamicCatalogSnapshot.bundledFallback(
      now: updated,
      ttl: const Duration(hours: 1),
    ));

    final loaded = await repository.load(
      now: updated.add(const Duration(hours: 2)),
    );

    expect(loaded, isNotNull);
    expect(loaded!.state, DynamicCatalogSnapshotState.stale);
    expect(preferences.dynamicModelCatalogSnapshotJson, isNotNull);
  });

  test('malformed or unsupported snapshots are rejected safely', () async {
    preferences.dynamicModelCatalogSnapshotJson = '{not-json';
    expect(await repository.load(), isNull);

    expect(
      () => DynamicCatalogSnapshot.fromJson(<String, dynamic>{
        'schemaVersion': 99,
        'snapshotId': 'future',
        'state': 'fresh',
        'updatedAt': '2026-08-05T00:00:00Z',
        'expiresAt': '2026-08-06T00:00:00Z',
        'providers': <dynamic>[],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('error receipts redact length and never break on an expired cache',
      () async {
    final updated = DateTime.utc(2026, 8, 5, 10);
    final previous = DynamicCatalogSnapshot.bundledFallback(
      now: updated,
      ttl: const Duration(hours: 1),
    );
    await repository.saveError(
      previous: previous,
      now: updated.add(const Duration(days: 2)),
      message: 'token=secret-value ${'x' * 500}',
    );

    final loaded =
        await repository.load(now: updated.add(const Duration(days: 2)));
    expect(loaded?.state, DynamicCatalogSnapshotState.error);
    expect(loaded?.errorMessage, isNot(contains('secret-value')));
    expect(loaded?.errorMessage?.length, lessThanOrEqualTo(240));
  });

  test('provider records reject models from another namespace', () {
    expect(
      () => DynamicProviderRecord.fromJson(<String, dynamic>{
        'id': 'openrouter',
        'label': 'OpenRouter',
        'models': <dynamic>[
          <String, dynamic>{
            'id': 'openai/gpt-5.4',
            'providerId': 'openai',
            'label': 'Wrong provider',
            'route': 'cloud',
          },
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('Gateway selection payload excludes untrusted advertised budgets', () {
    const model = DynamicModelRecord(
      id: 'openrouter/openai/future-model',
      providerId: 'openrouter',
      providerModelId: 'openai/future-model',
      label: 'Future model',
      route: ModelRouteKind.cloud,
      advertisedContextWindow: 999999999,
      advertisedMaxOutputTokens: 999999999,
    );

    expect(model.gatewayModelConfig, <String, dynamic>{
      'id': 'openai/future-model',
      'name': 'Future model',
    });
    expect(model.gatewayModelConfig, isNot(contains('contextWindow')));
    expect(model.gatewayModelConfig, isNot(contains('maxTokens')));
  });
}
