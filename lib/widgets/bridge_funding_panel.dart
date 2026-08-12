import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bridge/bridge_capability_service.dart';
import '../services/bridge/bridge_funding_controller.dart';
import '../services/bridge/bridge_models.dart';
import '../services/bridge/external_jumper_fallback.dart';
import '../services/bridge/external_wallet_session_service.dart';
import 'bridge_review_sheet.dart';
import 'glass_card.dart';
import 'relay_deposit_sheet.dart';

final class BridgeFundingPanel extends StatefulWidget {
  const BridgeFundingPanel({
    super.key,
    required this.controller,
    required this.capabilities,
    required this.baseDestinationAddress,
    required this.baseWalletAvailable,
    required this.baseMainnetSelected,
    this.initialSourceChainId,
    this.initialSourceTokenSymbol,
    this.onFundingCompleted,
    this.launchExternal = _launchExternal,
    this.copyText = _copyText,
    this.clock = DateTime.now,
  });

  final BridgeFundingUiController controller;
  final BridgeCapabilitySource capabilities;
  final String? baseDestinationAddress;
  final bool baseWalletAvailable;
  final bool baseMainnetSelected;
  final int? initialSourceChainId;
  final String? initialSourceTokenSymbol;
  final ValueChanged<BridgeFundingReceipt>? onFundingCompleted;
  final Future<bool> Function(Uri uri) launchExternal;
  final Future<void> Function(String text) copyText;
  final DateTime Function() clock;

  @override
  State<BridgeFundingPanel> createState() => _BridgeFundingPanelState();
}

final class _BridgeFundingPanelState extends State<BridgeFundingPanel> {
  final _amount = TextEditingController();
  final _refundAddress = TextEditingController();
  final _recoveryId = TextEditingController();

  BridgeCapabilitySnapshot? _snapshot;
  BridgeFundingMethod _method = BridgeFundingMethod.connectedWallet;
  BridgeChain? _sourceChain;
  BridgeToken? _sourceToken;
  List<ExternalWalletOption> _walletOptions = const <ExternalWalletOption>[];
  bool _loadingCapabilities = false;
  bool _usingCachedCapabilities = false;
  bool _busy = false;
  bool _resumeStarted = false;
  bool _selfCustodyConfirmed = false;
  bool _startAnotherTransfer = false;
  String? _error;
  final Set<String> _completionCallbacksDelivered = <String>{};

  bool get _entryAvailable =>
      widget.baseWalletAvailable &&
      widget.baseDestinationAddress != null &&
      widget.baseMainnetSelected;

  BridgeFundingReceipt? get _activeReceipt => widget.controller.activeReceipt;

  BridgeFundingReceipt? get _latestReceipt {
    final active = _activeReceipt;
    if (active != null) return active;
    final receipts = <BridgeFundingReceipt>[...widget.controller.receipts]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return receipts.isEmpty ? null : receipts.first;
  }

  @override
  void initState() {
    super.initState();
    if (_entryAvailable) unawaited(_loadCapabilities());
  }

  @override
  void didUpdateWidget(covariant BridgeFundingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseDestinationAddress != widget.baseDestinationAddress ||
        oldWidget.baseWalletAvailable != widget.baseWalletAvailable ||
        oldWidget.baseMainnetSelected != widget.baseMainnetSelected ||
        oldWidget.initialSourceChainId != widget.initialSourceChainId ||
        oldWidget.initialSourceTokenSymbol != widget.initialSourceTokenSymbol) {
      _snapshot = null;
      _sourceChain = null;
      _sourceToken = null;
      _resumeStarted = false;
      if (_entryAvailable) unawaited(_loadCapabilities());
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _refundAddress.dispose();
    _recoveryId.dispose();
    super.dispose();
  }

