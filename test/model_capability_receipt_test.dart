import 'dart:convert';

import 'package:clawa/services/dynamic_model_catalog.dart';
import 'package:clawa/services/model_capability_receipt.dart';
import 'package:clawa/services/model_execution_policy.dart';
import 'package:clawa/services/model_provider_catalog.dart';
import 'package:clawa/services/preferences_service.dart';
import 'package:clawa/services/provider_turn_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesService preferences;
  late ModelCapabilityReceiptRepository receipts;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = PreferencesService();
    await preferences.init();
    preferences.modelCapabilityReceiptsJson = null;
    receipts = ModelCapabilityReceiptRepository(preferences: preferences);
  });

  test('shipped evidence is exact-route scoped and truthful', () async {
    final assessed = await DynamicModelCatalogRepository(
      preferences: preferences,
    ).assess(_veniceSnapshot());
    final models = assessed.providers.single.models;

    final glm = models.singleWhere((model) => model.id.endsWith('glm-5-2'));
    final gemini =
        models.singleWhere((model) => model.id.endsWith('gemini-3-6-flash'));
    final gemma =
        models.singleWhere((model) => model.id.endsWith('gemma-4-uncensored'));
    final llama = models.singleWhere((model) => model.id.endsWith('llama-3'));

    expect(glm.agentReady, isTrue);
    expect(glm.readinessLabel, 'Agent-ready');
    expect(glm.capabilityAssessmentId, isNotNull);
    expect(gemini.agentReady, isFalse);
    expect(gemini.readinessLabel, 'Tool schema accepted');
    expect(gemma.readinessLabel, 'Chat only');
    expect(llama.readinessLabel, 'Provider advertises tools');
  });

  test('load-or-bundled always merges current capability evidence', () async {
    preferences.dynamicModelCatalogSnapshotJson = _veniceSnapshot().encode();

    final loaded = await DynamicModelCatalogRepository(
      preferences: preferences,
    ).loadOrBundled(now: DateTime.utc(2026, 8, 13, 13));

    final glm = loaded.providers.single.models
        .singleWhere((model) => model.id == 'venice/zai-org-glm-5-2');
    expect(glm.agentReady, isTrue);
  });

  test('local successful full loop survives and promotes only that route',
      () async {
    await receipts.recordSuccessfulTurn(
      modelId: 'venice/llama-3',
      toolCallObserved: true,
      toolResultObserved: true,
      assistantTextObserved: true,
      now: DateTime.utc(2026, 8, 13, 12),
    );

    final assessed = await DynamicModelCatalogRepository(
      preferences: preferences,
    ).assess(_veniceSnapshot(), now: DateTime.utc(2026, 8, 13, 13));
    final models = assessed.providers.single.models;
    expect(
      models.singleWhere((model) => model.id == 'venice/llama-3').agentReady,
      isTrue,
    );
    expect(
      models
          .singleWhere((model) => model.id == 'venice/gemini-3-6-flash')
          .agentReady,
      isFalse,
    );
  });

  test('explicit probe is persisted as distinct exact-route evidence',
      () async {
    await receipts.recordSuccessfulExplicitProbe(
      modelId: 'venice/llama-3',
      now: DateTime.utc(2026, 8, 13, 12),
    );

    final current = await receipts.readCurrent(now: DateTime.utc(2026, 8, 13));
    final receipt = current.singleWhere(
      (item) => item.namespacedModelId == 'venice/llama-3',
    );
    expect(receipt.source, ModelCapabilityReceiptSource.explicitProbe);
    expect(receipt.chatEvidence, ModelChatEvidence.verified);
    expect(receipt.toolEvidence, ModelToolEvidence.loopVerified);
  });

  test('schema failure quarantines exact model without disabling chat',
      () async {
    final failure = ProviderTurnFailure.classify(
      'Invalid request parameters: tool payload',
      trace: const ProviderTurnTrace(
        requestAccepted: true,
        toolCallObserved: false,
        toolResultObserved: false,
        assistantTextObserved: false,
      ),
    );
    await receipts.recordFailure(
      modelId: 'venice/llama-3',
      failure: failure,
      now: DateTime.utc(2026, 8, 13, 12),
    );

    final assessed = await DynamicModelCatalogRepository(
      preferences: preferences,
    ).assess(_veniceSnapshot(), now: DateTime.utc(2026, 8, 13, 13));
    final llama = assessed.providers.single.models
        .singleWhere((model) => model.id == 'venice/llama-3');
    expect(llama.liveAvailable, isTrue);
    expect(llama.toolReadiness, ModelToolReadiness.incompatible);
    expect(llama.readinessLabel, 'Chat only');
  });

  test('newer tool failure overrides an older explicit pass', () async {
    await receipts.recordSuccessfulExplicitProbe(
      modelId: 'venice/llama-3',
      now: DateTime.utc(2026, 8, 13, 10),
    );
    await receipts.recordFailure(
      modelId: 'venice/llama-3',
      failure: ProviderTurnFailure.classify(
        'Invalid request parameters: tool payload',
        trace: const ProviderTurnTrace(
          requestAccepted: true,
          toolCallObserved: false,
          toolResultObserved: false,
          assistantTextObserved: false,
        ),
      ),
      now: DateTime.utc(2026, 8, 13, 11),
    );

    final latest = await receipts.latestToolReceiptForModel(
      'venice/llama-3',
      now: DateTime.utc(2026, 8, 13, 12),
    );
    final assessed = await DynamicModelCatalogRepository(
      preferences: preferences,
    ).assess(_veniceSnapshot(), now: DateTime.utc(2026, 8, 13, 12));

    expect(latest?.toolEvidence, ModelToolEvidence.incompatible);
    expect(
      assessed.providers.single.models
          .singleWhere((model) => model.id == 'venice/llama-3')
          .toolReadiness,
      ModelToolReadiness.incompatible,
    );
  });

  test('local evidence overrides shipped baseline even with an earlier clock',
      () async {
    await receipts.recordFailure(
      modelId: 'venice/zai-org-glm-5-2',
      failure: ProviderTurnFailure.classify(
        'Invalid request parameters: tool payload',
        trace: const ProviderTurnTrace(
          requestAccepted: true,
          toolCallObserved: false,
          toolResultObserved: false,
          assistantTextObserved: false,
        ),
      ),
      now: DateTime.utc(2026, 8, 12, 23, 59),
    );

    final assessed = await DynamicModelCatalogRepository(
      preferences: preferences,
    ).assess(_veniceSnapshot(), now: DateTime.utc(2026, 8, 13, 12));

    expect(
      assessed.providers.single.models
          .singleWhere((model) => model.id == 'venice/zai-org-glm-5-2')
          .toolReadiness,
      ModelToolReadiness.incompatible,
    );
  });

  test('newer explicit pass repairs an older tool quarantine', () async {
    await receipts.recordFailure(
      modelId: 'venice/llama-3',
      failure: ProviderTurnFailure.classify(
        'Invalid request parameters: tool payload',
        trace: const ProviderTurnTrace(
          requestAccepted: true,
          toolCallObserved: false,
          toolResultObserved: false,
          assistantTextObserved: false,
        ),
      ),
      now: DateTime.utc(2026, 8, 13, 10),
    );
    await receipts.recordSuccessfulExplicitProbe(
      modelId: 'venice/llama-3',
      now: DateTime.utc(2026, 8, 13, 11),
    );

    final latest = await receipts.latestToolReceiptForModel(
      'venice/llama-3',
      now: DateTime.utc(2026, 8, 13, 12),
    );

    expect(latest?.toolEvidence, ModelToolEvidence.loopVerified);
  });

  test('ordinary chat success does not lift an existing tool quarantine',
      () async {
    await receipts.recordFailure(
      modelId: 'venice/llama-3',
      failure: ProviderTurnFailure.classify(
        'Invalid request parameters: tool payload',
        trace: const ProviderTurnTrace(
          requestAccepted: true,
          toolCallObserved: false,
          toolResultObserved: false,
          assistantTextObserved: false,
        ),
      ),
      now: DateTime.utc(2026, 8, 13, 10),
    );
    await receipts.recordSuccessfulTurn(
      modelId: 'venice/llama-3',
      toolCallObserved: false,
      toolResultObserved: false,
      assistantTextObserved: true,
      now: DateTime.utc(2026, 8, 13, 11),
    );

    final latest = await receipts.latestToolReceiptForModel(
      'venice/llama-3',
      now: DateTime.utc(2026, 8, 13, 12),
    );
    final assessed = await DynamicModelCatalogRepository(
      preferences: preferences,
    ).assess(_veniceSnapshot(), now: DateTime.utc(2026, 8, 13, 12));

    expect(latest?.toolEvidence, ModelToolEvidence.incompatible);
    expect(
      assessed.providers.single.models
          .singleWhere((model) => model.id == 'venice/llama-3')
          .toolReadiness,
      ModelToolReadiness.incompatible,
    );
  });

  test('receipt storage contains no turn payload or secrets', () async {
    await receipts.recordSuccessfulTurn(
      modelId: 'venice/llama-3',
      toolCallObserved: true,
      toolResultObserved: true,
      assistantTextObserved: true,
      now: DateTime.utc(2026, 8, 13, 12),
    );
    final encoded = preferences.modelCapabilityReceiptsJson!;
    final decoded = jsonDecode(encoded) as List<dynamic>;

    expect(decoded, hasLength(1));
    expect(encoded, isNot(contains('prompt')));
    expect(encoded, isNot(contains('arguments')));
    expect(encoded, isNot(contains('toolResult')));
    expect(encoded, isNot(contains('signature')));
    expect(encoded, isNot(contains('apiKey')));
  });

  test('fingerprint mismatch prevents stale promotion', () {
    final now = DateTime.utc(2026, 8, 13);
    final receipt = ModelCapabilityReceipt(
      assessmentId: 'old-gateway-receipt',
      providerId: 'venice',
      namespacedModelId: 'venice/llama-3',
      upstreamModelId: 'llama-3',
      endpointClass: ModelCapabilityReceipt.endpointClassFor('venice'),
      gatewayVersion: '2026.6.0',
      compatibilityProfileVersion:
          ModelCapabilityReceipt.currentCompatibilityProfileVersion,
      toolSchemaDigest: ModelCapabilityReceipt.currentToolSchemaDigest,
      streamMode: ModelCapabilityReceipt.currentStreamMode,
      appVersion: '2.2.0',
      observedAt: now,
      source: ModelCapabilityReceiptSource.localTurn,
      chatEvidence: ModelChatEvidence.verified,
      toolEvidence: ModelToolEvidence.loopVerified,
    );

    expect(receipt.isCurrentAt(now), isFalse);
  });
}

