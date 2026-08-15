import 'paid_provider_proxy_models.dart';

/// One process-local authorization for the user-confirmed compatibility test.
/// It is never persisted, exposed to the Gateway, or inferred from prompt text.
class PaidProviderToolProbeAuthorization {
  PaidProviderToolProbeAuthorization({
    DateTime Function()? clock,
    this.lifetime = const Duration(minutes: 10),
    this.maxRequests = 8,
  }) : _clock = clock ?? DateTime.now;

  static final PaidProviderToolProbeAuthorization instance =
      PaidProviderToolProbeAuthorization();

  final DateTime Function() _clock;
  final Duration lifetime;
  final int maxRequests;

  _ProbePermit? _permit;

  void authorize({
    required PaidProviderId provider,
    required String modelId,
  }) {
    final canonical = modelId.trim();
    if (!canonical.startsWith('${provider.wireName}/') ||
        canonical.length <= provider.wireName.length + 1 ||
        lifetime <= Duration.zero ||
        maxRequests <= 0) {
      throw ArgumentError('Tool-probe authorization is invalid.');
    }
    final now = _clock().toUtc();
    _permit = _ProbePermit(
      provider: provider,
      modelId: canonical,
      expiresAt: now.add(lifetime),
      remainingRequests: maxRequests,
    );
  }

  bool consumeIfAuthorized({
    required PaidProviderId provider,
    required String modelId,
  }) {
    final permit = _permit;
    final now = _clock().toUtc();
    if (permit == null || !now.isBefore(permit.expiresAt)) {
      _permit = null;
      return false;
    }
    if (permit.provider != provider ||
        permit.modelId != modelId.trim() ||
        permit.remainingRequests <= 0) {
      return false;
    }
    _permit = permit.copyWith(
      remainingRequests: permit.remainingRequests - 1,
    );
    return true;
  }

  void close({required PaidProviderId provider, required String modelId}) {
    final permit = _permit;
    if (permit?.provider == provider && permit?.modelId == modelId.trim()) {
      _permit = null;
    }
  }

  void clear() => _permit = null;
}

class _ProbePermit {
  const _ProbePermit({
    required this.provider,
    required this.modelId,
    required this.expiresAt,
    required this.remainingRequests,
  });

  final PaidProviderId provider;
  final String modelId;
  final DateTime expiresAt;
  final int remainingRequests;

  _ProbePermit copyWith({required int remainingRequests}) => _ProbePermit(
        provider: provider,
        modelId: modelId,
        expiresAt: expiresAt,
        remainingRequests: remainingRequests,
      );
}
