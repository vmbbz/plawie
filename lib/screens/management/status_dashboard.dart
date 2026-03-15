import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clawa/services/native_bridge.dart';
import '../../app.dart';

class StatusDashboard extends StatefulWidget {
  const StatusDashboard({super.key});

  @override
  State<StatusDashboard> createState() => _StatusDashboardState();
}

class _StatusDashboardState extends State<StatusDashboard> {
  bool _isBatteryOptimized = false;
  bool _nodeRunning = false;
  bool _gatewayRunning = false;

  @override
  void initState() {
    super.initState();
    _refreshSystemStatus();
  }

  Future<void> _refreshSystemStatus() async {
    final optimized = await NativeBridge.isBatteryOptimized();
    final node = await NativeBridge.isNodeServiceRunning();
    final gateway = await NativeBridge.isGatewayRunning();

    if (mounted) {
      setState(() {
        _isBatteryOptimized = optimized;
        _nodeRunning = node;
        _gatewayRunning = gateway;
      });
    }
  }

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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Core Engines'),
                  const SizedBox(height: 16),
                  _buildServiceCard(
                    context,
                    'Clawa Gateway',
                    'Main orchestrator & API bridge',
                    _gatewayRunning,
                    Icons.hub_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildServiceCard(
                    context,
                    'OpenClaw Node',
                    'Agent execution & WebSocket',
                    _nodeRunning,
                    Icons.terminal_rounded,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context, 'Background Stability'),
                  const SizedBox(height: 16),
                  _buildStabilityConfig(context),
                  const SizedBox(height: 32),
                  _buildSectionHeader(context, 'System Persistence'),
                  const SizedBox(height: 16),
                  _buildPersistenceInfo(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'System Watchdog',
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
        letterSpacing: 1.5,
        color: AppColors.statusGrey.withOpacity(0.8),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String name, String desc, bool isRunning, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isRunning ? AppColors.statusGreen : Colors.red).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isRunning ? AppColors.statusGreen : Colors.redAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(desc, style: TextStyle(fontSize: 12, color: AppColors.statusGrey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                color: (isRunning ? AppColors.statusGreen : Colors.red).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
                child: Text(
                  isRunning ? 'REACHABLE' : 'DOWN',
                  style: TextStyle(
                    color: isRunning ? AppColors.statusGreen : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStabilityConfig(BuildContext context) {
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
          _buildInfoRow(
            'Sticky Foreground',
            'Service restarts if OS kills app',
            true,
            Icons.anchor_rounded,
          ),
          const Divider(height: 32),
          _buildActionRow(
            'Keep-Alive WakeLock',
            'Prevents CPU sleep deep-states',
            Icons.bolt_rounded,
            () => NativeBridge.acquirePartialWakeLock(),
          ),
          const Divider(height: 32),
          _buildActionRow(
            'Battery Optimization',
            _isBatteryOptimized ? 'RESTRICTED (Tap to fix)' : 'UNRESTRICTED',
            Icons.battery_saver_rounded,
            () => NativeBridge.requestBatteryOptimization(),
            statusColor: _isBatteryOptimized ? Colors.orangeAccent : AppColors.statusGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildPersistenceInfo(BuildContext context) {
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
          _buildInfoRow('Database Sync', 'Automatic on skill change', true, Icons.save_rounded),
          const Divider(height: 32),
          _buildInfoRow('Session Files', '/root/.openclaw/session.json', true, Icons.folder_zip_rounded),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String subtitle, bool isActive, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.statusGrey),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.statusGrey)),
            ],
          ),
        ),
        if (isActive) Icon(Icons.check_circle_rounded, color: AppColors.statusGreen, size: 18),
      ],
    );
  }

  Widget _buildActionRow(String title, String subtitle, IconData icon, VoidCallback onTap, {Color? statusColor}) {
    return InkWell(
      onTap: () {
        onTap();
        Future.delayed(const Duration(seconds: 1), _refreshSystemStatus);
      },
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: statusColor ?? AppColors.statusGrey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: statusColor ?? AppColors.statusGrey)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.statusGrey),
        ],
      ),
    );
  }
}
