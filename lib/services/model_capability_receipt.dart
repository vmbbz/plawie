import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../constants.dart';
import 'gateway_tool_catalog.dart';
import 'model_provider_catalog.dart';
import 'preferences_service.dart';
import 'provider_turn_failure.dart';

enum ModelCapabilityReceiptSource { shipped, localTurn, explicitProbe }

enum ModelChatEvidence { none, verified, failed }

enum ModelToolEvidence { none, schemaAccepted, loopVerified, incompatible }

/// Non-secret proof about one exact provider/model compatibility route.
/// Prompts, arguments, results, signatures, credentials, and payment proofs
/// are deliberately not representable in this record.
class ModelCapabilityReceipt {
  const ModelCapabilityReceipt({
    required this.assessmentId,
    required this.providerId,
    required this.namespacedModelId,
    required this.upstreamModelId,
    required this.endpointClass,
    required this.gatewayVersion,
    required this.compatibilityProfileVersion,
    required this.toolSchemaDigest,
    required this.streamMode,
    required this.appVersion,
    required this.observedAt,
    required this.source,
    required this.chatEvidence,
    required this.toolEvidence,
    this.expiresAt,
    this.catalogRevision,
    this.sanitizedFailureKind,
    this.detail,
  });

  static const int schemaVersion = 1;
  static const String currentGatewayVersion = '2026.7.1';
  static const String currentCompatibilityProfileVersion = 'provider-tools-v3';
  static const String currentStreamMode = 'gateway-streaming';

  final String assessmentId;
  final String providerId;
  final String namespacedModelId;
  final String upstreamModelId;
  final String endpointClass;
  final String gatewayVersion;
  final String compatibilityProfileVersion;
  final String toolSchemaDigest;
  final String streamMode;
  final String appVersion;
  final DateTime observedAt;
  final DateTime? expiresAt;
  final String? catalogRevision;
  final ModelCapabilityReceiptSource source;
  final ModelChatEvidence chatEvidence;
  final ModelToolEvidence toolEvidence;
  final String? sanitizedFailureKind;
  final String? detail;

  bool isCurrentAt(DateTime now) =>
      gatewayVersion == currentGatewayVersion &&
      compatibilityProfileVersion == currentCompatibilityProfileVersion &&
      toolSchemaDigest == currentToolSchemaDigest &&
      streamMode == currentStreamMode &&
      (expiresAt == null || expiresAt!.isAfter(now.toUtc()));

