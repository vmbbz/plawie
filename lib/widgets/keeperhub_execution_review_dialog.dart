import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';
import '../services/keeperhub/keeperhub_approval_broker.dart';
import '../services/keeperhub/keeperhub_models.dart';
import '../services/sensitive_approval_surface.dart';

class KeeperHubExecutionApprovalHost extends StatefulWidget {
  const KeeperHubExecutionApprovalHost({
    required this.navigatorKey,
    required this.child,
    this.broker,
    this.approvalSurface,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final KeeperHubApprovalBroker? broker;
  final SensitiveApprovalSurface? approvalSurface;

  @override
  State<KeeperHubExecutionApprovalHost> createState() =>
      _KeeperHubExecutionApprovalHostState();
}

class _KeeperHubExecutionApprovalHostState
    extends State<KeeperHubExecutionApprovalHost> with WidgetsBindingObserver {
  late final KeeperHubApprovalBroker _broker;
  late final SensitiveApprovalSurface _approvalSurface;
  StreamSubscription<PendingKeeperHubApproval>? _subscription;
  Route<dynamic>? _dialogRoute;
  String? _dialogIntentId;
  bool _foreground = false;

  @override
  void initState() {
    super.initState();
    _broker = widget.broker ?? KeeperHubApprovalBroker.instance;
    _approvalSurface =
        widget.approvalSurface ?? SensitiveApprovalSurface.instance;
    WidgetsBinding.instance.addObserver(this);
    _subscription = _broker.approvals.listen(_handleApproval);
    _applyLifecycle(WidgetsBinding.instance.lifecycleState);
  }

  void _applyLifecycle(AppLifecycleState? state) {
    _foreground = state == null || state == AppLifecycleState.resumed;
    if (_foreground) {
      _broker.markAppForeground();
      return;
    }
    _broker.markAppBackground();
    final route = _dialogRoute;
    final navigator = widget.navigatorKey.currentState;
    if (route != null && navigator != null) navigator.removeRoute(route);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _applyLifecycle(state);
  }

  Future<void> _handleApproval(PendingKeeperHubApproval approval) async {
    if (!_foreground ||
        _dialogIntentId != null ||
        _broker.activeApproval?.intentId != approval.intentId) {
      _cancelSafely(approval.intentId);
      return;
    }
    _dialogIntentId = approval.intentId;
    final surfaceOwner = 'keeperhub:${approval.intentId}';
    var surfaceActive = false;
    try {
      surfaceActive = await _approvalSurface.acquire(surfaceOwner);
      if (!surfaceActive ||
          !_foreground ||
          !mounted ||
          _broker.activeApproval?.intentId != approval.intentId) {
        _cancelSafely(approval.intentId);
        return;
      }
      final navigator = widget.navigatorKey.currentState;
      final navigatorContext = widget.navigatorKey.currentContext;
      if (navigator == null ||
          navigatorContext == null ||
          !navigatorContext.mounted) {
        _cancelSafely(approval.intentId);
        return;
      }
      late final DialogRoute<bool> route;
      route = DialogRoute<bool>(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (_) => KeeperHubExecutionReviewDialog(
          approval: approval,
          onApprove: () => navigator.removeRoute(route, true),
          onCancel: () => navigator.removeRoute(route, false),
        ),
      );
      _dialogRoute = route;
      final approved = await navigator.push<bool>(route) ?? false;
      if (approved && _foreground) {
        _approveSafely(approval.intentId);
      } else {
        _cancelSafely(approval.intentId);
      }
    } catch (_) {
      _cancelSafely(approval.intentId);
      _showSecureSurfaceFailure();
    } finally {
      _dialogRoute = null;
      _dialogIntentId = null;
      if (surfaceActive) {
        await _approvalSurface.release(surfaceOwner).catchError((_) {});
      }
    }
  }

  void _approveSafely(String intentId) {
    try {
      _broker.approve(intentId);
    } on KeeperHubException {
      // Background/expiry can win the race with the visible button.
    }
  }

  void _cancelSafely(String intentId) {
    try {
      _broker.cancel(intentId);
    } on KeeperHubException {
      // The broker may already have completed this one-use decision.
    }
  }

  void _showSecureSurfaceFailure() {
    final context = widget.navigatorKey.currentContext;
    if (!mounted || context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Secure Agent Wallet review unavailable. Nothing was authorized.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _broker.markAppBackground();
    unawaited(_subscription?.cancel());
    final intentId = _dialogIntentId;
    if (intentId != null) {
      unawaited(
        _approvalSurface.release('keeperhub:$intentId').catchError((_) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class KeeperHubExecutionReviewDialog extends StatefulWidget {
  const KeeperHubExecutionReviewDialog({
    required this.approval,
    required this.onApprove,
    required this.onCancel,
    this.clock,
    super.key,
  });

  final PendingKeeperHubApproval approval;
  final VoidCallback onApprove;
  final VoidCallback onCancel;
  final DateTime Function()? clock;

  @override
  State<KeeperHubExecutionReviewDialog> createState() =>
      _KeeperHubExecutionReviewDialogState();
}

class _KeeperHubExecutionReviewDialogState
    extends State<KeeperHubExecutionReviewDialog> {
  Timer? _timer;
  late int _secondsRemaining;
  bool _completed = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _remainingSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _completed) return;
      final remaining = _remainingSeconds();
      if (remaining <= 0) {
        _complete(widget.onCancel);
      } else if (remaining != _secondsRemaining) {
        setState(() => _secondsRemaining = remaining);
      }
    });
  }

  int _remainingSeconds() {
    final milliseconds =
        widget.approval.expiresAt.toUtc().difference(_now).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds + 999) ~/ 1000;
  }

  void _complete(VoidCallback callback) {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    callback();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approval = widget.approval;
    final expired = _secondsRemaining <= 0;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(
          Icons.admin_panel_settings_outlined,
          color: AppColors.statusGreen,
          size: 30,
        ),
        title: const Text('Authorize Agent Wallet proof'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _notice(context),
                const SizedBox(height: 16),
                _detail(context, 'ACTION', 'Zero-value self-transfer'),
                _detail(context, 'AMOUNT', approval.amount),
                _detail(
                  context,
                  'NETWORK',
                  'Base Sepolia · chain ${approval.chainId}',
                ),
                _detail(
                  context,
                  'AGENT EXECUTION WALLET',
                  approval.agentWalletAddress,
                  mono: true,
                ),
                _detail(
                  context,
                  'PERSONAL WALLET APPROVER',
                  approval.personalWalletAddress,
                  mono: true,
                ),
                _detail(context, 'REASON', approval.reason),
                _detail(
                  context,
                  'SIMULATION',
                  approval.simulation.success &&
                          !approval.simulation.wouldRevert
                      ? 'Passed · gas estimate ${approval.simulation.gasEstimate}'
                      : 'Unsafe',
                ),
                const SizedBox(height: 8),
                Text(
                  expired
                      ? 'Approval expired'
                      : 'Expires in $_secondsRemaining seconds',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: expired
                            ? Theme.of(context).colorScheme.error
                            : AppColors.statusAmber,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _complete(widget.onCancel),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: expired ? null : () => _complete(widget.onApprove),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Continue to device auth'),
          ),
        ],
      ),
    );
  }

  Widget _notice(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.statusGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.statusGreen.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          'KeeperHub manages the Agent Execution Wallet key. This testnet proof moves 0 ETH. Plawie will request fresh Android authentication before submitting the exact simulated request.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );

  Widget _detail(
    BuildContext context,
    String label,
    String value, {
    bool mono = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.statusGreen,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
            ),
            const SizedBox(height: 3),
            SelectableText(
              value,
              style: mono
                  ? GoogleFonts.robotoMono(fontSize: 11, height: 1.35)
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
}
