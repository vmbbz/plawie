import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'dynamic_model_catalog.dart';
import 'model_execution_policy.dart';
import 'model_provider_catalog.dart';
import 'venice_wallet_auth_service.dart';

enum ProviderDiscoveryFormat {
  openAiModels,
  googleModels,
  veniceModels,
  blockRunModels,
}

enum ProviderDiscoveryAuth {
  bearer,
  anthropicApiKey,
  googleQueryKey,
  veniceWalletIdentity,
  none,
}

/// Trusted, non-secret connection metadata for a provider's model endpoint.
/// Model records themselves always come from the endpoint response.
class ProviderDiscoverySpec {
  const ProviderDiscoverySpec({
    required this.providerId,
    required this.endpoint,
    required this.format,
    required this.auth,
    this.requiresApiKey = true,
  });

  final String providerId;
  final String endpoint;
  final ProviderDiscoveryFormat format;
  final ProviderDiscoveryAuth auth;
  final bool requiresApiKey;
}

class ProviderDiscoveryException implements Exception {
  const ProviderDiscoveryException({
    required this.providerId,
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String providerId;
  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ProviderDiscoveryException($providerId, $code): $message';
}

/// Fetches provider model metadata without touching Gateway configuration.
///
/// The service intentionally accepts the API key from its caller instead of
/// reading credentials from files or preferences. That keeps discovery
/// independently testable and prevents a model refresh from becoming another
/// credential owner. Calls are deduplicated per provider and cached through
/// [DynamicModelCatalogRepository].
class ProviderModelDiscoveryService {
  ProviderModelDiscoveryService({
    http.Client? client,
    DynamicModelCatalogRepository? repository,
    DateTime Function()? clock,
    Duration timeout = const Duration(seconds: 12),
    Duration cacheTtl = DynamicModelCatalogRepository.defaultTtl,
    VeniceWalletAuthService? veniceWalletAuth,
  })  : _client = client ?? http.Client(),
        _repository = repository ?? DynamicModelCatalogRepository(),
        _clock = clock ?? DateTime.now,
        _timeout = timeout,
        _cacheTtl = cacheTtl,
        _veniceWalletAuth = veniceWalletAuth ?? VeniceWalletAuthService();

  static final Map<String, ProviderDiscoverySpec> specs =
      <String, ProviderDiscoverySpec>{
    'google': const ProviderDiscoverySpec(
      providerId: 'google',
      endpoint: 'https://generativelanguage.googleapis.com/v1beta/models',
      format: ProviderDiscoveryFormat.googleModels,
      auth: ProviderDiscoveryAuth.googleQueryKey,
    ),
    'anthropic': const ProviderDiscoverySpec(
      providerId: 'anthropic',
      endpoint: 'https://api.anthropic.com/v1/models',
      format: ProviderDiscoveryFormat.openAiModels,
      auth: ProviderDiscoveryAuth.anthropicApiKey,
    ),
    'openai': const ProviderDiscoverySpec(
      providerId: 'openai',
      endpoint: 'https://api.openai.com/v1/models',
      format: ProviderDiscoveryFormat.openAiModels,
      auth: ProviderDiscoveryAuth.bearer,
    ),
    'xai': const ProviderDiscoverySpec(
      providerId: 'xai',
      endpoint: 'https://api.x.ai/v1/models',
      format: ProviderDiscoveryFormat.openAiModels,
      auth: ProviderDiscoveryAuth.bearer,
    ),
    'openrouter': const ProviderDiscoverySpec(
      providerId: 'openrouter',
      endpoint: 'https://openrouter.ai/api/v1/models',
      format: ProviderDiscoveryFormat.openAiModels,
      auth: ProviderDiscoveryAuth.bearer,
    ),
    'groq': const ProviderDiscoverySpec(
      providerId: 'groq',
      endpoint: 'https://api.groq.com/openai/v1/models',
      format: ProviderDiscoveryFormat.openAiModels,
      auth: ProviderDiscoveryAuth.bearer,
    ),
    'zenmux': const ProviderDiscoverySpec(
      providerId: 'zenmux',
      endpoint: 'https://zenmux.ai/api/v1/models',
      format: ProviderDiscoveryFormat.openAiModels,
      auth: ProviderDiscoveryAuth.bearer,
    ),
    'venice': const ProviderDiscoverySpec(
      providerId: 'venice',
      endpoint: 'https://api.venice.ai/api/v1/models',
      format: ProviderDiscoveryFormat.veniceModels,
      auth: ProviderDiscoveryAuth.veniceWalletIdentity,
      requiresApiKey: false,
    ),
    'blockrun': const ProviderDiscoverySpec(
      providerId: 'blockrun',
      endpoint: 'https://blockrun.ai/api/v1/models',
      format: ProviderDiscoveryFormat.blockRunModels,
      auth: ProviderDiscoveryAuth.none,
      requiresApiKey: false,
    ),
  };

  static const int _maxCatalogResponseBytes = 4 * 1024 * 1024;

  final http.Client _client;
  final DynamicModelCatalogRepository _repository;
  final DateTime Function() _clock;
  final Duration _timeout;
  final Duration _cacheTtl;
  final VeniceWalletAuthService _veniceWalletAuth;
  final Map<String, Future<DynamicCatalogSnapshot>> _inFlight =
      <String, Future<DynamicCatalogSnapshot>>{};

  Future<DynamicCatalogSnapshot> refreshProvider(
    String provider, {
    String? apiKey,
  }) {
    final providerId = ModelProviderCatalog.normalizeProvider(provider);
    return _inFlight.putIfAbsent(
      providerId,
      () => _runRefresh(providerId, apiKey: apiKey),
    );
  }

  Future<DynamicCatalogSnapshot> _runRefresh(
    String providerId, {
    required String? apiKey,
  }) async {
    try {
      return await _refresh(providerId, apiKey: apiKey);
    } finally {
      _inFlight.remove(providerId);
    }
  }

  Future<DynamicCatalogSnapshot> _refresh(
    String providerId, {
    required String? apiKey,
  }) async {
    final spec = specs[providerId];
    if (spec == null) {
      throw ProviderDiscoveryException(
        providerId: providerId,
        code: 'unsupported_provider',
        message: 'Model discovery is not available for this provider yet.',
      );
    }
    final normalizedKey = apiKey?.trim() ?? '';
    final now = _clock().toUtc();
    final cached = await _repository.load(now: now);
    final cachedProvider = cached?.providers
        .where((provider) => provider.id == providerId)
        .firstOrNull;
    if (spec.requiresApiKey && normalizedKey.isEmpty) {
      return _persistFailureAndRethrow(
        providerId: providerId,
        cached: cached,
        cachedProvider: cachedProvider,
        now: now,
        error: const ProviderDiscoveryException(
          providerId: 'unknown',
          code: 'configuration_required',
          message: 'Add the provider API key before refreshing its models.',
        ),
      );
    }

    try {
      final result = await _fetch(
        spec,
        apiKey: normalizedKey,
        ifNoneMatch: cachedProvider?.etag,
      );
      final models = result.notModified
          ? (cachedProvider?.models ?? const <DynamicModelRecord>[])
          : result.models;
      if (models.isEmpty) {
        throw const ProviderDiscoveryException(
          providerId: 'unknown',
          code: 'empty_response',
          message: 'The provider returned no chat-capable models.',
        );
      }

      final provider = _connectedProvider(
        providerId,
        cachedProvider: cachedProvider,
        models: models,
        etag: result.etag ?? cachedProvider?.etag,
        refreshedAt: now,
      );
      final base = cached ??
          DynamicCatalogSnapshot.bundledFallback(now: now, ttl: _cacheTtl);
      final snapshot = _replaceProvider(
        base,
        provider,
        now: now,
        state: DynamicCatalogSnapshotState.fresh,
        source: 'mixed-provider-api',
        errorMessage: null,
      );
      await _repository.save(snapshot);
      return snapshot;
    } on ProviderDiscoveryException catch (error) {
      return _persistFailureAndRethrow(
        providerId: providerId,
        cached: cached,
        cachedProvider: cachedProvider,
        now: now,
        error: error,
      );
    } on VeniceWalletAuthException catch (error) {
      return _persistFailureAndRethrow(
        providerId: providerId,
        cached: cached,
        cachedProvider: cachedProvider,
        now: now,
        error: ProviderDiscoveryException(
          providerId: providerId,
          code: error.code,
          message: error.message,
        ),
      );
    } on TimeoutException {
      return _persistFailureAndRethrow(
        providerId: providerId,
        cached: cached,
        cachedProvider: cachedProvider,
        now: now,
        error: const ProviderDiscoveryException(
          providerId: 'unknown',
          code: 'timed_out',
          message: 'The provider model request timed out.',
        ),
      );
    } on http.ClientException {
      return _persistFailureAndRethrow(
        providerId: providerId,
        cached: cached,
        cachedProvider: cachedProvider,
        now: now,
        error: const ProviderDiscoveryException(
          providerId: 'unknown',
          code: 'network_error',
          message: 'The provider model request could not be completed.',
        ),
      );
    } on FormatException {
      return _persistFailureAndRethrow(
        providerId: providerId,
        cached: cached,
        cachedProvider: cachedProvider,
        now: now,
        error: const ProviderDiscoveryException(
          providerId: 'unknown',
          code: 'invalid_response',
          message: 'The provider returned invalid model metadata.',
        ),
      );
    }
  }

  Future<DynamicCatalogSnapshot> _persistFailureAndRethrow({
    required String providerId,
    required DynamicCatalogSnapshot? cached,
    required DynamicProviderRecord? cachedProvider,
    required DateTime now,
    required ProviderDiscoveryException error,
  }) async {
    final safeError = error.providerId == 'unknown'
        ? ProviderDiscoveryException(
            providerId: providerId,
            code: error.code,
            message: error.message,
            statusCode: error.statusCode,
          )
        : error;
    final base = cached ??
        DynamicCatalogSnapshot.bundledFallback(now: now, ttl: _cacheTtl);
    final previous = cachedProvider ?? _staticProvider(providerId);
    final safeMessage = _safeErrorMessage(safeError.message);
    final catalogState = previous.lastRefreshedAt != null &&
            previous.source == 'provider-api' &&
            previous.models.any((model) => model.liveAvailable)
        ? DynamicProviderCatalogState.stale
        : previous.models.isEmpty
            ? DynamicProviderCatalogState.unavailable
            : DynamicProviderCatalogState.offlineFallback;
    final failedProvider = DynamicProviderRecord(
      id: previous.id,
      label: previous.label,
      subtitle: previous.subtitle,
      description: previous.description,
      authenticationMode: previous.authenticationMode,
      defaultModelId: previous.defaultModelId,
      connectionState: _failureConnectionState(safeError.code),
      catalogState: catalogState,
      source: previous.source,
      etag: previous.etag,
      lastRefreshedAt: previous.lastRefreshedAt,
      errorMessage: safeMessage,
      models: previous.models,
    );
    final snapshot = _replaceProvider(
      base,
      failedProvider,
      now: now,
      state: base.state == DynamicCatalogSnapshotState.error
          ? DynamicCatalogSnapshotState.error
          : base.effectiveState(now),
      source: base.source,
      errorMessage: safeMessage,
    );
    await _repository.save(snapshot);
    throw safeError;
  }

  Future<_ProviderFetchResult> _fetch(
    ProviderDiscoverySpec spec, {
    required String apiKey,
    required String? ifNoneMatch,
  }) async {
    final discovered = <String, DynamicModelRecord>{};
    String? pageToken;
    String? etag;

    for (var page = 0; page < 10; page++) {
      final uri = _buildUri(
        spec,
        apiKey: apiKey,
        pageToken: pageToken,
      );
      final headers = <String, String>{
        'Accept': 'application/json',
        'User-Agent': 'plawie-app/2.2',
      };
      if (ifNoneMatch != null && page == 0) {
        headers['If-None-Match'] = ifNoneMatch;
      }
      if (spec.auth == ProviderDiscoveryAuth.bearer && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      } else if (spec.auth == ProviderDiscoveryAuth.anthropicApiKey &&
          apiKey.isNotEmpty) {
        headers['x-api-key'] = apiKey;
        headers['anthropic-version'] = '2023-06-01';
      } else if (spec.auth == ProviderDiscoveryAuth.veniceWalletIdentity) {
        headers['X-Sign-In-With-X'] = await _veniceIdentityHeader(uri);
      }

      final response = await _getBounded(spec, uri, headers);
      etag ??= _safeEtag(response.headers['etag']);
      if (response.statusCode == 304) {
        return const _ProviderFetchResult.notModified();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProviderDiscoveryException(
          providerId: spec.providerId,
          code: _discoveryErrorCode(response.statusCode, auth: spec.auth),
          message: _discoveryErrorMessage(response.statusCode, auth: spec.auth),
          statusCode: response.statusCode,
        );
      }

      final decoded = _decodeObject(response.body, spec.providerId);
      final items = _itemsFor(spec.format, decoded);
      for (final item in items) {
        final model = _parseModel(spec, item);
        if (model != null) discovered.putIfAbsent(model.id, () => model);
      }

      if (spec.format != ProviderDiscoveryFormat.googleModels) break;
      final next = decoded['nextPageToken'];
      if (next is! String || next.trim().isEmpty) break;
      pageToken = next.trim();
    }

    return _ProviderFetchResult(
      models: discovered.values.toList(growable: false),
      etag: etag,
    );
  }

  Future<String> _veniceIdentityHeader(Uri uri) async {
    try {
      return await _veniceWalletAuth.authorize('GET', uri);
    } on VeniceWalletAuthException {
      rethrow;
    } catch (_) {
      throw const ProviderDiscoveryException(
        providerId: 'venice',
        code: 'wallet_auth_failed',
        message: 'The secure wallet could not authorize Venice discovery.',
      );
    }
  }

  Future<http.Response> _getBounded(
    ProviderDiscoverySpec spec,
    Uri uri,
    Map<String, String> headers,
  ) async {
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers.addAll(headers);
    final streamed = await _client.send(request).timeout(_timeout);
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in streamed.stream.timeout(_timeout)) {
      length += chunk.length;
      if (length > _maxCatalogResponseBytes) {
        throw ProviderDiscoveryException(
          providerId: spec.providerId,
          code: 'response_too_large',
          message: 'The provider model catalog exceeded the safe size limit.',
        );
      }
      bytes.add(chunk);
    }
    return http.Response.bytes(
      bytes.takeBytes(),
      streamed.statusCode,
      headers: streamed.headers,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
      request: request,
    );
  }

  Uri _buildUri(
    ProviderDiscoverySpec spec, {
    required String apiKey,
    String? pageToken,
  }) {
    final uri = Uri.parse(spec.endpoint);
    final query = <String, String>{
      ...uri.queryParameters,
      if (spec.auth == ProviderDiscoveryAuth.googleQueryKey) 'key': apiKey,
      if (pageToken != null) 'pageToken': pageToken,
    };
    return query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeObject(String body, String providerId) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    throw ProviderDiscoveryException(
      providerId: providerId,
      code: 'invalid_response',
      message: 'The provider returned invalid model metadata.',
    );
  }

  List<Map<dynamic, dynamic>> _itemsFor(
    ProviderDiscoveryFormat format,
    Map<String, dynamic> decoded,
  ) {
    final raw = decoded['data'] ?? decoded['models'];
    if (raw is! List) {
      throw const ProviderDiscoveryException(
        providerId: 'unknown',
        code: 'invalid_response',
        message: 'The provider returned no model list.',
      );
    }
    return raw.whereType<Map>().toList(growable: false);
  }

  DynamicModelRecord? _parseModel(
    ProviderDiscoverySpec spec,
    Map<dynamic, dynamic> raw,
  ) {
    final modelSpec = raw['model_spec'] is Map
        ? raw['model_spec'] as Map<dynamic, dynamic>
        : const <dynamic, dynamic>{};
    final modelCapabilities = modelSpec['capabilities'] is Map
        ? modelSpec['capabilities'] as Map<dynamic, dynamic>
        : const <dynamic, dynamic>{};
    var sourceId = (raw['id'] ?? raw['name'])?.toString().trim() ?? '';
    if (spec.format == ProviderDiscoveryFormat.googleModels &&
        sourceId.startsWith('models/')) {
      sourceId = sourceId.substring('models/'.length);
    }
    if (!_isSafeSourceModelId(sourceId) ||
        !_isChatCandidate(spec, raw, sourceId)) {
      return null;
    }

    final providerId = spec.providerId;
    final id = _namespacedModelId(providerId, sourceId);
    final staticModel = ModelProviderCatalog.modelById(id);
    final supportsToolCalls = _toolSupport(raw);
    final supportsVision = _visionSupport(raw);
    final effectiveSupportsToolCalls =
        supportsToolCalls ?? staticModel?.supportsToolCalls;
    final toolReadiness = supportsToolCalls == false ||
            staticModel?.toolPolicy == ModelToolPolicy.disabled
        ? ModelToolReadiness.incompatible
        : effectiveSupportsToolCalls == true
            ? ModelToolReadiness.providerAdvertised
            : ModelToolReadiness.unknown;
    final deprecationDate = _providerDeprecationDate(raw);
    final deprecated =
        deprecationDate != null && !deprecationDate.isAfter(_clock().toUtc());
    final capabilities = <String>{
      ..._stringList(raw['capabilities']),
      ..._stringList(raw['supported_parameters']),
      ..._stringList(raw['categories']),
      ...modelCapabilities.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString()),
      ..._modalities(raw),
      if (supportsToolCalls == true) 'tool-calls',
      if (supportsVision == true) 'vision',
      if (modelCapabilities['supportsReasoning'] == true) 'reasoning',
    };

    return DynamicModelRecord(
      id: id,
      providerId: providerId,
      label: (modelSpec['name'] ??
              raw['displayName'] ??
              raw['name'] ??
              raw['id'] ??
              sourceId)
          .toString()
          .trim(),
      route: ModelRouteKind.cloud,
      providerModelId: sourceId,
      description: (raw['description'] ?? modelSpec['description'] ?? '')
          .toString()
          .trim(),
      sourceModelId: sourceId,
      capabilities: capabilities,
      supportsToolCalls: effectiveSupportsToolCalls,
      supportsVision: supportsVision ?? staticModel?.supportsVision,
      toolPolicy: supportsToolCalls == false
          ? ModelToolPolicy.disabled
          : staticModel?.toolPolicy == ModelToolPolicy.reliable
              ? ModelToolPolicy.reliable
              : ModelToolPolicy.variable,
      chatReadiness: ModelChatReadiness.providerAdvertised,
      toolReadiness: toolReadiness,
      advertisedContextWindow: _firstPositiveInt(<dynamic>[
        raw['context_length'],
        raw['inputTokenLimit'],
        raw['contextWindow'],
        raw['context_window'],
        modelSpec['availableContextTokens'],
        (raw['top_provider'] as Map?)?['context_length'],
      ]),
      advertisedMaxOutputTokens: _firstPositiveInt(<dynamic>[
        raw['max_output_tokens'],
        raw['max_output'],
        raw['outputTokenLimit'],
        modelSpec['maxOutputTokens'],
        (raw['top_provider'] as Map?)?['max_completion_tokens'],
      ]),
      deprecationDate: deprecationDate,
      recommended: staticModel?.recommended ?? false,
      liveAvailable: !deprecated,
      unavailableReason: deprecated
          ? 'This provider retired the model on ${deprecationDate.toIso8601String().split('T').first}.'
          : null,
    );
  }