  bool matchesModel({
    required String providerId,
    required String namespacedModelId,
    required String upstreamModelId,
    required DateTime now,
  }) =>
      this.providerId == providerId &&
      this.namespacedModelId == namespacedModelId &&
      this.upstreamModelId == upstreamModelId &&
      endpointClass == endpointClassFor(providerId) &&
      isCurrentAt(now);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'assessmentId': assessmentId,
        'providerId': providerId,
        'namespacedModelId': namespacedModelId,
        'upstreamModelId': upstreamModelId,
        'endpointClass': endpointClass,
        'gatewayVersion': gatewayVersion,
        'compatibilityProfileVersion': compatibilityProfileVersion,
        'toolSchemaDigest': toolSchemaDigest,
        'streamMode': streamMode,
        'appVersion': appVersion,
        'observedAt': observedAt.toUtc().toIso8601String(),
        if (expiresAt != null)
          'expiresAt': expiresAt!.toUtc().toIso8601String(),
        if (catalogRevision != null) 'catalogRevision': catalogRevision,
        'source': source.name,
        'chatEvidence': chatEvidence.name,
        'toolEvidence': toolEvidence.name,
        if (sanitizedFailureKind != null)
          'sanitizedFailureKind': sanitizedFailureKind,
        if (detail != null) 'detail': detail,
      };

  factory ModelCapabilityReceipt.fromJson(Map<dynamic, dynamic> raw) {
    if (raw['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported capability receipt version.');
    }
    final receipt = ModelCapabilityReceipt(
      assessmentId: _requiredSafeText(raw, 'assessmentId'),
      providerId: _requiredSafeText(raw, 'providerId'),
      namespacedModelId: _requiredSafeText(raw, 'namespacedModelId'),
      upstreamModelId: _requiredSafeText(raw, 'upstreamModelId'),
      endpointClass: _requiredSafeText(raw, 'endpointClass'),
      gatewayVersion: _requiredSafeText(raw, 'gatewayVersion'),
      compatibilityProfileVersion:
          _requiredSafeText(raw, 'compatibilityProfileVersion'),
      toolSchemaDigest: _requiredSafeText(raw, 'toolSchemaDigest'),
      streamMode: _requiredSafeText(raw, 'streamMode'),
      appVersion: _requiredSafeText(raw, 'appVersion'),
      observedAt: _requiredDate(raw, 'observedAt'),
      expiresAt: _optionalDate(raw, 'expiresAt'),
      catalogRevision: _optionalSafeText(raw, 'catalogRevision'),
      source: _enumValue(
        ModelCapabilityReceiptSource.values,
        raw['source'],
        'source',
      ),
      chatEvidence: _enumValue(
          ModelChatEvidence.values, raw['chatEvidence'], 'chatEvidence'),
      toolEvidence: _enumValue(
          ModelToolEvidence.values, raw['toolEvidence'], 'toolEvidence'),
      sanitizedFailureKind: _optionalSafeText(raw, 'sanitizedFailureKind'),
      detail: _optionalSafeText(raw, 'detail', maxLength: 240),
    );
    receipt.validate();
    return receipt;
  }

  void validate() {
    if (namespacedModelId != '$providerId/$upstreamModelId') {
      throw const FormatException('Capability receipt model identity differs.');
    }
    if (endpointClass != endpointClassFor(providerId)) {
      throw const FormatException('Capability receipt endpoint class differs.');
    }
    if (expiresAt != null && !expiresAt!.isAfter(observedAt)) {
      throw const FormatException('Capability receipt expiry is invalid.');
    }
  }

  static String endpointClassFor(String providerId) => switch (providerId) {
        'venice' => 'venice-openai-completions-loopback-v1',
        'blockrun' => 'blockrun-openai-completions-loopback-v1',
        _ => '$providerId-gateway-provider-v1',
      };

  static String get currentToolSchemaDigest {
    final commands = GatewayToolCatalog.mobileNodeAllowCommands.toList()
      ..sort();
    final material = jsonEncode(<String, dynamic>{
      'profile': GatewayToolCatalog.mobileSafeProfile,
      'allow': GatewayToolCatalog.defaultMobileAllowList,
      'nodeCommands': commands,
      'schemaProfile': 'plawie-mobile-tools-v1',
    });
    return sha256.convert(utf8.encode(material)).toString();
  }

  static String assessmentIdFor({
    required String providerId,
    required String upstreamModelId,
    required ModelCapabilityReceiptSource source,
    required DateTime observedAt,
  }) {
    final material = '$providerId\n$upstreamModelId\n${source.name}\n'
        '${observedAt.toUtc().toIso8601String()}\n'
        '$currentCompatibilityProfileVersion\n$currentToolSchemaDigest';
    return sha256.convert(utf8.encode(material)).toString().substring(0, 24);
  }
}

class ModelCapabilityReceiptRepository {
  ModelCapabilityReceiptRepository({PreferencesService? preferences})
      : _preferences = preferences ?? PreferencesService();

  static const int _maxLocalReceipts = 120;
  static const Duration _localReceiptTtl = Duration(days: 30);

  final PreferencesService _preferences;

