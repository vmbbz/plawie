import 'dart:ui';
import 'package:flutter/material.dart';
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

class BotManagementDashboard extends StatelessWidget {
  const BotManagementDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
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
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        title: Text(
          'Bot Management',
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.statusGrey.withOpacity(0.8),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<GatewayProvider>(
      builder: (context, provider, _) {
        final health = provider.detailedHealth;
        final uptimeMs = health?['uptimeMs'] as int?;
        final isHealthy = provider.state.status == GatewayStatus.running;
        // health RPC returns { uptimeMs, health: { durationMs, agents:[], ok } }
        final healthInner = health?['health'] as Map<String, dynamic>?;
        final agentsCount = (healthInner?['agents'] as List?)?.length ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            ),
          ),
          padding: const EdgeInsets.all(20),
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
                    healthInner?['durationMs'] != null ? 'ms' : '--',
                    Icons.speed_rounded,
                    AppColors.statusAmber,
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
            color: color.withOpacity(0.1),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
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
      ),
    );
  }
}
