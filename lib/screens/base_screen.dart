import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:decimal/decimal.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_payment_provider_catalog.dart';
import '../services/base_service.dart';
import '../services/base_wallet_recovery_view_model.dart';
import '../services/bridge_quote_service.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../services/provider_balance_service.dart';
import '../services/x402_payment_service.dart';
import '../services/x402_payment_transport_service.dart';
import '../widgets/status_card.dart';
import '../widgets/glass_card.dart';

class BaseScreen extends StatefulWidget {
  const BaseScreen({super.key});

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
  final BridgeQuoteService _bridgeQuotes = BridgeQuoteService();
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
    _bridgeQuotes.dispose();
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
      final savedPaymentProvider =
          AiPaymentProviderCatalog.byId(_prefs.aiPaymentProvider);
      if (savedPaymentProvider != null) {
        _selectedAiPaymentProvider = savedPaymentProvider.id;
        _providerBalance = _providerBalances.cached(savedPaymentProvider.id);
      }
      await _baseService.initialize();
      _paymentReceipts = await _x402Transport.receiptStore.read();
      if (_baseService.isConnected) {
        await _baseService.refreshBalance();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          NebulaBg(),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 100,
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
                      'BASE',
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
                  // Network toggle
                  PopupMenuButton<bool>(
                    icon: Icon(
                      Icons.public,
                      color: _baseService.useSepolia
                          ? Colors.orange
                          : Colors.blue.shade400,
                    ),
                    tooltip: 'Network: ${_baseService.networkName}',
                    onSelected: (useSepolia) async {
                      await _baseService.setNetwork(sepolia: useSepolia);
                      setState(() {});
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: true,
                        child: Row(
                          children: [
                            Icon(Icons.science,
                                color: _baseService.useSepolia
                                    ? Colors.orange
                                    : Colors.grey,
                                size: 20),
                            const SizedBox(width: 8),
                            const Text('Base Sepolia (Testnet)'),
                            if (_baseService.useSepolia) ...[
                              const Spacer(),
                              const Icon(Icons.check, size: 18),
                            ]
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: false,
                        child: Row(
                          children: [
                            Icon(Icons.public,
                                color: !_baseService.useSepolia
                                    ? Colors.blue
                                    : Colors.grey,
                                size: 20),
                            const SizedBox(width: 8),
                            const Text('Base Mainnet'),
                            if (!_baseService.useSepolia) ...[
                              const Spacer(),
                              const Icon(Icons.check, size: 18),
                            ]
                          ],
                        ),
                      ),
                    ],
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWalletHeader(theme),
                              const SizedBox(height: 16),
                              _buildWalletStatePanel(theme),
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
                                  subtitle:
                                      'Transfer ETH to an address or .base.eth name',
                                  icon: Icons.send,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _showSendEthDialog,
                                ),
                                StatusCard(
                                  title: 'Send USDC',
                                  subtitle: 'Transfer USDC stablecoin',
                                  icon: Icons.attach_money,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _showSendUsdcDialog,
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
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_calls_rounded,
                    color: Color(0xFF5B8CFF), size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fund Base from another chain',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Text(
                  'QUOTE ONLY',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Check a live LI.FI route from Ethereum, Solana, or Robinhood Chain into this Base wallet. The source transaction stays in your external wallet; Plawie never signs arbitrary bridge calldata.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: BridgeQuoteService.sourceChains
                  .map((chain) => Chip(
                        avatar: Icon(
                          chain.type == BridgeChainType.svm
                              ? Icons.blur_circular_rounded
                              : Icons.hexagon_outlined,
                          size: 14,
                        ),
                        label: Text(chain.name),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _baseService.isConnected
                    ? _showBridgeQuoteDialog
                    : _showWalletRequiredDialog,
                icon: const Icon(Icons.route_outlined),
                label: const Text('Get live bridge quote'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBridgeQuoteDialog() async {
    var sourceChain = BridgeQuoteService.sourceChains.first;
    var sourceToken = sourceChain.nativeToken;
    var busy = false;
    String? dialogError;
    final amountController = TextEditingController();
    final sourceAddressController = TextEditingController();
    BridgeQuote? quote;
    await showDialog<void>(
      context: context,
      barrierDismissible: !busy,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bridge into Base'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<BridgeSourceChain>(
                  initialValue: sourceChain,
                  decoration: const InputDecoration(labelText: 'Source chain'),
                  items: BridgeQuoteService.sourceChains
                      .map((chain) => DropdownMenuItem(
                            value: chain,
                            child: Text(chain.name),
                          ))
                      .toList(growable: false),
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setDialogState(() {
                            sourceChain = value;
                            sourceToken = value.nativeToken;
                            dialogError = null;
                          });
                        },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('${sourceChain.id}-$sourceToken'),
                  initialValue: sourceToken,
                  decoration: const InputDecoration(labelText: 'Pay with'),
                  items: <String>{sourceChain.nativeToken, 'USDC'}
                      .map((token) => DropdownMenuItem(
                            value: token,
                            child: Text(token),
                          ))
                      .toList(growable: false),
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) {
                            setDialogState(() => sourceToken = value);
                          }
                        },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  enabled: !busy,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Source amount',
                    suffixText: sourceToken,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sourceAddressController,
                  enabled: !busy,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: '${sourceChain.name} source-wallet address',
                    helperText: 'The external wallet that will sign and pay',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Destination: ${_baseService.address}\n'
                  'Receive: Base USDC\n'
                  'Slippage limit: 0.5%',
                  style: const TextStyle(fontSize: 11, height: 1.4),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!,
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 11)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() {
                        busy = true;
                        dialogError = null;
                      });
                      try {
                        quote = await _bridgeQuotes.quoteToBaseUsdc(
                          BridgeQuoteRequest(
                            sourceChain: sourceChain,
                            sourceToken: sourceToken,
                            amount: amountController.text,
                            sourceAddress: sourceAddressController.text,
                            baseDestinationAddress: _baseService.address ?? '',
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (error) {
                        if (ctx.mounted) {
                          setDialogState(() {
                            dialogError = '$error';
                            busy = false;
                          });
                        }
                      }
                    },
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(busy ? 'Checking…' : 'Get quote'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    sourceAddressController.dispose();
    if (!mounted || quote == null) return;
    await _showBridgeQuoteResult(quote!);
  }

  Future<void> _showBridgeQuoteResult(BridgeQuote quote) async {
    final fee = quote.estimatedFeesUsd;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Live bridge estimate'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${quote.sourceAmount} ${quote.sourceToken} → at least ${quote.destinationAmountMinimum} ${quote.destinationToken}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Route: ${quote.routeTool}\n'
                'From: ${quote.sourceChain.name}\n'
                'To: Base\n'
                '${quote.estimatedDurationSeconds == null ? '' : 'Estimated time: ~${quote.estimatedDurationSeconds}s\n'}'
                '${fee == null ? '' : 'Estimated route + gas cost: \$${fee.toStringAsFixed(2)}\n'}'
                'Quote validity: 60 seconds',
                style: const TextStyle(fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 12),
              const Text(
                'This is planning data only. Plawie discarded LI.FI transaction calldata. Jumper and your external source wallet must produce and show a fresh final transaction for you to approve.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final opened = await launchUrl(
                quote.externalCompletionUrl,
                mode: LaunchMode.externalApplication,
              );
              if (!opened && mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Could not open Jumper.')),
                );
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open Jumper'),
          ),
        ],
      ),
    );
  }

  // ── Section helpers ────────────────────────────────────────────────────────

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
    final mainnetReady = !_baseService.useSepolia;

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
                    const Expanded(
                      child: Text(
                        'x402 payments use Base Mainnet, not Sepolia.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _baseService.setNetwork(sepolia: false);
                        if (mounted) setState(() {});
                      },
                      child: const Text('Switch'),
                    ),
                  ],
                ),
              ),
            ],
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
                  Text(selected.fundingLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(selected.description,
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.4)),
                  const SizedBox(height: 10),
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
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _baseService.isConnected
                        ? _showReceiveDialog
                        : _showWalletRequiredDialog,
                    icon: const Icon(Icons.account_balance_wallet_outlined,
                        size: 18),
                    label: const Text('Fund wallet'),
                  ),
                ),
                if (selected.supportsTopUp) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _baseService.isConnected && mainnetReady
                          ? _aiPaymentBusy
                              ? null
                              : () => _showTopUpPreparation(selected)
                          : _baseService.isConnected
                              ? _switchToMainnetForAiPayments
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
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                '${receipt.providerId ?? 'x402'} · $amount USDC · ${receipt.state.name} · ${_shortDate(receipt.recordedAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      receipt.state == X402PaymentState.settled
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                ),
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
    await _baseService.setNetwork(sepolia: false);
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
    PreparedX402Payment? prepared;
    try {
      prepared = await _x402Transport.prepareTopUp(provider);
      if (!mounted) {
        _x402Transport.reject(prepared);
        return;
      }
      setState(() => _aiPaymentProgress =
          'Challenge verified. Waiting for your explicit approval.');
      final approved = await _showX402Approval(prepared);
      if (!approved) {
        _x402Transport.reject(prepared);
        if (mounted) {
          setState(() => _aiPaymentProgress = 'Payment cancelled.');
        }
        return;
      }
      if (!mounted) return;
      setState(() => _aiPaymentProgress =
          'Unlock the secure wallet to sign this one payment…');
      final receipt = await _x402Transport.approveAndSubmit(
        prepared,
        walletAddress: _baseService.address ?? '',
      );
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
            const SizedBox(height: 12),
            Divider(color: theme.dividerColor.withValues(alpha: 0.35)),
            const SizedBox(height: 8),
            Text(
              'Signed app updates preserve this wallet. Clearing Plawie app data or '
              'uninstalling removes it from this device, so export a backup before funding.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
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
          subtitle: 'Generate and protect a new Base EVM keypair',
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
    final recovery = BaseWalletRecoveryViewModel.fromStatus(
      _baseService.walletStatus,
    );
    final shortAddr = addr != null && addr.length >= 8
        ? '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}'
        : recovery.title;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0052FF), // Base blue
            Colors.purple.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base Wallet',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shortAddr,
                      style: GoogleFonts.robotoMono(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (_baseService.isConnected)
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                  tooltip: 'Copy address',
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: _baseService.address ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
                    );
                  },
                ),
            ],
          ),
          if (_baseService.isConnected) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 15, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_baseService.securityLevel} · auth per payment',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '${_baseService.ethBalance.toStringAsFixed(6)} ETH',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_baseService.usdcBalance.toStringAsFixed(2)} USDC',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
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
    final isSepolia = _baseService.useSepolia;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSepolia
            ? Colors.orange.withValues(alpha: 0.1)
            : const Color(0xFF0052FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSepolia
              ? Colors.orange.withValues(alpha: 0.4)
              : const Color(0xFF0052FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSepolia ? Icons.science : Icons.public,
            size: 16,
            color: isSepolia ? Colors.orange : const Color(0xFF0052FF),
          ),
          const SizedBox(width: 8),
          Text(
            _baseService.networkName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSepolia ? Colors.orange : const Color(0xFF0052FF),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· Chain ID ${_baseService.chainId}',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isSepolia) ...[
            const Spacer(),
            Text(
              'TESTNET',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.orange.withValues(alpha: 0.8),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Transaction history ────────────────────────────────────────────────────

  Widget _buildTransactionHistory(ThemeData theme) {
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
        if (txs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No transactions yet',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        return Column(
          children: txs.map((tx) => _buildTxTile(theme, tx)).toList(),
        );
      },
    );
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
            _skillRow(Icons.account_balance_wallet, 'get_balance',
                'Check ETH + USDC balance'),
            _skillRow(Icons.send, 'send_eth',
                'Send ETH to 0x address or .base.eth name'),
            _skillRow(Icons.attach_money, 'send_usdc', 'Send USDC stablecoin'),
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
        title: const Text('Create Base Wallet'),
        content: const Text(
          'Generate a new EVM keypair protected by Android Keystore and your '
          'device lock. Signed app updates preserve it, but clearing app data '
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
              decoration: const InputDecoration(
                labelText: 'To (0x address or .base.eth)',
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

  void _showSendUsdcDialog() {
    final toCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send USDC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: toCtrl,
              decoration: const InputDecoration(
                labelText: 'To (0x address or .base.eth)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              decoration: const InputDecoration(labelText: 'Amount (USDC)'),
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
                token: 'USDC',
                destination: to,
                amount: amt,
              );
              if (!approved || !mounted) return;
              setState(() => _isLoading = true);
              try {
                final approval = _baseService.issueVisibleTransferApproval(
                  action: 'send_usdc',
                  destination: to,
                  amount: amt,
                );
                await _baseService.sendUsdc(to, amt, approval: approval);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('USDC sent!')),
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
            const Text('Your Base wallet address:',
                style: TextStyle(fontSize: 12)),
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
        title: const Text('Remove Base Wallet'),
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