  Future<List<ModelCapabilityReceipt>> readCurrent({DateTime? now}) async {
    await _preferences.init();
    final timestamp = (now ?? DateTime.now()).toUtc();
    final local = <ModelCapabilityReceipt>[];
    final encoded = _preferences.modelCapabilityReceiptsJson;
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            try {
              final receipt = ModelCapabilityReceipt.fromJson(item);
              if (receipt.isCurrentAt(timestamp)) local.add(receipt);
            } on FormatException {
              // Ignore one malformed/expired non-secret receipt.
            }
          }
        }
      } on FormatException {
        // Corrupt compatibility metadata is disposable and never authoritative.
      }
    }
    return <ModelCapabilityReceipt>[
      ..._shippedReceipts,
      ...local,
    ];
  }

  Future<ModelCapabilityReceipt?> latestForModel(
    String modelId, {
    DateTime? now,
  }) async {
    final canonical = ModelProviderCatalog.canonicalizeModelId(modelId);
    final separator = canonical.indexOf('/');
    if (separator <= 0 || separator == canonical.length - 1) return null;
    final providerId = canonical.substring(0, separator);
    final upstreamModelId = canonical.substring(separator + 1);
    final timestamp = (now ?? DateTime.now()).toUtc();
    final matching = (await readCurrent(now: timestamp))
        .where((receipt) => receipt.matchesModel(
              providerId: providerId,
              namespacedModelId: canonical,
              upstreamModelId: upstreamModelId,
              now: timestamp,
            ))
        .toList(growable: false)
      ..sort(_compareReceiptAuthority);
    return matching.isEmpty ? null : matching.last;
  }

  /// Returns the newest current observation that actually exercised or
  /// rejected tools. A later ordinary chat receipt must not erase a verified
  /// tool loop or lift a quarantine it did not retest.
  Future<ModelCapabilityReceipt?> latestToolReceiptForModel(
    String modelId, {
    DateTime? now,
  }) async {
    final canonical = ModelProviderCatalog.canonicalizeModelId(modelId);
    final separator = canonical.indexOf('/');
    if (separator <= 0 || separator == canonical.length - 1) return null;
    final providerId = canonical.substring(0, separator);
    final upstreamModelId = canonical.substring(separator + 1);
    final timestamp = (now ?? DateTime.now()).toUtc();
    final matching = (await readCurrent(now: timestamp))
        .where((receipt) =>
            receipt.toolEvidence != ModelToolEvidence.none &&
            receipt.matchesModel(
              providerId: providerId,
              namespacedModelId: canonical,
              upstreamModelId: upstreamModelId,
              now: timestamp,
            ))
        .toList(growable: false)
      ..sort(_compareReceiptAuthority);
    return matching.isEmpty ? null : matching.last;
  }

  Future<void> recordSuccessfulTurn({
    required String modelId,
    required bool toolCallObserved,
    required bool toolResultObserved,
    required bool assistantTextObserved,
    String? catalogRevision,
    DateTime? now,
  }) async {
    if (!assistantTextObserved) return;
    final toolEvidence = toolCallObserved && toolResultObserved
        ? ModelToolEvidence.loopVerified
        : ModelToolEvidence.none;
    await _upsert(_newLocalReceipt(
      modelId: modelId,
      chatEvidence: ModelChatEvidence.verified,
      toolEvidence: toolEvidence,
      source: ModelCapabilityReceiptSource.localTurn,
      catalogRevision: catalogRevision,
      now: now,
    ));
  }

  Future<void> recordSuccessfulExplicitProbe({
    required String modelId,
    String? catalogRevision,
    DateTime? now,
  }) async {
    await _upsert(_newLocalReceipt(
      modelId: modelId,
      chatEvidence: ModelChatEvidence.verified,
      toolEvidence: ModelToolEvidence.loopVerified,
      source: ModelCapabilityReceiptSource.explicitProbe,
      catalogRevision: catalogRevision,
      detail:
          'Explicit foreground test completed the exact read-only tool loop.',
      now: now,
    ));
  }

  /// Persists a completed foreground probe that did not satisfy the bounded
  /// tool contract. The reason comes from [ModelToolCompatibilityProbe]'s
  /// closed evaluator vocabulary; no prompt, tool payload, or provider body is
  /// stored in the receipt.
  Future<void> recordFailedExplicitProbe({
    required String modelId,
    required String reason,
    required bool assistantTextObserved,
    String? catalogRevision,
    DateTime? now,
  }) async {
    final sanitizedReason =
        reason.replaceAll(RegExp(r'[\u0000-\u001F\u007F]+'), ' ').trim();
    final boundedReason = sanitizedReason.length <= 180
        ? sanitizedReason
        : '${sanitizedReason.substring(0, 179)}…';
    await _upsert(_newLocalReceipt(
      modelId: modelId,
      chatEvidence: assistantTextObserved
          ? ModelChatEvidence.verified
          : ModelChatEvidence.none,
      toolEvidence: ModelToolEvidence.incompatible,
      source: ModelCapabilityReceiptSource.explicitProbe,
      catalogRevision: catalogRevision,
      failureKind: 'explicitProbeContractFailed',
      detail: 'Explicit tool test failed: $boundedReason',
      now: now,
    ));
  }

  Future<void> recordFailure({
    required String modelId,
    required ProviderTurnFailure failure,
    ModelCapabilityReceiptSource source =
        ModelCapabilityReceiptSource.localTurn,
    String? catalogRevision,
    DateTime? now,
  }) async {
    final toolEvidence = switch (failure.kind) {
      ProviderFailureKind.schemaRejected => ModelToolEvidence.incompatible,
      ProviderFailureKind.replayMetadataMissing =>
        ModelToolEvidence.schemaAccepted,
      _ => ModelToolEvidence.none,
    };
    if (toolEvidence == ModelToolEvidence.none) return;
    await _upsert(_newLocalReceipt(
      modelId: modelId,
      chatEvidence: ModelChatEvidence.none,
      toolEvidence: toolEvidence,
      source: source,
      catalogRevision: catalogRevision,
      failureKind: failure.kind.name,
      detail: failure.kind == ProviderFailureKind.replayMetadataMissing
          ? 'Tool call passed; continuation metadata needs repair.'
          : 'This exact route rejected the mobile tool request.',
      now: now,
    ));
  }

  Future<void> _upsert(ModelCapabilityReceipt receipt) async {
    await _preferences.init();
    final current = await readCurrent();
    final local = current
        .where((item) => item.source != ModelCapabilityReceiptSource.shipped)
        .where((item) => !_isFullySupersededBy(item, receipt))
        .toList(growable: true)
      ..add(receipt)
      ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
    final bounded = local.take(_maxLocalReceipts).map((item) => item.toJson());
    _preferences.modelCapabilityReceiptsJson = jsonEncode(bounded.toList());
  }

  ModelCapabilityReceipt _newLocalReceipt({
    required String modelId,
    required ModelChatEvidence chatEvidence,
    required ModelToolEvidence toolEvidence,
    required ModelCapabilityReceiptSource source,
    String? catalogRevision,
    String? failureKind,
    String? detail,
    DateTime? now,
  }) {
    final canonical = ModelProviderCatalog.canonicalizeModelId(modelId);
    final separator = canonical.indexOf('/');
    if (separator <= 0 || separator == canonical.length - 1) {
      throw const FormatException('Capability model ID must be namespaced.');
    }
    final providerId = canonical.substring(0, separator);
    final upstreamModelId = canonical.substring(separator + 1);
    final observedAt = (now ?? DateTime.now()).toUtc();
    return ModelCapabilityReceipt(
      assessmentId: ModelCapabilityReceipt.assessmentIdFor(
        providerId: providerId,
        upstreamModelId: upstreamModelId,
        source: source,
        observedAt: observedAt,
      ),
      providerId: providerId,
      namespacedModelId: canonical,
      upstreamModelId: upstreamModelId,
      endpointClass: ModelCapabilityReceipt.endpointClassFor(providerId),
      gatewayVersion: ModelCapabilityReceipt.currentGatewayVersion,
      compatibilityProfileVersion:
          ModelCapabilityReceipt.currentCompatibilityProfileVersion,
      toolSchemaDigest: ModelCapabilityReceipt.currentToolSchemaDigest,
      streamMode: ModelCapabilityReceipt.currentStreamMode,
      appVersion: AppConstants.version,
      observedAt: observedAt,
      expiresAt: observedAt.add(_localReceiptTtl),
      catalogRevision: catalogRevision,
      source: source,
      chatEvidence: chatEvidence,
      toolEvidence: toolEvidence,
      sanitizedFailureKind: failureKind,
      detail: detail,
    )..validate();
  }

  static List<ModelCapabilityReceipt> get _shippedReceipts {
    final observedAt = DateTime.utc(2026, 8, 13);
    ModelCapabilityReceipt shipped(
      String upstreamModelId, {
      required ModelChatEvidence chat,
      required ModelToolEvidence tools,
      String? detail,
    }) {
      const providerId = 'venice';
      return ModelCapabilityReceipt(
        assessmentId: ModelCapabilityReceipt.assessmentIdFor(
          providerId: providerId,
          upstreamModelId: upstreamModelId,
          source: ModelCapabilityReceiptSource.shipped,
          observedAt: observedAt,
        ),
        providerId: providerId,
        namespacedModelId: '$providerId/$upstreamModelId',
        upstreamModelId: upstreamModelId,
        endpointClass: ModelCapabilityReceipt.endpointClassFor(providerId),
        gatewayVersion: ModelCapabilityReceipt.currentGatewayVersion,
        compatibilityProfileVersion:
            ModelCapabilityReceipt.currentCompatibilityProfileVersion,
        toolSchemaDigest: ModelCapabilityReceipt.currentToolSchemaDigest,
        streamMode: ModelCapabilityReceipt.currentStreamMode,
        appVersion: AppConstants.version,
        observedAt: observedAt,
        source: ModelCapabilityReceiptSource.shipped,
        chatEvidence: chat,
        toolEvidence: tools,
        detail: detail,
      )..validate();
    }

    return <ModelCapabilityReceipt>[
      shipped(
        'zai-org-glm-5-2',
        chat: ModelChatEvidence.verified,
        tools: ModelToolEvidence.loopVerified,
        detail: 'Verified complete mobile tool loop on a physical device.',
      ),
      shipped(
        'gemini-3-6-flash',
        chat: ModelChatEvidence.verified,
        tools: ModelToolEvidence.schemaAccepted,
        detail: 'Tool call passed; continuation metadata needs repair.',
      ),
      shipped(
        'gemma-4-uncensored',
        chat: ModelChatEvidence.none,
        tools: ModelToolEvidence.incompatible,
        detail: 'This Venice route rejected the mobile tool request.',
      ),
    ];
  }

  static int _compareReceiptAuthority(
    ModelCapabilityReceipt a,
    ModelCapabilityReceipt b,
  ) {
    final shippedOrder = _shippedBaselineOrder(a, b);
    if (shippedOrder != 0) return shippedOrder;
    final observedOrder = a.observedAt.compareTo(b.observedAt);
    if (observedOrder != 0) return observedOrder;
    return a.source.index.compareTo(b.source.index);
  }

  static int _shippedBaselineOrder(
    ModelCapabilityReceipt a,
    ModelCapabilityReceipt b,
  ) {
    final aShipped = a.source == ModelCapabilityReceiptSource.shipped;
    final bShipped = b.source == ModelCapabilityReceiptSource.shipped;
    if (aShipped == bShipped) return 0;
    return aShipped ? -1 : 1;
  }

  static bool _isFullySupersededBy(
    ModelCapabilityReceipt existing,
    ModelCapabilityReceipt incoming,
  ) {
    if (existing.namespacedModelId != incoming.namespacedModelId ||
        existing.endpointClass != incoming.endpointClass) {
      return false;
    }
    final preservesChat = existing.chatEvidence != ModelChatEvidence.none &&
        incoming.chatEvidence == ModelChatEvidence.none;
    final preservesTools = existing.toolEvidence != ModelToolEvidence.none &&
        incoming.toolEvidence == ModelToolEvidence.none;
    return !preservesChat && !preservesTools;
  }
}

T _enumValue<T extends Enum>(List<T> values, dynamic value, String field) {
  if (value is! String) throw FormatException('$field is required.');
  return values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw FormatException('Unknown $field.'),
  );
}

String _requiredSafeText(
  Map<dynamic, dynamic> raw,
  String key, {
  int maxLength = 300,
}) {
  final value = _optionalSafeText(raw, key, maxLength: maxLength);
  if (value == null) throw FormatException('$key is required.');
  return value;
}

String? _optionalSafeText(
  Map<dynamic, dynamic> raw,
  String key, {
  int maxLength = 300,
}) {
  final value = raw[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be text.');
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed.length > maxLength ||
      trimmed.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
    throw FormatException('$key is invalid.');
  }
  return trimmed;
}

DateTime _requiredDate(Map<dynamic, dynamic> raw, String key) {
  final value = _optionalDate(raw, key);
  if (value == null) throw FormatException('$key is required.');
  return value;
}

DateTime? _optionalDate(Map<dynamic, dynamic> raw, String key) {
  final value = raw[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a date.');
  return DateTime.parse(value).toUtc();
}
