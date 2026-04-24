import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../services/skills_service.dart';
import '../../../services/base_service.dart';
import '../../../app.dart';

/// Base Chain skill page — device-native wallet powered by BaseService.
/// Always available (no gateway install needed).
/// Shows ETH + USDC balance, AgentKit status, and full skill documentation.
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
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Base Wallet',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color:
                  Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  // ── Balance card ───────────────────────────────────────────────────────────

  Widget _buildBalanceCard(BuildContext context) {
    final connected = _baseService.isConnected;
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
                      'Base Chain Wallet',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                    Text(
                      _baseService.networkName,
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
            Text(
              '${_baseService.usdcBalance.toStringAsFixed(2)} USDC',
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
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11),
              ),
            ),
          ] else ...[
            Text(
              'No wallet connected',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0052FF)),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Wallet'),
              onPressed: () async {
                setState(() => _loading = true);
                try {
                  await _baseService.createWallet();
                } catch (e) {
                  if (mounted) setState(() => _error = e.toString());
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── AgentKit banner ────────────────────────────────────────────────────────

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
                  'Coinbase AgentKit',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  '50+ AI-driven Base actions — gasless swaps, NFT deploy, DCA, bridge.',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              // Navigate to Skills Manager to install cdp-agentkit
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Go to Skills Manager → Discover → Coinbase AgentKit to install.'),
                  duration: Duration(seconds: 4),
                ),
              );
            },
            child: const Text('Install',
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
      labelStyle:
          GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Create a wallet above to use Base actions.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        _actionRow(context, Icons.account_balance_wallet, 'Check Balance',
            'Returns ETH + USDC balance', () => _runAction('get_balance')),
        _actionRow(context, Icons.send, 'Send ETH',
            'Transfer ETH to address or .base.eth',
            () => _promptSend(context, 'eth')),
        _actionRow(context, Icons.attach_money, 'Send USDC',
            'Transfer USDC stablecoin',
            () => _promptSend(context, 'usdc')),
        _actionRow(context, Icons.person_search, 'Resolve Basename',
            'Look up a .base.eth address',
            () => _promptResolve(context)),
        _actionRow(context, Icons.history, 'View History',
            'Last 10 transactions from Basescan',
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
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11)),
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
              decoration: const InputDecoration(
                  labelText: 'To (0x address or .base.eth)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              decoration: InputDecoration(
                  labelText: 'Amount (${token.toUpperCase()})'),
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
              final amt = amtCtrl.text.trim();
              Navigator.pop(ctx);
              if (to.isEmpty || amt.isEmpty) return;
              setState(() => _loading = true);
              try {
                final result = await SkillsService().executeSkill(
                  'base-chain',
                  parameters: {
                    'action': token == 'eth' ? 'send_eth' : 'send_usdc',
                    'to': to,
                    'amount': amt,
                  },
                );
                if (mounted) {
                  if (result.success) {
                    _showResult(context,
                        token == 'eth' ? 'send_eth' : 'send_usdc', result.data);
                  } else {
                    setState(() => _error = result.error);
                  }
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
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
                if (mounted) {
                  if (result.success) {
                    _showResult(context, 'resolve_basename', result.data);
                  } else {
                    setState(() => _error = result.error);
                  }
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
        border:
            Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.statusAmber, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? 'Something went wrong',
              style: const TextStyle(
                  color: AppColors.statusAmber, fontSize: 12),
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

