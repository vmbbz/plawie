import 'dart:async';
import 'dart:math' as math;
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

/// Zoom-in page transition — cards feel like they're flying into the new screen.
Route<T> _zoomRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 360),
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) {
    final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(curve), child: child),
    );
  },
);

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
          NebulaBg(),
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

                  // Moving dark gradient background layer
                  _AnimatedDarkGridBg(
                    child: Consumer<GatewayProvider>(
                      builder: (context, provider, _) {
                        final gwState = provider.state;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _BlobDashCard(
                              title: 'Chat with Plawie',
                              subtitle: gwState.isRunning ? 'Talk to your local AI' : 'Start gateway first',
                              icon: Icons.chat_bubble_outline_rounded,
                              iconColor: AppColors.statusGreen,
                              widthFactor: 1.0,
                              blobSeed: 0,
                              enabled: gwState.isRunning,
                              onTap: gwState.isRunning
                                  ? () => Navigator.of(context).push(_zoomRoute(const ChatScreen()))
                                  : null,
                            ),
                            _BlobDashCard(
                              title: 'Bots',
                              subtitle: 'System RPCs',
                              icon: Icons.settings_ethernet_rounded,
                              iconColor: Colors.tealAccent,
                              widthFactor: 0.48,
                              blobSeed: 4,
                              onTap: () => Navigator.of(context).push(_zoomRoute(const BotManagementDashboard())),
                            ),
                            _BlobDashCard(
                              title: 'Terminal',
                              subtitle: 'Ubuntu Shell',
                              icon: Icons.terminal_rounded,
                              iconColor: Colors.cyanAccent,
                              widthFactor: 0.48,
                              blobSeed: 2,
                              onTap: () => Navigator.of(context).push(_zoomRoute(const TerminalScreen())),
                            ),
                            _BlobDashCard(
                              title: 'Web Dashboard',
                              subtitle: gwState.isRunning ? 'Open in browser' : 'Offline',
                              icon: Icons.dashboard_rounded,
                              iconColor: Colors.blueAccent,
                              widthFactor: 1.0,
                              blobSeed: 3,
                              enabled: gwState.isRunning,
                              onTap: gwState.isRunning ? () async {
                                final currentUrl = gwState.dashboardUrl;
                                if (currentUrl != null && currentUrl.contains('token=')) {
                                  Navigator.of(context).push(_zoomRoute(WebDashboardScreen(url: currentUrl)));
                                  return;
                                }
                                showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                                final url = await provider.fetchAuthenticatedDashboardUrl();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(_zoomRoute(WebDashboardScreen(url: url)));
                                }
                              } : null,
                            ),
                            _BlobDashCard(
                              title: 'Base',
                              subtitle: 'ETH & USDC',
                              icon: Icons.account_balance_wallet_rounded,
                              iconColor: const Color(0xFF0052FF),
                              widthFactor: 0.48,
                              blobSeed: 1,
                              onTap: () => Navigator.of(context).push(_zoomRoute(const BaseScreen())),
                            ),
                            Consumer<NodeProvider>(
                              builder: (context, nodeProvider, _) => _BlobDashCard(
                                title: 'Node',
                                subtitle: nodeProvider.state.isPaired ? 'Linked' : 'Capabilities',
                                icon: Icons.devices_rounded,
                                iconColor: Colors.white60,
                                widthFactor: 0.48,
                                blobSeed: 5,
                                onTap: () => Navigator.of(context).push(_zoomRoute(const NodeScreen())),
                              ),
                            ),
                            _BlobDashCard(
                              title: 'Update',
                              subtitle: 'Fix WebSocket',
                              icon: Icons.system_update_alt_rounded,
                              iconColor: Colors.purpleAccent,
                              widthFactor: 0.48,
                              blobSeed: 6,
                              onTap: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Update Gateway'),
                                    content: const Text('This will update OpenClaw to the latest version. Continue?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Update')),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  try {
                                    await BootstrapService().updateGateway();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gateway updated!'), backgroundColor: AppColors.statusGreen));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.statusRed));
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
                              blobSeed: 7,
                              onTap: () => Navigator.of(context).push(_zoomRoute(const OnboardingScreen())),
                            ),
                            _BlobDashCard(
                              title: 'Help',
                              subtitle: 'Usage guides',
                              icon: Icons.help_outline_rounded,
                              iconColor: Colors.white70,
                              widthFactor: 0.48,
                              blobSeed: 8,
                              onTap: () => Navigator.of(context).push(_zoomRoute(const HelpScreen())),
                            ),
                            _BlobDashCard(
                              title: 'Logs',
                              subtitle: 'Real-time feed',
                              icon: Icons.article_outlined,
                              iconColor: Colors.white54,
                              widthFactor: 0.48,
                              blobSeed: 9,
                              onTap: () => Navigator.of(context).push(_zoomRoute(const LogsScreen())),
                            ),
                            _BlobDashCard(
                              title: 'Packages',
                              subtitle: 'Go, Brew, toolkits',
                              icon: Icons.extension_rounded,
                              iconColor: Colors.purpleAccent,
                              widthFactor: 0.48,
                              blobSeed: 10,
                              onTap: () => Navigator.of(context).push(_zoomRoute(const PackagesScreen())),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 36),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Plawie v${AppConstants.version}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.appMotto,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.18), fontSize: 10),
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
        SizedBox(
          height: 40,
          child: Center(
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 600),
              alignment: Alignment.centerLeft,
              crossFadeState: _showTagline ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
                provider.state.isRepairing ? 'PLEASE WAIT...' : AppConstants.appMotto.toUpperCase(),
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

// ─── Animated dark gradient background behind the grid ────────────────────────

class _AnimatedDarkGridBg extends StatefulWidget {
  final Widget child;
  const _AnimatedDarkGridBg({required this.child});

  @override
  State<_AnimatedDarkGridBg> createState() => _AnimatedDarkGridBgState();
}

class _AnimatedDarkGridBgState extends State<_AnimatedDarkGridBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Background and padding removed as requested to let cards breathe
    return Padding(
      padding: EdgeInsets.zero,
      child: widget.child,
    );
  }
}

