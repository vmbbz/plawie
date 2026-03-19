import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../../services/skills_service.dart';
import '../../../widgets/skill_install_hero.dart';
import '../../../app.dart';

/// Agent Work — powered by MoltLaunch (moltlaunch.com)
/// MoltLaunch is an on-chain AI agent work coordination platform on **Base mainnet**
/// (Ethereum L2). NOT Solana — uses EVM wallets, ETH escrow, and ERC-8004 identity.
///
/// Identity standard: ERC-8004 on Base chain
///   Contracts (Base mainnet):
///     Identity Registry:  0x8004A169FB4a3325136EB29fA0ceB6D2e539a432
///     Reputation Registry: 0x8004BAa17C55a88189AE136b182e5fdA19dE9b63
///     Escrow (MandateEscrowV5): 0x5Df1ffa02c8515a0Fed7d0e5d6375FcD2c1950Ee
///
/// Data fetched via gateway:
///   1. get_identity → EVM wallet + ERC-8004 registration status
///   2. get_rep → job dashboard, reputation, payouts
///
/// REST API: https://api.moltlaunch.com
///
/// get_identity response fields:
///   wallet_address  - EVM address '0x...' (agent's Base wallet)
///   display_name    - registered agent name on MoltLaunch
///   agent_id        - MoltLaunch internal agent UUID
///   verified        - bool, ERC-8004 onchain registration confirmed
///   reputation      - int 0-100 stored onchain via ERC-8004 Reputation Registry
///
/// get_rep response fields:
///   reputation           - int 0-100
///   total_jobs_completed - int
///   pending_payouts_eth  - float, ETH awaiting payout (from claims/escrow)
///   active_gig_list      - list of tasks/gigs:
///     title    - task description
///     task_id  - MoltLaunch task ID 'm1...'
///     status   - 'requested' | 'quoted' | 'accepted' | 'submitted' | 'completed' | 'disputed'
///     price    - float ETH (quoted/agreed price)
///     client   - '0x...' client EVM address (truncated for display)

class AgentWorkPage extends StatefulWidget {
  const AgentWorkPage({super.key});

  @override
  State<AgentWorkPage> createState() => _AgentWorkPageState();
}

class _AgentWorkPageState extends State<AgentWorkPage> {
  Map<String, dynamic>? _identity;
  Map<String, dynamic> _repData = {
    'reputation': 0,
    'total_jobs_completed': 0,
    'pending_payouts_eth': 0.0,
    'active_gig_list': [],
  };
  bool _loadingIdentity = true;
  bool _loadingRep = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  bool get _isEnabled {
    final skill = SkillsService().getSkill('molt_launch');
    return skill?.enabled ?? false;
  }

  Future<void> _loadAll() async {
    await _loadIdentity();
    if (_hasIdentity) await _loadRep();
  }

  Future<void> _loadIdentity() async {
    if (!mounted) return;
    setState(() { _loadingIdentity = true; _error = null; });

    final result = await SkillsService()
        .executeSkill('molt_launch', parameters: {'method': 'get_identity'});

    if (!mounted) return;
    if (result.success) {
      final raw = result.data;
      setState(() {
        _identity = (raw is Map<String, dynamic>) ? raw : null;
        _loadingIdentity = false;
      });
    } else {
      setState(() {
        _loadingIdentity = false;
        _error = result.error ?? 'Could not load agent identity';
      });
    }
  }

  Future<void> _loadRep() async {
    if (!mounted) return;
    setState(() { _loadingRep = true; });

    final result = await SkillsService()
        .executeSkill('molt_launch', parameters: {'method': 'get_rep'});

    if (!mounted) return;
    if (result.success) {
      final raw = result.data;
      if (raw is Map<String, dynamic>) {
        setState(() { _repData = raw; _loadingRep = false; });
      } else {
        setState(() { _loadingRep = false; });
      }
    } else {
      setState(() {
        _loadingRep = false;
        _error = result.error ?? 'Could not load job data';
      });
    }
  }

  /// Register the agent on MoltLaunch via gateway → skills.execute → molt_launch.register
  /// Gateway runs: POST https://api.moltlaunch.com/api/agents/register
  Future<void> _registerAgent() async {
    if (!mounted) return;
    setState(() { _loadingIdentity = true; _error = null; });

    final result = await SkillsService()
        .executeSkill('molt_launch', parameters: {'method': 'register'});

    if (!mounted) return;
    if (result.success) {
      // Re-fetch identity after registration
      await _loadAll();
    } else {
      setState(() {
        _loadingIdentity = false;
        _error = result.error ?? 'Registration failed — check gateway connection';
      });
    }
  }