  DateTime? _providerDeprecationDate(Map<dynamic, dynamic> raw) {
    for (final value in <dynamic>[
      raw['expiration_date'],
      raw['deprecation_date'],
      raw['deprecated_at'],
    ]) {
      if (value is! String || value.trim().isEmpty) continue;
      final normalized = value.trim();
      final dateOnly =
          RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(normalized);
      final parsed = dateOnly == null
          ? DateTime.tryParse(normalized)
          : DateTime.utc(
              int.parse(dateOnly.group(1)!),
              int.parse(dateOnly.group(2)!),
              int.parse(dateOnly.group(3)!),
            );
      if (parsed != null) return parsed.toUtc();
    }
    return null;
  }

  DynamicProviderRecord _connectedProvider(
    String providerId, {
    required DynamicProviderRecord? cachedProvider,
    required List<DynamicModelRecord> models,
    required String? etag,
    required DateTime refreshedAt,
  }) {
    final fallback = cachedProvider ?? _staticProvider(providerId);
    final defaultModel = <String?>[
      fallback.defaultModelId,
      models.firstOrNull?.id,
    ].firstWhere(
      (id) => id != null && models.any((model) => model.id == id),
      orElse: () => null,
    );
    return DynamicProviderRecord(
      id: providerId,
      label: fallback.label,
      subtitle: fallback.subtitle,
      description: fallback.description,
      authenticationMode: fallback.authenticationMode,
      defaultModelId: defaultModel,
      connectionState: fallback.authenticationMode ==
              ProviderAuthenticationMode.walletIdentity
          ? DynamicProviderConnectionState.unknown
          : DynamicProviderConnectionState.connected,
      catalogState: DynamicProviderCatalogState.fresh,
      source: 'provider-api',
      etag: etag,
      lastRefreshedAt: refreshedAt,
      models: models,
    );
  }

