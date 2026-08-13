import 'dart:convert';

import 'model_execution_policy.dart';
import 'model_capability_receipt.dart';
import 'model_provider_catalog.dart';
import 'preferences_service.dart';

/// The lifecycle of a locally cached provider/model catalog.
enum DynamicCatalogSnapshotState {
  fresh,
  stale,
  offlineFallback,
  unavailable,
  empty,
  error,
}

/// Per-provider catalog truth inside a mixed snapshot. A snapshot can contain
/// one freshly refreshed provider alongside bundled or stale records for the
/// others, so the snapshot-level state is not sufficient for readiness UI.
enum DynamicProviderCatalogState {
  fresh,
  stale,
  offlineFallback,
  unavailable,
}

/// Connection information is deliberately separate from model discovery.
/// A provider can be discoverable while the user still needs to configure it.
enum DynamicProviderConnectionState {
  unknown,
  connected,
  needsConfiguration,
  unavailable,
  error,
}

/// Evidence that a model can complete an ordinary chat turn through the exact
/// provider route Plawie will use. A catalog listing is only an advertisement;
/// it is not a successful inference receipt.
enum ModelChatReadiness {
  unknown,
  providerAdvertised,
  verified,
  failed,
}

/// Evidence accumulated across the complete tool lifecycle. In particular,
/// accepting a tool schema does not prove that the provider can replay a tool
/// result and produce the final assistant response.
enum ModelToolReadiness {
  unknown,
  providerAdvertised,
  schemaAccepted,
  loopVerified,
  incompatible,
}

/// A model record used by dynamic discovery and the future grouped picker.
///
/// The context/output fields are advertised provider metadata only. They must
/// be passed through ModelExecutionPolicy before they influence a Gateway
/// request; this class never changes chat context or request budgets itself.
class DynamicModelRecord {
  const DynamicModelRecord({
    required this.id,
    required this.providerId,
    required this.label,
    required this.route,
    this.providerModelId,
    this.description = '',
    this.sourceModelId,
    this.capabilities = const <String>{},
    this.supportsToolCalls,
    this.supportsVision,
    this.toolPolicy = ModelToolPolicy.variable,
    this.chatReadiness = ModelChatReadiness.unknown,
    this.toolReadiness = ModelToolReadiness.unknown,
    this.advertisedContextWindow,
    this.advertisedMaxOutputTokens,
    this.deprecationDate,
    this.replacementModelId,
    this.recommended = false,
    this.liveAvailable = true,
    this.unavailableReason,
    this.capabilityAssessmentId,
    this.capabilityDetail,
  });

  final String id;
  final String providerId;
  final String label;
  final ModelRouteKind route;
  final String? providerModelId;
  final String description;
  final String? sourceModelId;
  final Set<String> capabilities;
  final bool? supportsToolCalls;
  final bool? supportsVision;
  final ModelToolPolicy toolPolicy;
  final ModelChatReadiness chatReadiness;
  final ModelToolReadiness toolReadiness;
  final int? advertisedContextWindow;
  final int? advertisedMaxOutputTokens;
  final DateTime? deprecationDate;
  final String? replacementModelId;
  final bool recommended;
  final bool liveAvailable;
  final String? unavailableReason;
  final String? capabilityAssessmentId;
  final String? capabilityDetail;

  bool get agentReady =>
      liveAvailable &&
      chatReadiness == ModelChatReadiness.verified &&
      toolReadiness == ModelToolReadiness.loopVerified &&
      supportsToolCalls == true &&
      toolPolicy != ModelToolPolicy.disabled;

  String get readinessLabel {
    if (chatReadiness == ModelChatReadiness.failed) {
      return 'Chat verification failed';
    }
    return switch (toolReadiness) {
      ModelToolReadiness.loopVerified => 'Agent-ready',
      ModelToolReadiness.schemaAccepted => 'Tool schema accepted',
      ModelToolReadiness.providerAdvertised => 'Provider advertises tools',
      ModelToolReadiness.incompatible => 'Chat only',
      ModelToolReadiness.unknown =>
        supportsToolCalls == false ? 'Chat only' : 'Tool support unknown',
    };
  }