  Future<void> _loadCapabilities() async {
    if (_loadingCapabilities || !_entryAvailable) return;
    setState(() {
      _loadingCapabilities = true;
      _usingCachedCapabilities = false;
      _error = null;
    });
    try {
      final snapshot = await widget.capabilities.refresh(
        internalBaseWalletAvailable: widget.baseWalletAvailable,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loadingCapabilities = false;
        _selectDefaults();
      });
      _resumeActiveReceipt();
    } catch (_) {
      if (!mounted) return;
      final cached = widget.capabilities.cachedSnapshot;
      setState(() {
        _snapshot = cached;
        _usingCachedCapabilities = cached != null;
        _loadingCapabilities = false;
        _error = cached == null
            ? 'Funding routes could not be refreshed. Check your connection and retry.'
            : null;
        _selectDefaults();
      });
      _resumeActiveReceipt();
    }
  }

  void _selectDefaults() {
    final chains = _chainsFor(_method);
    if (!chains.contains(_sourceChain)) {
      _sourceChain = _preferredChain(chains);
    }
    final tokens = _tokensFor(_method, _sourceChain);
    if (!tokens.contains(_sourceToken)) {
      _sourceToken = _preferredToken(tokens);
    }
  }

  BridgeChain? _preferredChain(List<BridgeChain> chains) {
    if (chains.isEmpty) return null;
    final preferredId = widget.initialSourceChainId;
    if (preferredId != null) {
      for (final chain in chains) {
        if (chain.id == preferredId) return chain;
      }
    }
    return chains.first;
  }

  BridgeToken? _preferredToken(List<BridgeToken> tokens) {
    if (tokens.isEmpty) return null;
    final preferredSymbol = widget.initialSourceTokenSymbol?.toUpperCase();
    if (preferredSymbol != null) {
      for (final token in tokens) {
        if (token.symbol.toUpperCase() == preferredSymbol) return token;
      }
    }
    return tokens.first;
  }

  List<BridgeChain> _chainsFor(BridgeFundingMethod method) {
    final snapshot = _snapshot;
    if (snapshot == null) return const <BridgeChain>[];
    return method == BridgeFundingMethod.relayDeposit
        ? snapshot.relayChains
        : snapshot.connectedChains;
  }

  List<BridgeToken> _tokensFor(
    BridgeFundingMethod method,
    BridgeChain? chain,
  ) {
    final snapshot = _snapshot;
    if (snapshot == null || chain == null) return const <BridgeToken>[];
    return method == BridgeFundingMethod.relayDeposit
        ? snapshot.relayTokensFor(chain.id)
        : snapshot.connectedTokensFor(chain.id);
  }

  void _changeMethod(BridgeFundingMethod method) {
    if (_busy || _activeReceipt != null || method == _method) return;
    setState(() {
      _method = method;
      _walletOptions = const <ExternalWalletOption>[];
      _error = null;
      _selectDefaults();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Color(0xFF5B8CFF), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fund Base from another chain',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const _MainnetBadge(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a source wallet network below. The destination stays this app-owned Base wallet, and Plawie never imports the source wallet key.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.baseWalletAvailable ||
                widget.baseDestinationAddress == null)
              const _Notice(
                icon: Icons.account_balance_wallet_outlined,
                text: 'Create or restore the internal Base wallet first.',
              )
            else if (!widget.baseMainnetSelected)
              const _Notice(
                icon: Icons.warning_amber_rounded,
                text: 'Switch to Base Mainnet to use external funding.',
              )
            else ...[
              _destination(theme),
              const SizedBox(height: 12),
              if (_loadingCapabilities && _snapshot == null)
                const _LoadingRoutes()
              else ...[
                if (_usingCachedCapabilities)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _Notice(
                      icon: Icons.cloud_off_rounded,
                      text:
                          'Using recently cached routes. A live refresh is required before transfer.',
                    ),
                  ),
                if (_activeReceipt != null)
                  _buildReceipt(_activeReceipt!)
                else if (_latestReceipt?.state ==
                        BridgeFundingState.completed &&
                    !_startAnotherTransfer)
                  _buildCompletedReceipt(_latestReceipt!)
                else ...[
                  _methodSelector(),
                  if (_method == BridgeFundingMethod.connectedWallet &&
                      widget.controller.connectedExternalWallet != null) ...[
                    const SizedBox(height: 10),
                    _connectedWalletCard(
                      widget.controller.connectedExternalWallet!,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _fundingForm(),
                  if (_walletOptions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _walletCapabilityList(),
                  ],
                  const SizedBox(height: 12),
                  _primaryAction(),
                  const SizedBox(height: 8),
                  _jumperAction(),
                ],
                if (_activeReceipt == null &&
                    _latestReceipt != null &&
                    (_latestReceipt!.state != BridgeFundingState.completed ||
                        _startAnotherTransfer)) ...[
                  const SizedBox(height: 12),
                  _buildRecentReceipt(_latestReceipt!),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                _ErrorNotice(message: _error!),
              ],
              if (_snapshot == null && !_loadingCapabilities)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _loadCapabilities,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry route check'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _destination(ThemeData theme) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Base destination', style: theme.textTheme.labelMedium),
            const SizedBox(height: 3),
            SelectableText(widget.baseDestinationAddress!),
          ],
        ),
      );

  Widget _methodSelector() {
    final relayKnown = _snapshot?.relayChains.isNotEmpty == true ||
        _snapshot?.availabilityReasons.containsKey('relay') == true;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Connect wallet'),
          selected: _method == BridgeFundingMethod.connectedWallet,
          onSelected: (_) => _changeMethod(BridgeFundingMethod.connectedWallet),
        ),
        if (relayKnown)
          ChoiceChip(
            label: const Text('One-time address'),
            selected: _method == BridgeFundingMethod.relayDeposit,
            onSelected: (_) => _changeMethod(BridgeFundingMethod.relayDeposit),
          ),
      ],
    );
  }

  Widget _connectedWalletCard(ExternalWalletIdentity identity) {
    final chainName =
        _chainFor(identity.chainId)?.name ?? 'Chain ID ${identity.chainId}';
    return Container(
      key: const Key('bridge-connected-wallet'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wallet_rounded, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EXTERNAL SOURCE WALLET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${identity.walletLabel} · $chainName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  _shortWalletAddress(identity.publicAddress),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('bridge-change-wallet'),
            onPressed: _busy ? null : _changeExternalWallet,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeExternalWallet() => _runBusy(() async {
        await widget.controller.disconnectExternalWallet();
        if (!mounted) return;
        setState(() {
          _walletOptions = const <ExternalWalletOption>[];
          _error = null;
        });
      });

  Widget _fundingForm() {
    final chains = _chainsFor(_method);
    final tokens = _tokensFor(_method, _sourceChain);
    if (chains.isEmpty) {
      final reason = _snapshot?.availabilityReasons[
              _method == BridgeFundingMethod.relayDeposit ? 'relay' : 'lifi'] ??
          'No verified source route is available right now.';
      return _Notice(icon: Icons.route_outlined, text: reason);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<BridgeChain>(
          key: const Key('bridge-source-chain'),
          initialValue: _sourceChain,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Source wallet network',
          ),
          items: [
            for (final chain in chains)
              DropdownMenuItem(
                value: chain,
                child: Text(
                  chain.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _busy
              ? null
              : (chain) {
                  if (chain == null) return;
                  setState(() {
                    _sourceChain = chain;
                    final available = _tokensFor(_method, chain);
                    _sourceToken = _preferredToken(available);
                    _walletOptions = const <ExternalWalletOption>[];
                    _error = null;
                  });
                },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<BridgeToken>(
          key: ValueKey<String>('bridge-source-token-${_sourceChain?.id}'),
          initialValue: _sourceToken,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Source token'),
          items: [
            for (final token in tokens)
              DropdownMenuItem(
                value: token,
                child: Text(
                  '${token.symbol} · ${_shortAddress(token.address)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _busy
              ? null
              : (token) => setState(() {
                    _sourceToken = token;
                    _error = null;
                  }),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('bridge-amount'),
          controller: _amount,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Exact source amount',
            suffixText: _sourceToken?.symbol,
          ),
        ),
        if (_sourceChain?.id == BridgeConstants.baseChainId) ...[
          const SizedBox(height: 8),
          const _Notice(
            icon: Icons.swap_horiz_rounded,
            text:
                'Base is the destination network too. This sends USDC directly from another Base wallet into Plawie; it is not a cross-chain bridge. Keep a little Base ETH in the source wallet for gas.',
          ),
        ],
        if (_sourceChain?.id == BridgeConstants.robinhoodChainId) ...[
          const SizedBox(height: 8),
          const _Notice(
            icon: Icons.local_gas_station_outlined,
            text:
                'Keep some ETH in the Robinhood source wallet for gas. Do not bridge the full ETH balance; USDG transfers also require ETH gas.',
          ),
        ],
        if (_method == BridgeFundingMethod.relayDeposit) ...[
          const SizedBox(height: 12),
          const _Notice(
            icon: Icons.block_rounded,
            text:
                'Exchange / CEX withdrawals are not supported. Use a self-custody wallet whose refund address you control.',
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('bridge-refund-address'),
            controller: _refundAddress,
            enabled: !_busy,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Personal refund address',
              helperText: 'Must belong to you on the selected source chain',
            ),
          ),
          CheckboxListTile(
            key: const Key('bridge-self-custody'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _selfCustodyConfirmed,
            onChanged: _busy
                ? null
                : (value) => setState(() {
                      _selfCustodyConfirmed = value == true;
                    }),
            title: const Text(
              'I control this source wallet and refund address',
            ),
          ),
        ],
        for (final reason in _visibleAvailabilityReasons()) ...[
          const SizedBox(height: 8),
          Text(
            reason,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Iterable<String> _visibleAvailabilityReasons() sync* {
    final reasons = _snapshot?.availabilityReasons ?? const <String, String>{};
    for (final entry in reasons.entries) {
      if (entry.key == 'execution') continue;
      yield entry.value;
    }
  }

  Widget _primaryAction() {
    final enabled = !_busy &&
        !_usingCachedCapabilities &&
        _sourceChain != null &&
        _sourceToken != null;
    final relay = _method == BridgeFundingMethod.relayDeposit;
    return FilledButton.icon(
      key: const Key('bridge-primary-action'),
      onPressed: enabled
          ? relay
              ? _createRelayInstruction
              : _connectAndPrepare
          : null,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(relay ? Icons.qr_code_2_rounded : Icons.wallet_rounded),
      label: Text(
        _busy
            ? 'Preparing…'
            : relay
                ? 'Create one-time address'
                : 'Connect external wallet',
      ),
    );
  }

  Widget _jumperAction() => OutlinedButton.icon(
        onPressed: _busy || _sourceChain == null || _sourceToken == null
            ? null
            : _openJumper,
        icon: const Icon(Icons.open_in_new_rounded),
        label: const Text('Continue externally with Jumper'),
      );

  Widget _walletCapabilityList() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in _walletOptions)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                option.available ? Icons.check_circle : Icons.info_outline,
                color: option.available ? Colors.greenAccent : Colors.orange,
              ),
              title: Text(option.label),
              subtitle: option.reason == null ? null : Text(option.reason!),
            ),
        ],
      );

  Future<void> _connectAndPrepare() async {
    final request = _buildRequest(BridgeFundingMethod.connectedWallet);
    if (request == null) return;
    await _runBusy(() async {
      await _requireLiveCapabilities(request);
      final options = await widget.controller.discoverWallets(
        request.sourceChain,
      );
      if (mounted) setState(() => _walletOptions = options);
      var transport = await _chooseTransport(request.sourceChain, options);
      if (transport == null) {
        throw const ExternalWalletException('wallet_transport_unavailable');
      }
      try {
        await widget.controller.prepareConnected(
          request,
          transport: transport,
        );
      } on ExternalWalletException catch (error) {
        if (request.sourceChain.type != BridgeChainType.svm ||
            error.code != 'wallet_transport_unavailable' ||
            transport != ExternalWalletTransport.solanaMwa) {
          rethrow;
        }
        final fallbackOptions = await widget.controller.discoverWallets(
          request.sourceChain,
        );
        if (mounted) setState(() => _walletOptions = fallbackOptions);
        transport = await _chooseTransport(
          request.sourceChain,
          fallbackOptions,
          fallbackOnly: true,
        );
        if (transport == null) rethrow;
        await widget.controller.prepareConnected(
          request,
          transport: transport,
        );
      }
      if (!mounted) return;
      await _runReviewFlow(request);
    });
  }

  Future<ExternalWalletTransport?> _chooseTransport(
    BridgeChain chain,
    List<ExternalWalletOption> options, {
    bool fallbackOnly = false,
  }) async {
    if (chain.type == BridgeChainType.evm) {
      for (final option in options) {
        if (option.available &&
            (option.transport == ExternalWalletTransport.reownEvm ||
                option.transport == ExternalWalletTransport.baseAccountMwp)) {
          return option.transport;
        }
      }
      return null;
    }
    if (!fallbackOnly) {
      for (final option in options) {
        if (option.available &&
            option.transport == ExternalWalletTransport.solanaMwa) {
          return option.transport;
        }
      }
    }
    final fallbacks = options
        .where((option) =>
            option.available &&
            (option.transport == ExternalWalletTransport.reownSolanaPhantom ||
                option.transport ==
                    ExternalWalletTransport.reownSolanaSolflare))
        .toList();
    if (fallbacks.isEmpty || !mounted) return null;
    return showModalBottomSheet<ExternalWalletTransport>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              title: Text('Choose compatible wallet'),
              subtitle: Text(
                'Mobile Wallet Adapter was unavailable. Choose an enabled sign-only fallback.',
              ),
            ),
            for (final option in fallbacks)
              ListTile(
                title: Text(option.label),
                onTap: () => Navigator.pop(context, option.transport),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _runReviewFlow(BridgeFundingRequest request) async {
    while (mounted) {
      final receipt = widget.controller.activeReceipt;
      if (receipt == null ||
          receipt.state != BridgeFundingState.awaitingPlawieReview) {
        return;
      }
      final kind = widget.controller.pendingReviewKind(receipt.intentId);
      if (kind == null) {
        throw const BridgeValidationException(
          'bridge_review_not_resumable',
        );
      }
      if (!mounted) return;
      final approved = await BridgeReviewSheet.show(
        context,
        receipt: receipt,
        reviewKind: kind,
        sourceChainName: request.sourceChain.name,
        sourceAmountDisplay: request.amount,
        minimumOutputDisplay: _formatUnits(
          receipt.minimumOutputUnits ?? '0',
          6,
        ),
      );
      if (!approved) {
        await widget.controller.cancelBeforeSubmission(receipt.intentId);
        if (mounted) setState(() {});
        return;
      }
      if (kind == BridgeReviewKind.allowance) {
        await widget.controller.confirmEvmAllowance(receipt.intentId);
      } else {
        await widget.controller.confirmConnectedBridge(receipt.intentId);
      }
      _notifyIfCompleted(receipt.intentId);
      if (mounted) setState(() {});
      if (kind == BridgeReviewKind.bridge) {
        final current = widget.controller.activeReceipt;
        if (current != null && _statusCanRefresh(current)) {
          _resumeStarted = false;
          _resumeActiveReceipt();
        }
        return;
      }
    }
  }

  Future<void> _createRelayInstruction() async {
    final request = _buildRequest(BridgeFundingMethod.relayDeposit);
    if (request == null) return;
    if (!request.selfCustodyConfirmed) {
      setState(() => _error =
          'Confirm that you control the source wallet and refund address.');
      return;
    }
    await _runBusy(() async {
      await _requireLiveCapabilities(request);
      RelayDepositInstruction instruction;
      try {
        instruction = await widget.controller.prepareRelayDeposit(request);
      } on BridgeValidationException catch (error) {
        if (error.code != 'old_relay_address_warning_required' || !mounted) {
          rethrow;
        }
        final acknowledged = await _confirmOldRelayAddress();
        if (!acknowledged) return;
        instruction = await widget.controller.prepareRelayDeposit(
          request,
          oldAddressWarningAcknowledged: true,
        );
      }
      if (!mounted) return;
      final action = await RelayDepositSheet.show(
        context,
        instruction: instruction,
        onCopy: widget.copyText,
        clock: widget.clock,
      );
      if (action == RelayDepositSheetAction.hide) {
        final receipt = widget.controller.activeReceipt;
        if (receipt != null) {
          await widget.controller.archiveRelayInstructions(receipt.intentId);
        }
      }
      _resumeStarted = false;
      _resumeActiveReceipt();
      if (mounted) setState(() {});
    });
  }

  Future<bool> _confirmOldRelayAddress() async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Replace old deposit address?'),
          content: const Text(
            'The previous address remains trackable but must never be reused. A new instruction will use a different address.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep old instruction'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create new address'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _openJumper() async {
    final request = _buildRequest(BridgeFundingMethod.externalJumper);
    if (request == null) return;
    final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Continue externally'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jumper will create a new route. Plawie will not submit or monitor it. Verify the Base destination before approving.',
                ),
                const SizedBox(height: 12),
                SelectableText(request.baseDestinationAddress),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Jumper'),
              ),
            ],
          ),
        ) ??
        false;
    if (!proceed) return;
    final opened = await widget.launchExternal(
      const ExternalJumperFallback().build(request),
    );
    if (!opened && mounted) {
      setState(() => _error = 'Could not open Jumper. No transfer was made.');
    }
  }

  BridgeFundingRequest? _buildRequest(BridgeFundingMethod method) {
    final chain = _sourceChain;
    final token = _sourceToken;
    final destination = widget.baseDestinationAddress;
    if (chain == null || token == null || destination == null) {
      setState(() => _error = 'Choose a supported source chain and token.');
      return null;
    }
    String units;
    try {
      units = _amountUnits(_amount.text, token.decimals);
    } on FormatException {
      setState(() => _error =
          'Enter a positive amount with at most ${token.decimals} decimal places.');
      return null;
    }
    final refund = method == BridgeFundingMethod.relayDeposit
        ? _refundAddress.text.trim()
        : null;
    if (method == BridgeFundingMethod.relayDeposit &&
        !_validAddress(refund ?? '', chain.type)) {
      setState(() =>
          _error = 'Enter a valid personal refund address for ${chain.name}.');
      return null;
    }
    setState(() => _error = null);
    return BridgeFundingRequest(
      method: method,
      sourceChain: chain,
      sourceToken: token,
      amount: _normalizeAmount(_amount.text),
      amountUnits: units,
      baseDestinationAddress: destination,
      refundAddress: refund,
      selfCustodyConfirmed: _selfCustodyConfirmed,
    );
  }

  Widget _buildReceipt(BridgeFundingReceipt receipt) {
    if (receipt.submissionOutcomeUnknown &&
        receipt.sourceTransactionHash == null) {
      return _unknownOutcome(receipt);
    }
    final relay = receipt.method == BridgeFundingMethod.relayDeposit;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF5B8CFF).withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _stateTitle(receipt.state),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${receipt.sourceTokenSymbol} · ${receipt.provider}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (receipt.sourceTransactionHash != null)
            SelectableText('Source: ${receipt.sourceTransactionHash}'),
          if (receipt.destinationTransactionHash != null)
            SelectableText('Base: ${receipt.destinationTransactionHash}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (relay && receipt.depositAddressExposed)
                OutlinedButton(
                  onPressed: _busy ? null : () => _showPersistedRelay(receipt),
                  child: const Text('View deposit instructions'),
                ),
              if (_statusCanRefresh(receipt))
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _refreshReceipt(receipt),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh status'),
                ),
              if (receipt.balanceRefreshPending)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _runBusy(() => widget.controller
                          .refreshBaseBalance(receipt.intentId)),
                  child: const Text('Refresh Base balance'),
                ),
              if (_canCancelBeforeSubmission(receipt))
                TextButton.icon(
                  key: const Key('bridge-cancel-pre-submission'),
                  onPressed: _busy ? null : () => _cancelPreSubmission(receipt),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(
                    receipt.state == BridgeFundingState.awaitingPlawieReview
                        ? 'Discard stale review'
                        : 'Cancel and retry',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedReceipt(BridgeFundingReceipt receipt) {
    final output = _receivedAmount(receipt);
    return Container(
      key: const Key('bridge-completion-confirmation'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.greenAccent.withValues(alpha: .42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.greenAccent, size: 22),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Base funding confirmed',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$output USDC arrived in the Plawie wallet on Base Mainnet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 5),
          Text(
            '${_sourceAmount(receipt)} ${receipt.sourceTokenSymbol} from '
            '${_sourceChainLabel(receipt.sourceChainId)} · '
            '${receipt.providerSubstatus ?? receipt.providerStatus ?? 'Completed'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (receipt.balanceRefreshPending) ...[
            const SizedBox(height: 8),
            const _Notice(
              icon: Icons.sync_problem_rounded,
              text:
                  'Delivery is confirmed, but the displayed Base balance still needs a successful refresh.',
            ),
          ],
          const SizedBox(height: 10),
          _receiptActions(receipt, includeBridgeMore: true),
          const SizedBox(height: 4),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('bridge-completion-details'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: const Text(
                'Transaction details',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              children: [_receiptDetails(receipt)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unknownOutcome(BridgeFundingReceipt receipt) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: .7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wallet result needs verification',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Plawie will not send again. Provide the wallet transaction identifier or run an evidence-bound Solana history scan.',
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('bridge-recovery-id'),
              controller: _recoveryId,
              enabled: !_busy,
              autocorrect: false,
              decoration: InputDecoration(
                labelText:
                    receipt.sourceChainId == BridgeConstants.solanaChainId
                        ? 'Solana signature'
                        : 'Transaction hash',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : () => _recoverReceipt(receipt),
              child: Text(
                receipt.sourceChainId == BridgeConstants.solanaChainId
                    ? 'Verify Solana signature'
                    : 'Verify transaction hash',
              ),
            ),
            if (receipt.sourceChainId == BridgeConstants.solanaChainId)
              TextButton(
                onPressed: _busy ? null : () => _scanSolana(receipt),
                child: const Text('Scan wallet history safely'),
              ),
          ],
        ),
      );

  Widget _buildRecentReceipt(BridgeFundingReceipt receipt) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Latest funding receipt'),
        subtitle: Text(_stateTitle(receipt.state)),
        children: [
          _receiptDetails(receipt),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _receiptActions(receipt),
          ),
          if (receipt.method == BridgeFundingMethod.relayDeposit ||
              _statusCanRefresh(receipt))
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (receipt.method == BridgeFundingMethod.relayDeposit &&
                      receipt.depositAddressExposed)
                    OutlinedButton(
                      onPressed:
                          _busy ? null : () => _showPersistedRelay(receipt),
                      child: const Text('View deposit instructions'),
                    ),
                  if (_statusCanRefresh(receipt))
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _refreshReceipt(receipt),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh status'),
                    ),
                ],
              ),
            ),
        ],
      );

  Widget _receiptDetails(BridgeFundingReceipt receipt) {
    final sourceHash = receipt.sourceTransactionHash;
    final destinationHash = receipt.destinationTransactionHash;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sent: ${_sourceAmount(receipt)} ${receipt.sourceTokenSymbol} · '
            '${_sourceChainLabel(receipt.sourceChainId)}',
          ),
          if (receipt.actualOutputUnits != null ||
              receipt.minimumOutputUnits != null)
            Text('Received: ${_receivedAmount(receipt)} USDC · Base Mainnet'),
          Text('Route: ${receipt.routeTool ?? receipt.provider}'),
          Text('Updated: ${_receiptTimestamp(receipt.updatedAt)}'),
          if (sourceHash != null) ...[
            const SizedBox(height: 5),
            SelectableText('Source transaction: $sourceHash'),
          ],
          if (destinationHash != null) ...[
            const SizedBox(height: 5),
            SelectableText('Base transaction: $destinationHash'),
          ],
          const SizedBox(height: 5),
          SelectableText('Destination: ${receipt.baseDestinationAddress}'),
        ],
      ),
    );
  }

  Widget _receiptActions(
    BridgeFundingReceipt receipt, {
    bool includeBridgeMore = false,
  }) {
    final sourceUri = _sourceExplorerUri(receipt);
    final baseUri = _baseExplorerUri(receipt);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (baseUri != null)
          OutlinedButton.icon(
            key: const Key('bridge-open-base-transaction'),
            onPressed: _busy ? null : () => _openExplorer(baseUri),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Base transaction'),
          ),
        if (sourceUri != null && sourceUri != baseUri)
          OutlinedButton.icon(
            key: const Key('bridge-open-source-transaction'),
            onPressed: _busy ? null : () => _openExplorer(sourceUri),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Source transaction'),
          ),
        if (includeBridgeMore)
          TextButton.icon(
            key: const Key('bridge-start-another-transfer'),
            onPressed: _busy
                ? null
                : () => setState(() => _startAnotherTransfer = true),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Add more funds'),
          ),
      ],
    );
  }

  Future<void> _openExplorer(Uri uri) async {
    final opened = await widget.launchExternal(uri);
    if (!opened && mounted) {
      setState(() => _error = 'The transaction explorer could not be opened.');
    }
  }

  Uri? _sourceExplorerUri(BridgeFundingReceipt receipt) {
    final hash = receipt.sourceTransactionHash;
    if (hash == null) return null;
    if (receipt.sourceChainId == BridgeConstants.solanaChainId) {
      return Uri.https('solscan.io', '/tx/$hash');
    }
    final host = switch (receipt.sourceChainId) {
      BridgeConstants.ethereumChainId => 'etherscan.io',
      BridgeConstants.baseChainId => 'basescan.org',
      BridgeConstants.robinhoodChainId =>
        'explorer.mainnet.chain.robinhood.com',
      _ => null,
    };
    return host == null ? null : Uri.https(host, '/tx/$hash');
  }

  Uri? _baseExplorerUri(BridgeFundingReceipt receipt) {
    final hash = receipt.destinationTransactionHash ??
        (receipt.sourceChainId == BridgeConstants.baseChainId
            ? receipt.sourceTransactionHash
            : null);
    return hash == null ? null : Uri.https('basescan.org', '/tx/$hash');
  }

  String _sourceAmount(BridgeFundingReceipt receipt) => _formatUnits(
        receipt.sourceAmountUnits,
        _tokenFor(receipt)?.decimals ??
            _fallbackDecimals(receipt.sourceTokenSymbol),
      );

  String _receivedAmount(BridgeFundingReceipt receipt) => _formatUnits(
        receipt.actualOutputUnits ?? receipt.minimumOutputUnits ?? '0',
        6,
      );

  Future<void> _requireLiveCapabilities(BridgeFundingRequest request) async {
    late final BridgeCapabilitySnapshot live;
    try {
      live = await widget.capabilities.refresh(
        internalBaseWalletAvailable: widget.baseWalletAvailable,
      );
    } catch (_) {
      throw const BridgeValidationException(
        'live_bridge_capabilities_required',
      );
    }
    if (!mounted) {
      throw const BridgeValidationException('funding_panel_not_foreground');
    }
    if (live.availabilityReasons.containsKey('execution')) {
      throw const BridgeValidationException(
        'live_bridge_capabilities_required',
      );
    }

    final relay = request.method == BridgeFundingMethod.relayDeposit;
    final chains = relay ? live.relayChains : live.connectedChains;
    final chainAvailable = chains.any((chain) =>
        chain.id == request.sourceChain.id &&
        chain.type == request.sourceChain.type);
    final tokens = relay
        ? live.relayTokensFor(request.sourceChain.id)
        : live.connectedTokensFor(request.sourceChain.id);
    final tokenAvailable = tokens.any(
      (token) =>
          token.decimals == request.sourceToken.decimals &&
          (request.sourceChain.type == BridgeChainType.svm
              ? token.address == request.sourceToken.address
              : token.address.toLowerCase() ==
                  request.sourceToken.address.toLowerCase()),
    );

    setState(() {
      _snapshot = live;
      _usingCachedCapabilities = false;
      if (!chainAvailable || !tokenAvailable) _selectDefaults();
    });
    if (!chainAvailable || !tokenAvailable) {
      throw const BridgeValidationException(
        'live_bridge_route_changed',
      );
    }
  }

  Future<void> _showPersistedRelay(BridgeFundingReceipt receipt) async {
    final instruction = _instructionFromReceipt(receipt);
    if (instruction == null) {
      setState(() => _error = 'Stored deposit instruction is incomplete.');
      return;
    }
    final action = await RelayDepositSheet.show(
      context,
      instruction: instruction,
      onCopy: widget.copyText,
      clock: widget.clock,
    );
    if (action == RelayDepositSheetAction.hide) {
      await _runBusy(
        () => widget.controller.archiveRelayInstructions(receipt.intentId),
      );
    }
  }

  RelayDepositInstruction? _instructionFromReceipt(
    BridgeFundingReceipt receipt,
  ) {
    final chain = _chainFor(receipt.sourceChainId);
    final token = _tokenFor(receipt);
    final address = receipt.depositAddress;
    final requestId = receipt.providerRequestId;
    final expiresAt = receipt.expiresAt;
    if (chain == null ||
        token == null ||
        address == null ||
        requestId == null ||
        expiresAt == null ||
        receipt.refundAddress == null) {
      return null;
    }
    final request = BridgeFundingRequest(
      method: BridgeFundingMethod.relayDeposit,
      sourceChain: chain,
      sourceToken: token,
      amount: _formatUnits(receipt.sourceAmountUnits, token.decimals),
      amountUnits: receipt.sourceAmountUnits,
      baseDestinationAddress: receipt.baseDestinationAddress,
      refundAddress: receipt.refundAddress,
      selfCustodyConfirmed: true,
    );
    return RelayDepositInstruction(
      requestId: requestId,
      depositAddress: address,
      request: request,
      minimumOutputUnits: receipt.minimumOutputUnits ?? '0',
      minimumOutputDisplay: _formatUnits(receipt.minimumOutputUnits ?? '0', 6),
      createdAt: receipt.createdAt,
      expiresAt: expiresAt,
    );
  }

  Future<void> _refreshReceipt(BridgeFundingReceipt receipt) => _runBusy(
        () async {
          await widget.controller.refreshStatus(receipt.intentId);
          _notifyIfCompleted(receipt.intentId);
        },
      );

  Future<void> _cancelPreSubmission(BridgeFundingReceipt receipt) => _runBusy(
        () async {
          await widget.controller.cancelBeforeSubmission(receipt.intentId);
          _resumeStarted = false;
          _walletOptions = const <ExternalWalletOption>[];
          if (mounted) setState(() {});
        },
      );

  Future<void> _pollInBackground(String intentId) async {
    try {
      await widget.controller.pollSettlement(intentId);
      _notifyIfCompleted(intentId);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Transfer was not resent. Status can be refreshed safely.');
      }
    }
  }

  void _notifyIfCompleted(String intentId) {
    if (_completionCallbacksDelivered.contains(intentId)) {
      return;
    }
    BridgeFundingReceipt? completed;
    for (final receipt in widget.controller.receipts) {
      if (receipt.intentId == intentId &&
          receipt.state == BridgeFundingState.completed &&
          receipt.baseDestinationAddress.toLowerCase() ==
              widget.baseDestinationAddress?.toLowerCase()) {
        completed = receipt;
        break;
      }
    }
    if (completed == null) return;
    _completionCallbacksDelivered.add(intentId);
    if (mounted) setState(() => _startAnotherTransfer = false);
    widget.onFundingCompleted?.call(completed);
  }

  void _resumeActiveReceipt() {
    if (_resumeStarted || !mounted) return;
    final receipt = widget.controller.activeReceipt ?? _latestTrackableReceipt;
    if (receipt == null || !_statusCanRefresh(receipt)) return;
    _resumeStarted = true;
    unawaited(_pollInBackground(receipt.intentId));
  }

  BridgeFundingReceipt? get _latestTrackableReceipt {
    final receipts = <BridgeFundingReceipt>[...widget.controller.receipts]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    for (final receipt in receipts) {
      if (_statusCanRefresh(receipt)) return receipt;
    }
    return null;
  }

  Future<void> _recoverReceipt(BridgeFundingReceipt receipt) => _runBusy(
        () => receipt.sourceChainId == BridgeConstants.solanaChainId
            ? widget.controller.recoverSolanaSignature(
                receipt.intentId,
                _recoveryId.text.trim(),
              )
            : widget.controller.recoverEvmTransactionHash(
                receipt.intentId,
                _recoveryId.text.trim(),
              ),
      );

  Future<void> _scanSolana(BridgeFundingReceipt receipt) => _runBusy(() async {
        final result =
            await widget.controller.scanSolanaRecovery(receipt.intentId);
        if (!mounted) return;
        setState(() => _error = switch (result) {
              SolanaRecoveryScanResult.matched =>
                'Matching Solana transaction found and attached.',
              SolanaRecoveryScanResult.inconclusive =>
                'History is incomplete. Plawie will not resend.',
              SolanaRecoveryScanResult.ambiguous =>
                'More than one match needs manual review.',
              SolanaRecoveryScanResult.expired =>
                'No submission was found and the reviewed blockhash expired.',
            });
      });

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on BridgeValidationException catch (error) {
      if (mounted) setState(() => _error = _bridgeError(error));
    } on ExternalWalletException catch (error) {
      if (mounted) setState(() => _error = _walletError(error));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Funding could not continue. No automatic retry or resend occurred.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  BridgeChain? _chainFor(int chainId) {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    for (final chain in <BridgeChain>{
      ...snapshot.connectedChains,
      ...snapshot.relayChains,
    }) {
      if (chain.id == chainId) return chain;
    }
    return null;
  }

  BridgeToken? _tokenFor(BridgeFundingReceipt receipt) {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    final tokens = <BridgeToken>{
      ...snapshot.connectedTokensFor(receipt.sourceChainId),
      ...snapshot.relayTokensFor(receipt.sourceChainId),
    };
    for (final token in tokens) {
      final same = receipt.sourceChainId == BridgeConstants.solanaChainId
          ? token.address == receipt.sourceTokenAddress
          : token.address.toLowerCase() ==
              receipt.sourceTokenAddress.toLowerCase();
      if (same) return token;
    }
    return null;
  }
}

