import 'dart:async';

import 'keeperhub_execution_models.dart';
import 'keeperhub_models.dart';

enum KeeperHubApprovalDecision {
  approved,
  cancelled,
  expired,
  appBackgrounded,
}

class PendingKeeperHubApproval {
  const PendingKeeperHubApproval({
    required this.intentId,
    required this.personalWalletAddress,
    required this.agentWalletAddress,
    required this.chainId,
    required this.amount,
    required this.reason,
    required this.simulation,
    required this.simulationFingerprint,
    required this.idempotencyKey,
    required this.expiresAt,
  });

  final String intentId;
  final String personalWalletAddress;
  final String agentWalletAddress;
  final int chainId;
  final String amount;
  final String reason;
  final KeeperHubSimulation simulation;
  final String simulationFingerprint;
  final String idempotencyKey;
  final DateTime expiresAt;

  Map<String, dynamic> toAgentJson() => <String, dynamic>{
        'intentId': intentId,
        'agentWalletAddress': agentWalletAddress,
        'chainId': chainId,
        'amount': amount,
        'reason': reason,
        'simulation': simulation.toJson(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'mayApproveOrExecute': false,
      };
}

class KeeperHubApprovalBroker {
  KeeperHubApprovalBroker({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static final KeeperHubApprovalBroker instance = KeeperHubApprovalBroker();

  final DateTime Function() _clock;
  final StreamController<PendingKeeperHubApproval> _controller =
      StreamController<PendingKeeperHubApproval>.broadcast();
  PendingKeeperHubApproval? _active;
  Completer<KeeperHubApprovalDecision>? _decision;
  Timer? _expiryTimer;
  bool _foreground = false;
  bool _closed = false;

  Stream<PendingKeeperHubApproval> get approvals => _controller.stream;
  PendingKeeperHubApproval? get activeApproval => _active;

  void markAppForeground() {
    if (!_closed) _foreground = true;
  }

  void markAppBackground() {
    _foreground = false;
    _complete(KeeperHubApprovalDecision.appBackgrounded);
  }

  Future<KeeperHubApprovalDecision> requestApproval(
    PendingKeeperHubApproval approval,
  ) async {
    if (_closed || !_foreground || !_controller.hasListener) {
      throw const KeeperHubException(
        'approval_ui_unavailable',
        'The visible Agent Wallet approval UI is unavailable.',
      );
    }
    if (_active != null || _decision != null) {
      throw const KeeperHubException(
        'approval_busy',
        'Another Agent Wallet approval is already active.',
      );
    }
    final now = _clock().toUtc();
    if (!approval.expiresAt.toUtc().isAfter(now)) {
      return KeeperHubApprovalDecision.expired;
    }
    _active = approval;
    final completer = Completer<KeeperHubApprovalDecision>();
    _decision = completer;
    _expiryTimer = Timer(approval.expiresAt.toUtc().difference(now), () {
      _complete(KeeperHubApprovalDecision.expired);
    });
    _controller.add(approval);
    try {
      return await completer.future;
    } finally {
      if (identical(_decision, completer)) {
        _expiryTimer?.cancel();
        _expiryTimer = null;
        _active = null;
        _decision = null;
      }
    }
  }

  void approve(String intentId) {
    _requireActive(intentId);
    if (!_foreground || !_controller.hasListener) {
      throw const KeeperHubException(
        'approval_ui_unavailable',
        'The visible Agent Wallet approval UI is unavailable.',
      );
    }
    _complete(KeeperHubApprovalDecision.approved);
  }

  void cancel(String intentId) {
    _requireActive(intentId);
    _complete(KeeperHubApprovalDecision.cancelled);
  }

  void _requireActive(String intentId) {
    if (_active?.intentId != intentId || _decision?.isCompleted != false) {
      throw const KeeperHubException(
        'approval_not_active',
        'The Agent Wallet approval is no longer active.',
      );
    }
  }

  void _complete(KeeperHubApprovalDecision decision) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (_decision?.isCompleted == false) _decision!.complete(decision);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    markAppBackground();
    await _controller.close();
  }
}