// ─── Organic Blob Card ────────────────────────────────────────────────────────

class _BlobDashCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool enabled;
  final double widthFactor;
  /// Seed offsets the animation phase so each card has a unique blob shape.
  final int blobSeed;

  const _BlobDashCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.blobSeed,
    this.iconColor = Colors.white70,
    this.onTap,
    this.enabled = true,
    this.widthFactor = 1.0,
  });

  @override
  State<_BlobDashCard> createState() => _BlobDashCardState();
}

class _BlobDashCardState extends State<_BlobDashCard> with TickerProviderStateMixin {
  late AnimationController _blobCtrl; // slow organic morph
  late AnimationController _tapCtrl;  // fast tap scale feedback

  // Physics float state
  Offset _floatOffset = Offset.zero;
  Offset _floatVelocity = Offset.zero;
  static const double _stiffness = 80.0;   // spring pull toward zero
  static const double _damping = 14.0;     // air resistance
  static const double _idleAmplitude = 2.5; // px, very subtle hover

  void _tick() {
    if (!mounted) return;
    final dt = 1 / 60;
    final seed = widget.blobSeed.toDouble();
    final t = _blobCtrl.value;

    // Idle sinusoidal float — unique phase per card
    final idleX = _idleAmplitude * math.sin(t * 2 * math.pi + seed * 1.1);
    final idleY = _idleAmplitude * math.cos(t * 2 * math.pi * 0.7 + seed * 0.8);
    final idleTarget = Offset(idleX, idleY);

    // Spring toward idle position
    final springForce = (idleTarget - _floatOffset) * _stiffness;
    _floatVelocity = (_floatVelocity + springForce * dt) * (1.0 - _damping * dt).clamp(0.0, 1.0);
    _floatOffset = _floatOffset + _floatVelocity * dt;

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Each card gets a unique speed slightly offset so they never look in sync
    final speed = 5 + (widget.blobSeed % 3) * 1.5;
    _blobCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (speed * 1000).toInt()),
    )..repeat();
    _blobCtrl.addListener(_tick);
    _tapCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 130));
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 40 - (widget.widthFactor < 1.0 ? 14 : 0)) * widget.widthFactor;
    final cardHeight = widget.widthFactor == 1.0 ? 84.0 : 112.0; // Taller for stacked layout
    final opacity = widget.enabled ? 1.0 : 0.4;

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTapDown: (_) => _tapCtrl.forward(),
        onTapUp: (_) => _tapCtrl.reverse(),
        onTapCancel: () => _tapCtrl.reverse(),
        onTap: widget.onTap,
        onPanUpdate: (d) {
          // Nudge velocity on drag — spring will pull it back
          _floatVelocity += d.delta * 2.5;
        },
        child: Transform.translate(
          offset: _floatOffset,
          child: ScaleTransition(
          scale: _tapCtrl.drive(
            Tween(begin: 1.0, end: 0.93).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: AnimatedBuilder(
            animation: _blobCtrl,
            builder: (context, child) {
              final t = _blobCtrl.value;
              final seed = widget.blobSeed.toDouble();
              final clipper = _BlobClipper(t: t, seed: seed);
              return SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Stack(
                  children: [
                    // Layer 1: Glass fill (Stable RRect, no clipping)
                    Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.iconColor.withValues(alpha: 0.14),
                            widget.iconColor.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.2),
                          ],
                        ),
                        border: Border.all(
                          color: widget.iconColor.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                    // Layer 2: Animated glowing blob border
                    CustomPaint(
                      size: Size(cardWidth, cardHeight),
                      painter: _BlobBorderPainter(
                        t: t,
                        seed: seed,
                        color: widget.iconColor,
                      ),
                    ),
                    // Layer 3: Content
                    child!,
                  ],
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.widthFactor == 1.0 ? 20 : 16,
                vertical: 14,
              ),
              child: widget.widthFactor == 1.0
                  ? Row(
                      children: [
                        _iconBox(),
                        const SizedBox(width: 16),
                        Expanded(child: _textCol()),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white.withValues(alpha: 0.25)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _iconBox(),
                        const Spacer(),
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
        color: widget.iconColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.iconColor.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: widget.iconColor.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(widget.icon, color: widget.iconColor, size: 17),
    );
  }

  Widget _textCol() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: widget.widthFactor == 1.0 ? 15 : 13, // Scale for grid
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          widget.subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: widget.widthFactor == 1.0 ? 11 : 10,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Blob math ────────────────────────────────────────────────────────────────
//
// We model the blob as 8 control points around an ellipse.
// Each point's radius oscillates with sin/cos at a unique phase derived
// from its index and the card's seed. This gives a slow "breathing membrane"
// effect — organic but not chaotic.

List<Offset> _blobPoints(double t, double seed, double w, double h) {
  const n = 8;
  final cx = w / 2;
  final cy = h / 2;
  final rx = w * 0.46;
  final ry = h * 0.44;

  return List.generate(n, (i) {
    final angle = (i / n) * 2 * math.pi;
    // Each point breathes at its own rate/phase, seeded by card index
    final phase = seed * 0.7 + i * 0.9;
    final radiusScale = 1.0 + 0.06 * math.sin(t * 2 * math.pi + phase)
                            + 0.03 * math.cos(t * 4 * math.pi + phase * 1.3);
    return Offset(
      cx + rx * radiusScale * math.cos(angle),
      cy + ry * radiusScale * math.sin(angle),
    );
  });
}

Path _buildBlobPath(double t, double seed, double w, double h) {
  final pts = _blobPoints(t, seed, w, h);
  final n = pts.length;
  final path = Path();

  for (int i = 0; i < n; i++) {
    final prev = pts[(i - 1 + n) % n];
    final curr = pts[i];
    final next = pts[(i + 1) % n];

    // Catmull-Rom → Bézier: smooth tangents through all points
    final cp1 = Offset(curr.dx + (next.dx - prev.dx) / 6, curr.dy + (next.dy - prev.dy) / 6);
    final cp2next = pts[(i + 2) % n];
    final cp2 = Offset(next.dx - (cp2next.dx - curr.dx) / 6, next.dy - (cp2next.dy - curr.dy) / 6);

    if (i == 0) path.moveTo(curr.dx, curr.dy);
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
  }
  path.close();
  return path;
}

class _BlobClipper extends CustomClipper<Path> {
  final double t;
  final double seed;
  _BlobClipper({required this.t, required this.seed});

  @override
  Path getClip(Size size) => _buildBlobPath(t, seed, size.width, size.height);

  @override
  bool shouldReclip(_BlobClipper old) => old.t != t;
}

class _BlobBorderPainter extends CustomPainter {
  final double t;
  final double seed;
  final Color color;
  _BlobBorderPainter({required this.t, required this.seed, required this.color});

  @override
  @override
  void paint(Canvas canvas, Size size) {
    // Yesterday's "Soul" - a subtle, breathing RRect border glow
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final alpha = 0.3 + 0.2 * math.sin(t * 2 * math.pi + seed);

    // Subtle outer glow
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Crisp breathing inner border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_BlobBorderPainter old) => old.t != t;
}
