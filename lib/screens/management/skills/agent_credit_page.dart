import '../../../services/skills_service.dart';
import '../../../widgets/skill_install_hero.dart';

class AgentCreditPage extends StatefulWidget {
  const AgentCreditPage({super.key});

  @override
  State<AgentCreditPage> createState() => _AgentCreditPageState();
}

class _AgentCreditPageState extends State<AgentCreditPage> {
  Map<String, dynamic> _mappedData = {
    'budget_cap': 0,
    'current_spend': 0,
    'audit_log': [],
  };

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
    final result = await SkillsService().executeSkill('valeo_sentinel', parameters: {'method': 'get_budget'});
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
                         _buildSentinelStatus(context),
                         const SizedBox(height: 32),
                         _buildSectionHeader(context, 'Credit Ceiling (Sentinel)'),
                         const SizedBox(height: 16),
                         _buildCreditVisualizer(context),
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
          'Agent Credit',
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

  Widget _buildSentinelStatus(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.withOpacity(0.2), Colors.blue.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.blueAccent, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sentinel Protection',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Policy-Enforced Autonomous Spending',
                  style: TextStyle(color: AppColors.statusGrey, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(value: true, onChanged: (v) {}, activeColor: AppColors.statusGreen),
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

  Widget _buildCreditVisualizer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cap = (_mappedData['budget_cap'] ?? 0).toDouble();
    final spend = (_mappedData['current_spend'] ?? 0).toDouble();
    final available = (cap - spend).clamp(0.0, cap);
    final utilization = cap > 0 ? (spend / cap).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLargeStat(context, 'Total Credit', '\$${cap.toStringAsFixed(2)}'),
              _buildLargeStat(context, 'Available', '\$${available.toStringAsFixed(2)}', AppColors.statusGreen),
            ],
          ),
          const SizedBox(height: 32),
          Stack(
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: utilization,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.blueAccent, AppColors.statusGreen]),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                       BoxShadow(color: AppColors.statusGreen.withOpacity(0.3), blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text('Utilized: ${(utilization * 100).toStringAsFixed(1)}%', style: TextStyle(color: AppColors.statusGrey, fontSize: 11)),
               Text('Sentinel Policy ID: XP-921', style: TextStyle(color: AppColors.statusGrey, fontSize: 11)),
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
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogs(BuildContext context) {
    return Column(
      children: [
         _buildAuditRow(context, 'OpenAI API Top-up', 'Approved', 'Recently', Icons.check_circle_rounded, AppColors.statusGreen), // Research-backed: audit_log_summary
         const SizedBox(height: 12),
         _buildAuditRow(context, 'Twilio Credits Auto-Refill', 'Approved', '2h ago', Icons.check_circle_rounded, AppColors.statusGreen),
         const SizedBox(height: 12),
         _buildAuditRow(context, 'High-Risk Token Swap', 'BLOCKED', '5h ago', Icons.block_flipped, AppColors.statusRed),
      ],
    );
  }

  Widget _buildAuditRow(BuildContext context, String desc, String result, String time, IconData icon, Color color) {
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
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(time, style: const TextStyle(color: AppColors.statusGrey, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
