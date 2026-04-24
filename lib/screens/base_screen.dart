import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:decimal/decimal.dart';
import '../services/base_service.dart';
import '../widgets/status_card.dart';
import '../widgets/glass_card.dart';

class BaseScreen extends StatefulWidget {
  const BaseScreen({super.key});

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  final BaseService _baseService = BaseService();
  StreamSubscription<BaseEvent>? _eventSub;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _eventSub = _baseService.events.listen(_onEvent);
    _initBase();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
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
      await _baseService.initialize();
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
    if (!_baseService.isConnected) return;
    setState(() => _isLoading = true);
    try {
      await _baseService.refreshBalance();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn),
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
                      background: Container(
                          color: Colors.black.withValues(alpha: 0.2)),
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
                  if (_baseService.isConnected)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshBalance,
                      tooltip: 'Refresh balance',
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
                              const SizedBox(height: 24),
                              _buildNetworkBanner(theme),
                              const SizedBox(height: 16),

                              _sectionLabel(theme, 'WALLET ACTIONS'),

                              if (!_baseService.isConnected) ...[
                                StatusCard(
                                  title: 'Create Wallet',
                                  subtitle: 'Generate new Base EVM keypair',
                                  icon: Icons.add_circle_outline,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _showCreateWalletDialog,
                                ),
                                StatusCard(
                                  title: 'Import Wallet',
                                  subtitle: 'Import from private key',
                                  icon: Icons.file_download,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _showImportWalletDialog,
                                ),
                              ],

                              if (_baseService.isConnected) ...[
                                StatusCard(
                                  title: 'Send ETH',
                                  subtitle: 'Transfer ETH to an address or .base.eth name',
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
                                  title: 'Disconnect Wallet',
                                  subtitle: 'Remove wallet from this device',
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

  // ── Wallet header card ─────────────────────────────────────────────────────

  Widget _buildWalletHeader(ThemeData theme) {
    final addr = _baseService.address;
    final shortAddr = addr != null && addr.length >= 8
        ? '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}'
        : 'Not Connected';

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
                  icon: const Icon(Icons.copy,
                      color: Colors.white70, size: 20),
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
    final isSent = tx.from.toLowerCase() ==
        (_baseService.address ?? '').toLowerCase();
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
        style: TextStyle(
            fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
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
            _skillRow(Icons.attach_money, 'send_usdc',
                'Send USDC stablecoin'),
            _skillRow(Icons.person_search, 'resolve_basename',
                'Resolve .base.eth → 0x address'),
            _skillRow(Icons.history, 'get_history',
                'Fetch recent transactions'),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.rocket_launch,
                    color: Colors.purple, size: 16),
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
          border: Border.all(
              color: theme.colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!,
                  style: TextStyle(
                      color: theme.colorScheme.error, fontSize: 12)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _error = null),
            ),
          ],
        ),
      );

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showCreateWalletDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Base Wallet'),
        content: const Text(
            'Generate a new EVM keypair on Base. Store your private key safely — it cannot be recovered if lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Wallet'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Private Key (hex)',
            hintText: '0x... or raw hex',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final key = ctrl.text.trim();
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
    );
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final to = toCtrl.text.trim();
              final amt = Decimal.tryParse(amtCtrl.text.trim());
              Navigator.pop(ctx);
              if (to.isEmpty || amt == null) return;
              setState(() => _isLoading = true);
              try {
                await _baseService.sendEth(to, amt);
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final to = toCtrl.text.trim();
              final amt = Decimal.tryParse(amtCtrl.text.trim());
              Navigator.pop(ctx);
              if (to.isEmpty || amt == null) return;
              setState(() => _isLoading = true);
              try {
                await _baseService.sendUsdc(to, amt);
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final key = await _baseService.exportPrivateKey();
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Private Key'),
                  content: SelectableText(key ?? 'Not found',
                      style: GoogleFonts.robotoMono(fontSize: 11)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: key ?? ''));
                        Navigator.pop(context);
                      },
                      child: const Text('Copy & Close'),
                    ),
                  ],
                ),
              );
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
        title: const Text('Disconnect Wallet'),
        content: const Text(
            'This will remove your private key from this device. Make sure you have a backup first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await _baseService.deleteWallet();
              setState(() {});
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