  DynamicCatalogSnapshot _replaceProvider(
    DynamicCatalogSnapshot base,
    DynamicProviderRecord provider, {
    required DateTime now,
    required DynamicCatalogSnapshotState state,
    required String source,
    required String? errorMessage,
  }) {
    final providers = <DynamicProviderRecord>[
      for (final existing in base.providers)
        if (existing.id == provider.id) provider else existing,
    ];
    if (!providers.any((existing) => existing.id == provider.id)) {
      providers.add(provider);
    }
    return DynamicCatalogSnapshot(
      schemaVersion: DynamicCatalogSnapshot.currentSchemaVersion,
      snapshotId: base.snapshotId,
      state: state,
      updatedAt:
          state == DynamicCatalogSnapshotState.fresh ? now : base.updatedAt,
      expiresAt: state == DynamicCatalogSnapshotState.fresh
          ? now.add(_cacheTtl)
          : base.expiresAt,
      providers: providers,
      source: source,
      errorMessage: errorMessage,
    );
  }

  DynamicProviderRecord _staticProvider(String providerId) {
    final option = ModelProviderCatalog.providerById(providerId);
    if (option == null) {
      throw ProviderDiscoveryException(
        providerId: providerId,
        code: 'unsupported_provider',
        message: 'Model discovery is not available for this provider yet.',
      );
    }
    return DynamicProviderRecord.fromStatic(option);
  }

