import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/native_bridge.dart';
import '../services/paid_provider_approval_broker.dart';
import '../services/paid_provider_proxy_models.dart';
import '../services/paid_provider_turn_authorization_service.dart';

typedef PaidProviderSensitiveUiSetter = Future<void> Function(bool visible);

/// App-scoped owner for paid-provider foreground state and visible approvals.
///
/// The broker remains fail-closed until this widget is mounted, foregrounded,
/// and subscribed. It is deliberately above individual screens so route
/// changes cannot strand a pending approval or create competing dialogs.
class PaidProviderApprovalHost extends StatefulWidget {
  const PaidProviderApprovalHost({
    required this.navigatorKey,
    required this.child,
    this.broker,
    this.turnAuthorization,
    this.setSensitiveUiVisible,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final PaidProviderApprovalBroker? broker;
  final PaidProviderTurnAuthorizationService? turnAuthorization;
  final PaidProviderSensitiveUiSetter? setSensitiveUiVisible;

  @override
  State<PaidProviderApprovalHost> createState() =>
      _PaidProviderApprovalHostState();
}

class _PaidProviderApprovalHostState extends State<PaidProviderApprovalHost>
    with WidgetsBindingObserver {
  late final PaidProviderApprovalBroker _broker;
  late final PaidProviderTurnAuthorizationService _turnAuthorization;
  late final PaidProviderSensitiveUiSetter _setSensitiveUiVisible;
  StreamSubscription<PendingPaidProviderApproval>? _approvalSubscription;
  Route<dynamic>? _dialogRoute;
  String? _dialogIntentId;
  bool _foreground = false;

  @override
  void initState() {
    super.initState();
    _broker = widget.broker ?? PaidProviderApprovalBroker.instance;
    _turnAuthorization = widget.turnAuthorization ??
        PaidProviderTurnAuthorizationService.instance;
    _setSensitiveUiVisible =
        widget.setSensitiveUiVisible ?? NativeBridge.setSensitiveUiVisible;
    WidgetsBinding.instance.addObserver(this);
    _approvalSubscription = _broker.approvals.listen(_handleApproval);
    _applyLifecycle(WidgetsBinding.instance.lifecycleState);
  }

  void _applyLifecycle(AppLifecycleState? state) {
    final foreground = state == null || state == AppLifecycleState.resumed;
    _foreground = foreground;
    if (foreground) {
      _broker.markAppForeground();
      _turnAuthorization.markAppForeground();
      return;
    }

    _broker.markAppBackground();
    _turnAuthorization.markAppBackground();
    final route = _dialogRoute;
    final navigator = widget.navigatorKey.currentState;
    if (route != null && navigator != null) {
      // PopScope blocks back/navigation gestures. Removing the exact captured
      // dialog route is the intentional lifecycle escape hatch.
      navigator.removeRoute(route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _applyLifecycle(state);
  }

  Future<void> _handleApproval(PendingPaidProviderApproval approval) async {
    if (!_foreground ||
        _dialogIntentId != null ||
        _broker.activeApproval?.intentId != approval.intentId) {
      _cancelSafely(approval.intentId);
      return;
    }

    _dialogIntentId = approval.intentId;
    var sensitiveSurfaceActive = false;
    try {
      await _setSensitiveUiVisible(true);
      sensitiveSurfaceActive = true;
      if (!_foreground ||
          !mounted ||
          _broker.activeApproval?.intentId != approval.intentId) {
        _cancelSafely(approval.intentId);
        return;
      }

      final navigatorContext = widget.navigatorKey.currentContext;
      final navigator = widget.navigatorKey.currentState;
      if (navigatorContext == null ||
          !navigatorContext.mounted ||
          navigator == null) {
        _cancelSafely(approval.intentId);
        return;
      }
      late final DialogRoute<bool> route;
      route = DialogRoute<bool>(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PaidProviderApprovalDialog(
            approval: approval,
            onApprove: () => navigator.removeRoute(route, true),
            onCancel: () => navigator.removeRoute(route, false),
          );
        },
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
      if (sensitiveSurfaceActive) {
        await _setSensitiveUiVisible(false).catchError((_) {});
      }
    }
  }

  void _approveSafely(String intentId) {
    try {
      _broker.approve(intentId);
    } on PaidProviderApprovalException {
      // Expiry/background can win the race with the visible button.
    }
  }

  void _cancelSafely(String intentId) {
    try {
      _broker.cancel(intentId);
    } on PaidProviderApprovalException {
      // The broker may already have expired or background-cancelled it.
    }
  }

  void _showSecureSurfaceFailure() {
    if (!mounted) return;
    final context = widget.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Secure payment approval unavailable. No payment was authorized.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _broker.markAppBackground();
    _turnAuthorization.markAppBackground();
    unawaited(_approvalSubscription?.cancel());
    if (_dialogIntentId != null) {
      unawaited(_setSensitiveUiVisible(false).catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class PaidProviderApprovalDialog extends StatefulWidget {
  const PaidProviderApprovalDialog({
    required this.approval,
    required this.onApprove,
    required this.onCancel,
    this.clock,
    super.key,
  });

  final PendingPaidProviderApproval approval;
  final VoidCallback onApprove;
  final VoidCallback onCancel;
  final DateTime Function()? clock;

  @override
  State<PaidProviderApprovalDialog> createState() =>
      _PaidProviderApprovalDialogState();
}

class _PaidProviderApprovalDialogState
    extends State<PaidProviderApprovalDialog> {
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

  void _complete(VoidCallback action) {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    action();
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
        title: const Text('Approve exact AI payment'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatUsdcUnits(approval.amountUnits)} ${approval.asset}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _Detail(label: 'Provider', value: _providerLabel(approval)),
                _Detail(label: 'Model', value: approval.modelId),
                _Detail(label: 'Network', value: approval.network),
                _Detail(label: 'Purpose', value: approval.reason),
                _Detail(label: 'Resource', value: approval.resource.host),
                _Detail(
                  label: 'Expires',
                  value: expired ? 'Expired' : '$_secondsRemaining seconds',
                ),
                const SizedBox(height: 10),
                Text(
                  'Recipient · ${_shortAddress(approval.payTo)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        approval.payTo,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy recipient',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: approval.payTo),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(content: Text('Recipient copied.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Request ${_shortFingerprint(approval.requestFingerprint)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                const Text(
                  'This approval is one-use and covers only this amount, '
                  'recipient, model request, and expiry. Android will ask for '
                  'your device credential before signing. Chat and agents '
                  'cannot approve it.',
                  style: TextStyle(fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _complete(widget.onCancel),
            child: const Text('Reject'),
          ),
          FilledButton.icon(
            onPressed: expired ? null : () => _complete(widget.onApprove),
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Approve & unlock'),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _providerLabel(PendingPaidProviderApproval approval) =>
    switch (approval.provider) {
      PaidProviderId.venice => 'Venice',
      PaidProviderId.blockrun => 'BlockRun',
    };

String _formatUsdcUnits(String raw) {
  final units = BigInt.tryParse(raw);
  if (units == null || units.isNegative) return 'Invalid amount';
  final scale = BigInt.from(1000000);
  final whole = units ~/ scale;
  final fraction = (units % scale).toString().padLeft(6, '0');
  return '$whole.$fraction';
}

String _shortAddress(String value) {
  if (value.length <= 14) return value;
  return '${value.substring(0, 8)}…${value.substring(value.length - 6)}';
}

String _shortFingerprint(String value) {
  if (value.length <= 12) return value;
  return '${value.substring(0, 12)}…';
}
