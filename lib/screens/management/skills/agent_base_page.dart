import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:decimal/decimal.dart';
import '../../../services/skills_service.dart';
import '../../../services/base_service.dart';
import '../../../services/base_wallet_recovery_view_model.dart';
import '../../../app.dart';
import '../../base_screen.dart';

/// Wallet skill page — device-native EVM identity powered by BaseService.
/// Always available (no gateway install needed).
/// Shows exact per-network assets, AgentKit roadmap status, and skill
/// documentation.
class AgentBasePage extends StatefulWidget {
  const AgentBasePage({super.key});

  @override
  State<AgentBasePage> createState() => _AgentBasePageState();
}

class _AgentBasePageState extends State<AgentBasePage>
    with SingleTickerProviderStateMixin {
  final _baseService = BaseService();
  bool _loading = true;
  String? _error;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _baseService.initialize();
      if (_baseService.isConnected) await _baseService.refreshBalance();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWalletManager() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const BaseScreen()),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          if (_error != null)
            SliverToBoxAdapter(child: _buildErrorBanner(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBalanceCard(context),
                        const SizedBox(height: 24),
                        _buildAgentKitBanner(context),
                        const SizedBox(height: 24),
                        _buildTabBar(context, theme),
                        const SizedBox(height: 16),
                        _buildTabContent(context, theme),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: AppLayout.standardSliverHeaderHeight,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Wallet Networks',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Theme.of(context)
                  .scaffoldBackgroundColor
                  .withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  // ── Balance card ───────────────────────────────────────────────────────────

  Widget _buildBalanceCard(BuildContext context) {
    final connected = _baseService.isConnected;
    final recovery = BaseWalletRecoveryViewModel.fromStatus(
      _baseService.walletStatus,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0052FF), Color(0xFF7B2FBE)],
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plawie EVM Wallet',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                    Text(
                      'Viewing ${_baseService.networkName}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (connected)
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
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
          if (connected) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              icon: const Icon(Icons.hub_outlined, size: 18),
              label: const Text('Switch Base / Robinhood network'),
              onPressed: _openWalletManager,
            ),
          ],
          const SizedBox(height: 16),
          if (connected) ...[
            Text(
              '${_baseService.ethBalance.toStringAsFixed(6)} ETH',
              style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            if (_baseService.stablecoinSymbol != null)
              Text(
                '${_baseService.stablecoinBalance.toStringAsFixed(2)} ${_baseService.stablecoinSymbol}',
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Clipboard.setData(
                  ClipboardData(text: _baseService.address ?? '')),
              child: Text(
                _shortAddr(_baseService.address ?? ''),
                style: GoogleFonts.robotoMono(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
              ),
            ),
          ] else ...[
            Text(
              recovery.title,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              recovery.guidance,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0052FF)),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Manage Wallet'),
              onPressed: _openWalletManager,
            ),
          ],
        ],
      ),
    );
  }

  // ── AgentKit roadmap boundary ─────────────────────────────────────────────

  Widget _buildAgentKitBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch, color: Colors.purple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coinbase AgentKit · not integrated',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  'No CDP wallet provider or Plawie approval adapter is active. '
                  'This Base wallet remains a separate custody route.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.purple),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: null,
            child: const Text('Roadmap',
                style: TextStyle(color: Colors.purple, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar(BuildContext context, ThemeData theme) {
    return TabBar(
      controller: _tabs,
      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
      tabs: const [
        Tab(text: 'Actions'),
        Tab(text: 'Skill Docs'),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context, ThemeData theme) {
    return AnimatedBuilder(
      animation: _tabs,
      builder: (_, __) {
        return _tabs.index == 0
            ? _buildActionsTab(context, theme)
            : _buildDocsTab(context, theme);
      },
    );
  }

  // ── Actions tab ────────────────────────────────────────────────────────────

  Widget _buildActionsTab(BuildContext context, ThemeData theme) {
    if (!_baseService.isConnected) {
      final recovery = BaseWalletRecoveryViewModel.fromStatus(
        _baseService.walletStatus,
      );
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                recovery.guidance,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openWalletManager,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Open wallet manager'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _actionRow(
            context,
            Icons.account_balance_wallet,
            'Check Balance',
            'Returns exact assets on the selected network',
            () => _runAction('get_balance')),
        _actionRow(
            context,
            Icons.send,
            'Send ETH',
            _baseService.network.supportsBasenames
                ? 'Transfer ETH to address or .base.eth'
                : 'Transfer ETH to an explicit 0x address',
            () => _promptSend(context, 'eth')),
        if (_baseService.stablecoinSymbol != null)
          _actionRow(
            context,
            Icons.attach_money,
            'Send ${_baseService.stablecoinSymbol}',
            'Transfer official ${_baseService.stablecoinSymbol} on ${_baseService.networkName}',
            () => _promptSend(
              context,
              _baseService.stablecoinSymbol!.toLowerCase(),
            ),
          ),
        if (_baseService.network.supportsBasenames)
          _actionRow(context, Icons.person_search, 'Resolve Basename',
              'Look up a .base.eth address', () => _promptResolve(context)),
        _actionRow(
            context,
            Icons.history,
            'View History',
            'Last 10 transactions on ${_baseService.networkName}',
            () => _runAction('get_history')),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh Balances'),
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _actionRow(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFF0052FF).withValues(alpha: 0.1),
        child: Icon(icon, size: 18, color: const Color(0xFF0052FF)),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  Future<void> _runAction(String action) async {
    setState(() => _loading = true);
    try {
      final result = await SkillsService()
          .executeSkill('base-chain', parameters: {'action': action});
      if (!mounted) return;
      if (result.success) {
        _showResult(context, action, result.data);
      } else {
        setState(() => _error = result.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResult(BuildContext context, String action, dynamic data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(action.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(fontSize: 14)),
        content: SingleChildScrollView(
          child: SelectableText(
            _prettyJson(data),
            style: GoogleFonts.robotoMono(fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  String _prettyJson(dynamic data) {
    if (data is Map || data is List) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    }
    return data?.toString() ?? 'null';
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

  void _promptSend(BuildContext context, String token) {
    final toCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send ${token.toUpperCase()}'),
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
              decoration:
                  InputDecoration(labelText: 'Amount (${token.toUpperCase()})'),
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
                token: token.toUpperCase(),
                destination: to,
                amount: amt,
              );
              if (!approved || !mounted) return;
              setState(() => _loading = true);
              try {
                final action = switch (token) {
                  'eth' => 'send_eth',
                  'usdg' => 'send_usdg',
                  _ => 'send_usdc',
                };
                final approval = _baseService.issueVisibleTransferApproval(
                  action: action,
                  destination: to,
                  amount: amt,
                );
                final result = await SkillsService().executeSkill(
                  'base-chain',
                  parameters: {
                    'action': action,
                    'to': to,
                    'amount': amt.toString(),
                  },
                  context: {'baseTransferApproval': approval},
                );
                if (!context.mounted) return;
                if (result.success) {
                  _showResult(context, action, result.data);
                } else {
                  setState(() => _error = result.error);
                }
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _promptResolve(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Basename'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(labelText: 'Name (e.g. alice.base.eth)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              Navigator.pop(ctx);
              if (name.isEmpty) return;
              setState(() => _loading = true);
              try {
                final result = await SkillsService().executeSkill(
                  'base-chain',
                  parameters: {'action': 'resolve_basename', 'name': name},
                );
                if (!context.mounted) return;
                if (result.success) {
                  _showResult(context, 'resolve_basename', result.data);
                } else {
                  setState(() => _error = result.error);
                }
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  // ── Docs tab ───────────────────────────────────────────────────────────────

  Widget _buildDocsTab(BuildContext context, ThemeData theme) {
    final skill = SkillsService().getSkill('base-chain');
    if (skill == null) {
      return const Center(child: Text('Skill not found'));
    }
    return MarkdownBody(
      data: skill.body,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        code: GoogleFonts.robotoMono(fontSize: 11),
        p: theme.textTheme.bodySmall,
      ),
    );
  }

  // ── Error banner ───────────────────────────────────────────────────────────

  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statusAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.statusAmber, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? 'Something went wrong',
              style:
                  const TextStyle(color: AppColors.statusAmber, fontSize: 12),
            ),
          ),
          TextButton(
              onPressed: _load,
              child: const Text('Retry', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _shortAddr(String addr) {
    if (addr.length < 10) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }
}