final class _MainnetBadge extends StatelessWidget {
  const _MainnetBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF0052FF).withValues(alpha: .18),
        ),
        child: const Text(
          'MAINNET',
          style: TextStyle(
            color: Color(0xFF7EA4FF),
            fontWeight: FontWeight.w800,
            fontSize: 9,
          ),
        ),
      );
}

final class _LoadingRoutes extends StatelessWidget {
  const _LoadingRoutes();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(child: Text('Checking funding routes…')),
        ],
      );
}

final class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: .35),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

final class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: .45)),
        ),
        child: Text(message),
      );
}

bool _statusCanRefresh(BridgeFundingReceipt receipt) =>
    receipt.state == BridgeFundingState.awaitingDeposit ||
    receipt.state == BridgeFundingState.depositDetected ||
    receipt.state == BridgeFundingState.submitted ||
    receipt.state == BridgeFundingState.sourcePending ||
    receipt.state == BridgeFundingState.destinationPending ||
    (receipt.method == BridgeFundingMethod.relayDeposit &&
        receipt.state == BridgeFundingState.expired);

bool _canCancelBeforeSubmission(BridgeFundingReceipt receipt) =>
    receipt.sourceTransactionHash == null &&
    !receipt.submissionOutcomeUnknown &&
    <BridgeFundingState>{
      BridgeFundingState.draft,
      BridgeFundingState.checkingCapabilities,
      BridgeFundingState.connectingWallet,
      BridgeFundingState.collectingRefundAddress,
      BridgeFundingState.quoting,
      BridgeFundingState.awaitingPlawieReview,
    }.contains(receipt.state);

