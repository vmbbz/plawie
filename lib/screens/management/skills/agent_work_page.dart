import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../../services/skills_service.dart';
import '../../../widgets/skill_install_hero.dart';
import '../../../app.dart';

class AgentWorkPage extends StatefulWidget {
  const AgentWorkPage({super.key});

  @override
  State<AgentWorkPage> createState() => _AgentWorkPageState();
}

class _AgentWorkPageState extends State<AgentWorkPage> {
  Map<String, dynamic> _mappedData = {
    'reputation_score': 0.0,
    'total_jobs_completed': 0,
    'pending_payouts': 0,
    'active_gig_list': [],
  };

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  bool get _isEnabled {
    final skill = SkillsService().getSkill('molt_launch');
    return skill?.enabled ?? false;
  }

  Future<void> _refreshData() async {
    final result = await SkillsService().executeSkill('molt_launch', parameters: {'method': 'get_rep'});
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
                         _buildIdentityCard(context),
                         const SizedBox(height: 32),
                         _buildSectionHeader(context, 'Active Gigs & Bids'),
                         const SizedBox(height: 16),
                         _buildActivityList(context),
                         const SizedBox(height: 32),
                         _buildSectionHeader(context, 'Reputation & Metrics'),
                         const SizedBox(height: 16),
                         _buildMetricsGrid(context),
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
          'Agent Work',
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

  Widget _buildIdentityCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Colors.orangeAccent, Colors.redAccent]),
            ),
            child: const Icon(Icons.badge_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'On-chain Identity',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'ERC-8004 Registry (Base L2)',
                  style: TextStyle(color: AppColors.statusGrey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'VERIFIED AGENT',
                    style: TextStyle(color: AppColors.statusGreen, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.qr_code_2_rounded, color: AppColors.statusGrey),
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
        color: AppColors.statusGrey.withOpacity(0.8),
      ),
    );
  }

  Widget _buildActivityList(BuildContext context) {
    return Column(
      children: [
        _buildActivityRow(context, 'Smart Contract Audit', 'In Progress', '1.24 ETH', Icons.security_rounded),
        const SizedBox(height: 12),
        _buildActivityRow(context, 'Docs Translation', 'Pending Review', '0.45 ETH', Icons.translate_rounded),
      ],
    );
  }

  Widget _buildActivityRow(BuildContext context, String title, String status, String price, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.statusGreen, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(status, style: const TextStyle(color: AppColors.statusGrey, fontSize: 11)),
              ],
            ),
          ),
          Text(price, style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final completed = _mappedData['total_jobs_completed'] ?? 0;
    final reputation = _mappedData['reputation_score'] ?? 0.0;
    final escrow = _mappedData['pending_payouts'] ?? 0;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.8,
      children: [
        _buildMetricItem(context, 'COMPLETED', '$completed', Icons.task_alt_rounded, AppColors.statusGreen),
        _buildMetricItem(context, 'REPUTATION', '${(reputation * 5).toStringAsFixed(2)}/5', Icons.star_rounded, AppColors.statusAmber),
        _buildMetricItem(context, 'IN ESCROW', '$escrow TOKENS', Icons.account_balance_wallet_rounded, AppColors.statusGreen),
        _buildMetricItem(context, 'COORD.', 'Optimized', Icons.hub_rounded, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildMetricItem(BuildContext context, String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.statusGrey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
