import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../../services/skills_service.dart';
import '../../../widgets/skill_install_hero.dart';
import '../../../app.dart';

/// Agent Credit — powered by Valeo Sentinel (valeo.cash)
/// Valeo Sentinel is an enterprise compliance & budget enforcement layer
/// for the x402 payment protocol, specifically built for AI agent autonomous spending.
///
/// Data fetched via: SkillsService.executeSkill('valeo_sentinel', {method: 'get_budget'})
///
/// Valeo Sentinel API response fields (per official valeo.cash docs):
///   budget_cap       - total authorized spend cap (USD cents)
///   current_spend    - current period spend (USD cents)
///   sentinel_active  - bool, protection policy enforcement on/off
///   policy_id        - policy identifier string (e.g. 'XP-921')
///   per_call_limit   - max USD cents per single API call (0 = unlimited)
///   hourly_limit     - max USD cents per hour
///   daily_limit      - max USD cents per day
///   lifetime_limit   - max USD cents lifetime
///   audit_log        - list of spend decisions:
///     agentId     - agent identifier
///     team        - team or workspace name
///     endpoint    - API endpoint the agent attempted to call
///     tx_hash     - transaction hash (x402 payment reference)
///     timing      - ISO 8601 timestamp
///     action      - human-readable description of what was attempted
///     amount_cents - amount in USD cents
///     result       - 'approved' | 'blocked' | 'pending'

class AgentCreditPage extends StatefulWidget {
  const AgentCreditPage({super.key});

  @override
  State<AgentCreditPage> createState() => _AgentCreditPageState();
}

class _AgentCreditPageState extends State<AgentCreditPage> {
  Map<String, dynamic> _data = {
    'budget_cap': 0,
    'current_spend': 0,
    'sentinel_active': false,
    'policy_id': '--',
    'per_call_limit': 0,
    'hourly_limit': 0,
    'daily_limit': 0,
    'lifetime_limit': 0,
    'audit_log': [],
  };
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  bool get _isEnabled {
    final skill = SkillsService().getSkill('valeo_sentinel');
    return skill?.enabled ?? false;
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    final result = await SkillsService()
        .executeSkill('valeo_sentinel', parameters: {'method': 'get_budget'});

    if (!mounted) return;
    if (result.success) {
      final raw = result.data;
      if (raw is Map<String, dynamic>) {
        setState(() { _data = raw; _loading = false; });
      } else {
        setState(() { _loading = false; });
      }
    } else {
      setState(() {
        _loading = false;
        _error = result.error ?? 'Could not load Sentinel data';
      });
    }
  }

  Future<void> _setSentinelActive(bool value) async {
    await SkillsService().executeSkill('valeo_sentinel',
        parameters: {'method': 'set_policy', 'active': value});
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: !_isEnabled
          ? _buildInstallHero(context)
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(context),
                  if (_error != null)
                    SliverToBoxAdapter(child: _buildErrorBanner(context)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
                                _buildSentinelStatus(context),
                                const SizedBox(height: 32),
                                _buildSectionHeader(context, 'Credit Ceiling (Sentinel)'),
                                const SizedBox(height: 16),
                                _buildCreditVisualizer(context),
                                const SizedBox(height: 32),
                                _buildSectionHeader(context, 'Spend Limits'),
                                const SizedBox(height: 16),
                                _buildLimitsGrid(context),
                                const SizedBox(height: 32),
                                _buildSectionHeader(context, 'Intercepted Logs'),
                                const SizedBox(height: 16),
                                _buildAuditLogs(context),
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
    final skill = SkillsService().getSkill('valeo_sentinel');
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
        SafeArea(
          child: SkillInstallHero(skill: skill, onInstalled: () => setState(() {})),
        ),
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
          Expanded(
            child: Text(_error ?? 'Gateway offline',
                style: const TextStyle(color: AppColors.statusAmber, fontSize: 12)),
          ),
          TextButton(onPressed: _refreshData, child: const Text('Retry', style: TextStyle(fontSize: 12))),
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
        title: Text('Agent Credit',
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

  Widget _buildSentinelStatus(BuildContext context) {
    final sentinelActive = _data['sentinel_active'] == true;
    final policyId = (_data['policy_id'] ?? '--').toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.withValues(alpha: sentinelActive ? 0.25 : 0.1),
            Colors.blue.withValues(alpha: sentinelActive ? 0.15 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: (sentinelActive ? Colors.blue : AppColors.statusGrey)
                .withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (sentinelActive ? Colors.blue : AppColors.statusGrey)
                  .withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_rounded,
                color: sentinelActive ? Colors.blueAccent : AppColors.statusGrey, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sentinel Protection',
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  sentinelActive
                      ? 'Policy $policyId — ACTIVE'
                      : 'Policy enforcement disabled',
                  style: TextStyle(
                      color: sentinelActive ? Colors.blueAccent : AppColors.statusGrey,
                      fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: sentinelActive,
            onChanged: _setSentinelActive,
            activeThumbColor: AppColors.statusGreen,
          ),
        ],
      ),
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

  Widget _buildCreditVisualizer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cap = (_data['budget_cap'] ?? 0) as num;
    final spend = (_data['current_spend'] ?? 0) as num;
    final available = (cap - spend).clamp(0, double.infinity);
    final utilization = cap > 0 ? (spend / cap).clamp(0.0, 1.0) : 0.0;

    if (cap == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
        ),
        child: const Center(
          child: Text('No budget configured — Connect gateway to see limits',
              style: TextStyle(color: AppColors.statusGrey, fontSize: 13)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLargeStat(context, 'Total Budget', '\$${(cap / 100).toStringAsFixed(2)}'),
              _buildLargeStat(context, 'Available',
                  '\$${(available / 100).toStringAsFixed(2)}', AppColors.statusGreen),
            ],
          ),
          const SizedBox(height: 28),
          Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: utilization.toDouble(),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.blueAccent,
                      utilization > 0.8 ? AppColors.statusAmber : AppColors.statusGreen,
                    ]),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.statusGreen.withValues(alpha: 0.3),
                          blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Utilized: ${(utilization * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppColors.statusGrey, fontSize: 11)),
              Text('Spent: \$${(spend / 100).toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.statusGrey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeStat(BuildContext context, String label, String value, [Color? valueColor]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.statusGrey)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 24, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildLimitsGrid(BuildContext context) {
    final perCall = (_data['per_call_limit'] ?? 0) as num;
    final hourly = (_data['hourly_limit'] ?? 0) as num;
    final daily = (_data['daily_limit'] ?? 0) as num;
    final lifetime = (_data['lifetime_limit'] ?? 0) as num;

    String centsDisplay(num cents) =>
        cents == 0 ? 'Unlimited' : '\$${(cents / 100).toStringAsFixed(2)}';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: [
        _buildLimitChip(context, 'Per Call', centsDisplay(perCall)),
        _buildLimitChip(context, 'Per Hour', centsDisplay(hourly)),
        _buildLimitChip(context, 'Per Day', centsDisplay(daily)),
        _buildLimitChip(context, 'Lifetime', centsDisplay(lifetime)),
      ],
    );
  }

