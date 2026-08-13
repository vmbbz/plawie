import 'package:clawa/services/dynamic_model_catalog.dart';
import 'package:clawa/services/model_provider_catalog.dart';
import 'package:clawa/services/provider_compatible_fallback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proposes a verified model only inside the selected provider', () {
    final fallback = ProviderCompatibleFallbackPlanner.find(
      snapshot: _snapshot(),
      selectedModelId: 'venice/gemma',
      requiresVision: false,
    );

    expect(fallback?.modelId, 'venice/glm');
    expect(fallback?.providerId, 'venice');
  });

  test('never proposes advertised, cross-provider, or modality-losing routes',
      () {
    final advertised = ProviderCompatibleFallbackPlanner.find(
      snapshot: _snapshot(includeVerified: false),
      selectedModelId: 'venice/gemma',
      requiresVision: false,
    );
    final vision = ProviderCompatibleFallbackPlanner.find(
      snapshot: _snapshot(),
      selectedModelId: 'venice/gemma',
      requiresVision: true,
    );

    expect(advertised, isNull);
    expect(vision, isNull);
  });
}

DynamicCatalogSnapshot _snapshot({bool includeVerified = true}) {
  DynamicModelRecord model(
    String id, {
    required String provider,
    required ModelToolReadiness tools,
    bool recommended = false,
  }) =>
      DynamicModelRecord(
        id: '$provider/$id',
        providerId: provider,
        label: id,
        route: ModelRouteKind.cloud,
        supportsToolCalls: true,
        supportsVision: false,
        chatReadiness: tools == ModelToolReadiness.loopVerified
            ? ModelChatReadiness.verified
            : ModelChatReadiness.providerAdvertised,
        toolReadiness: tools,
        recommended: recommended,
      );
  return DynamicCatalogSnapshot(
    schemaVersion: DynamicCatalogSnapshot.currentSchemaVersion,
    snapshotId: 'fallback-test',
    state: DynamicCatalogSnapshotState.fresh,
    updatedAt: DateTime.utc(2026, 8, 13),
    expiresAt: DateTime.utc(2026, 8, 14),
    providers: <DynamicProviderRecord>[
      DynamicProviderRecord(
        id: 'venice',
        label: 'Venice',
        authenticationMode: ProviderAuthenticationMode.walletIdentity,
        models: <DynamicModelRecord>[
          model('gemma',
              provider: 'venice', tools: ModelToolReadiness.incompatible),
          model('advertised',
              provider: 'venice', tools: ModelToolReadiness.providerAdvertised),
          if (includeVerified)
            model('glm',
                provider: 'venice',
                tools: ModelToolReadiness.loopVerified,
                recommended: true),
        ],
      ),
      DynamicProviderRecord(
        id: 'openrouter',
        label: 'OpenRouter',
        authenticationMode: ProviderAuthenticationMode.apiKey,
        models: <DynamicModelRecord>[
          model('verified',
              provider: 'openrouter', tools: ModelToolReadiness.loopVerified),
        ],
      ),
    ],
  );
}
