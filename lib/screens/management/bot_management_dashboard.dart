import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';
import '../../models/gateway_state.dart';
import '../../app.dart';
import 'bot_method_explorer.dart';
import 'status_dashboard.dart';
import 'agent_manager.dart';
import 'config_editor.dart';
import 'skills_manager.dart';
import '../../widgets/glass_card.dart';
class BotManagementDashboard extends StatelessWidget {
  const BotManagementDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark base for NebulaBg
      body: Stack(
        children: [
          const NebulaBg(),
          CustomScrollView(
            slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSectionHeader(context, 'Real-time Metrics'),
                   const SizedBox(height: 12),
                   const StatusSummaryCard(),
                   const SizedBox(height: 32),
                   _buildSectionHeader(context, 'Management Domains'),
                   const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate([
                _CategoryCard(
                  title: 'System',
                  subtitle: 'Health & Core',
                  icon: Icons.settings_input_component,
                  color: AppColors.statusAmber,
                  onTap: () => _navigateToExplorer(context, 'system'),
                ),
                _CategoryCard(
                  title: 'Config',
                  subtitle: 'openclaw.json',
                  icon: Icons.tune_rounded,
                   color: AppColors.statusGreen,
                  onTap: () => _navigateToExplorer(context, 'config'),
                ),
                _CategoryCard(
                  title: 'Agents',
                  subtitle: 'Fleet Control',
                  icon: Icons.smart_toy_rounded,
                  color: AppColors.statusGreen,
                  onTap: () => _navigateToExplorer(context, 'agents'),
                ),
                _CategoryCard(
                  title: 'Skills',
                  subtitle: 'Capabilities',
                  icon: Icons.extension_rounded,
                  color: Colors.purpleAccent,
                  onTap: () => _navigateToExplorer(context, 'skills'),
                ),
                _CategoryCard(
                  title: 'Node',
                  subtitle: 'P2P & Devices',
                  icon: Icons.device_hub_rounded,
                  color: Colors.orangeAccent,
                  onTap: () => _navigateToExplorer(context, 'node'),
                ),
                _CategoryCard(
                  title: 'All Methods',
                  subtitle: 'Flat RPC Map',
                  icon: Icons.data_array_rounded,
                  color: AppColors.statusGrey,
                  onTap: () => _navigateToExplorer(context, ''),
                ),
              ]),
            ),
          ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
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
      stretch: true,
      backgroundColor: Colors.transparent,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/app_icon_official.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: 10),
          Text(
            'MANAGEMENT',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 3.0,
              color: Colors.white,
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
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
        letterSpacing: 1.2,
        color: AppColors.statusGrey.withValues(alpha: 0.8),
      ),
    );
  }

  void _navigateToExplorer(BuildContext context, String categoryFilter) {
    Widget target;
    switch (categoryFilter) {
      case 'agents':
        target = const AgentManager();
        break;
      case 'config':
        target = const ConfigEditor();
        break;
      case 'system':
        target = const StatusDashboard();
        break;
      case 'skills':
        target = const SkillsManager();
        break;
      default:
        target = BotMethodExplorer(initialFilter: categoryFilter);
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => target),
    );
  }
}

class StatusSummaryCard extends StatelessWidget {
  const StatusSummaryCard({super.key});

  String _formatUptime(int? ms) {
    if (ms == null) return '--';
    final duration = Duration(milliseconds: ms);
    if (duration.inDays > 0) return '${duration.inDays}d ${duration.inHours % 24}h';
    if (duration.inHours > 0) return '${duration.inHours}h ${duration.inMinutes % 60}m';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    return '${duration.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GatewayProvider>(
      builder: (context, provider, _) {
        final health    = provider.detailedHealth;
        final isHealthy = provider.state.status == GatewayStatus.running;
        final agentsCount = (health?['agents'] as List?)?.length ?? 0;
        final latency = health?['durationMs'] ?? health?['latency_ms'];

        // Uptime: prefer remote field, fall back to local startedAt delta.
        int? uptimeMs = health?['uptimeMs'] as int?;
        if (uptimeMs == null && provider.state.startedAt != null && isHealthy) {
          uptimeMs = DateTime.now().difference(provider.state.startedAt!).inMilliseconds;
        }

        // Skills count — gateway-confirmed active skills list.
        final skillsCount = (provider.state.activeSkills ?? []).length;

        // Tools count — number of entries in tools.allow[] parsed from config.
        // We read from the last known config snapshot stored in detailedHealth
        // or fall back to the _toolCatalog size (always accurate offline).
        final toolsConfig = health?['config']?['tools']?['allow'];
        final toolsCount  = toolsConfig is List
            ? toolsConfig.length
            : _ToolCountHelper.catalogSize;

        return GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                   _buildMetric(
                    context,
                    'UPTIME',
                    _formatUptime(uptimeMs),
                    Icons.timer_outlined,
                    AppColors.statusGreen,
                  ),
                  const Spacer(),
                  _buildMetric(
                    context,
                    'HEALTH',
                    isHealthy ? 'Live' : 'Offline',
                    Icons.health_and_safety_outlined,
                    isHealthy ? AppColors.statusGreen : AppColors.statusRed,
                  ),
                ],
              ),
              const Divider(height: 32),
              Row(
                children: [
                   _buildMetric(
                    context,
                    'AGENTS',
                    agentsCount.toString(),
                    Icons.smart_toy_outlined,
                     AppColors.statusGreen,
                  ),
                  const Spacer(),
                  _buildMetric(
                    context,
                    'LATENCY',
                    latency != null ? '${latency}ms' : '--',
                    Icons.speed_rounded,
                    AppColors.statusAmber,
                  ),
                ],
              ),
              const Divider(height: 32),
              Row(
                children: [
                  // SKILLS — live count of gateway-active skills
                   _buildMetric(
                    context,
                    'SKILLS',
                    isHealthy ? skillsCount.toString() : '--',
                    Icons.extension_rounded,
                    Colors.purpleAccent,
                  ),
                  const Spacer(),
                  // TOOLS — tools.allow[] count from openclaw.json
                  _buildMetric(
                    context,
                    'TOOLS',
                    isHealthy ? toolsCount.toString() : '--',
                    Icons.build_rounded,
                    Colors.blueAccent,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.statusGrey,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.firaCode(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.statusGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Provides the catalog size of gateway primitive tools so the TOOLS metric
/// has a sensible offline value before config.get returns.
/// Must stay in sync with the _toolCatalog list in skills_manager.dart.
class _ToolCountHelper {
  /// Number of entries in the _toolCatalog map in skills_manager.
  /// Update this if you add/remove tools from that map.
  static const int catalogSize = 19;
}