  DynamicModelRecord withCapabilityReceipt(ModelCapabilityReceipt receipt) {
    final chat = switch (receipt.chatEvidence) {
      ModelChatEvidence.none => chatReadiness,
      ModelChatEvidence.verified => ModelChatReadiness.verified,
      ModelChatEvidence.failed => ModelChatReadiness.failed,
    };
    final receiptTools = switch (receipt.toolEvidence) {
      ModelToolEvidence.none => toolReadiness,
      ModelToolEvidence.schemaAccepted => ModelToolReadiness.schemaAccepted,
      ModelToolEvidence.loopVerified => ModelToolReadiness.loopVerified,
      ModelToolEvidence.incompatible => ModelToolReadiness.incompatible,
    };
    final ownsToolAssessment = receipt.toolEvidence != ModelToolEvidence.none ||
        capabilityAssessmentId == null;
    return DynamicModelRecord(
      id: id,
      providerId: providerId,
      label: label,
      route: route,
      providerModelId: providerModelId,
      description: description,
      sourceModelId: sourceModelId,
      capabilities: capabilities,
      supportsToolCalls: supportsToolCalls,
      supportsVision: supportsVision,
      toolPolicy: toolPolicy,
      chatReadiness: chat,
      toolReadiness: receiptTools,
      advertisedContextWindow: advertisedContextWindow,
      advertisedMaxOutputTokens: advertisedMaxOutputTokens,
      deprecationDate: deprecationDate,
      replacementModelId: replacementModelId,
      recommended: recommended,
      liveAvailable: liveAvailable,
      unavailableReason: unavailableReason,
      capabilityAssessmentId:
          ownsToolAssessment ? receipt.assessmentId : capabilityAssessmentId,
      capabilityDetail: ownsToolAssessment ? receipt.detail : capabilityDetail,
    );
  }

  bool isDeprecatedAt(DateTime now) =>
      deprecationDate != null && !deprecationDate!.isAfter(now.toUtc());

  String get shortId => id.contains('/') ? id.split('/').last : id;

  /// Model ID expected inside `models.providers.<provider>.models`.
  ///
  /// Provider payloads are allowed to use nested IDs (for example
  /// `openai/gpt-5` through OpenRouter), so this cannot be derived with a
  /// simple last-segment split.
  String get gatewayModelId {
    final source = providerModelId?.trim() ?? '';
    if (source.isNotEmpty) return source;
    final prefix = '$providerId/';
    return id.startsWith(prefix) ? id.substring(prefix.length) : shortId;
  }

  Map<String, dynamic> get gatewayModelConfig {
    if (!liveAvailable) {
      throw StateError(
        unavailableReason ?? 'This model is not available from a live catalog.',
      );
    }
    return <String, dynamic>{
      'id': gatewayModelId,
      'name': label,
    };
  }

  factory DynamicModelRecord.fromStatic(ModelOption model) {
    return DynamicModelRecord(
      id: model.id,
      providerId: model.providerId,
      label: model.label,
      route: model.route,
      providerModelId: model.providerModelId,
      description: model.description,
      capabilities: <String>{
        if (model.supportsToolCalls) 'tool-calls',
        if (model.supportsVision) 'vision',
      },
      supportsToolCalls: model.supportsToolCalls,
      supportsVision: model.supportsVision,
      toolPolicy: model.toolPolicy,
      chatReadiness: ModelChatReadiness.providerAdvertised,
      toolReadiness: !model.supportsToolCalls ||
              model.toolPolicy == ModelToolPolicy.disabled
          ? ModelToolReadiness.incompatible
          : ModelToolReadiness.providerAdvertised,
      advertisedContextWindow: model.contextWindow,
      advertisedMaxOutputTokens: model.maxTokens,
      deprecationDate: model.deprecationDate,
      replacementModelId: model.replacementModelId,
      recommended: model.recommended,
      liveAvailable: true,
    );
  }

