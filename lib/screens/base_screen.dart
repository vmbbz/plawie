import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:decimal/decimal.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../services/ai_payment_provider_catalog.dart';
import '../services/base_service.dart';
import '../services/base_wallet_recovery_view_model.dart';
import '../services/bridge/bridge_funding_runtime.dart';
import '../services/bridge/bridge_models.dart';
import '../services/dynamic_model_catalog.dart';
import '../services/native_bridge.dart';
import '../services/paid_provider_gateway_coordinator.dart';
import '../services/preferences_service.dart';
import '../services/provider_balance_service.dart';
import '../services/provider_model_discovery_service.dart';
import '../services/provider_top_up_funding_coordinator.dart';
import '../services/wallet_funded_provider_readiness.dart';
import '../services/x402_payment_service.dart';
import '../services/x402_payment_transport_service.dart';
import '../widgets/status_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/bridge_funding_panel.dart';
import '../widgets/keeperhub_agent_wallet_card.dart';

class BaseScreen extends StatefulWidget {
  const BaseScreen({
    super.key,
    this.initialPaymentProviderId,
    this.initialAction,
  });

  final String? initialPaymentProviderId;
  final WalletFundedProviderAction? initialAction;

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  final BaseService _baseService = BaseService();
  final PreferencesService _prefs = PreferencesService();
  final X402PaymentTransportService _x402Transport =
      X402PaymentTransportService();
  final ProviderBalanceService _providerBalances =
      ProviderBalanceService.instance;
  BridgeFundingRuntime? _bridgeFunding;
  StreamSubscription<BaseEvent>? _eventSub;
  bool _isLoading = false;
  String? _error;
  String _selectedAiPaymentProvider =
      AiPaymentProviderCatalog.providers.first.id;
  List<X402PaymentReceipt> _paymentReceipts = const <X402PaymentReceipt>[];
  bool _aiPaymentBusy = false;
  String? _aiPaymentProgress;
  ProviderBalanceSnapshot? _providerBalance;
  bool _providerBalanceBusy = false;
  bool _providerReadinessBusy = false;
  DynamicCatalogSnapshot _modelCatalog =
      DynamicCatalogSnapshot.bundledFallback();
  PaidProviderTransportState _paidTransportState =
      PaidProviderTransportState.stopped;
  bool _initialActionHandled = false;

  @override
  void initState() {
    super.initState();
    _eventSub = _baseService.events.listen(_onEvent);
    _initBase();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _x402Transport.dispose();
    final bridgeFunding = _bridgeFunding;
    if (bridgeFunding != null) unawaited(bridgeFunding.dispose());
    super.dispose();
  }

  void _onEvent(BaseEvent event) {
    if (!mounted) return;
    if (event.type == BaseEventType.error) {
      setState(() => _error = event.message);
    } else {
      setState(() {});
    }
  }

  Future<void> _initBase() async {
    setState(() => _isLoading = true);
    try {
      await _prefs.init();
      final selectedPaymentProvider =
          AiPaymentProviderCatalog.byId(widget.initialPaymentProviderId) ??
              AiPaymentProviderCatalog.byId(_prefs.aiPaymentProvider);
      if (selectedPaymentProvider != null) {
        _selectedAiPaymentProvider = selectedPaymentProvider.id;
        _providerBalance = _providerBalances.cached(selectedPaymentProvider.id);
        _prefs.aiPaymentProvider = selectedPaymentProvider.id;
      }
      await _baseService.initialize();
      if (!mounted) return;
      _bridgeFunding ??= BridgeFundingRuntime.create(
        context: context,
        preferences: _prefs,
        baseService: _baseService,
        isForeground: () => mounted,
      );
      final cachedCatalog = await DynamicModelCatalogRepository().load();
      _modelCatalog =
          (cachedCatalog ?? DynamicCatalogSnapshot.bundledFallback())
              .withEffectiveState(DateTime.now());
      final transportHealth =
          await PaidProviderGatewayCoordinator.instance.inspectHealth();
      _paidTransportState = transportHealth == null
          ? PaidProviderTransportState.stopped
          : transportHealth
              ? PaidProviderTransportState.healthy
              : PaidProviderTransportState.unhealthy;
      _paymentReceipts = await _x402Transport.receiptStore.read();
      if (_baseService.isConnected) {
        await _baseService.refreshBalance();
        if (_baseService.isBaseMainnet) {
          await _baseService.refreshBaseUsdcBalanceUnitsForPayment();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (mounted && !_initialActionHandled && widget.initialAction != null) {
      _initialActionHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runInitialProviderAction());
      });
    }
  }

  Future<void> _runInitialProviderAction() async {
    final action = widget.initialAction;
    final provider =
        AiPaymentProviderCatalog.byId(_selectedAiPaymentProvider) ??
            AiPaymentProviderCatalog.providers.first;
    switch (action) {
      case WalletFundedProviderAction.fundWallet:
        if (_baseService.isConnected) {
          await _showBaseFundingModal();
        } else {
          _showWalletRequiredDialog();
        }
        break;
      case WalletFundedProviderAction.switchToMainnet:
        if (_baseService.isConnected) {
          await _switchToMainnetForAiPayments();
        } else {
          _showWalletRequiredDialog();
        }
        break;
      case WalletFundedProviderAction.refreshBalance:
        if (_baseService.isConnected) {
          await _refreshProviderBalance(provider);
        } else {
          _showWalletRequiredDialog();
        }
        break;
      case WalletFundedProviderAction.topUpVenice:
        if (!_baseService.isConnected) {
          _showWalletRequiredDialog();
        } else {
          await _showTopUpPreparation(provider);
        }
        break;
      case WalletFundedProviderAction.none:
      case WalletFundedProviderAction.openBase:
      case WalletFundedProviderAction.restartGateway:
      case WalletFundedProviderAction.refreshModels:
      case null:
        break;
    }
  }