String _stateTitle(BridgeFundingState state) => switch (state) {
      BridgeFundingState.awaitingPlawieReview => 'Review required',
      BridgeFundingState.awaitingDeposit => 'Waiting for exact deposit',
      BridgeFundingState.awaitingExternalWallet => 'Waiting for wallet',
      BridgeFundingState.depositDetected => 'Deposit detected',
      BridgeFundingState.submitted ||
      BridgeFundingState.sourcePending =>
        'Source transaction pending',
      BridgeFundingState.destinationPending => 'Base delivery pending',
      BridgeFundingState.completed => 'Funding completed',
      BridgeFundingState.partial => 'Partially filled',
      BridgeFundingState.refunded => 'Refunded by provider',
      BridgeFundingState.expired => 'Instruction expired',
      BridgeFundingState.failed => 'Funding failed',
      BridgeFundingState.cancelled => 'Cancelled before submission',
      _ => 'Funding in progress',
    };

String _shortWalletAddress(String value) {
  if (value.length <= 14) return value;
  return '${value.substring(0, 7)}…${value.substring(value.length - 5)}';
}

String _bridgeError(BridgeValidationException error) => switch (error.code) {
      'active_bridge_receipt_exists' =>
        'Another funding transfer is still active. Resume it first.',
      'base_destination_changed' =>
        'The internal Base wallet changed. Request a fresh route.',
      'prepared_wallet_context_changed' ||
      'connected_wallet_mismatch' =>
        'Wallet account or chain changed. No transaction was sent.',
      'quote_expired' => 'The quote expired. No transaction was sent.',
      'live_bridge_capabilities_required' =>
        'The live funding routes could not be refreshed. Nothing was connected or sent.',
      'live_bridge_route_changed' =>
        'The selected route is no longer in the live funding routes. Review the updated choices.',
      'relay_late_deposit_evidence_missing' =>
        'Relay status lacks safe deposit evidence. Nothing was resent.',
      _ => error.message.isEmpty
          ? 'Funding stopped safely (${error.code}).'
          : error.message,
    };