DynamicCatalogSnapshot _veniceSnapshot() {
  final now = DateTime.utc(2026, 8, 13);
  DynamicModelRecord model(String upstream) => DynamicModelRecord(
        id: 'venice/$upstream',
        providerId: 'venice',
        providerModelId: upstream,
        label: upstream,
        route: ModelRouteKind.cloud,
        supportsToolCalls: true,
        toolPolicy: ModelToolPolicy.reliable,
        chatReadiness: ModelChatReadiness.providerAdvertised,
        toolReadiness: ModelToolReadiness.providerAdvertised,
      );
  return DynamicCatalogSnapshot(
    schemaVersion: DynamicCatalogSnapshot.currentSchemaVersion,
    snapshotId: 'venice-test',
    state: DynamicCatalogSnapshotState.fresh,
    updatedAt: now,
    expiresAt: now.add(const Duration(days: 1)),
    providers: <DynamicProviderRecord>[
      DynamicProviderRecord(
        id: 'venice',
        label: 'Venice',
        authenticationMode: ProviderAuthenticationMode.walletIdentity,
        catalogState: DynamicProviderCatalogState.fresh,
        source: 'provider-api',
        models: <DynamicModelRecord>[
          model('zai-org-glm-5-2'),
          model('gemini-3-6-flash'),
          model('gemma-4-uncensored'),
          model('llama-3'),
        ],
      ),
    ],
  );
}
