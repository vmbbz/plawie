import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../../services/skills_service.dart';
import '../../../widgets/skill_install_hero.dart';
import '../../../app.dart';

class AgentWalletPage extends StatefulWidget {
  const AgentWalletPage({super.key});

  @override
  State<AgentWalletPage> createState() => _AgentWalletPageState();
}

class _AgentWalletPageState extends State<AgentWalletPage> {
  Map<String, dynamic> _mappedData = {
    'balanceCents': 0,
    'spendLimitCents': 0,
    'status': 'LOADING',
    'last4': '****',
  };

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
    final result = await SkillsService().executeSkill('agent_card', parameters: {'method': 'get_balance'});
    if (result.success && mounted) {
      setState(() {
        _mappedData = result.data as Map<String, dynamic>;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: !_isEnabled 
        ? _buildInstallHero(context)
        : RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGlassCard(context),
                        const SizedBox(height: 32),
                        _buildSectionHeader(context, 'Wallet Status'),
                        const SizedBox(height: 16),
                        _buildStatusGrid(context),
                        const SizedBox(height: 32),
                        _buildSectionHeader(context, 'Spending Limits'),
                        const SizedBox(height: 16),
                        _buildLimitsCard(context),
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
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context) {
    final balance = (_mappedData['balanceCents'] ?? 0) / 100;
    final last4 = _mappedData['last4'] ?? '****';
    
    return AspectRatio(
      aspectRatio: 1.586, // Standard credit card ratio
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blueAccent.withOpacity(0.4),
              Colors.purpleAccent.withOpacity(0.4),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AgentCard',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const Icon(Icons.contactless_outlined, color: Colors.white70, size: 24),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '**** **** **** $last4',
                    style: GoogleFonts.firaCode(
                      fontSize: 22,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                              color: Colors.white.withOpacity(0.5),
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
                              color: Colors.white.withOpacity(0.5),
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '12/28',
                            style: GoogleFonts.firaCode(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
        color: AppColors.statusGrey.withOpacity(0.8),
      ),
    );
  }

  Widget _buildStatusGrid(BuildContext context) {
    final status = _mappedData['status'] ?? 'UNKNOWN';
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildInfoItem(context, 'Provider', 'Alchemy', Icons.account_balance_outlined),
        _buildInfoItem(context, 'Network', 'Mastercard', Icons.public),
        _buildInfoItem(context, 'Status', status, Icons.check_circle_outline, status == 'OPEN' ? AppColors.statusGreen : AppColors.statusGrey),
        _buildInfoItem(context, 'Auto-Refill', 'Enabled', Icons.refresh_rounded, AppColors.statusGreen),
      ],
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value, IconData icon, [Color? color]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
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
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balanceCents = _mappedData['balanceCents'] ?? 0;
    final limitCents = _mappedData['spendLimitCents'] ?? 100000;
    final progress = (balanceCents / limitCents).clamp(0.0, 1.0);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildLimitRow(context, 'Daily Limit', progress, '\$${(balanceCents/100).toStringAsFixed(0)} / \$${(limitCents/100).toStringAsFixed(0)}'),
          const SizedBox(height: 20),
          _buildLimitRow(context, 'Monthly Limit', 0.15, '\$750 / \$5,000'),
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
            backgroundColor: Colors.white.withOpacity(0.05),
            color: progress > 0.8 ? AppColors.statusAmber : AppColors.statusGreen,
            minHeight: 6,
          ),
        ),
      ],
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
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Manage'),
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