String _walletError(ExternalWalletException error) => switch (error.code) {
      'wallet_user_rejected' =>
        'Wallet request was rejected. Nothing was sent.',
      'wallet_transport_unavailable' =>
        'No compatible wallet transport is available for this route.',
      'wallet_chain_mismatch' ||
      'wallet_account_mismatch' =>
        'Wallet account or network changed. Nothing was sent.',
      'wallet_operation_in_progress' =>
        'A wallet request is already waiting for your response.',
      _ => 'Wallet request stopped safely (${error.code}).',
    };

String _amountUnits(String input, int decimals) {
  final normalized = input.trim();
  if (decimals < 0 ||
      decimals > 36 ||
      !RegExp(r'^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$').hasMatch(normalized)) {
    throw const FormatException('invalid amount');
  }
  final parts = normalized.split('.');
  final fraction = parts.length == 1 ? '' : parts[1];
  if (fraction.length > decimals) throw const FormatException('precision');
  final units = BigInt.parse(
    '${parts[0]}${fraction.padRight(decimals, '0')}',
  );
  if (units <= BigInt.zero) throw const FormatException('zero');
  return units.toString();
}

String _normalizeAmount(String input) {
  var value = input.trim();
  if (!value.contains('.')) return value;
  value = value.replaceFirst(RegExp(r'0+$'), '');
  return value.endsWith('.') ? value.substring(0, value.length - 1) : value;
}

String _formatUnits(String units, int decimals) {
  final value = BigInt.tryParse(units);
  if (value == null || value.isNegative || decimals < 0) return units;
  final padded = value.toString().padLeft(decimals + 1, '0');
  if (decimals == 0) return padded;
  final whole = padded.substring(0, padded.length - decimals);
  final fraction = padded
      .substring(padded.length - decimals)
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole : '$whole.$fraction';
}

int _fallbackDecimals(String symbol) => switch (symbol.toUpperCase()) {
      'ETH' => 18,
      'SOL' => 9,
      _ => 6,
    };

String _sourceChainLabel(int chainId) => switch (chainId) {
      BridgeConstants.ethereumChainId => 'Ethereum',
      BridgeConstants.baseChainId => 'Base Mainnet',
      BridgeConstants.robinhoodChainId => 'Robinhood Chain',
      BridgeConstants.solanaChainId => 'Solana',
      _ => 'Chain $chainId',
    };

String _receiptTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

bool _validAddress(String address, BridgeChainType type) =>
    type == BridgeChainType.evm
        ? RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)
        : RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address);

String _shortAddress(String address) {
  if (address.length <= 14) return address;
  return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
}

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> _copyText(String text) =>
    Clipboard.setData(ClipboardData(text: text));
