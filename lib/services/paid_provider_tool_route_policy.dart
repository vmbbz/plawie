import 'model_capability_receipt.dart';
import 'model_provider_catalog.dart';
import 'paid_provider_proxy_models.dart';
import 'paid_provider_tool_probe_authorization.dart';

/// Enforces exact-model tool quarantine at the paid-provider transport edge.
///
/// Unknown/advertised routes remain testable and real successful foreground
/// turns can promote them. Only a current `incompatible` receipt removes tool
/// definitions, and the explicit foreground probe is the sole bypass so a
/// repaired route can prove itself again.
class PaidProviderToolRoutePolicy {
  PaidProviderToolRoutePolicy({
    ModelCapabilityReceiptRepository? receipts,
    PaidProviderToolProbeAuthorization? probeAuthorization,
  })  : _receipts = receipts ?? ModelCapabilityReceiptRepository(),
        _probeAuthorization =
            probeAuthorization ?? PaidProviderToolProbeAuthorization.instance;

  final ModelCapabilityReceiptRepository _receipts;
  final PaidProviderToolProbeAuthorization _probeAuthorization;

  Future<Map<String, dynamic>> apply(
    Map<String, dynamic> request, {
    required PaidProviderId provider,
  }) async {
    if (request['tools'] is! List || (request['tools'] as List).isEmpty) {
      return request;
    }
    final canonical = _canonicalModelId(request['model'], provider: provider);
    if (canonical == null) return request;
    final receipt = await _receipts.latestToolReceiptForModel(canonical);
    if (receipt?.toolEvidence != ModelToolEvidence.incompatible) {
      return request;
    }
    if (_probeAuthorization.consumeIfAuthorized(
      provider: provider,
      modelId: canonical,
    )) {
      return request;
    }

    final copied = Map<String, dynamic>.from(request)
      ..remove('tools')
      ..remove('tool_choice')
      ..remove('parallel_tool_calls');
    return copied;
  }

  static String? _canonicalModelId(
    Object? rawModel, {
    required PaidProviderId provider,
  }) {
    final value = rawModel?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final prefix = '${provider.wireName}/';
    final candidate = value.startsWith(prefix) ? value : '$prefix$value';
    try {
      final canonical = ModelProviderCatalog.canonicalizeModelId(candidate);
      return canonical.startsWith(prefix) ? canonical : null;
    } on FormatException {
      return null;
    }
  }
}
