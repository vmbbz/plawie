import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../../services/skills_service.dart';
import '../../../widgets/skill_install_hero.dart';
import '../../../app.dart';

/// Agent Wallet — powered by AgentCard.ai (agentcard.ai)
/// Virtual Visa card issued by AgentCard for autonomous AI agent spending.
/// Data is fetched via: SkillsService.executeSkill('agent_card', {method: 'get_balance'})
/// which proxies through OpenClaw gateway → skills.execute → agent_card skill handler.
///
/// Official AgentCard.ai (private beta) response fields (inferred from CLI schema):
///   id            - card unique identifier
///   last4         - last 4 digits of the Visa card
///   balance       - current balance in USD cents
///   spendLimit    - configured spend limit in USD cents
///   status        - 'OPEN' | 'PAUSED' | 'TERMINATED' | 'DISCONNECTED'
///   expiryMonth   - 2-digit month string e.g. '12'
///   expiryYear    - 4-digit year string e.g. '2027'
///   network       - always 'Visa'
///   autoRefill    - bool, whether auto-refill policy is active
///   cardholderName - name on card (agent name)

class AgentWalletPage extends StatefulWidget {
  const AgentWalletPage({super.key});

  @override
  State<AgentWalletPage> createState() => _AgentWalletPageState();
}

class _AgentWalletPageState extends State<AgentWalletPage> {
  Map<String, dynamic> _data = {
    'id': '',
    'last4': '----',
    'balance': 0,
    'spendLimit': 0,
    'status': 'LOADING',
    'expiryMonth': '--',
    'expiryYear': '----',
    'network': 'Visa',
    'autoRefill': false,
    'cardholderName': '',
  };
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  bool get _isEnabled {
    final skill = SkillsService().getSkill('agent_card');
    return skill?.enabled ?? false;
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    final result = await SkillsService()
        .executeSkill('agent_card', parameters: {'method': 'get_balance'});

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
        _error = result.error ?? 'Could not load card data';
      });
    }
  }

  Future<void> _setAutoRefill(bool value) async {
    await SkillsService().executeSkill('agent_card',
        parameters: {'method': 'set_refill_policy', 'enabled': value});
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
                                _buildGlassCard(context),
                                const SizedBox(height: 32),
                                _buildSectionHeader(context, 'Card Status'),
                                const SizedBox(height: 16),
                                _buildStatusGrid(context),
                                const SizedBox(height: 32),
                                _buildSectionHeader(context, 'Spending Limits'),
                                const SizedBox(height: 16),
                                _buildLimitsCard(context),
                                const SizedBox(height: 32),
                                _buildSectionHeader(context, 'Settings'),
                                const SizedBox(height: 16),
                                _buildSettingsCard(context),
                                const SizedBox(height: 40),
                                _buildActionButtons(context),
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
    final skill = SkillsService().getSkill('agent_card');
    if (skill == null) return const Center(child: Text('Skill not found'));
    return Stack(
      children: [
        Positioned(
          top: 40,
          left: 10,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        SafeArea(
          child: SkillInstallHero(
            skill: skill,
            onInstalled: () => setState(() {}),
          ),
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
            child: Text(
              _error ?? 'Gateway offline — showing last known state',
              style: const TextStyle(color: AppColors.statusAmber, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _refreshData,
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
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
        title: Text(
          'Agent Wallet',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context) {
    // AgentCard.ai: balance is in USD cents
    final balanceCents = (_data['balance'] ?? 0) as num;
    final balance = balanceCents / 100;
    final last4 = _data['last4'] ?? '----';
    final expiryMonth = _data['expiryMonth'] ?? '--';
    final expiryYear = _data['expiryYear'] ?? '----';
    // Show last 2 digits of year for card display
    final expiryYearShort = expiryYear.length >= 2
        ? expiryYear.substring(expiryYear.length - 2)
        : expiryYear;
    final cardholderName = (_data['cardholderName'] ?? '').toString();
    final network = (_data['network'] ?? 'Visa').toString();

    return AspectRatio(
      aspectRatio: 1.586, // ISO/IEC 7810 ID-1 standard card ratio
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E), // Deep navy — AgentCard brand feel
              Color(0xFF311B92),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF311B92).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AgentCard',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          Text(
                            'agentcard.ai',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      // Network logo area
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          network.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Chip icon row
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.memory_rounded, size: 14, color: Colors.black54),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.wifi_rounded, color: Colors.white54, size: 18),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '**** **** **** $last4',
                    style: GoogleFonts.firaCode(
                      fontSize: 20,
                      letterSpacing: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BALANCE',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '\$${balance.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'EXPIRY',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '$expiryMonth/$expiryYearShort',
                            style: GoogleFonts.firaCode(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (cardholderName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      cardholderName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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

  Widget _buildStatusGrid(BuildContext context) {
    final status = (_data['status'] ?? 'UNKNOWN').toString();
    final isOpen = status == 'OPEN';
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildInfoItem(context, 'Provider', 'AgentCard.ai', Icons.credit_card_outlined),
        _buildInfoItem(context, 'Network', _data['network'] ?? 'Visa', Icons.public),
        _buildInfoItem(
          context,
          'Status',
          status,
          Icons.check_circle_outline,
          isOpen ? AppColors.statusGreen : AppColors.statusAmber,
        ),
        _buildInfoItem(
          context,
          'Auto-Refill',
          (_data['autoRefill'] == true) ? 'Enabled' : 'Disabled',
          Icons.refresh_rounded,
          (_data['autoRefill'] == true) ? AppColors.statusGreen : AppColors.statusGrey,
        ),
      ],
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value, IconData icon, [Color? color]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.statusGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.statusGrey)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // balance and spendLimit are in cents per AgentCard.ai CLI schema
    final balanceCents = (_data['balance'] ?? 0) as num;
    final limitCents = (_data['spendLimit'] ?? 1) as num;
    final safeLimit = limitCents <= 0 ? 1 : limitCents;
    final progress = (balanceCents / safeLimit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _buildLimitRow(
            context,
            'Spend Limit',
            progress.toDouble(),
            '\$${(balanceCents / 100).toStringAsFixed(2)} / \$${(safeLimit / 100).toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildLimitRow(BuildContext context, String label, double progress, String detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(detail, style: GoogleFonts.firaCode(fontSize: 11, color: AppColors.statusGrey)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            color: progress > 0.8 ? AppColors.statusAmber : AppColors.statusGreen,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final autoRefill = _data['autoRefill'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.refresh_rounded, size: 20, color: AppColors.statusGreen),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auto-Refill', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('Automatically top up when balance runs low',
                    style: TextStyle(fontSize: 11, color: AppColors.statusGrey)),
              ],
            ),
          ),
          Switch(
            value: autoRefill,
            onChanged: _setAutoRefill,
            activeThumbColor: AppColors.statusGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Funds'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('AgentCard.ai'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}
