import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../services/bootstrap_service.dart';
import '../widgets/gateway_controls.dart';
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

/// Zoom-in page transition — cards feel like they're flying into the new screen.
Route<T> _zoomRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
              scale: Tween(begin: 0.88, end: 1.0).animate(curve), child: child),
        );
      },
    );

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(color: Colors.black.withValues(alpha: 0.18)),
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
          const _StaticHomeBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GatewayControls(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
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
                  Consumer<GatewayProvider>(
                    builder: (context, provider, _) {
                      final gwState = provider.state;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          _BlobDashCard(
                            title: 'Chat with Plawie',
                            subtitle: gwState.isRunning
                                ? 'Talk to your local AI'
                                : 'Start gateway first',
                            icon: Icons.chat_bubble_outline_rounded,
                            iconColor: AppColors.statusGreen,
                            widthFactor: 1.0,
                            enabled: gwState.isRunning,
                            onTap: gwState.isRunning
                                ? () => Navigator.of(context)
                                    .push(_zoomRoute(const ChatScreen()))
                                : null,
                          ),
                          _BlobDashCard(
                            title: 'Bots',
                            subtitle: 'System RPCs',
                            icon: Icons.settings_ethernet_rounded,
                            iconColor: Colors.tealAccent,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context).push(
                                _zoomRoute(const BotManagementDashboard())),
                          ),
                          _BlobDashCard(
                            title: 'Terminal',
                            subtitle: 'Manual rollback shell',
                            icon: Icons.terminal_rounded,
                            iconColor: Colors.cyanAccent,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context)
                                .push(_zoomRoute(const TerminalScreen())),
                          ),
                          _BlobDashCard(
                            title: 'Web Dashboard',
                            subtitle: gwState.isRunning
                                ? 'Open in browser'
                                : 'Offline',
                            icon: Icons.dashboard_rounded,
                            iconColor: Colors.blueAccent,
                            widthFactor: 1.0,
                            enabled: gwState.isRunning,
                            onTap: gwState.isRunning
                                ? () async {
                                    final currentUrl = gwState.dashboardUrl;
                                    if (currentUrl != null &&
                                        currentUrl.contains('token=')) {
                                      Navigator.of(context).push(_zoomRoute(
                                          WebDashboardScreen(url: currentUrl)));
                                      return;
                                    }
                                    showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => const Center(
                                            child:
                                                CircularProgressIndicator()));
                                    final url = await provider
                                        .fetchAuthenticatedDashboardUrl();
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).push(_zoomRoute(
                                          WebDashboardScreen(url: url)));
                                    }
                                  }
                                : null,
                          ),
                          _BlobDashCard(
                            title: 'Base',
                            subtitle: 'ETH & USDC',
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFF0052FF),
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context)
                                .push(_zoomRoute(const BaseScreen())),
                          ),
                          Consumer<NodeProvider>(
                            builder: (context, nodeProvider, _) =>
                                _BlobDashCard(
                              title: 'Node',
                              subtitle: nodeProvider.state.isPaired
                                  ? 'Linked'
                                  : 'Capabilities',
                              icon: Icons.devices_rounded,
                              iconColor: Colors.white60,
                              widthFactor: 0.48,
                              onTap: () => Navigator.of(context)
                                  .push(_zoomRoute(const NodeScreen())),
                            ),
                          ),
                          _BlobDashCard(
                            title: 'Update',
                            subtitle: 'Fix WebSocket',
                            icon: Icons.system_update_alt_rounded,
                            iconColor: Colors.purpleAccent,
                            widthFactor: 0.48,
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Update Gateway'),
                                  content: const Text(
                                      'This will update OpenClaw to the latest version. Continue?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Update')),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  await BootstrapService().updateGateway();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Gateway updated!'),
                                            backgroundColor:
                                                AppColors.statusGreen));
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text('Update failed: $e'),
                                            backgroundColor:
                                                AppColors.statusRed));
                                  }
                                }
                              }
                            },
                          ),
                          _BlobDashCard(
                            title: 'Setup',
                            subtitle: 'Config keys',
                            icon: Icons.vpn_key_rounded,
                            iconColor: Colors.orangeAccent,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context)
                                .push(_zoomRoute(const OnboardingScreen())),
                          ),
                          _BlobDashCard(
                            title: 'Help',
                            subtitle: 'Usage guides',
                            icon: Icons.help_outline_rounded,
                            iconColor: Colors.white70,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context)
                                .push(_zoomRoute(const HelpScreen())),
                          ),
                          _BlobDashCard(
                            title: 'Logs',
                            subtitle: 'Real-time feed',
                            icon: Icons.article_outlined,
                            iconColor: Colors.white54,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context)
                                .push(_zoomRoute(const LogsScreen())),
                          ),
                          _BlobDashCard(
                            title: 'Runtime Extras',
                            subtitle: 'PRoot extras, skills',
                            icon: Icons.extension_rounded,
                            iconColor: Colors.purpleAccent,
                            widthFactor: 0.48,
                            onTap: () => Navigator.of(context)
                                .push(_zoomRoute(const PackagesScreen())),
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
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.appMotto,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.18),
                              fontSize: 10),
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
        Text(
          provider.state.isRepairing ? 'Repairing System...' : 'Plawie',
          style: TextStyle(
            color: provider.state.isRepairing
                ? AppColors.statusAmber
                : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _StaticHomeBackdrop extends StatelessWidget {
  const _StaticHomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.25, -0.45),
          radius: 1.35,
          colors: [
            Color(0xFF08242A),
            Color(0xFF031016),
            Colors.black,
          ],
          stops: [0.0, 0.48, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

// ─── Lightweight Dashboard Card ──────────────────────────────────────────────

class _BlobDashCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool enabled;
  final double widthFactor;

  const _BlobDashCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor = Colors.white70,
    this.onTap,
    this.enabled = true,
    this.widthFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth =
        (screenWidth - 40 - (widthFactor < 1.0 ? 14 : 0)) * widthFactor;
    const cardHeight = 112.0;
    final contentOpacity = enabled ? 1.0 : 0.42;

    return Opacity(
      opacity: contentOpacity,
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(18),
            splashColor: iconColor.withValues(alpha: 0.10),
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    iconColor.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.035),
                    Colors.black.withValues(alpha: 0.28),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    spreadRadius: -10,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconBox(),
                    const SizedBox(height: 12),
                    _textCol(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: iconColor.withValues(alpha: 0.45), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.16),
            blurRadius: 10,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: 17),
    );
  }

  Widget _textCol() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
