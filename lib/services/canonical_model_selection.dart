import 'dart:convert';

import 'dynamic_model_catalog.dart';
import 'model_provider_catalog.dart';

/// Immutable identity for one user-selected model route.
///
/// The legacy configured-model string remains the Gateway compatibility value,
/// while this receipt keeps the provider, upstream ID, and display label bound
/// together from the picker through the chat header and send preflight.
class CanonicalModelSelection {
  const CanonicalModelSelection({
    required this.providerId,
    required this.namespacedModelId,
    required this.upstreamModelId,
    required this.displayLabel,
    required this.routeKind,
    this.connectionId,
    this.catalogRevision,
    this.capabilityAssessmentId,
  });

  final String providerId;
  final String namespacedModelId;
  final String upstreamModelId;
  final String displayLabel;
  final ModelRouteKind routeKind;
  final String? connectionId;
  final String? catalogRevision;
  final String? capabilityAssessmentId;

  bool matchesModelId(String modelId) =>
      namespacedModelId == ModelProviderCatalog.canonicalizeModelId(modelId);

  factory CanonicalModelSelection.fromDynamic(
    DynamicModelRecord model, {
    String? connectionId,
    String? catalogRevision,
    String? capabilityAssessmentId,
  }) {
    return CanonicalModelSelection(
      providerId: model.providerId,
      namespacedModelId: model.id,
      upstreamModelId: model.gatewayModelId,
      displayLabel: model.label,
      routeKind: model.route,
      connectionId: connectionId,
      catalogRevision: catalogRevision,
      capabilityAssessmentId:
          capabilityAssessmentId ?? model.capabilityAssessmentId,
    )..validate();
  }

  factory CanonicalModelSelection.fromModelId(String modelId) {
    final canonical = ModelProviderCatalog.canonicalizeModelId(modelId);
    final staticModel = ModelProviderCatalog.modelById(canonical);
    final separator = canonical.indexOf('/');
    final providerId = separator > 0
        ? canonical.substring(0, separator)
        : ModelProviderCatalog.isDirectLocalModelId(canonical)
            ? 'local-llm'
            : 'agent';
    final upstreamModelId = separator > 0 && separator < canonical.length - 1
        ? canonical.substring(separator + 1)
        : canonical;
    return CanonicalModelSelection(
      providerId: providerId,
      namespacedModelId: canonical,
      upstreamModelId: staticModel?.providerModelId ?? upstreamModelId,
      displayLabel:
          staticModel?.label ?? ModelProviderCatalog.labelForModel(canonical),
      routeKind: staticModel?.route ??
          (ModelProviderCatalog.isDirectLocalModelId(canonical)
              ? ModelRouteKind.onDevice
              : ModelRouteKind.cloud),
    )..validate();
  }

  factory CanonicalModelSelection.fromJson(Map<dynamic, dynamic> raw) {
    final routeName = _requiredText(raw, 'routeKind');
    final selection = CanonicalModelSelection(
      providerId: _requiredText(raw, 'providerId'),
      namespacedModelId: _requiredText(raw, 'namespacedModelId'),
      upstreamModelId: _requiredText(raw, 'upstreamModelId'),
      displayLabel: _requiredText(raw, 'displayLabel'),
      routeKind: ModelRouteKind.values.firstWhere(
        (route) => route.name == routeName,
        orElse: () => throw const FormatException('Unknown model route.'),
      ),
      connectionId: _optionalText(raw, 'connectionId'),
      catalogRevision: _optionalText(raw, 'catalogRevision'),
      capabilityAssessmentId: _optionalText(raw, 'capabilityAssessmentId'),
    );
    selection.validate();
    return selection;
  }

  static CanonicalModelSelection? tryDecode(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      return CanonicalModelSelection.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'providerId': providerId,
        'namespacedModelId': namespacedModelId,
        'upstreamModelId': upstreamModelId,
        'displayLabel': displayLabel,
        'routeKind': routeKind.name,
        if (connectionId != null) 'connectionId': connectionId,
        if (catalogRevision != null) 'catalogRevision': catalogRevision,
        if (capabilityAssessmentId != null)
          'capabilityAssessmentId': capabilityAssessmentId,
      };

  String encode() => jsonEncode(toJson());

  void validate() {
    for (final entry in <String, String>{
      'providerId': providerId,
      'namespacedModelId': namespacedModelId,
      'upstreamModelId': upstreamModelId,
      'displayLabel': displayLabel,
    }.entries) {
      final value = entry.value.trim();
      if (value.isEmpty ||
          value.length > 240 ||
          value.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
        throw FormatException('Invalid canonical model ${entry.key}.');
      }
    }
    final prefix = '$providerId/';
    if (!namespacedModelId.startsWith(prefix) ||
        namespacedModelId.substring(prefix.length) != upstreamModelId) {
      throw const FormatException(
        'Canonical model provider/upstream identity does not match.',
      );
    }
  }
}

String _requiredText(Map<dynamic, dynamic> raw, String key) {
  final value = raw[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Canonical model field $key is required.');
  }
  return value.trim();
}

String? _optionalText(Map<dynamic, dynamic> raw, String key) {
  final value = raw[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Canonical model field $key must be text.');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
