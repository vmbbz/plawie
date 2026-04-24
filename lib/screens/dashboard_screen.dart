import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../services/bootstrap_service.dart';
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
import 'base_screen.dart';
import 'help_screen.dart';
import 'management/bot_management_dashboard.dart';
import 'package:google_fonts/google_fonts.dart';

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
        title: Consumer<GatewayProvider>(
          builder: (context, provider, _) => _buildAnimatedTitle(provider),
        ),
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

                  // ── Fluid Staggered Grid ─────────────────────────────────────────
                  Consumer<GatewayProvider>(
                    builder: (context, provider, _) {
                      final gwState = provider.state;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // 1. Primary Action: Chat (Wide Fluid Pod)
                          _FluidDashCard(
                            title: 'Chat with Plawie',
                            subtitle: gwState.isRunning ? 'Talk to your local AI' : 'Start gateway first',
                            icon: Icons.chat_bubble_outline_rounded,
                            iconColor: AppColors.statusGreen,
                            widthFactor: 1.0, 
                            enabled: gwState.isRunning,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(32),
                            ),
                            onTap: gwState.isRunning ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen())) : null,
                          ),
                          
                          // 2. Base Chain (Square Fluid Pod)
                          _FluidDashCard(
                            title: 'Base',
                            subtitle: 'ETH & USDC',
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFF0052FF),
                            widthFactor: 0.48, 
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(32),
                              bottomLeft: Radius.circular(28),
                              bottomRight: Radius.circular(12),
                            ),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BaseScreen())),
                          ),

                          // 3. Terminal (Square Fluid Pod)
                          _FluidDashCard(
                            title: 'Terminal',
                            subtitle: 'Ubuntu Shell',
                            icon: Icons.terminal_rounded,
                            iconColor: Colors.cyanAccent,
                            widthFactor: 0.48,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(32),
                            ),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TerminalScreen())),
                          ),

                          // 4. Web Dashboard (Wide)
                          _FluidDashCard(
                            title: 'Web Dashboard',
                            subtitle: gwState.isRunning ? 'Open in browser' : 'Offline',
                            icon: Icons.dashboard_rounded,
                            iconColor: Colors.blueAccent,
                            widthFactor: 1.0,
                            enabled: gwState.isRunning,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(32),
                              bottomRight: Radius.circular(32),
                            ),
                            onTap: gwState.isRunning ? () async {
                              final currentUrl = gwState.dashboardUrl;
                              if (currentUrl != null && currentUrl.contains('token=')) {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => WebDashboardScreen(url: currentUrl)));
                                return;
                              }
                              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                              final url = await provider.fetchAuthenticatedDashboardUrl();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => WebDashboardScreen(url: url)));
                              }
                            } : null,
                          ),

                          // 5. Bot Management (Square)
                          _FluidDashCard(
                            title: 'Bots',
                            subtitle: 'System RPCs',
                            icon: Icons.settings_ethernet_rounded,
                            iconColor: Colors.tealAccent,
                            widthFactor: 0.48,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(24),
                            ),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BotManagementDashboard())),
                          ),

                          // 6. Node (Square)
                          Consumer<NodeProvider>(
                            builder: (context, nodeProvider, _) => _FluidDashCard(
                              title: 'Node',
                              subtitle: nodeProvider.state.isPaired ? 'Linked' : 'Capabilities',
                              icon: Icons.devices_rounded,
                              iconColor: Colors.white60,
                              widthFactor: 0.48,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(32),
                                bottomLeft: Radius.circular(24),
                                bottomRight: Radius.circular(12),
                              ),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NodeScreen())),
                            ),
                          ),

                          // 7. Gateway Update (Square)
                          _FluidDashCard(
                            title: 'Update',
                            subtitle: 'Fix WebSocket',
                            icon: Icons.system_update_alt_rounded,
                            iconColor: Colors.purpleAccent,
                            widthFactor: 0.48,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(32),
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(12),
                            ),
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Update Gateway'),
                                  content: const Text('This will update OpenClaw to the latest version to fix WebSocket handshake issues. Continue?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Update'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirmed == true) {
                                try {
                                  await BootstrapService().updateGateway();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Gateway updated successfully!'),
                                        backgroundColor: AppColors.statusGreen,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Update failed: $e'),
                                        backgroundColor: AppColors.statusRed,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          ),

                          // 8. Onboarding & Help (Small Row)
                           _FluidDashCard(
                            title: 'Setup',
                            subtitle: 'Config keys',
                            icon: Icons.vpn_key_rounded,
                            iconColor: Colors.orangeAccent,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen())),
                          ),
                          _FluidDashCard(
                            title: 'Help',
                            subtitle: 'Usage guides',
                            icon: Icons.help_outline_rounded,
                            iconColor: Colors.white70,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
                          ),
                          
                          // 8. System Tools: Logs & Packages (Bottom Row)
                          _FluidDashCard(
                            title: 'Logs',
                            subtitle: 'Real-time feed',
                            icon: Icons.article_outlined,
                            iconColor: Colors.white54,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogsScreen())),
                          ),
                          _FluidDashCard(
                            title: 'Packages',
                            subtitle: 'Go, Brew, toolkits',
                            icon: Icons.extension_rounded,
                            iconColor: Colors.purpleAccent,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PackagesScreen())),
                          ),
                        ],
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

  Widget _buildAnimatedTitle(GatewayProvider provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App icon prefix - always present
        SvgPicture.asset(
          'assets/app_icon_official.svg',
          width: 22,
          height: 22,
          colorFilter: ColorFilter.mode(
            provider.state.isRepairing ? AppColors.statusAmber : Colors.white,
            BlendMode.srcIn,
          ),
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
              firstChild: Text(
                provider.state.isRepairing ? 'Repairing System...' : 'Plawie',
                style: TextStyle(
                  color: provider.state.isRepairing ? AppColors.statusAmber : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.0,
                ),
              ),
              secondChild: Text(
                provider.state.isRepairing 
                    ? 'PLEASE WAIT...' 
                    : AppConstants.appMotto.toUpperCase(),
                style: TextStyle(
                  color: provider.state.isRepairing 
                      ? AppColors.statusAmber.withValues(alpha: 0.8) 
                      : Colors.white.withValues(alpha: 0.6),
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

/// Liquid glass fluid dashboard pod.
class _FluidDashCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool enabled;
  final double widthFactor;
  final BorderRadius? borderRadius;

  const _FluidDashCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor = Colors.white70,
    this.onTap,
    this.enabled = true,
    this.widthFactor = 1.0,
    this.borderRadius,
  });

  @override
  State<_FluidDashCard> createState() => _FluidDashCardState();
}

class _FluidDashCardState extends State<_FluidDashCard> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.enabled ? 1.0 : 0.45;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 40 - (widget.widthFactor < 1.0 ? 12 : 0)) * widget.widthFactor;

    // Fluid asymmetric shapes if not specified
    final radius = widget.borderRadius ?? BorderRadius.circular(20);

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTapDown: (_) => _anim.forward(),
        onTapUp: (_) => _anim.reverse(),
        onTapCancel: () => _anim.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _anim.drive(Tween(begin: 1.0, end: 0.94).chain(CurveTween(curve: Curves.easeOutCubic))),
          child: SizedBox(
            width: cardWidth,
            child: GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 0, // Handled by outer decoration
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      splashColor: widget.iconColor.withValues(alpha: 0.1),
                      highlightColor: widget.iconColor.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon header
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: widget.iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.iconColor.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Icon(widget.icon, color: widget.iconColor, size: 18),
                            ),
                            const SizedBox(height: 16),
                            // Text
                            Text(
                              widget.title,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
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
