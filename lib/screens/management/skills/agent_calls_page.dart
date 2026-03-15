import '../../../services/skills_service.dart';
import '../../../widgets/skill_install_hero.dart';

class AgentCallsPage extends StatefulWidget {
  const AgentCallsPage({super.key});

  @override
  State<AgentCallsPage> createState() => _AgentCallsPageState();
}

class _AgentCallsPageState extends State<AgentCallsPage> {
  Map<String, dynamic> _mappedData = {
    'phone_number': '...',
    'status': 'LOADING',
    'concurrent_sessions': 0,
  };

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  bool get _isEnabled {
    final skill = SkillsService().getSkill('twilio_voice');
    return skill?.enabled ?? false;
  }

  Future<void> _refreshData() async {
    final result = await SkillsService().executeSkill('twilio_voice', parameters: {'method': 'get_status'});
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
                         _buildNumberCard(context),
                         const SizedBox(height: 32),
                         _buildSectionHeader(context, 'Voice Orchestration'),
                         const SizedBox(height: 16),
                         _buildRelayToggles(context),
                         const SizedBox(height: 32),
                         _buildSectionHeader(context, 'Recent Conversations'),
                         const SizedBox(height: 16),
                         _buildCallLogs(context),
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
    final skill = SkillsService().getSkill('twilio_voice');
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
          'Agent Calls',
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

  Widget _buildNumberCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phoneNumber = _mappedData['phone_number'] ?? '...';
    final activeSessions = _mappedData['concurrent_sessions'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.phone_in_talk_rounded, color: Colors.redAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Virtual Number', style: TextStyle(color: AppColors.statusGrey, fontSize: 11)),
                    Text(
                      phoneNumber,
                      style: GoogleFonts.firaCode(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified_user_rounded, color: AppColors.statusGreen, size: 18),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat('Inbound', '156'),
              const VerticalDivider(width: 1),
              _buildMiniStat('Active', '$activeSessions'),
              const VerticalDivider(width: 1),
              _buildMiniStat('Duration', '18h'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.statusGrey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
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

  Widget _buildRelayToggles(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildToggleRow('Twilio Relay', true, Icons.hub_rounded), // Research-backed: ConversationRelay
          const Divider(height: 24),
          _buildToggleRow('Transcription', true, Icons.subtitles_rounded), // Research-backed: transcription_enabled_flag
          const Divider(height: 24),
          _buildToggleRow('Human Handoff (Escalation)', false, Icons.person_add_rounded),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, bool value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.statusGreen),
        const SizedBox(width: 16),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Switch(value: value, onChanged: (v) {}, activeColor: AppColors.statusGreen),
      ],
    );
  }

  Widget _buildCallLogs(BuildContext context) {
    return Column(
      children: [
        _buildCallCard(context, 'John Doe', 'Inbound', '4m 22s', 'Seeking help with order status. AI resolved.'),
        const SizedBox(height: 12),
        _buildCallCard(context, 'Sarah Smith', 'Outbound', '1m 05s', 'Payment confirmation follow-up.'),
      ],
    );
  }

  Widget _buildCallCard(BuildContext context, String name, String type, String duration, String summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(duration, style: GoogleFonts.firaCode(fontSize: 11, color: AppColors.statusGrey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(type, style: TextStyle(color: type == 'Inbound' ? Colors.blueAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            summary,
            style: TextStyle(color: AppColors.statusGrey, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