  factory DynamicModelRecord.fromJson(Map<dynamic, dynamic> raw) {
    final providerId = _requiredId(raw, 'providerId');
    final id = _requiredId(raw, 'id');
    if (!id.startsWith('$providerId/')) {
      throw FormatException(
        'Dynamic model id must be namespaced by its provider: $id',
      );
    }

    final capabilities = raw['capabilities'];
    if (capabilities != null && capabilities is! List) {
      throw const FormatException('Model capabilities must be a list.');
    }

    return DynamicModelRecord(
      id: id,
      providerId: providerId,
      label: _requiredString(raw, 'label'),
      route: _modelRouteFromJson(raw['route']),
      providerModelId: _optionalString(raw, 'providerModelId'),
      description: _optionalString(raw, 'description') ?? '',
      sourceModelId: _optionalString(raw, 'sourceModelId'),
      capabilities: {
        for (final value in (capabilities as List? ?? const <dynamic>[]))
          if (value is String && value.trim().isNotEmpty) value.trim(),
      },
      supportsToolCalls: _optionalBool(raw, 'supportsToolCalls'),
      supportsVision: _optionalBool(raw, 'supportsVision'),
      toolPolicy: _toolPolicyFromJson(raw['toolPolicy']),
      chatReadiness: _chatReadinessFromJson(raw['chatReadiness']),
      toolReadiness: _toolReadinessFromJson(
        raw['toolReadiness'],
        supportsToolCalls: _optionalBool(raw, 'supportsToolCalls'),
        toolPolicy: _toolPolicyFromJson(raw['toolPolicy']),
      ),
      advertisedContextWindow:
          _optionalPositiveInt(raw, 'advertisedContextWindow'),
      advertisedMaxOutputTokens:
          _optionalPositiveInt(raw, 'advertisedMaxOutputTokens'),
      deprecationDate: _optionalDateTime(raw, 'deprecationDate'),
      replacementModelId: _optionalString(raw, 'replacementModelId'),
      recommended: raw['recommended'] == true,
      liveAvailable: raw['liveAvailable'] != false,
      unavailableReason: _optionalString(raw, 'unavailableReason'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'providerId': providerId,
        'label': label,
        'route': route.name,
        if (providerModelId != null) 'providerModelId': providerModelId,
        if (description.isNotEmpty) 'description': description,
        if (sourceModelId != null) 'sourceModelId': sourceModelId,
        if (capabilities.isNotEmpty)
          'capabilities': (capabilities.toList()..sort()),
        if (supportsToolCalls != null) 'supportsToolCalls': supportsToolCalls,
        if (supportsVision != null) 'supportsVision': supportsVision,
        'toolPolicy': toolPolicy.name,
        'chatReadiness': chatReadiness.name,
        'toolReadiness': toolReadiness.name,
        if (advertisedContextWindow != null)
          'advertisedContextWindow': advertisedContextWindow,
        if (advertisedMaxOutputTokens != null)
          'advertisedMaxOutputTokens': advertisedMaxOutputTokens,
        if (deprecationDate != null)
          'deprecationDate': deprecationDate!.toUtc().toIso8601String(),
        if (replacementModelId != null)
          'replacementModelId': replacementModelId,
        if (recommended) 'recommended': true,
        'liveAvailable': liveAvailable,
        if (unavailableReason != null) 'unavailableReason': unavailableReason,
      };
}

/// A provider plus its dynamically discovered models and connection state.
class DynamicProviderRecord {
  const DynamicProviderRecord({
    required this.id,
    required this.label,
    required this.models,
    this.subtitle = '',
    this.description = '',
    this.authenticationMode = ProviderAuthenticationMode.apiKey,
    this.defaultModelId,
    this.connectionState = DynamicProviderConnectionState.unknown,
    this.catalogState = DynamicProviderCatalogState.offlineFallback,
    this.source = 'unknown',
    this.etag,
    this.lastRefreshedAt,
    this.errorMessage,
  });

  final String id;
  final String label;
  final String subtitle;
  final String description;
  final ProviderAuthenticationMode authenticationMode;
  final String? defaultModelId;
  final DynamicProviderConnectionState connectionState;
  final DynamicProviderCatalogState catalogState;
  final String source;
  final String? etag;
  final DateTime? lastRefreshedAt;
  final String? errorMessage;
  final List<DynamicModelRecord> models;

  bool get requiresApiKey =>
      authenticationMode == ProviderAuthenticationMode.apiKey;

  factory DynamicProviderRecord.fromStatic(ProviderOption provider) {
    var models = ModelProviderCatalog.cloudModels
        .where((model) => model.providerId == provider.id)
        .map(DynamicModelRecord.fromStatic)
        .toList(growable: false);
    if (models.isEmpty &&
        provider.authenticationMode ==
            ProviderAuthenticationMode.walletIdentity) {
      models = <DynamicModelRecord>[
        DynamicModelRecord(
          id: '${provider.id}/catalog-unavailable',
          providerId: provider.id,
          label: 'Refresh ${provider.label} models',
          route: ModelRouteKind.cloud,
          description:
              'Connect the secure Base wallet and refresh to load current models.',
          supportsToolCalls: false,
          supportsVision: false,
          toolPolicy: ModelToolPolicy.disabled,
          liveAvailable: false,
          unavailableReason:
              'Current ${provider.label} models have not been loaded on this device.',
        ),
      ];
    }
    final defaultModelId = models.any(
      (model) => model.id == provider.defaultModel && model.liveAvailable,
    )
        ? provider.defaultModel
        : null;
    return DynamicProviderRecord(
      id: provider.id,
      label: provider.label,
      subtitle: provider.subtitle,
      description: provider.description,
      authenticationMode: provider.authenticationMode,
      defaultModelId: defaultModelId,
      catalogState: DynamicProviderCatalogState.offlineFallback,
      source: 'bundled-static',
      models: models,
    );
  }

  factory DynamicProviderRecord.fromJson(Map<dynamic, dynamic> raw) {
    final models = raw['models'];
    if (models is! List) {
      throw const FormatException('Provider models must be a list.');
    }
    final providerId = _requiredId(raw, 'id');
    final parsedModels = models
        .map((value) {
          if (value is! Map) {
            throw const FormatException('Provider model records must be maps.');
          }
          return DynamicModelRecord.fromJson(value);
        })
        .where((model) => model.providerId == providerId)
        .toList(growable: false);
    if (parsedModels.length != models.length) {
      throw FormatException(
        'Provider $providerId contains a model from another provider.',
      );
    }

    final source = _optionalString(raw, 'source') ?? 'unknown';
    return DynamicProviderRecord(
      id: providerId,
      label: _requiredString(raw, 'label'),
      subtitle: _optionalString(raw, 'subtitle') ?? '',
      description: _optionalString(raw, 'description') ?? '',
      authenticationMode: _providerAuthenticationModeFromJson(
        raw['authenticationMode'],
        legacyRequiresApiKey: raw['requiresApiKey'] != false,
      ),
      defaultModelId: _optionalString(raw, 'defaultModelId'),
      connectionState: _providerStateFromJson(raw['connectionState']),
      catalogState: _providerCatalogStateFromJson(
        raw['catalogState'],
        source: source,
      ),
      source: source,
      etag: _optionalString(raw, 'etag'),
      lastRefreshedAt: _optionalDateTime(raw, 'lastRefreshedAt'),
      errorMessage: _optionalString(raw, 'errorMessage'),
      models: parsedModels,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'subtitle': subtitle,
        'description': description,
        'authenticationMode': authenticationMode.name,
        'requiresApiKey': requiresApiKey,
        if (defaultModelId != null) 'defaultModelId': defaultModelId,
        'connectionState': connectionState.name,
        'catalogState': catalogState.name,
        'source': source,
        if (etag != null) 'etag': etag,
        if (lastRefreshedAt != null)
          'lastRefreshedAt': lastRefreshedAt!.toUtc().toIso8601String(),
        if (errorMessage != null) 'errorMessage': errorMessage,
        'models': models.map((model) => model.toJson()).toList(growable: false),
      };
}

/// Versioned, serializable snapshot for offline/stale model selection.
class DynamicCatalogSnapshot {
  const DynamicCatalogSnapshot({
    required this.schemaVersion,
    required this.snapshotId,
    required this.state,
    required this.updatedAt,
    required this.expiresAt,
    required this.providers,
    this.source = 'unknown',
    this.errorMessage,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String snapshotId;
  final DynamicCatalogSnapshotState state;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final List<DynamicProviderRecord> providers;
  final String source;
  final String? errorMessage;

  bool get hasModels => providers.any((provider) => provider.models.isNotEmpty);

  bool get isUsable =>
      state != DynamicCatalogSnapshotState.error &&
      state != DynamicCatalogSnapshotState.unavailable &&
      hasModels;

  DynamicCatalogSnapshotState effectiveState(DateTime now) {
    if (state == DynamicCatalogSnapshotState.fresh &&
        !expiresAt.isAfter(now.toUtc())) {
      return DynamicCatalogSnapshotState.stale;
    }
    return state;
  }

  DynamicCatalogSnapshot withEffectiveState(DateTime now) {
    final effective = effectiveState(now);
    if (effective == state) return this;
    final staleProviders = <DynamicProviderRecord>[
      for (final provider in providers)
        if (provider.catalogState == DynamicProviderCatalogState.fresh)
          DynamicProviderRecord(
            id: provider.id,
            label: provider.label,
            subtitle: provider.subtitle,
            description: provider.description,
            authenticationMode: provider.authenticationMode,
            defaultModelId: provider.defaultModelId,
            connectionState: provider.connectionState,
            catalogState: DynamicProviderCatalogState.stale,
            source: provider.source,
            etag: provider.etag,
            lastRefreshedAt: provider.lastRefreshedAt,
            errorMessage: provider.errorMessage,
            models: provider.models,
          )
        else
          provider,
    ];
    return DynamicCatalogSnapshot(
      schemaVersion: schemaVersion,
      snapshotId: snapshotId,
      state: effective,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      providers: staleProviders,
      source: source,
      errorMessage: errorMessage,
    );
  }

  DynamicCatalogSnapshot withCapabilityReceipts(
    Iterable<ModelCapabilityReceipt> receipts, {
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final current = receipts.where((receipt) => receipt.isCurrentAt(timestamp));
    return DynamicCatalogSnapshot(
      schemaVersion: schemaVersion,
      snapshotId: snapshotId,
      state: state,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      source: source,
      errorMessage: errorMessage,
      providers: <DynamicProviderRecord>[
        for (final provider in providers)
          DynamicProviderRecord(
            id: provider.id,
            label: provider.label,
            subtitle: provider.subtitle,
            description: provider.description,
            authenticationMode: provider.authenticationMode,
            defaultModelId: provider.defaultModelId,
            connectionState: provider.connectionState,
            catalogState: provider.catalogState,
            source: provider.source,
            etag: provider.etag,
            lastRefreshedAt: provider.lastRefreshedAt,
            errorMessage: provider.errorMessage,
            models: <DynamicModelRecord>[
              for (final model in provider.models)
                _applyNewestMatchingReceipt(
                  model,
                  current,
                  now: timestamp,
                ),
            ],
          ),
      ],
    );
  }

  factory DynamicCatalogSnapshot.fromJson(Map<dynamic, dynamic> raw) {
    final schemaVersion = raw['schemaVersion'];
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported model catalog schema version: $schemaVersion',
      );
    }
    final providers = raw['providers'];
    if (providers is! List) {
      throw const FormatException('Catalog providers must be a list.');
    }
    final parsedProviders = providers.map((value) {
      if (value is! Map) {
        throw const FormatException('Catalog provider records must be maps.');
      }
      return DynamicProviderRecord.fromJson(value);
    }).toList(growable: false);
    final snapshot = DynamicCatalogSnapshot(
      schemaVersion: schemaVersion as int,
      snapshotId: _requiredString(raw, 'snapshotId'),
      state: _catalogStateFromJson(raw['state']),
      updatedAt: _requiredDateTime(raw, 'updatedAt'),
      expiresAt: _requiredDateTime(raw, 'expiresAt'),
      providers: parsedProviders,
      source: _optionalString(raw, 'source') ?? 'unknown',
      errorMessage: _optionalString(raw, 'errorMessage'),
    );
    snapshot.validate();
    return snapshot;
  }

  Map<String, dynamic> toJson() {
    validate();
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'snapshotId': snapshotId,
      'state': state.name,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'source': source,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'providers': providers
          .map((provider) => provider.toJson())
          .toList(growable: false),
    };
  }

  String encode() => jsonEncode(toJson());

  void validate() {
    if (schemaVersion != currentSchemaVersion) {
      throw StateError('Unsupported model catalog schema version.');
    }
    if (snapshotId.trim().isEmpty) {
      throw StateError('Model catalog snapshot ID is required.');
    }
    if (updatedAt.isAfter(expiresAt)) {
      throw StateError('Model catalog expiry precedes its update time.');
    }

    final providerIds = <String>{};
    for (final provider in providers) {
      if (!_isSafeId(provider.id) || !providerIds.add(provider.id)) {
        throw StateError('Duplicate or invalid provider ID: ${provider.id}');
      }
      final modelIds = <String>{};
      for (final model in provider.models) {
        if (model.providerId != provider.id ||
            !_isSafeId(model.id) ||
            !modelIds.add(model.id)) {
          throw StateError(
            'Invalid or duplicate model ${model.id} in ${provider.id}.',
          );
        }
        if (!model.liveAvailable &&
            (model.unavailableReason?.trim().isEmpty ?? true)) {
          throw StateError(
            'Unavailable model ${model.id} must explain why it is unavailable.',
          );
        }
      }
      if (provider.defaultModelId != null &&
          !provider.models.any((model) =>
              model.id == provider.defaultModelId && model.liveAvailable)) {
        throw StateError(
          'Provider ${provider.id} default model is not live in its snapshot.',
        );
      }
    }
  }

  static DynamicCatalogSnapshot bundledFallback({
    DateTime? now,
    Duration ttl = const Duration(hours: 24),
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final providers = ModelProviderCatalog.providers
        .map(DynamicProviderRecord.fromStatic)
        .toList(growable: false);
    return DynamicCatalogSnapshot(
      schemaVersion: currentSchemaVersion,
      snapshotId: 'bundled-static-v1',
      state: DynamicCatalogSnapshotState.offlineFallback,
      updatedAt: timestamp,
      expiresAt: timestamp.add(ttl),
      providers: providers,
      source: 'bundled-static',
    );
  }
}

/// Persistent cache for provider/model metadata. It never stores credentials.
class DynamicModelCatalogRepository {
  DynamicModelCatalogRepository({PreferencesService? preferences})
      : _preferences = preferences ?? PreferencesService();

  static const Duration defaultTtl = Duration(hours: 24);

  final PreferencesService _preferences;

  Future<DynamicCatalogSnapshot?> load({DateTime? now}) async {
    await _preferences.init();
    final encoded = _preferences.dynamicModelCatalogSnapshotJson;
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final timestamp = now ?? DateTime.now();
      final snapshot = DynamicCatalogSnapshot.fromJson(decoded)
          .withEffectiveState(timestamp);
      return snapshot;
    } on FormatException {
      return null;
    } on StateError {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<DynamicCatalogSnapshot?> loadAssessed({DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    final snapshot = await load(now: timestamp);
    return snapshot == null ? null : assess(snapshot, now: timestamp);
  }

  Future<DynamicCatalogSnapshot> assess(
    DynamicCatalogSnapshot snapshot, {
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final receipts = await ModelCapabilityReceiptRepository(
      preferences: _preferences,
    ).readCurrent(now: timestamp);
    return snapshot.withCapabilityReceipts(receipts, now: timestamp);
  }

  Future<DynamicCatalogSnapshot> loadOrBundled({DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    final cached = await loadAssessed(now: timestamp);
    if (cached != null && cached.hasModels) return cached;
    return assess(
      DynamicCatalogSnapshot.bundledFallback(now: timestamp),
      now: timestamp,
    );
  }

  Future<void> save(DynamicCatalogSnapshot snapshot) async {
    await _preferences.init();
    snapshot.validate();
    _preferences.dynamicModelCatalogSnapshotJson = snapshot.encode();
  }

  Future<void> saveError({
    required String message,
    DynamicCatalogSnapshot? previous,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final base = previous ?? await load(now: timestamp);
    final expiry = base?.expiresAt.isAfter(timestamp) == true
        ? base!.expiresAt
        : timestamp;
    final error = DynamicCatalogSnapshot(
      schemaVersion: DynamicCatalogSnapshot.currentSchemaVersion,
      snapshotId:
          base?.snapshotId ?? 'error-${timestamp.microsecondsSinceEpoch}',
      state: DynamicCatalogSnapshotState.error,
      updatedAt: timestamp,
      expiresAt: expiry,
      providers: base?.providers ?? const <DynamicProviderRecord>[],
      source: base?.source ?? 'dynamic-discovery',
      errorMessage: _redactError(message),
    );
    await save(error);
  }

  Future<void> clear() async {
    await _preferences.init();
    _preferences.dynamicModelCatalogSnapshotJson = null;
  }
}

String _requiredString(Map<dynamic, dynamic> raw, String key) {
  final value = raw[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Catalog field $key is required.');
  }
  return value.trim();
}

String _requiredId(Map<dynamic, dynamic> raw, String key) {
  final value = _requiredString(raw, key);
  if (!_isSafeId(value)) throw FormatException('Invalid catalog ID: $value');
  return value;
}

String? _optionalString(Map<dynamic, dynamic> raw, String key) {
  final value = raw[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Catalog field $key must be text.');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool? _optionalBool(Map<dynamic, dynamic> raw, String key) {
  final value = raw[key];
  if (value == null) return null;
  if (value is! bool) {
    throw FormatException('Catalog field $key must be boolean.');
  }
  return value;
}

int? _optionalPositiveInt(Map<dynamic, dynamic> raw, String key) {
  final value = raw[key];
  if (value == null) return null;
  if (value is! int || value <= 0) {
    throw FormatException('Catalog field $key must be a positive integer.');
  }
  return value;
}

DateTime? _optionalDateTime(Map<dynamic, dynamic> raw, String key) {
  final value = raw[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Catalog field $key must be a date.');
  }
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('Catalog field $key is not a valid date.');
  }
}

DateTime _requiredDateTime(Map<dynamic, dynamic> raw, String key) {
  final value = _optionalDateTime(raw, key);
  if (value == null) throw FormatException('Catalog field $key is required.');
  return value;
}

DynamicCatalogSnapshotState _catalogStateFromJson(dynamic value) {
  if (value is! String) return DynamicCatalogSnapshotState.error;
  return DynamicCatalogSnapshotState.values.firstWhere(
    (state) => state.name == value,
    orElse: () => DynamicCatalogSnapshotState.error,
  );
}

DynamicProviderConnectionState _providerStateFromJson(dynamic value) {
  if (value is! String) return DynamicProviderConnectionState.unknown;
  return DynamicProviderConnectionState.values.firstWhere(
    (state) => state.name == value,
    orElse: () => DynamicProviderConnectionState.unknown,
  );
}

DynamicProviderCatalogState _providerCatalogStateFromJson(
  dynamic value, {
  required String source,
}) {
  if (value is! String) {
    return source == 'provider-api'
        ? DynamicProviderCatalogState.fresh
        : DynamicProviderCatalogState.offlineFallback;
  }
  return DynamicProviderCatalogState.values.firstWhere(
    (state) => state.name == value,
    orElse: () => DynamicProviderCatalogState.offlineFallback,
  );
}

ProviderAuthenticationMode _providerAuthenticationModeFromJson(
  dynamic value, {
  required bool legacyRequiresApiKey,
}) {
  if (value is String) {
    return ProviderAuthenticationMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => legacyRequiresApiKey
          ? ProviderAuthenticationMode.apiKey
          : ProviderAuthenticationMode.none,
    );
  }
  return legacyRequiresApiKey
      ? ProviderAuthenticationMode.apiKey
      : ProviderAuthenticationMode.none;
}

ModelRouteKind _modelRouteFromJson(dynamic value) {
  if (value is! String) return ModelRouteKind.cloud;
  return ModelRouteKind.values.firstWhere(
    (route) => route.name == value,
    orElse: () => ModelRouteKind.cloud,
  );
}

ModelToolPolicy _toolPolicyFromJson(dynamic value) {
  if (value is! String) return ModelToolPolicy.variable;
  return ModelToolPolicy.values.firstWhere(
    (policy) => policy.name == value,
    orElse: () => ModelToolPolicy.variable,
  );
}

ModelChatReadiness _chatReadinessFromJson(dynamic value) {
  if (value is! String) return ModelChatReadiness.providerAdvertised;
  return ModelChatReadiness.values.firstWhere(
    (readiness) => readiness.name == value,
    orElse: () => ModelChatReadiness.unknown,
  );
}

ModelToolReadiness _toolReadinessFromJson(
  dynamic value, {
  required bool? supportsToolCalls,
  required ModelToolPolicy toolPolicy,
}) {
  if (value is String) {
    return ModelToolReadiness.values.firstWhere(
      (readiness) => readiness.name == value,
      orElse: () => ModelToolReadiness.unknown,
    );
  }
  // Legacy dynamic snapshots must not inherit the old overclaim where a
  // provider advertisement was serialized as a reliable tool route.
  if (supportsToolCalls == false || toolPolicy == ModelToolPolicy.disabled) {
    return ModelToolReadiness.incompatible;
  }
  if (supportsToolCalls == true) {
    return ModelToolReadiness.providerAdvertised;
  }
  return ModelToolReadiness.unknown;
}

bool _isSafeId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 240) return false;
  return !trimmed.contains(RegExp(r'[\u0000-\u001F\u007F]')) &&
      !trimmed.contains('..');
}

String _redactError(String message) {
  var compact = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  compact = compact.replaceAllMapped(
    RegExp(
      r'\b(api[-_ ]?key|token|secret|password|authorization)\b\s*[:=]\s*[^,\s]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=[redacted]',
  );
  if (compact.isEmpty) return 'Provider model discovery failed.';
  return compact.length <= 240 ? compact : '${compact.substring(0, 239)}…';
}

DynamicModelRecord _applyNewestMatchingReceipt(
  DynamicModelRecord model,
  Iterable<ModelCapabilityReceipt> receipts, {
  required DateTime now,
}) {
  final matching = receipts
      .where((receipt) => receipt.matchesModel(
            providerId: model.providerId,
            namespacedModelId: model.id,
            upstreamModelId: model.gatewayModelId,
            now: now,
          ))
      .toList(growable: false)
    ..sort((a, b) {
      final aShipped = a.source == ModelCapabilityReceiptSource.shipped;
      final bShipped = b.source == ModelCapabilityReceiptSource.shipped;
      if (aShipped != bShipped) return aShipped ? -1 : 1;
      final observedOrder = a.observedAt.compareTo(b.observedAt);
      if (observedOrder != 0) return observedOrder;
      return a.source.index.compareTo(b.source.index);
    });
  var assessed = model;
  for (final receipt in matching) {
    assessed = assessed.withCapabilityReceipt(receipt);
  }
  return assessed;
}