  Widget _buildLimitChip(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 9, color: AppColors.statusGrey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAuditLogs(BuildContext context) {
    final logs = _data['audit_log'];
    final List<dynamic> logList = (logs is List) ? logs : [];

    if (logList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 36,
                color: AppColors.statusGrey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('No audit events yet',
                style: TextStyle(color: AppColors.statusGrey, fontSize: 13)),
            const Text('Approved and blocked spend decisions appear here',
                style: TextStyle(color: AppColors.statusGrey, fontSize: 11)),
          ],
        ),
      );
    }

    return Column(
      children: logList.take(10).map((log) {
        final Map<String, dynamic> entry = (log is Map<String, dynamic>)
            ? log
            : (log is String)
                ? {'action': log, 'result': 'approved'}
                : Map<String, dynamic>.from(log as Map);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAuditRow(context, entry),
        );
      }).toList(),
    );
  }

  Widget _buildAuditRow(BuildContext context, Map<String, dynamic> entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Per Valeo Sentinel docs: agentId, team, endpoint, tx_hash, timing, action, amount_cents, result
    final action = (entry['action'] ?? entry['endpoint'] ?? 'Unknown action').toString();
    final result = (entry['result'] ?? 'approved').toString();
    final amountCents = (entry['amount_cents'] ?? 0) as num;
    final timing = (entry['timing'] ?? '').toString();
    final txHash = (entry['tx_hash'] ?? '').toString();

    // Show timing as relative if it's an ISO timestamp
    String timeDisplay = timing;
    if (timing.isNotEmpty) {
      try {
        final dt = DateTime.parse(timing);
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 60) {
          timeDisplay = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          timeDisplay = '${diff.inHours}h ago';
        } else {
          timeDisplay = '${diff.inDays}d ago';
        }
      } catch (_) {
        timeDisplay = timing;
      }
    }

    final isBlocked = result == 'blocked';
    final isPending = result == 'pending';
    final color = isBlocked
        ? AppColors.statusRed
        : isPending
            ? AppColors.statusAmber
            : AppColors.statusGreen;

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
          Icon(
            isBlocked
                ? Icons.block_rounded
                : isPending
                    ? Icons.pending_rounded
                    : Icons.check_circle_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    if (timeDisplay.isNotEmpty)
                      Text(timeDisplay,
                          style: const TextStyle(color: AppColors.statusGrey, fontSize: 10)),
                    if (amountCents > 0) ...[
                      const Text(' · ', style: TextStyle(color: AppColors.statusGrey, fontSize: 10)),
                      Text('\$${(amountCents / 100).toStringAsFixed(2)}',
                          style: GoogleFonts.firaCode(fontSize: 10, color: AppColors.statusGrey)),
                    ],
                    if (txHash.isNotEmpty) ...[
                      const Text(' · ', style: TextStyle(color: AppColors.statusGrey, fontSize: 10)),
                      Text(
                        '${txHash.substring(0, txHash.length.clamp(0, 8))}...',
                        style: GoogleFonts.firaCode(fontSize: 10, color: AppColors.statusGrey),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.toUpperCase(),
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
