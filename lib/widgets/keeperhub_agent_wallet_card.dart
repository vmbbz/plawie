import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';
import '../services/keeperhub/keeperhub_execution_models.dart';
import '../services/keeperhub/keeperhub_models.dart';
import '../services/keeperhub/keeperhub_proof_network.dart';
import '../services/keeperhub/keeperhub_wallet_controller.dart';
import 'glass_card.dart';

class KeeperHubAgentWalletCard extends StatefulWidget {
  const KeeperHubAgentWalletCard({
    required this.personalWalletAddress,
    this.controller,
    super.key,
  });

  final String? personalWalletAddress;
  final KeeperHubWalletController? controller;

  @override
  State<KeeperHubAgentWalletCard> createState() =>
      _KeeperHubAgentWalletCardState();
}

class _KeeperHubAgentWalletCardState extends State<KeeperHubAgentWalletCard> {
  late final KeeperHubWalletController _controller;
  late final bool _ownsController;
  KeeperHubWalletSnapshot? _snapshot;
  bool _loading = true;
  bool _busy = false;
  String? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? DefaultKeeperHubWalletController();
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant KeeperHubAgentWalletCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personalWalletAddress != widget.personalWalletAddress) {
      unawaited(_reload());
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.close();
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await _controller.load();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      if (mounted) setState(() => _error = _safeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    final personal = widget.personalWalletAddress;
    if (personal == null) return;
    final resuming = _snapshot?.connection != null;
    final approved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.hub_outlined),
            title: Text(
              resuming
                  ? 'Resume Agent Wallet setup?'
                  : 'Create Agent Execution Wallet?',
            ),
            content: Text(
              resuming
                  ? 'Plawie will verify the secured organization credential and use a fresh bounded Personal Wallet sign-in only if KeeperHub still needs to finish provisioning. No new execution or payment will be created.'
                  : 'Plawie will use your Personal Wallet for two bounded, device-authenticated approvals: KeeperHub sign-in and creation of one organization credential. KeeperHub/Turnkey—not Plawie—will manage a separate Agent Execution Wallet. The credential stays in encrypted app storage and is never exposed to the AI agent.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.fingerprint),
                label: Text(resuming ? 'Resume securely' : 'Connect securely'),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved || !mounted) return;
    await _run(
      initialProgress: 'Starting secure KeeperHub connection…',
      operation: () => _controller.connect(
        personalWalletAddress: personal,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress.message);
        },
      ),
    );
  }

  Future<void> _prepareProof() => _run(
        initialProgress: 'Simulating a zero-value Base Mainnet proof…',
        operation: _controller.prepareProof,
      );

  Future<void> _reviewAndExecute(String intentId) => _run(
        initialProgress: 'Waiting for your secure review…',
        operation: () => _controller.reviewAndExecute(intentId),
      );

  Future<void> _resume() => _run(
        initialProgress: 'Reconciling the existing execution…',
        operation: _controller.resumeActive,
      );

  Future<void> _discard(String intentId) => _run(
        initialProgress: 'Discarding the unsubmitted proof…',
        operation: () => _controller.discardPrepared(intentId),
      );

  Future<void> _revoke() async {
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              Icons.link_off,
              color: Theme.of(dialogContext).colorScheme.error,
            ),
            title: const Text('Revoke Plawie access?'),
            content: const Text(
              'This permanently revokes Plawie’s remote KeeperHub organization credential after fresh device authentication. It does not delete the KeeperHub account or managed wallet. Existing redacted receipts remain on this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep connected'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Authenticate & revoke'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await _run(
      initialProgress: 'Authorizing remote credential revocation…',
      operation: () => _controller.revoke(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress.message);
        },
      ),
    );
  }

  Future<void> _run({
    required String initialProgress,
    required Future<KeeperHubWalletSnapshot> Function() operation,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = initialProgress;
      _error = null;
    });
    try {
      final snapshot = await operation();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      if (mounted) setState(() => _error = _safeError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  String _safeError(Object error) => error is KeeperHubException
      ? error.message
      : 'Agent Wallet operation could not be completed safely.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connection = _snapshot?.connection;
    final personal = widget.personalWalletAddress;
    final personalMatches = personal != null &&
        connection != null &&
        connection.personalWalletAddress.toLowerCase() ==
            personal.toLowerCase();
    final ready = connection?.isReady == true && personalMatches;

    return GlassCard(
      accentColor: ready ? AppColors.statusGreen : AppColors.statusAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme, connection),
          const SizedBox(height: 14),
          if (_loading && _snapshot == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            )
          else if (personal == null)
            _message(
              theme,
              'Create or restore the Personal Wallet first. It remains your self-custodial identity and approval key.',
            )
          else if (connection == null)
            _disconnected(theme)
          else if (!personalMatches)
            _warning(
              theme,
              'The secured Agent Wallet belongs to a different Personal Wallet. Restore that Personal Wallet before reconnecting or executing.',
            )
          else
            _connected(theme, connection),
          if (_progress != null) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_progress!, style: theme.textTheme.bodySmall),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            _warning(theme, _error!),
          ],
        ],
      ),
    );
  }

  Widget _header(ThemeData theme, KeeperHubConnectionRecord? connection) {
    final (statusLabel, statusColor) = switch (connection?.phase) {
      KeeperHubConnectionPhase.ready => ('CONNECTED', AppColors.statusGreen),
      KeeperHubConnectionPhase.provisioning => (
          'SETTING UP',
          AppColors.statusAmber
        ),
      KeeperHubConnectionPhase.credentialInvalid => (
          'RECONNECT',
          theme.colorScheme.error
        ),
      KeeperHubConnectionPhase.revocationUnknown => (
          'REVOKE ?',
          theme.colorScheme.error
        ),
      null => ('OPTIONAL', AppColors.statusAmber),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.statusGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.hub_outlined,
            color: AppColors.statusGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agent Execution Wallet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Reliable agent execution with human approval',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh Agent Wallet state',
          visualDensity: VisualDensity.compact,
          onPressed: _busy || _loading ? null : _reload,
          icon: const Icon(Icons.refresh, size: 19),
        ),
        _chip(statusLabel, statusColor),
      ],
    );
  }

  Widget _disconnected(ThemeData theme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _custodyNotice(theme),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: const Icon(Icons.add_moderator_outlined),
              label: const Text('Connect Agent Wallet'),
            ),
          ),
        ],
      );

  Widget _connected(
    ThemeData theme,
    KeeperHubConnectionRecord connection,
  ) {
    final active = _snapshot?.activeExecution;
    final terminalReceipts = (_snapshot?.receipts ?? const [])
        .where((record) => record.isTerminal)
        .take(3)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('KEEPERHUB-MANAGED', AppColors.statusAmber),
            _chip('BASE MAINNET', AppColors.statusGreen),
            _chip('HUMAN APPROVAL', AppColors.statusGreen),
          ],
        ),
        const SizedBox(height: 12),
        _addressRow(
          theme,
          label: 'Agent wallet',
          address: connection.agentWalletAddress ?? 'Provisioning…',
        ),
        const SizedBox(height: 8),
        _addressRow(
          theme,
          label: 'Personal approver',
          address: connection.personalWalletAddress,
        ),
        const SizedBox(height: 12),
        _custodyNotice(theme),
        if (connection.phase == KeeperHubConnectionPhase.revocationUnknown) ...[
          const SizedBox(height: 10),
          _warning(
            theme,
            'Remote revocation is not yet confirmed. The credential is still secured locally so you can retry without losing control of it.',
          ),
        ],
        if (!connection.isReady) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: const Icon(Icons.sync),
              label: Text(
                connection.phase == KeeperHubConnectionPhase.revocationUnknown
                    ? 'Re-check connection status'
                    : 'Resume secure setup',
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          if (active == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _prepareProof,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Simulate safe mainnet proof'),
              ),
            )
          else
            _activeExecution(theme, active),
        ],
        if (terminalReceipts.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'RECENT EXECUTION RECEIPTS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          for (final receipt in terminalReceipts) _receipt(theme, receipt),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy || active != null ? null : _revoke,
            icon: const Icon(Icons.link_off, size: 18),
            label: const Text('Revoke Plawie access'),
          ),
        ),
      ],
    );
  }

  Widget _activeExecution(
    ThemeData theme,
    KeeperHubExecutionRecord execution,
  ) {
    final canReview =
        execution.phase == KeeperHubExecutionPhase.awaitingApproval;
    final canDiscard = execution.phase == KeeperHubExecutionPhase.proposed ||
        execution.phase == KeeperHubExecutionPhase.awaitingApproval;
    final canResume = <KeeperHubExecutionPhase>{
      KeeperHubExecutionPhase.approved,
      KeeperHubExecutionPhase.submitting,
      KeeperHubExecutionPhase.polling,
      KeeperHubExecutionPhase.outcomeUnknown,
    }.contains(execution.phase);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.statusGreen.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_outlined,
                color: AppColors.statusGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _phaseLabel(execution.phase),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '0 ETH',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.statusGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            execution.phase == KeeperHubExecutionPhase.outcomeUnknown
                ? 'The same persisted work will be reconciled. Plawie will not create a replacement transaction.'
                : '${KeeperHubProofNetwork.name} self-transfer · simulation-bound · exactly 0 ETH',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canReview)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _reviewAndExecute(execution.intentId),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Review & authorize'),
                ),
              if (canResume)
                FilledButton.icon(
                  onPressed: _busy ? null : _resume,
                  icon: const Icon(Icons.sync),
                  label: Text(
                    execution.executionId == null
                        ? 'Reconcile exact request'
                        : 'Check execution status',
                  ),
                ),
              if (canDiscard)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _discard(execution.intentId),
                  icon: const Icon(Icons.close),
                  label: const Text('Discard'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receipt(ThemeData theme, KeeperHubExecutionRecord receipt) {
    final verified = receipt.phase == KeeperHubExecutionPhase.completed &&
        receipt.receipts.isNotEmpty &&
        receipt.receipts.every((item) => item.verified);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              verified ? Icons.verified_outlined : Icons.info_outline,
              color: verified
                  ? AppColors.statusGreen
                  : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _phaseLabel(receipt.phase),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    receipt.transactionHash == null
                        ? _formatDate(receipt.updatedAt)
                        : _shortAddress(receipt.transactionHash!),
                    style: GoogleFonts.robotoMono(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (receipt.transactionHash != null)
              IconButton(
                tooltip: 'Copy transaction hash',
                visualDensity: VisualDensity.compact,
                onPressed: () => _copy(receipt.transactionHash!),
                icon: const Icon(Icons.copy, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _custodyNotice(ThemeData theme) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.statusAmber.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.statusAmber.withValues(alpha: 0.24),
          ),
        ),
        child: Text(
          'Separate custody: your Personal Wallet stays Android-owned. KeeperHub/Turnkey manages this execution wallet. Every Plawie write still requires visible review and fresh device authentication.',
          style: theme.textTheme.bodySmall,
        ),
      );

  Widget _addressRow(
    ThemeData theme, {
    required String label,
    required String address,
  }) =>
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _shortAddress(address),
                  style: GoogleFonts.robotoMono(fontSize: 12),
                ),
              ],
            ),
          ),
          if (address.startsWith('0x'))
            IconButton(
              tooltip: 'Copy $label',
              visualDensity: VisualDensity.compact,
              onPressed: () => _copy(address),
              icon: const Icon(Icons.copy, size: 18),
            ),
        ],
      );

  Widget _warning(ThemeData theme, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.28),
          ),
        ),
        child: Text(text, style: theme.textTheme.bodySmall),
      );

  Widget _message(ThemeData theme, String text) => Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: GoogleFonts.robotoMono(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );

  String _phaseLabel(KeeperHubExecutionPhase phase) => switch (phase) {
        KeeperHubExecutionPhase.proposed => 'Simulation interrupted',
        KeeperHubExecutionPhase.awaitingApproval => 'Ready for human review',
        KeeperHubExecutionPhase.approved => 'Authorized locally',
        KeeperHubExecutionPhase.submitting => 'Submitting exact request',
        KeeperHubExecutionPhase.polling => 'Verifying on-chain receipt',
        KeeperHubExecutionPhase.outcomeUnknown =>
          'Outcome needs reconciliation',
        KeeperHubExecutionPhase.simulationFailed => 'Simulation failed safely',
        KeeperHubExecutionPhase.rejected => 'Rejected before execution',
        KeeperHubExecutionPhase.completed => 'Verified on-chain',
        KeeperHubExecutionPhase.failed => 'Execution failed',
      };

  String _shortAddress(String value) {
    if (value.length < 14) return value;
    return '${value.substring(0, 8)}…${value.substring(value.length - 6)}';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}
