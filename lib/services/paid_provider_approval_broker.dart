import 'dart:async';

import 'paid_provider_proxy_models.dart';

enum PaidProviderApprovalDecision {
  approved,
  cancelled,
  expired,
  appBackgrounded,
}

class PaidProviderApprovalException implements Exception {
  const PaidProviderApprovalException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PaidProviderApprovalException($code): $message';
}

class PendingPaidProviderApproval {
  const PendingPaidProviderApproval({
    required this.intentId,
    required this.provider,
    required this.modelId,
    required this.amountUnits,
    required this.asset,
    required this.network,
    required this.payTo,
    required this.resource,
    required this.expiresAt,
    required this.requestFingerprint,
    required this.reason,
  });

  final String intentId;
  final PaidProviderId provider;
  final String modelId;
  final String amountUnits;
  final String asset;
  final String network;
  final String payTo;
  final Uri resource;
  final DateTime expiresAt;
  final String requestFingerprint;
  final String reason;

  Map<String, dynamic> toAgentJson() => <String, dynamic>{
        'intentId': intentId,
        'provider': provider.wireName,
        'modelId': modelId,
        'amountUnits': amountUnits,
        'asset': asset,
        'network': network,
        'payTo': payTo,
        'resource': resource.toString(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'requestFingerprint': requestFingerprint,
        'reason': reason,
        'mayApproveOrSpend': false,
      };
}

/// Pauses one paid provider request while the canonical foreground UI reviews
/// it. Agent tools can observe only redacted payment status and have no route
/// to [approve] or [cancel]. Leaving the foreground cancels the pending intent.
class PaidProviderApprovalBroker {
  PaidProviderApprovalBroker({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static final PaidProviderApprovalBroker instance =
      PaidProviderApprovalBroker();

  final DateTime Function() _clock;
  final StreamController<PendingPaidProviderApproval> _controller =
      StreamController<PendingPaidProviderApproval>.broadcast();

  bool _appForeground = false;
  PendingPaidProviderApproval? _active;
  Completer<PaidProviderApprovalDecision>? _decision;
  Timer? _expiryTimer;
  bool _closed = false;

  Stream<PendingPaidProviderApproval> get approvals => _controller.stream;
  PendingPaidProviderApproval? get activeApproval => _active;
  bool get hasVisibleListener =>
      !_closed && _appForeground && _controller.hasListener;

  void markAppForeground() {
    if (_closed) return;
    _appForeground = true;
  }

  void markAppBackground() {
    _appForeground = false;
    _complete(PaidProviderApprovalDecision.appBackgrounded);
  }

  Future<PaidProviderApprovalDecision> requestApproval(
    PendingPaidProviderApproval approval,
  ) async {
    if (_closed || !_appForeground || !_controller.hasListener) {
      throw const PaidProviderApprovalException(
        'approval_ui_unavailable',
        'The visible BlockRun payment approval UI is unavailable.',
      );
    }
    if (_active != null || _decision != null) {
      throw const PaidProviderApprovalException(
        'approval_busy',
        'Another paid-provider approval is already active.',
      );
    }
    final now = _clock().toUtc();
    if (!approval.expiresAt.toUtc().isAfter(now)) {
      return PaidProviderApprovalDecision.expired;
    }
    _active = approval;
    final completer = Completer<PaidProviderApprovalDecision>();
    _decision = completer;
    final remaining = approval.expiresAt.toUtc().difference(now);
    _expiryTimer = Timer(remaining, () {
      _complete(PaidProviderApprovalDecision.expired);
    });
    _controller.add(approval);

    try {
      return await completer.future;
    } finally {
      if (identical(_decision, completer)) {
        _expiryTimer?.cancel();
        _expiryTimer = null;
        _decision = null;
        _active = null;
      }
    }
  }

  void approve(String intentId) {
    _requireActive(intentId);
    if (!_appForeground || !_controller.hasListener) {
      throw const PaidProviderApprovalException(
        'approval_ui_unavailable',
        'The visible BlockRun payment approval UI is unavailable.',
      );
    }
    _complete(PaidProviderApprovalDecision.approved);
  }

  void cancel(String intentId) {
    _requireActive(intentId);
    _complete(PaidProviderApprovalDecision.cancelled);
  }

  void _requireActive(String intentId) {
    final active = _active;
    if (active == null ||
        active.intentId != intentId ||
        _decision?.isCompleted != false) {
      throw const PaidProviderApprovalException(
        'approval_not_active',
        'The paid-provider approval is no longer active.',
      );
    }
  }

  void _complete(PaidProviderApprovalDecision result) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final decision = _decision;
    if (decision != null && !decision.isCompleted) decision.complete(result);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _appForeground = false;
    _complete(PaidProviderApprovalDecision.appBackgrounded);
    await _controller.close();
  }
}