  bool _isChatCandidate(
    ProviderDiscoverySpec spec,
    Map<dynamic, dynamic> raw,
    String sourceId,
  ) {
    final lower = sourceId.toLowerCase();
    const nonChatFragments = <String>[
      'embedding',
      'moderation',
      'whisper',
      'transcription',
      'text-to-speech',
      'tts-',
      'dall-e',
    ];
    if (nonChatFragments.any(lower.contains)) return false;

    if (spec.format == ProviderDiscoveryFormat.blockRunModels &&
        raw['available'] == false) {
      return false;
    }
    if (spec.format == ProviderDiscoveryFormat.veniceModels) {
      final type = raw['type']?.toString().trim().toLowerCase() ?? '';
      if (type.isNotEmpty && type != 'text') return false;
    }

    if (spec.format == ProviderDiscoveryFormat.googleModels) {
      final methods = _stringList(raw['supportedGenerationMethods']);
      if (methods.isNotEmpty && !methods.contains('generateContent')) {
        return false;
      }
    }
    final outputModalities = _stringList(
      (raw['architecture'] as Map?)?['output_modalities'] ??
          raw['output_modalities'],
    );
    if (outputModalities.isNotEmpty &&
        !outputModalities.any((value) => value.toLowerCase() == 'text')) {
      return false;
    }
    return true;
  }

