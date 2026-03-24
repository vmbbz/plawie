import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../widgets/gateway_controls.dart';
import '../widgets/glass_card.dart';
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
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    
    // Start the rotation loop
    _rotationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() => _showTagline = !_showTagline);
        if (_showTagline) {
          _taglineController.forward();
        } else {
          _taglineController.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
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
          // ── Nebula background ──────────────────────────────────────────────
          const NebulaBg(),

          // ── Content ────────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GatewayControls(),
                  const SizedBox(height: 20),

                  // Section label
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'QUICK ACTIONS',
                      style: TextStyle(
                        color: AppColors.statusGreen.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),

                  // ── Cards ──────────────────────────────────────────────────
                  Consumer<GatewayProvider>(
                    builder: (context, provider, _) => _DashCard(
                      title: 'Chat with Plawie',
                      subtitle: provider.state.isRunning
                          ? 'Talk to your local AI companion'
                          : 'Start gateway first',
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: AppColors.statusGreen,
                      enabled: provider.state.isRunning,
                      onTap: provider.state.isRunning
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ChatScreen()),
                              )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _DashCard(
                    title: 'Solana',
                    subtitle: 'Manage wallet and DeFi',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF9945FF),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SolanaScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _DashCard(
                    title: 'Terminal',
                    subtitle: 'Open Ubuntu shell inside Plawie',
                    icon: Icons.terminal_rounded,
                    iconColor: Colors.cyanAccent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TerminalScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Consumer<GatewayProvider>(
                    builder: (context, provider, _) => _DashCard(
                      title: 'Web Dashboard',
                      subtitle: provider.state.isRunning
                          ? 'Open Plawie dashboard in browser'
                          : 'Start gateway first',
                      icon: Icons.dashboard_rounded,
                      iconColor: Colors.blueAccent,
                      enabled: provider.state.isRunning,
                      onTap: provider.state.isRunning
                          ? () async {
                              final currentUrl = provider.state.dashboardUrl;
                              if (currentUrl != null && currentUrl.contains('token=')) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => WebDashboardScreen(url: currentUrl),
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
                              final url = await provider.fetchAuthenticatedDashboardUrl();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => WebDashboardScreen(url: url),
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _DashCard(
                    title: 'Onboarding',
                    subtitle: 'Configure API keys and binding',
                    icon: Icons.vpn_key_rounded,
                    iconColor: Colors.orangeAccent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _DashCard(
                    title: 'Packages',
                    subtitle: 'Install optional tools (Go, Homebrew)',
                    icon: Icons.extension_rounded,
                    iconColor: Colors.purpleAccent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PackagesScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _DashCard(
                    title: 'Logs',
                    subtitle: 'View gateway output and errors',
                    icon: Icons.article_outlined,
                    iconColor: Colors.white54,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LogsScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _DashCard(
                    title: 'Bot Management',
                    subtitle: 'Advanced tools & system RPCs',
                    icon: Icons.settings_ethernet_rounded,
                    iconColor: Colors.tealAccent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BotManagementDashboard()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _DashCard(
                    title: 'Help & Docs',
                    subtitle: 'Usage, commands, and guides',
                    icon: Icons.help_outline_rounded,
                    iconColor: Colors.white70,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Consumer<NodeProvider>(
                    builder: (context, nodeProvider, _) {
                      final nodeState = nodeProvider.state;
                      return _DashCard(
                        title: 'Node',
                        subtitle: nodeState.isPaired
                            ? 'Connected to gateway'
                            : nodeState.isDisabled
                                ? 'Device capabilities for AI'
                                : nodeState.statusText,
                        icon: Icons.devices_rounded,
                        iconColor: Colors.white60,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NodeScreen()),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 36),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Plawie v${AppConstants.version}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.appMotto,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.18),
                            fontSize: 10,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App icon prefix - always present
        SvgPicture.asset(
          'assets/app_icon_official.svg',
          width: 22,
          height: 22,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        const SizedBox(width: 12),
        // Rotator
        SizedBox(
          height: 40,
          child: Center(
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 600),
              alignment: Alignment.centerLeft,
              crossFadeState: _showTagline 
                  ? CrossFadeState.showSecond 
                  : CrossFadeState.showFirst,
              firstChild: const Text(
                'Plawie',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.0,
                ),
              ),
              secondChild: Text(
                AppConstants.appMotto.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Liquid glass dashboard action card.
class _DashCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool enabled;

  const _DashCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor = Colors.white70,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.45;
    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 20,
          accentColor: onTap != null ? null : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: iconColor.withValues(alpha: 0.1),
                highlightColor: iconColor.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      // Icon pill
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: iconColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),
                      const SizedBox(width: 16),
                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Chevron
                      Icon(
                        Icons.chevron_right_rounded,
                        color: onTap != null
                            ? Colors.white.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.15),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