  bool get _hasIdentity {
    final addr = _identity?['wallet_address'];
    return addr != null && addr.toString().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: !_isEnabled
          ? _buildInstallHero(context)
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(context),
                  if (_error != null)
                    SliverToBoxAdapter(child: _buildErrorBanner(context)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _loadingIdentity
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 80),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!_hasIdentity)
                                  _buildRegistrationGate(context),
                                if (_hasIdentity) ...[
                                  _buildIdentityCard(context),
                                  const SizedBox(height: 32),
                                  _buildSectionHeader(context, 'Active Tasks'),
                                  const SizedBox(height: 16),
                                  _buildTaskList(context),
                                  const SizedBox(height: 32),
                                  _buildSectionHeader(context, 'Performance'),
                                  const SizedBox(height: 16),
                                  _buildMetricsGrid(context),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInstallHero(BuildContext context) {
    final skill = SkillsService().getSkill('molt_launch');
    if (skill == null) return const Center(child: Text('Skill not found'));
    return Stack(
      children: [
        Positioned(
          top: 40, left: 10,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        SafeArea(child: SkillInstallHero(skill: skill, onInstalled: () => setState(() {}))),
      ],
    );
  }

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
          const Icon(Icons.cloud_off_rounded, color: AppColors.statusAmber, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(_error ?? 'Gateway offline',
              style: const TextStyle(color: AppColors.statusAmber, fontSize: 12))),
          TextButton(onPressed: _loadAll, child: const Text('Retry', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Agent Work',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color)),
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
                color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  /// Registration gate — shown when agent has no ERC-8004 identity registered.
  /// The gateway handles the mltl CLI commands; the user just taps "Register".
  Widget _buildRegistrationGate(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.12),
            Colors.deepOrange.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.badge_rounded, color: Colors.orange, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Register on MoltLaunch',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('ERC-8004 on-chain identity required',
                        style: TextStyle(color: AppColors.statusGrey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // What this means, factually
          const Text(
            'MoltLaunch is an AI agent job marketplace on Base mainnet (Ethereum L2). '
            'Your OpenClaw agent needs an ERC-8004 identity to get hired, quote prices, '
            'and receive ETH payments via onchain escrow.',
            style: TextStyle(color: AppColors.statusGrey, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),

          // How it works — no CLI shown to user
          _buildInfoRow(Icons.wallet_rounded, 'Base chain (Ethereum L2)',
              'ETH wallet auto-created by your gateway'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.verified_rounded, 'ERC-8004 Identity',
              'Registered on Base — permanent onchain reputation'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.security_rounded, 'Trustless Escrow',
              'Client funds locked before your agent does any work'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.trending_up_rounded, 'Reputation Registry',
              '0–100 score stored onchain after each job'),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingIdentity ? null : _registerAgent,
              icon: _loadingIdentity
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded),
              label: Text(_loadingIdentity ? 'Registering…' : 'Register Agent'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _loadAll,
              child: const Text('Already registered? Refresh',
                  style: TextStyle(color: AppColors.statusGrey, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.orange.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              Text(subtitle, style: const TextStyle(color: AppColors.statusGrey, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.statusGrey.withValues(alpha: 0.8),
          ),
    );
  }

  Widget _buildIdentityCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = (_identity?['display_name'] ?? '').toString();
    final walletAddr = (_identity?['wallet_address'] ?? '').toString();
    final verified = _identity?['verified'] == true;
    final reputation = (_identity?['reputation'] ?? 0) as num;
    // Shorten EVM address: 0x1234...abcd
    final shortAddr = walletAddr.length > 10
        ? '${walletAddr.substring(0, 6)}...${walletAddr.substring(walletAddr.length - 4)}'
        : walletAddr;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Orange gradient avatar for orange Base chain branding
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.orange, Colors.deepOrange],
              ),
            ),
            child: const Icon(Icons.badge_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? displayName : 'Unnamed Agent',
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  shortAddr,
                  style: GoogleFonts.firaCode(color: AppColors.statusGrey, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // ERC-8004 verified badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: verified
                            ? AppColors.statusGreen.withValues(alpha: 0.1)
                            : AppColors.statusGrey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        verified ? 'ERC-8004 VERIFIED' : 'UNVERIFIED',
                        style: TextStyle(
                          color: verified ? AppColors.statusGreen : AppColors.statusGrey,
                          fontSize: 9, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Reputation badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'REP $reputation/100',
                        style: const TextStyle(
                          color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Base chain badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'BASE CHAIN',
                        style: TextStyle(
                          color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context) {
    if (_loadingRep) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }

    final gigs = _repData['active_gig_list'];
    final List<dynamic> list = (gigs is List) ? gigs : [];

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 36, color: AppColors.statusGrey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('No active tasks', style: TextStyle(color: AppColors.statusGrey, fontSize: 13)),
            const Text('Task requests from clients appear here',
                style: TextStyle(color: AppColors.statusGrey, fontSize: 11)),
          ],
        ),
      );
    }

    return Column(
      children: list.take(5).map((item) {
        final task = (item is Map<String, dynamic>)
            ? item
            : Map<String, dynamic>.from(item as Map);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTaskRow(context, task),
        );
      }).toList(),
    );
  }

  Widget _buildTaskRow(BuildContext context, Map<String, dynamic> task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // MoltLaunch task flow: requested → quoted → accepted → submitted → completed
    final title = (task['title'] ?? 'Task').toString();
    final status = (task['status'] ?? 'requested').toString();
    final priceEth = (task['price'] ?? 0.0) as num;
    final clientAddr = (task['client'] ?? '').toString();
    final shortClient = clientAddr.length > 10
        ? '${clientAddr.substring(0, 6)}...${clientAddr.substring(clientAddr.length - 4)}'
        : clientAddr;

    final statusColors = <String, Color>{
      'requested': Colors.blueAccent,
      'quoted': Colors.purpleAccent,
      'accepted': AppColors.statusGreen,
      'submitted': AppColors.statusAmber,
      'completed': AppColors.statusGrey,
      'disputed': AppColors.statusRed,
    };
    final statusIcons = <String, IconData>{
      'requested': Icons.inbox_rounded,
      'quoted': Icons.price_check_rounded,
      'accepted': Icons.lock_rounded,
      'submitted': Icons.upload_rounded,
      'completed': Icons.task_alt_rounded,
      'disputed': Icons.gavel_rounded,
    };

    final color = statusColors[status] ?? AppColors.statusGrey;
    final icon = statusIcons[status] ?? Icons.work_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Text(status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                    if (shortClient.isNotEmpty) ...[
                      const Text(' · ', style: TextStyle(color: AppColors.statusGrey, fontSize: 10)),
                      Text(shortClient,
                          style: GoogleFonts.firaCode(fontSize: 9, color: AppColors.statusGrey)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Price in ETH — from MoltLaunch API
          if (priceEth > 0)
            Text(
              '${priceEth.toStringAsFixed(4)} ETH',
              style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    if (_loadingRep) return const SizedBox.shrink();

    final completed = (_repData['total_jobs_completed'] ?? 0) as num;
    final reputation = (_repData['reputation'] ?? 0) as num;
    final pendingEth = (_repData['pending_payouts_eth'] ?? 0.0) as num;

    // Reputation bar color: green 80+, amber 50-79, red <50
    Color repColor = reputation >= 80
        ? AppColors.statusGreen
        : reputation >= 50
            ? AppColors.statusAmber
            : AppColors.statusRed;

    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            _buildMetricItem(context, 'COMPLETED', '$completed', Icons.task_alt_rounded, AppColors.statusGreen),
            _buildMetricItem(context, 'REPUTATION', '$reputation/100', Icons.star_rounded, repColor),
            _buildMetricItem(context, 'PENDING ETH', '${pendingEth.toStringAsFixed(4)} ETH', Icons.account_balance_wallet_rounded, Colors.orange),
            _buildMetricItem(context, 'NETWORK', 'Base chain', Icons.hub_rounded, Colors.blueAccent),
          ],
        ),
        const SizedBox(height: 16),
        // Reputation progress bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: repColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: repColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Onchain Reputation',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Text('$reputation / 100',
                      style: GoogleFonts.firaCode(fontSize: 12, color: repColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (reputation / 100).clamp(0, 1).toDouble(),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: repColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ERC-8004 Reputation Registry on Base mainnet · 0–100 · Set by clients after each job',
                style: TextStyle(color: AppColors.statusGrey, fontSize: 10, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.statusGrey, fontWeight: FontWeight.bold)),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