  Future<void> _refreshBalance() async {
    setState(() => _isLoading = true);
    try {
      await _baseService.refreshWalletStatus();
      if (_baseService.isConnected) {
        await _baseService.refreshBalance();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectWalletNetwork(WalletNetwork selected) async {
    if (_isLoading || selected == _baseService.selectedNetwork) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _baseService.setWalletNetwork(selected);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makeCurrentNetworkDefault() async {
    if (_isLoading || _baseService.isSelectedNetworkDefault) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _baseService.setDefaultWalletNetwork(
        _baseService.selectedNetwork,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_baseService.defaultNetworkDefinition.name} will open by default',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _confirmTransfer({
    required String token,
    required String destination,
    required Decimal amount,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm transfer'),
            content: Text(
              'You are about to send $amount $token to:\n\n'
              '$destination\n\n'
              'Network: ${_baseService.networkName}\n\n'
              'This action will broadcast a blockchain transaction.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Approve & send'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedNetwork = _baseService.network;
    final stablecoin = selectedNetwork.token;
    final canSend = _baseService.ordinaryTransactionsAvailable && !_isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          NebulaBg(),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: AppLayout.standardSliverHeaderHeight,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/app_icon_official.svg',
                      width: 20,
                      height: 20,
                      colorFilter:
                          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'WALLET',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 3.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: FlexibleSpaceBar(
                      background:
                          Container(color: Colors.black.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
                actions: [
                  PopupMenuButton<WalletNetwork>(
                    icon: Icon(
                      _networkIcon(selectedNetwork),
                      color: _networkColor(selectedNetwork),
                    ),
                    tooltip: 'Network: ${_baseService.networkName}',
                    onSelected: _selectWalletNetwork,
                    itemBuilder: (context) => WalletNetworkPolicy.values
                        .map(
                          (definition) => PopupMenuItem<WalletNetwork>(
                            value: definition.network,
                            child: Row(
                              children: [
                                Icon(
                                  _networkIcon(definition),
                                  color: definition.network ==
                                          _baseService.selectedNetwork
                                      ? _networkColor(definition)
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(definition.isTestnet
                                      ? '${definition.name} (Testnet)'
                                      : definition.name),
                                ),
                                if (definition.network ==
                                    _baseService.selectedNetwork)
                                  const Icon(Icons.check, size: 18),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _refreshBalance,
                    tooltip: 'Refresh wallet status',
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: _isLoading && !_baseService.isConnected
                    ? const Padding(
                        padding: EdgeInsets.only(top: 100),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshBalance,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            AppLayout.pageTopInset,
                            20,
                            24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWalletHeader(theme),
                              const SizedBox(height: 16),
                              _buildWalletStatePanel(theme),
                              const SizedBox(height: 24),
                              _sectionLabel(theme, 'AGENT EXECUTION'),
                              KeeperHubAgentWalletCard(
                                personalWalletAddress: _baseService.address,
                              ),
                              const SizedBox(height: 24),
                              _buildNetworkBanner(theme),
                              const SizedBox(height: 16),
                              _sectionLabel(theme, 'AI PAYMENTS'),
                              _buildAiPaymentsPanel(theme),
                              const SizedBox(height: 16),
                              _sectionLabel(theme, 'BRIDGE INTO BASE'),
                              _buildBridgePanel(theme),
                              const SizedBox(height: 24),
                              _sectionLabel(theme, 'WALLET ACTIONS'),
                              if (!_baseService.isConnected)
                                ..._buildRecoveryActionCards(theme),
                              if (_baseService.isConnected) ...[
                                StatusCard(
                                  title: 'Send ETH',
                                  subtitle: canSend
                                      ? selectedNetwork.supportsBasenames
                                          ? 'Transfer ETH to an address or .base.eth name'
                                          : 'Transfer ETH to an explicit 0x address'
                                      : _baseService
                                          .ordinaryTransactionUnavailableReason,
                                  icon: Icons.send,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: canSend ? _showSendEthDialog : null,
                                ),
                                if (stablecoin != null)
                                  StatusCard(
                                    title: 'Send ${stablecoin.symbol}',
                                    subtitle: canSend
                                        ? 'Transfer official ${stablecoin.symbol} on ${selectedNetwork.name}'
                                        : _baseService
                                            .ordinaryTransactionUnavailableReason,
                                    icon: Icons.attach_money,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: canSend
                                        ? _showSendStablecoinDialog
                                        : null,
                                  ),
                                StatusCard(
                                  title: 'Receive',
                                  subtitle: 'Show your wallet address / QR',
                                  icon: Icons.qr_code,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _showReceiveDialog,
                                ),
                                const SizedBox(height: 24),
                                _sectionLabel(theme, 'RECENT TRANSACTIONS'),
                                _buildTransactionHistory(theme),
                                const SizedBox(height: 24),
                                _sectionLabel(theme, 'AI AGENT SKILLS'),
                                _buildSkillsInfo(theme),
                                const SizedBox(height: 24),
                                _sectionLabel(theme, 'WALLET MANAGEMENT'),
                                StatusCard(
                                  title: 'Export Private Key',
                                  subtitle: 'View and copy your private key',
                                  icon: Icons.vpn_key,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _showExportKeyDialog,
                                ),
                                StatusCard(
                                  title: 'Remove Wallet',
                                  subtitle:
                                      'Permanently remove this wallet from the device',
                                  icon: Icons.logout,
                                  trailing: Icon(Icons.chevron_right,
                                      color: theme.colorScheme.error),
                                  onTap: _showDisconnectDialog,
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                _buildErrorBanner(theme),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBridgePanel(ThemeData theme) {
    final runtime = _bridgeFunding;
    if (runtime == null) {
      return const GlassCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'External funding is unavailable because its local runtime could not be initialized.',
          ),
        ),
      );
    }
    return BridgeFundingPanel(
      controller: runtime.controller,
      capabilities: runtime.capabilities,
      baseDestinationAddress: _baseService.address,
      baseWalletAvailable: _baseService.isConnected,
      baseMainnetSelected: _baseService.isBaseMainnet,
      onFundingCompleted: _handleBridgeFundingCompleted,
    );
  }

  Future<void> _handleBridgeFundingCompleted(
    BridgeFundingReceipt receipt,
  ) async {
    try {
      if (receipt.balanceRefreshPending) {
        await _bridgeFunding?.controller.refreshBaseBalance(receipt.intentId);
      } else {
        await _baseService.refreshBaseUsdcBalanceUnitsForPayment();
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_bridgeReceivedAmount(receipt)} USDC confirmed on Base Mainnet.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error =
          'Funding settled, but the Base USDC display could not refresh: $error');
    }
  }

  // ── Section helpers ────────────────────────────────────────────────────────

  IconData _networkIcon(WalletNetworkDefinition definition) =>
      switch (definition.network) {
        WalletNetwork.baseMainnet => Icons.public,
        WalletNetwork.robinhoodMainnet => Icons.swap_horiz_rounded,
        WalletNetwork.baseSepolia => Icons.science,
      };

  Color _networkColor(WalletNetworkDefinition definition) =>
      switch (definition.network) {
        WalletNetwork.baseMainnet => const Color(0xFF0052FF),
        WalletNetwork.robinhoodMainnet => const Color(0xFF00C805),
        WalletNetwork.baseSepolia => Colors.orange,
      };

  Widget _sectionLabel(ThemeData theme, String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      );

  // ── AI payment hub ─────────────────────────────────────────────────────────────

  Widget _buildAiPaymentsPanel(ThemeData theme) {
    final selected =
        AiPaymentProviderCatalog.byId(_selectedAiPaymentProvider) ??
            AiPaymentProviderCatalog.providers.first;
    final mainnetReady = _baseService.isBaseMainnet;
    final readiness = _readinessFor(selected);
    final baseUsdc =
        _baseService.isBaseMainnet ? _baseService.usdcBalance : Decimal.zero;
    final baseFunded = baseUsdc > Decimal.zero;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined,
                    color: Color(0xFF0052FF), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Base Mainnet AI payments',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0052FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'USDC',
                    style: TextStyle(
                        color: Color(0xFF5B8CFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fund this wallet, top up a provider balance, or approve an exact x402 request. These are separate actions; Plawie never treats a chat message as payment approval.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.4),
            ),
            if (!mainnetReady) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'x402 payments settle on Base Mainnet. The wallet is currently showing ${_baseService.networkName}.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _baseService.setWalletNetwork(
                          WalletNetwork.baseMainnet,
                        );
                        if (mounted) setState(() {});
                      },
                      child: const Text('Switch'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              key: const Key('base-ai-payment-wallet-balance'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0052FF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF5B8CFF).withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Color(0xFF5B8CFF), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BASE PAYMENT WALLET',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _baseService.isBaseMainnet
                              ? '${baseUsdc.toString()} USDC available'
                              : 'Switch to Base Mainnet to check USDC',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (selected.fundingMode == AiPaymentFundingMode.perRequest &&
                      baseFunded)
                    const _WalletReadyBadge(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('PROVIDER',
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AiPaymentProviderCatalog.providers.map((provider) {
                return ChoiceChip(
                  label: Text(provider.label),
                  selected: provider.id == selected.id,
                  onSelected: (_) {
                    setState(() {
                      _selectedAiPaymentProvider = provider.id;
                      _providerBalance = _providerBalances.cached(provider.id);
                    });
                    _prefs.aiPaymentProvider = provider.id;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(readiness?.title ?? selected.fundingLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(readiness?.detail ?? selected.description,
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.4)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (readiness != null)
                        Text(
                          readiness.catalogLabel,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      if (readiness != null)
                        Text(
                          readiness.transportLabel,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      if (readiness != null &&
                          const <WalletFundedProviderAction>{
                            WalletFundedProviderAction.refreshModels,
                            WalletFundedProviderAction.restartGateway,
                          }.contains(readiness.primaryAction))
                        TextButton(
                          key: const Key('base-provider-readiness-action'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          onPressed: _providerReadinessBusy
                              ? null
                              : () => _runBaseReadinessAction(
                                    selected,
                                    readiness,
                                  ),
                          child: Text(_providerReadinessBusy
                              ? 'Working…'
                              : readiness.primaryActionLabel),
                        ),
                    ],
                  ),
                  if (selected.supportsTopUp) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _providerBalance?.summary ??
                                (selected.fundingMode ==
                                        AiPaymentFundingMode.perRequest
                                    ? 'No prepaid provider balance.'
                                    : 'Balance not checked on this device.'),
                            style: TextStyle(
                              color: _providerBalance?.needsAttention == true
                                  ? Colors.orangeAccent
                                  : theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed:
                              _baseService.isConnected && !_providerBalanceBusy
                                  ? () => _refreshProviderBalance(selected)
                                  : null,
                          icon: _providerBalanceBusy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Balance'),
                        ),
                      ],
                    ),
                  ],
                  if (!selected.supportsTopUp) ...[
                    const SizedBox(height: 7),
                    Text(
                      baseFunded
                          ? 'This Base USDC is already the BlockRun payment balance. Nothing is deposited into BlockRun in advance.'
                          : 'BlockRun has no prepaid balance. Add USDC to this Base wallet before a paid request.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _baseService.isConnected
                        ? () => unawaited(_showBaseFundingModal())
                        : _showWalletRequiredDialog,
                    icon: const Icon(Icons.account_balance_wallet_outlined,
                        size: 18),
                    label:
                        Text(baseFunded ? 'Add Base USDC' : 'Fund Base wallet'),
                  ),
                ),
                if (selected.supportsTopUp) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _baseService.isConnected
                          ? _aiPaymentBusy
                              ? null
                              : () => _showTopUpPreparation(selected)
                          : _showWalletRequiredDialog,
                      icon: _aiPaymentBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_card_rounded, size: 18),
                      label: Text(_aiPaymentBusy ? 'Preparing…' : 'Top up'),
                    ),
                  ),
                ],
              ],
            ),
            if (!selected.supportsTopUp) ...[
              const SizedBox(height: 10),
              Text(
                'No top-up is needed. Chat will show a separate amount, recipient, network, and expiry approval only after the provider returns a valid payment request.',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (_aiPaymentProgress != null) ...[
              const SizedBox(height: 10),
              Text(
                _aiPaymentProgress!,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 17, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: _paymentReceipts.isEmpty
                      ? Text(
                          'No x402 receipts yet. Settled payments will appear here.',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _paymentReceipts.take(3).map((receipt) {
                            final amount = _formatReceiptAmount(receipt.amount);
                            final deliveredUnverified =
                                receipt.responseDeliveredSettlementUnverified;
                            final status = deliveredUnverified
                                ? 'response delivered'
                                : receipt.settlementVerified
                                    ? 'settlement verified'
                                    : receipt.state.name;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${receipt.providerId ?? 'x402'} · $amount USDC · $status · ${_shortDate(receipt.recordedAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: receipt.settlementVerified
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                    ),
                                  ),
                                  if (deliveredUnverified)
                                    Text(
                                      'Settlement proof unavailable · paid request will not be retried.',
                                      style: TextStyle(
                                        fontSize: 10,
                                        height: 1.35,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(growable: false),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  WalletFundedProviderReadiness? _readinessFor(
    AiPaymentProviderOption selected,
  ) {
    DynamicProviderRecord? provider;
    for (final candidate in _modelCatalog.providers) {
      if (candidate.id == selected.id) {
        provider = candidate;
        break;
      }
    }
    if (provider == null) return null;
    return WalletFundedProviderReadinessService.evaluate(
      provider: provider,
      walletStatus: _baseService.walletStatus,
      isBaseMainnet: _baseService.isBaseMainnet,
      transportState: _paidTransportState,
      balance: _providerBalance,
      now: DateTime.now().toUtc(),
      baseUsdcBalance:
          _baseService.isBaseMainnet ? _baseService.usdcBalance : null,
    );
  }

  Future<void> _runBaseReadinessAction(
    AiPaymentProviderOption selected,
    WalletFundedProviderReadiness readiness,
  ) async {
    if (_providerReadinessBusy) return;
    setState(() => _providerReadinessBusy = true);
    try {
      if (readiness.primaryAction == WalletFundedProviderAction.refreshModels) {
        final refreshed =
            await ProviderModelDiscoveryService().refreshProvider(selected.id);
        _modelCatalog = refreshed.withEffectiveState(DateTime.now());
      } else if (readiness.primaryAction ==
          WalletFundedProviderAction.restartGateway) {
        final gateway = context.read<GatewayProvider>();
        await gateway.stop();
        await gateway.start();
        final health =
            await PaidProviderGatewayCoordinator.instance.inspectHealth();
        _paidTransportState = health == true
            ? PaidProviderTransportState.healthy
            : health == null
                ? PaidProviderTransportState.stopped
                : PaidProviderTransportState.unhealthy;
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(readiness.primaryAction ==
                  WalletFundedProviderAction.refreshModels
              ? '${selected.label} models refreshed.'
              : 'Gateway transport restarted.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Provider readiness action failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _providerReadinessBusy = false);
    }
  }

  void _showWalletRequiredDialog() {
    final view = BaseWalletRecoveryViewModel.fromStatus(
      _baseService.walletStatus,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(view.title),
        content: Text(
          '${view.consequence}\n\n${view.guidance}\n\n'
          'Funding a wallet never authorizes an AI payment.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (view.canCreate)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showCreateWalletDialog();
              },
              child: const Text('Create wallet'),
            ),
        ],
      ),
    );
  }

  Future<void> _switchToMainnetForAiPayments() async {
    if (!_baseService.isBaseMainnet) {
      await _baseService.setWalletNetwork(WalletNetwork.baseMainnet);
    }
    if (mounted) setState(() {});
  }

  Future<void> _showTopUpPreparation(
    AiPaymentProviderOption provider,
  ) async {
    if (_aiPaymentBusy) return;
    setState(() {
      _aiPaymentBusy = true;
      _aiPaymentProgress =
          'Requesting a fresh ${provider.label} payment challenge…';
    });
    try {
      final coordinator = ProviderTopUpFundingCoordinator(
        prepare: _x402Transport.prepareTopUp,
        reject: _x402Transport.reject,
        selectBaseMainnet: _switchToMainnetForAiPayments,
        refreshBaseUsdcBalance:
            _baseService.refreshBaseUsdcBalanceUnitsForPayment,
        requestFunding: _showProviderFundingModal,
        requestPaymentApproval: _showX402Approval,
        submitPayment: (payment) => _x402Transport.approveAndSubmit(
          payment,
          walletAddress: _baseService.address ?? '',
        ),
      );
      final receipt = await coordinator.run(
        provider,
        onProgress: (stage) {
          if (mounted) {
            setState(() =>
                _aiPaymentProgress = _providerTopUpProgress(provider, stage));
          }
        },
      );
      if (receipt == null) {
        if (mounted) setState(() => _aiPaymentProgress = 'Payment cancelled.');
        return;
      }
      _paymentReceipts = await _x402Transport.receiptStore.read();
      if (!mounted) return;
      final settled = receipt.state == X402PaymentState.settled;
      setState(() {
        _aiPaymentProgress = settled
            ? '${provider.label} confirmed the top-up.'
            : receipt.state == X402PaymentState.uncertain
                ? 'Submission is uncertain. Check the receipt before retrying.'
                : 'The provider rejected the signed payment. No automatic retry was attempted.';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(settled
            ? '${provider.label} top-up settled.'
            : _aiPaymentProgress!),
      ));
      await _baseService.refreshBalance();
    } catch (error) {
      if (!mounted) return;
      setState(() => _aiPaymentProgress = 'Top-up stopped safely: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Top-up stopped safely: $error')),
      );
    } finally {
      if (mounted) setState(() => _aiPaymentBusy = false);
    }
  }

  String _providerTopUpProgress(
    AiPaymentProviderOption provider,
    ProviderTopUpFundingStage stage,
  ) =>
      switch (stage) {
        ProviderTopUpFundingStage.selectingBase =>
          'Switching the Wallet view to Base Mainnet…',
        ProviderTopUpFundingStage.requestingChallenge =>
          'Requesting a fresh ${provider.label} payment challenge…',
        ProviderTopUpFundingStage.checkingBalance =>
          'Checking the exact Base USDC balance…',
        ProviderTopUpFundingStage.fundingRequired =>
          'More Base USDC is needed. Choose a source and approve the bridge separately.',
        ProviderTopUpFundingStage.verifyingFunding =>
          'Base delivery completed. Verifying the refreshed USDC balance…',
        ProviderTopUpFundingStage.requestingFreshChallenge =>
          'Funding verified. Requesting a new ${provider.label} challenge…',
        ProviderTopUpFundingStage.awaitingPaymentApproval =>
          'Challenge verified. Waiting for your separate payment approval.',
        ProviderTopUpFundingStage.submittingPayment =>
          'Unlock the secure wallet to sign this one payment…',
        ProviderTopUpFundingStage.cancelled => 'Payment cancelled.',
      };

  Future<bool> _showProviderFundingModal(
    ProviderFundingRequirement requirement,
  ) =>
      _showBaseFundingModal(requirement: requirement);

  Future<bool> _showBaseFundingModal({
    ProviderFundingRequirement? requirement,
  }) async {
    final runtime = _bridgeFunding;
    if (runtime == null || !_baseService.isConnected) return false;
    if (!_baseService.isBaseMainnet) {
      await _switchToMainnetForAiPayments();
    }
    if (!mounted) return false;

    final completed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF080A0E),
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: FractionallySizedBox(
            heightFactor: 0.94,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              requirement == null
                                  ? 'Add USDC to the Base wallet'
                                  : 'Fund ${requirement.provider.label} on Base',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              requirement == null
                                  ? 'Use Base USDC from another wallet, or choose another live source route. Every transfer requires separate review and wallet approval.'
                                  : 'At least ${requirement.requiredBaseUsdcDisplay} USDC is required in the Plawie Base wallet. Use Base USDC from another wallet, or choose any other live source route, then approve the provider payment separately.',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel funding',
                        onPressed: () => Navigator.pop(sheetContext, false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: BridgeFundingPanel(
                      controller: runtime.controller,
                      capabilities: runtime.capabilities,
                      baseDestinationAddress: _baseService.address,
                      baseWalletAvailable: _baseService.isConnected,
                      baseMainnetSelected: _baseService.isBaseMainnet,
                      initialSourceChainId: BridgeConstants.baseChainId,
                      initialSourceTokenSymbol: 'USDC',
                      startNewTransfer: true,
                      onFundingCompleted: (_) {
                        if (Navigator.of(sheetContext).canPop()) {
                          Navigator.pop(sheetContext, true);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return completed == true;
  }

  Future<void> _refreshProviderBalance(
    AiPaymentProviderOption provider,
  ) async {
    if (_providerBalanceBusy) return;
    setState(() => _providerBalanceBusy = true);
    try {
      final snapshot = await _providerBalances.refreshWalletProvider(
        provider: provider,
        walletAddress: _baseService.address ?? '',
      );
      if (!mounted) return;
      setState(() => _providerBalance = snapshot);
      if (snapshot.needsAttention) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snapshot.summary)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Balance refresh failed safely: $error')),
      );
    } finally {
      if (mounted) setState(() => _providerBalanceBusy = false);
    }
  }

  Future<bool> _showX402Approval(PreparedX402Payment payment) async {
    final requirement = payment.intent.challenge.requirement;
    final seconds = payment.intent.expiresAt
        .difference(DateTime.now().toUtc())
        .inSeconds
        .clamp(0, requirement.maxTimeoutSeconds);
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Approve exact AI payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${payment.amountUsd.toStringAsFixed(2)} USDC',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Provider: ${payment.provider.label}\n'
                    'Purpose: ${payment.intent.challenge.resourceDescription ?? 'Provider balance top-up'}\n'
                    'Network: ${AiPaymentProviderCatalog.networkLabel}\n'
                    'Payer: ${_baseService.address}\n'
                    'Recipient: ${requirement.payTo}\n'
                    'Host: ${payment.intent.requestUrl.host}\n'
                    'Expires in: $seconds seconds',
                    style: const TextStyle(fontSize: 12, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Approval is one-use. Android will ask for your device credential, then Plawie retries only this exact request once. Chat and agents cannot press this button.',
                    style: TextStyle(fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Reject'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Approve & unlock'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _formatReceiptAmount(String? units) {
    final parsed = BigInt.tryParse(units ?? '');
    if (parsed == null) return '?';
    return (parsed.toDouble() / 1000000).toStringAsFixed(2);
  }

  String _shortDate(DateTime value) {
    final local = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  // ── Wallet header card ─────────────────────────────────────────────────────

  Widget _buildWalletStatePanel(ThemeData theme) {
    final status = _baseService.walletStatus;
    final view = BaseWalletRecoveryViewModel.fromStatus(status);
    final requiresAttention = status.state != SecureWalletState.healthy &&
        status.state != SecureWalletState.absent;
    final accent = requiresAttention
        ? theme.colorScheme.error
        : status.state == SecureWalletState.healthy
            ? Colors.greenAccent
            : theme.colorScheme.primary;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  requiresAttention
                      ? Icons.gpp_maybe_outlined
                      : Icons.verified_user_outlined,
                  color: accent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(view.consequence, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 5),
                      Text(
                        view.guidance,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (status.errorCode.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Status code: ${status.errorCode}',
                style: GoogleFonts.robotoMono(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (status.state != SecureWalletState.healthy) ...[
              const SizedBox(height: 12),
              Divider(color: theme.dividerColor.withValues(alpha: 0.35)),
              const SizedBox(height: 8),
              Text(
                'Wallet storage survives signed app updates. Clearing Plawie app data '
                'or uninstalling removes any wallet record on this device.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecoveryActionCards(ThemeData theme) {
    final view = BaseWalletRecoveryViewModel.fromStatus(
      _baseService.walletStatus,
    );
    final cards = <Widget>[];
    const chevron = Icon(Icons.chevron_right);

    if (view.canCreate) {
      cards.add(
        StatusCard(
          title: 'Create Wallet',
          subtitle: 'Generate one EVM identity for Base and Robinhood Chain',
          icon: Icons.add_circle_outline,
          trailing: chevron,
          onTap: _showCreateWalletDialog,
        ),
      );
    }
    if (view.canImport) {
      cards.add(
        StatusCard(
          title: 'Import Wallet',
          subtitle: 'Restore a 32-byte private-key backup',
          icon: Icons.file_download,
          trailing: chevron,
          onTap: _showImportWalletDialog,
        ),
      );
    }
    if (view.canMigrate) {
      cards.add(
        StatusCard(
          title: 'Secure existing wallet',
          subtitle: 'Move the historical key into Android Keystore protection',
          icon: Icons.security,
          trailing: chevron,
          onTap: _migrateLegacyWallet,
        ),
      );
    }
    if (view.canRestoreBackup) {
      cards.add(
        StatusCard(
          title: 'Restore from backup',
          subtitle: 'Remove the unusable record, then import its private key',
          icon: Icons.restore,
          trailing: chevron,
          onTap: _recoverAndImportWallet,
        ),
      );
    }
    if (view.canRemoveDamaged) {
      cards.add(
        StatusCard(
          title: 'Remove damaged wallet',
          subtitle: 'Permanently remove only the classified unusable record',
          icon: Icons.delete_forever_outlined,
          trailing: Icon(Icons.chevron_right, color: theme.colorScheme.error),
          onTap: _removeDamagedWallet,
        ),
      );
    }
    if (view.canRemoveOrphanedAlias) {
      cards.add(
        StatusCard(
          title: 'Remove orphaned protection record',
          subtitle:
              'Delete the lone Plawie Keystore alias; no wallet is present',
          icon: Icons.cleaning_services_outlined,
          trailing: Icon(Icons.chevron_right, color: theme.colorScheme.error),
          onTap: _removeOrphanedWalletProtection,
        ),
      );
    }
    if (!view.actionsEnabled) {
      cards.add(
        StatusCard(
          title: 'Retry wallet status',
          subtitle: view.guidance,
          icon: Icons.refresh,
          trailing: chevron,
          onTap: _isLoading ? null : _refreshBalance,
        ),
      );
    }
    return cards;
  }

  Widget _buildWalletHeader(ThemeData theme) {
    final addr = _baseService.address;
    final selectedNetwork = _baseService.network;
    final accent = _networkColor(selectedNetwork);
    final stablecoin = selectedNetwork.token;
    final recovery = BaseWalletRecoveryViewModel.fromStatus(
      _baseService.walletStatus,
    );
    final shortAddr = addr != null && addr.length >= 8
        ? '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}'
        : recovery.title;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(accent, Colors.black, 0.08)!,
            Color.lerp(accent, Colors.purple.shade700, 0.72)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _networkIcon(selectedNetwork),
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      selectedNetwork.name,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_baseService.isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Protected',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_baseService.isConnected) ...[
            const SizedBox(height: 28),
            Text(
              'NETWORK BALANCE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: 0.66),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${_baseService.ethBalance.toStringAsFixed(6)} ETH',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: GoogleFonts.inter(
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
                color: Colors.white,
              ),
            ),
            if (stablecoin != null) ...[
              const SizedBox(height: 5),
              Text(
                '${_baseService.stablecoinBalance.toStringAsFixed(2)} ${stablecoin.symbol}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
            const SizedBox(height: 22),
          ] else
            const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _baseService.isConnected
                            ? 'SECURED ACCOUNT'
                            : 'WALLET STATUS',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        shortAddr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_baseService.isConnected)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    tooltip: 'Copy address',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _baseService.address ?? ''),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address copied')),
                      );
                    },
                  ),
              ],
            ),
          ),
          if (_baseService.isConnected) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_baseService.securityLevel} · approval required to sign',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Network banner ─────────────────────────────────────────────────────────

  Widget _buildNetworkBanner(ThemeData theme) {
    final selected = _baseService.network;
    final accent = _networkColor(selected);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WALLET NETWORK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text('Chain ID ${_baseService.chainId}',
                  style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Choose which network this secured Plawie account displays and sends on. This does not replace its private key or address.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final definition in WalletNetworkPolicy.values)
                ChoiceChip(
                  key: ValueKey<String>(
                    'wallet-network-${definition.storageValue}',
                  ),
                  avatar: Icon(
                    _networkIcon(definition),
                    size: 17,
                    color: definition.network == _baseService.selectedNetwork
                        ? _networkColor(definition)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    switch (definition.network) {
                      WalletNetwork.baseMainnet => 'Base',
                      WalletNetwork.robinhoodMainnet => 'Robinhood',
                      WalletNetwork.baseSepolia => 'Base testnet',
                    },
                  ),
                  selected: definition.network == _baseService.selectedNetwork,
                  onSelected: _isLoading ||
                          definition.network == _baseService.selectedNetwork
                      ? null
                      : (_) => _selectWalletNetwork(definition.network),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            key: const ValueKey<String>('wallet-default-network-control'),
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _baseService.isSelectedNetworkDefault
                  ? accent.withValues(alpha: 0.13)
                  : theme.colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _baseService.isSelectedNetworkDefault
                    ? accent.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _baseService.isSelectedNetworkDefault
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DEFAULT NETWORK',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_baseService.defaultNetworkDefinition.name} opens first',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_baseService.isSelectedNetworkDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'DEFAULT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  )
                else
                  TextButton(
                    key: const ValueKey<String>(
                      'make-current-wallet-network-default',
                    ),
                    onPressed: _isLoading ? null : _makeCurrentNetworkDefault,
                    child: const Text('Use current'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(_networkIcon(selected), size: 16, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${selected.name} · ${selected.nativeSymbol}'
                  '${selected.token == null ? '' : ' + ${selected.token!.symbol}'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              if (selected.isTestnet)
                Text(
                  'TESTNET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accent.withValues(alpha: 0.8),
                    letterSpacing: 1.0,
                  ),
                ),
            ],
          ),
          if (selected.network == WalletNetwork.robinhoodMainnet) ...[
            const SizedBox(height: 7),
            Text(
              'Robinhood uses the same Plawie address. ETH pays gas and the supported stablecoin is official USDG.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (!_baseService.ordinaryTransactionsAvailable) ...[
            const SizedBox(height: 7),
            Text(
              _baseService.ordinaryTransactionUnavailableReason,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Transaction history ────────────────────────────────────────────────────

  Widget _buildTransactionHistory(ThemeData theme) {
    final bridgeReceipts = _completedBridgeReceipts;
    return FutureBuilder<List<BaseTx>>(
      future: _baseService.fetchHistory(limit: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final txs = snapshot.data ?? [];
        if (txs.isEmpty && bridgeReceipts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No transactions yet',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        return Column(
          children: <Widget>[
            ...bridgeReceipts.map(
              (receipt) => _buildBridgeTransactionTile(theme, receipt),
            ),
            ...txs.map((tx) => _buildTxTile(theme, tx)),
          ],
        );
      },
    );
  }

  List<BridgeFundingReceipt> get _completedBridgeReceipts {
    final runtime = _bridgeFunding;
    if (runtime == null) return const <BridgeFundingReceipt>[];
    final receipts = runtime.controller.receipts
        .where((receipt) =>
            receipt.state == BridgeFundingState.completed &&
            _baseTransactionHash(receipt) != null)
        .toList(growable: false)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return receipts.take(5).toList(growable: false);
  }

  Widget _buildBridgeTransactionTile(
    ThemeData theme,
    BridgeFundingReceipt receipt,
  ) {
    final hash = _baseTransactionHash(receipt)!;
    final source = switch (receipt.sourceChainId) {
      BridgeConstants.ethereumChainId => 'Ethereum',
      BridgeConstants.baseChainId => 'Base wallet',
      BridgeConstants.robinhoodChainId => 'Robinhood',
      BridgeConstants.solanaChainId => 'Solana',
      _ => 'external chain',
    };
    return ListTile(
      key: ValueKey<String>('bridge-history-${receipt.intentId}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.green.withValues(alpha: 0.15),
        child: const Icon(Icons.call_received_rounded,
            size: 18, color: Colors.greenAccent),
      ),
      title: const Text(
        'Base funding received',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '$source · ${_shortDate(receipt.updatedAt)} · '
        '${receipt.providerSubstatus ?? receipt.providerStatus ?? 'Completed'}',
        style:
            TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: InkWell(
        onTap: () => _openTrustedTransaction(
          Uri.https('basescan.org', '/tx/$hash'),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${_bridgeReceivedAmount(receipt)} USDC',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.greenAccent,
                ),
              ),
              Text(
                '${hash.substring(0, 8)}… ↗',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTrustedTransaction(Uri uri) async {
    if (uri.scheme != 'https' || uri.host != 'basescan.org') return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction explorer could not open.')),
      );
    }
  }

  String? _baseTransactionHash(BridgeFundingReceipt receipt) {
    final destination = receipt.destinationTransactionHash?.trim();
    if (destination != null && destination.isNotEmpty) return destination;
    if (receipt.sourceChainId != BridgeConstants.baseChainId) return null;
    final source = receipt.sourceTransactionHash?.trim();
    return source == null || source.isEmpty ? null : source;
  }

  String _bridgeReceivedAmount(BridgeFundingReceipt receipt) {
    final units = BigInt.tryParse(
      receipt.actualOutputUnits ?? receipt.minimumOutputUnits ?? '0',
    );
    if (units == null || units.isNegative) return '0';
    final padded = units.toString().padLeft(7, '0');
    final whole = padded.substring(0, padded.length - 6);
    final fraction =
        padded.substring(padded.length - 6).replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? whole : '$whole.$fraction';
  }

  Widget _buildTxTile(ThemeData theme, BaseTx tx) {
    final isSent =
        tx.from.toLowerCase() == (_baseService.address ?? '').toLowerCase();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: tx.isError
            ? theme.colorScheme.error.withValues(alpha: 0.15)
            : isSent
                ? Colors.orange.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.15),
        child: Icon(
          tx.isError
              ? Icons.error_outline
              : isSent
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
          size: 18,
          color: tx.isError
              ? theme.colorScheme.error
              : isSent
                  ? Colors.orange
                  : Colors.green,
        ),
      ),
      title: Text(
        isSent ? 'Sent' : 'Received',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${tx.timestamp.day}/${tx.timestamp.month}/${tx.timestamp.year}',
        style:
            TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isSent ? '-' : '+'}${tx.value.toStringAsFixed(6)} ETH',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tx.isError
                  ? theme.colorScheme.error
                  : isSent
                      ? Colors.orange
                      : Colors.green,
            ),
          ),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: tx.hash)),
            child: Text(
              '${tx.hash.substring(0, 6)}…',
              style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Skills info panel ───────────────────────────────────────────────────

  Widget _buildSkillsInfo(ThemeData theme) {
    final token = _baseService.network.token;
    final supportsBasenames = _baseService.network.supportsBasenames;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy_rounded,
                    color: Color(0xFF0052FF), size: 20),
                const SizedBox(width: 8),
                Text(
                  'AI Agent Capabilities',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _skillRow(
              Icons.account_balance_wallet,
              'get_balance',
              token == null
                  ? 'Check ETH balance'
                  : 'Check ETH + ${token.symbol} balance',
            ),
            _skillRow(
              Icons.send,
              'send_eth',
              supportsBasenames
                  ? 'Send ETH to 0x address or .base.eth name'
                  : 'Send ETH to an explicit 0x address',
            ),
            if (token != null)
              _skillRow(
                Icons.attach_money,
                'send_${token.symbol.toLowerCase()}',
                'Send official ${token.symbol} on ${_baseService.networkName}',
              ),
            if (supportsBasenames)
              _skillRow(Icons.person_search, 'resolve_basename',
                  'Resolve .base.eth → 0x address'),
            _skillRow(
                Icons.history, 'get_history', 'Fetch recent transactions'),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.rocket_launch, color: Colors.purple, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Install Coinbase AgentKit in Skills for 50+ AI-driven Base actions '
                    '(gasless swaps, NFT deploy, DCA, bridge, Farcaster).',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _skillRow(IconData icon, String name, String desc) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF0052FF)),
            const SizedBox(width: 6),
            Text(name,
                style: GoogleFonts.robotoMono(
                    fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(desc,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  // ── Error banner ───────────────────────────────────────────────────────────

  Widget _buildErrorBanner(ThemeData theme) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!,
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _error = null),
            ),
          ],
        ),
      );

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<bool> _runWalletRecovery(
    Future<void> Function() operation,
    String successMessage,
  ) async {
    if (_isLoading) return false;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
      return true;
    } on SecureWalletException catch (error) {
      if (error.code != 'WALLET_RECOVERY_CANCELLED' && mounted) {
        setState(() => _error = error.toString());
      }
      return false;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recoverAndImportWallet() async {
    final recovered = await _runWalletRecovery(
      _baseService.removeDamagedWallet,
      'Damaged wallet record removed. Restore your backup now.',
    );
    if (!recovered || !mounted) return;
    final view = BaseWalletRecoveryViewModel.fromStatus(
      _baseService.walletStatus,
    );
    if (view.canImport) {
      _showImportWalletDialog();
    } else {
      setState(() => _error = view.guidance);
    }
  }

  Future<void> _removeDamagedWallet() async {
    await _runWalletRecovery(
      _baseService.removeDamagedWallet,
      'Damaged wallet record removed.',
    );
  }

  Future<void> _removeOrphanedWalletProtection() async {
    await _runWalletRecovery(
      _baseService.recoverOrphanedWalletProtection,
      'Orphaned wallet protection record removed.',
    );
  }

  void _showCreateWalletDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Plawie Wallet'),
        content: const Text(
          'Generate a new EVM keypair protected by Android Keystore and your '
          'device lock. The same address works on Base and Robinhood Chain. '
          'Signed app updates preserve it, but clearing app data '
          'or uninstalling removes it. Export a private-key backup before funding.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _baseService.createWallet();
              } catch (e) {
                if (mounted) setState(() => _error = e.toString());
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showImportWalletDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plawie does not persist this input in Dart. Temporary key bytes are '
              'passed to the native Android wallet manager and zeroed after the attempt.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Private Key (hex)',
                hintText: '0x... or raw 64-character hex',
              ),
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final key = ctrl.text.trim();
              ctrl.clear();
              Navigator.pop(ctx);
              if (key.isEmpty) return;
              setState(() => _isLoading = true);
              try {
                await _baseService.importWallet(key);
              } catch (e) {
                if (mounted) setState(() => _error = e.toString());
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _migrateLegacyWallet() async {
    final approved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Secure existing wallet'),
            content: const Text(
              'Plawie will move the existing wallet key into an Android '
              'Keystore envelope. Your device will require authentication '
              'for every transfer and AI payment.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.security),
                label: const Text('Secure wallet'),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await _baseService.migrateLegacyWallet();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSendEthDialog() {
    final toCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send ETH'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: toCtrl,
              decoration: InputDecoration(
                labelText: _baseService.network.supportsBasenames
                    ? 'To (0x address or .base.eth)'
                    : 'To (0x address)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              decoration: const InputDecoration(labelText: 'Amount (ETH)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final to = toCtrl.text.trim();
              final amt = Decimal.tryParse(amtCtrl.text.trim());
              Navigator.pop(ctx);
              if (to.isEmpty || amt == null || amt <= Decimal.zero) return;
              final approved = await _confirmTransfer(
                token: 'ETH',
                destination: to,
                amount: amt,
              );
              if (!approved || !mounted) return;
              setState(() => _isLoading = true);
              try {
                final approval = _baseService.issueVisibleTransferApproval(
                  action: 'send_eth',
                  destination: to,
                  amount: amt,
                );
                await _baseService.sendEth(to, amt, approval: approval);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ETH sent!')),
                  );
                }
              } catch (e) {
                if (mounted) setState(() => _error = e.toString());
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showSendStablecoinDialog() {
    final token = _baseService.network.token;
    if (token == null) return;
    final symbol = token.symbol;
    final toCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send $symbol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: toCtrl,
              decoration: InputDecoration(
                labelText: _baseService.network.supportsBasenames
                    ? 'To (0x address or .base.eth)'
                    : 'To (0x address)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              decoration: InputDecoration(labelText: 'Amount ($symbol)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final to = toCtrl.text.trim();
              final amt = Decimal.tryParse(amtCtrl.text.trim());
              Navigator.pop(ctx);
              if (to.isEmpty || amt == null || amt <= Decimal.zero) return;
              final approved = await _confirmTransfer(
                token: symbol,
                destination: to,
                amount: amt,
              );
              if (!approved || !mounted) return;
              setState(() => _isLoading = true);
              try {
                final approval = _baseService.issueVisibleTransferApproval(
                  action: symbol == 'USDG' ? 'send_usdg' : 'send_usdc',
                  destination: to,
                  amount: amt,
                );
                if (symbol == 'USDG') {
                  await _baseService.sendUsdg(to, amt, approval: approval);
                } else {
                  await _baseService.sendUsdc(to, amt, approval: approval);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$symbol sent!')),
                  );
                }
              } catch (e) {
                if (mounted) setState(() => _error = e.toString());
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showReceiveDialog() {
    final addr = _baseService.address ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Plawie wallet address on ${_baseService.networkName}:',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Text(
              'This is the same EVM address on Base and Robinhood Chain. Always verify the network before sending funds.',
              style: TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 12),
            SelectableText(
              addr,
              style: GoogleFonts.robotoMono(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: addr));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address copied')),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Copy'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showExportKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Private Key'),
        content: const Text(
            'WARNING: Never share your private key. Anyone with it has full control of your wallet.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _baseService.showPrivateKeyBackup();
              } catch (e) {
                if (mounted) setState(() => _error = e.toString());
              }
            },
            child: const Text('Show Key'),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Plawie Wallet'),
        content: const Text(
          'This permanently removes the encrypted wallet and Android Keystore '
          'protection key from this device. Make sure you have exported a backup first.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _baseService.deleteWallet();
              } catch (error) {
                if (mounted) setState(() => _error = error.toString());
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Remove wallet'),
          ),
        ],
      ),
    );
  }
}

class _WalletReadyBadge extends StatelessWidget {
  const _WalletReadyBadge();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('base-payment-wallet-ready'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.greenAccent, size: 13),
            SizedBox(width: 4),
            Text(
              'FUNDED',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
      );
}
