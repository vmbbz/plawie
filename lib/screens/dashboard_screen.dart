import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../widgets/gateway_controls.dart';
import '../widgets/status_card.dart';
import 'node_screen.dart';
import 'onboarding_screen.dart';
import 'terminal_screen.dart';
import 'web_dashboard_screen.dart';
import 'logs_screen.dart';
import 'packages_screen.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';
import 'solana_screen.dart';
import 'help_screen.dart';
import 'management/bot_management_dashboard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _taglineController;
  bool _showTagline = false;

  @override
  void initState() {
    super.initState();
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // After 2.5 seconds, cross-fade from app name to tagline
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() => _showTagline = true);
        _taglineController.forward();
      }
    });
  }

  @override
  void dispose() {
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _buildAnimatedTitle(),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Deep space gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.4,
                colors: [Color(0xFF0D1B2A), Color(0xFF080C14)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          // Ambient blue glow patches
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.statusGreen.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GatewayControls(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'QUICK ACTIONS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Consumer<GatewayProvider>(
                    builder: (context, provider, _) {
                      return StatusCard(
                        title: 'Chat with Plawie',
                        subtitle: provider.state.isRunning
                            ? 'Talk to your local AI companion'
                            : 'Start gateway first',
                        icon: Icons.chat_bubble_outline,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: provider.state.isRunning
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const ChatScreen()),
                                )
                            : null,
                      );
                    },
                  ),
                  StatusCard(
                    title: 'Solana',
                    subtitle: 'Manage Solana wallet and DeFi',
                    icon: Icons.account_balance_wallet,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SolanaScreen()),
                    ),
                  ),
                  StatusCard(
                    title: 'Terminal',
                    subtitle: 'Open Ubuntu shell inside Plawie',
                    icon: Icons.terminal,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const TerminalScreen()),
                    ),
                  ),
                  Consumer<GatewayProvider>(
                    builder: (context, provider, _) {
                      return StatusCard(
                        title: 'Web Dashboard',
                        subtitle: provider.state.isRunning
                            ? 'Open Plawie dashboard in browser'
                            : 'Start gateway first',
                        icon: Icons.dashboard,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: provider.state.isRunning
                            ? () async {
                                final currentUrl =
                                    provider.state.dashboardUrl;
                                if (currentUrl != null &&
                                    currentUrl.contains('token=')) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          WebDashboardScreen(url: currentUrl),
                                    ),
                                  );
                                  return;
                                }
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                                final url =
                                    await provider.fetchAuthenticatedDashboardUrl();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          WebDashboardScreen(url: url),
                                    ),
                                  );
                                }
                              }
                            : null,
                      );
                    },
                  ),
                  StatusCard(
                    title: 'Onboarding',
                    subtitle: 'Configure API keys and binding',
                    icon: Icons.vpn_key,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const OnboardingScreen()),
                    ),
                  ),
                  StatusCard(
                    title: 'Packages',
                    subtitle: 'Install optional tools (Go, Homebrew)',
                    icon: Icons.extension,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PackagesScreen()),
                    ),
                  ),
                  StatusCard(
                    title: 'Logs',
                    subtitle: 'View gateway output and errors',
                    icon: Icons.article_outlined,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LogsScreen()),
                    ),
                  ),
                  StatusCard(
                    title: 'Bot Management',
                    subtitle: 'Advanced tools & system RPCs',
                    icon: Icons.settings_ethernet,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const BotManagementDashboard()),
                    ),
                  ),
                  StatusCard(
                    title: 'Help & Docs',
                    subtitle: 'View OpenClaw usage, commands, and guides',
                    icon: Icons.help_outline_rounded,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    ),
                  ),
                  Consumer<NodeProvider>(
                    builder: (context, nodeProvider, _) {
                      final nodeState = nodeProvider.state;
                      return StatusCard(
                        title: 'Node',
                        subtitle: nodeState.isPaired
                            ? 'Connected to gateway'
                            : nodeState.isDisabled
                                ? 'Device capabilities for AI'
                                : nodeState.statusText,
                        icon: Icons.devices,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const NodeScreen()),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Plawie v${AppConstants.version}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.appMotto,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTitle() {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 700),
      crossFadeState:
          _showTagline ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icon/plawie_icon.png',
            width: 22,
            height: 22,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.auto_awesome,
              color: AppColors.statusGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Plawie',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      secondChild: Text(
        AppConstants.appMotto,
        style: const TextStyle(
          color: Colors.white54,
          fontWeight: FontWeight.w500,
          fontSize: 13,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