  bool? _toolSupport(Map<dynamic, dynamic> raw) {
    final explicit = raw['supportsToolCalls'];
    if (explicit is bool) return explicit;
    final modelSpec = raw['model_spec'];
    final nestedCapabilities =
        modelSpec is Map ? modelSpec['capabilities'] : null;
    if (nestedCapabilities is Map) {
      final nested = nestedCapabilities['supportsFunctionCalling'] ??
          nestedCapabilities['supportsToolCalls'];
      if (nested is bool) return nested;
    }
    final parameters = <String>{
      ..._stringList(raw['supported_parameters']),
      ..._stringList(raw['categories']),
      ..._stringList(raw['capabilities']),
    }.map((value) => value.toLowerCase()).toSet();
    if (parameters.any(
      (value) => value.contains('tool') || value.contains('function'),
    )) {
      return true;
    }
    return null;
  }

  bool? _visionSupport(Map<dynamic, dynamic> raw) {
    final modelSpec = raw['model_spec'];
    final nestedCapabilities =
        modelSpec is Map ? modelSpec['capabilities'] : null;
    if (nestedCapabilities is Map &&
        nestedCapabilities['supportsVision'] is bool) {
      return nestedCapabilities['supportsVision'] as bool;
    }
    final modalities = _modalities(raw)
        .map((value) => value.toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (modalities.isEmpty) return null;
    return modalities.any((value) => value.contains('image'));
  }

  Set<String> _modalities(Map<dynamic, dynamic> raw) {
    final architecture = raw['architecture'];
    return <String>{
      ..._stringList(raw['input_modalities']),
      ..._stringList(raw['output_modalities']),
      ..._stringList(raw['modalities']),
      if (architecture is Map) ..._stringList(architecture['input_modalities']),
      if (architecture is Map)
        ..._stringList(architecture['output_modalities']),
    };
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  int? _firstPositiveInt(List<dynamic> values) {
    for (final value in values) {
      if (value is num && value > 0) return value.toInt();
    }
    return null;
  }

  String _namespacedModelId(String providerId, String sourceId) {
    final normalized = sourceId.trim();
    return normalized == providerId || normalized.startsWith('$providerId/')
        ? normalized
        : '$providerId/$normalized';
  }

  bool _isSafeSourceModelId(String sourceId) {
    final normalized = sourceId.trim();
    return normalized.isNotEmpty &&
        normalized.length <= 220 &&
        !normalized.contains('..') &&
        !normalized.contains(RegExp(r'[\u0000-\u001F\u007F]'));
  }
}

class _ProviderFetchResult {
  const _ProviderFetchResult({
    this.models = const <DynamicModelRecord>[],
    this.etag,
    this.notModified = false,
  });

  const _ProviderFetchResult.notModified() : this(notModified: true);

  final List<DynamicModelRecord> models;
  final String? etag;
  final bool notModified;
}

String _discoveryErrorCode(
  int statusCode, {
  ProviderDiscoveryAuth? auth,
}) {
  if (statusCode >= 300 && statusCode < 400) return 'redirect_rejected';
  if ((statusCode == 401 || statusCode == 403) &&
      auth == ProviderDiscoveryAuth.veniceWalletIdentity) {
    return 'wallet_authentication_rejected';
  }
  if (statusCode == 401 || statusCode == 403) return 'authentication_required';
  if (statusCode == 429) return 'rate_limited';
  if (statusCode >= 500) return 'provider_unavailable';
  return 'http_$statusCode';
}

String _discoveryErrorMessage(
  int statusCode, {
  ProviderDiscoveryAuth? auth,
}) {
  if (statusCode >= 300 && statusCode < 400) {
    return 'The provider attempted to redirect model discovery.';
  }
  if ((statusCode == 401 || statusCode == 403) &&
      auth == ProviderDiscoveryAuth.veniceWalletIdentity) {
    return 'Venice rejected the fresh secure-wallet identity.';
  }
  if (statusCode == 401 || statusCode == 403) {
    return 'The provider rejected the saved API key.';
  }
  if (statusCode == 429) {
    return 'The provider is rate limiting model discovery.';
  }
  if (statusCode >= 500) return 'The provider model service is unavailable.';
  return 'The provider rejected the model discovery request.';
}

String? _safeEtag(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty ||
      normalized.length > 256 ||
      normalized.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
    return null;
  }
  return normalized;
}

DynamicProviderConnectionState _failureConnectionState(String code) {
  if (code == 'configuration_required') {
    return DynamicProviderConnectionState.needsConfiguration;
  }
  if (code == 'wallet_not_ready' || code == 'provider_unavailable') {
    return DynamicProviderConnectionState.unavailable;
  }
  return DynamicProviderConnectionState.error;
}

String _safeErrorMessage(String message) {
  final compact = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return 'Model discovery failed.';
  final redacted = compact.replaceAllMapped(
    RegExp(
      r'\b(api[-_ ]?key|token|secret|password|authorization)\b\s*[:=]\s*[^,\s]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=[redacted]',
  );
  return redacted.length <= 240 ? redacted : '${redacted.substring(0, 239)}…';
}
