import 'dart:convert';

import 'model_execution_policy.dart';
import 'model_provider_catalog.dart';
import 'preferences_service.dart';

/// The lifecycle of a locally cached provider/model catalog.
enum DynamicCatalogSnapshotState {
  fresh,
  stale,
  empty,
  error,
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
    this.advertisedContextWindow,
    this.advertisedMaxOutputTokens,
    this.recommended = false,
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
  final int? advertisedContextWindow;
  final int? advertisedMaxOutputTokens;
  final bool recommended;

  bool get agentReady =>
      supportsToolCalls == true && toolPolicy != ModelToolPolicy.disabled;

  String get shortId => id.contains('/') ? id.split('/').last : id;

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
      advertisedContextWindow: model.contextWindow,
      advertisedMaxOutputTokens: model.maxTokens,
      recommended: model.recommended,
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
      advertisedContextWindow:
          _optionalPositiveInt(raw, 'advertisedContextWindow'),
      advertisedMaxOutputTokens:
          _optionalPositiveInt(raw, 'advertisedMaxOutputTokens'),
      recommended: raw['recommended'] == true,
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
        if (advertisedContextWindow != null)
          'advertisedContextWindow': advertisedContextWindow,
        if (advertisedMaxOutputTokens != null)
          'advertisedMaxOutputTokens': advertisedMaxOutputTokens,
        if (recommended) 'recommended': true,
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
    this.requiresApiKey = true,
    this.defaultModelId,
    this.connectionState = DynamicProviderConnectionState.unknown,
    this.source = 'unknown',
    this.etag,
    this.lastRefreshedAt,
    this.errorMessage,
  });

  final String id;
  final String label;
  final String subtitle;
  final String description;
  final bool requiresApiKey;
  final String? defaultModelId;
  final DynamicProviderConnectionState connectionState;
  final String source;
  final String? etag;
  final DateTime? lastRefreshedAt;
  final String? errorMessage;
  final List<DynamicModelRecord> models;

  factory DynamicProviderRecord.fromStatic(ProviderOption provider) {
    final models = ModelProviderCatalog.cloudModels
        .where((model) => model.providerId == provider.id)
        .map(DynamicModelRecord.fromStatic)
        .toList(growable: false);
    return DynamicProviderRecord(
      id: provider.id,
      label: provider.label,
      subtitle: provider.subtitle,
      description: provider.description,
      requiresApiKey: provider.requiresApiKey,
      defaultModelId: provider.defaultModel,
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

    return DynamicProviderRecord(
      id: providerId,
      label: _requiredString(raw, 'label'),
      subtitle: _optionalString(raw, 'subtitle') ?? '',
      description: _optionalString(raw, 'description') ?? '',
      requiresApiKey: raw['requiresApiKey'] != false,
      defaultModelId: _optionalString(raw, 'defaultModelId'),
      connectionState: _providerStateFromJson(raw['connectionState']),
      source: _optionalString(raw, 'source') ?? 'unknown',
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
        'requiresApiKey': requiresApiKey,
        if (defaultModelId != null) 'defaultModelId': defaultModelId,
        'connectionState': connectionState.name,
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

  bool get isUsable => state != DynamicCatalogSnapshotState.error && hasModels;

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
    return DynamicCatalogSnapshot(
      schemaVersion: schemaVersion,
      snapshotId: snapshotId,
      state: effective,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      providers: providers,
      source: source,
      errorMessage: errorMessage,
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
      }
      if (provider.defaultModelId != null &&
          !provider.models
              .any((model) => model.id == provider.defaultModelId)) {
        throw StateError(
          'Provider ${provider.id} default model is not in its snapshot.',
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
      state: DynamicCatalogSnapshotState.fresh,
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
      return DynamicCatalogSnapshot.fromJson(decoded).withEffectiveState(
        now ?? DateTime.now(),
      );
    } on FormatException {
      return null;
    } on StateError {
      return null;
    } on TypeError {
      return null;
    }
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
