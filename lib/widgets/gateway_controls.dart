import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../models/gateway_state.dart';
import '../providers/gateway_provider.dart';
import '../screens/logs_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_card.dart';

class GatewayControls extends StatelessWidget {
  const GatewayControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GatewayProvider>(
      builder: (context, provider, _) {
        final state = provider.state;
        final isBooting = state.status == GatewayStatus.starting;

        return _PulsingBorder(
          enabled: isBooting,
          color: AppColors.statusAmber,
          child: ClipPath(
            clipper: _GatewayCardClipper(),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              borderRadius: 14,
              blurStrength: 25,
              innerTint: Colors.transparent,
              accentColor: state.isRunning
                  ? AppColors.statusGreen
                  : (isBooting ? AppColors.statusAmber : null),
              child: _DynamicGlow(
                color: state.isRunning
                    ? AppColors.statusGreen
                    : (isBooting ? AppColors.statusAmber : Colors.transparent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'GATEWAY',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ),
                        _statusBadge(state.status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (state.isRunning) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded,
                                color: Colors.white38, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText(
                                state.dashboardUrl ?? AppConstants.gatewayUrl,
                                style: GoogleFonts.firaCode(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                final url = state.dashboardUrl ??
                                    AppConstants.gatewayUrl;
                                Clipboard.setData(ClipboardData(text: url));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('URL copied to clipboard'),
                                    backgroundColor: AppColors.statusGreen,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Icon(Icons.copy_all_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(
                              color: AppColors.statusRed, fontSize: 12),
                        ),
                      ),
                    Row(
                      children: [
                        if (state.isStopped ||
                            state.status == GatewayStatus.error)
                          Expanded(
                            flex: 12,
                            child: _buildControlBtn(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                provider.start();
                              },
                              icon: Icons.play_arrow_rounded,
                              label: 'START',
                              color: state.status == GatewayStatus.error
                                  ? AppColors.statusRed
                                  : AppColors.statusGreen,
                              isPrimary: true,
                            ),
                          ),
                        if (state.isRunning || isBooting)
                          Expanded(
                            flex: 12,
                            child: _buildControlBtn(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                provider.stop();
                              },
                              icon: isBooting
                                  ? Icons.hourglass_empty_rounded
                                  : Icons.stop_rounded,
                              label: isBooting ? 'BOOTING' : 'STOP',
                              color: isBooting
                                  ? AppColors.statusAmber
                                  : AppColors.statusRed.withValues(alpha: 0.8),
                              isPrimary: true,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 10,
                          child: _buildControlBtn(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const LogsScreen()),
                              );
                            },
                            icon: Icons.analytics_outlined,
                            label: 'LOGS',
                            color: Colors.white38,
                            isPrimary: false,
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
      },
    );
  }

  Widget _statusBadge(GatewayStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case GatewayStatus.running:
        color = AppColors.statusGreen;
        label = 'LIVE';
        icon = Icons.stream_rounded;
        break;
      case GatewayStatus.starting:
        color = AppColors.statusAmber;
        label = 'BOOTING';
        icon = Icons.rocket_launch_rounded;
        break;
      case GatewayStatus.error:
        color = AppColors.statusRed;
        label = 'FAULT';
        icon = Icons.warning_amber_rounded;
        break;
      case GatewayStatus.stopped:
        color = Colors.white;
        label = 'OFFLINE';
        icon = Icons.power_settings_new_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 9,
                letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    required bool isPrimary,
  }) {
    return _EpicButton(
      onTap: onTap,
      icon: icon,
      label: label,
      color: color,
      isPrimary: isPrimary,
    );
  }
}

class _DynamicGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  const _DynamicGlow({required this.child, required this.color});

  @override
  State<_DynamicGlow> createState() => _DynamicGlowState();
}

class _DynamicGlowState extends State<_DynamicGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final glow = 0.05 + 0.1 * _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glow),
                blurRadius: 40 + 20 * _ctrl.value,
                spreadRadius: 2 * _ctrl.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _EpicButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;
  final bool isPrimary;

  const _EpicButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    required this.isPrimary,
  });

  @override
  State<_EpicButton> createState() => _EpicButtonState();
}

class _EpicButtonState extends State<_EpicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) => _ctrl.reverse(),
        onTapCancel: () => _ctrl.reverse(),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? widget.color
                : Colors.white.withValues(alpha: 0.05),
            gradient: widget.isPrimary
                ? LinearGradient(
                    colors: [
                      widget.color,
                      widget.color.withValues(alpha: 0.85)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isPrimary
                  ? widget.color.withValues(alpha: 0.4)
                  : widget.color.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GatewayCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final path = Path();
    path.moveTo(28, 0);
    path.lineTo(s.width - 16, 0);
    path.quadraticBezierTo(s.width, 0, s.width, 16);
    path.lineTo(s.width, s.height - 26);
    path.quadraticBezierTo(s.width, s.height, s.width - 26, s.height);
    path.lineTo(18, s.height);
    path.quadraticBezierTo(0, s.height, 0, s.height - 18);
    path.lineTo(0, 28);
    path.quadraticBezierTo(0, 0, 28, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_GatewayCardClipper old) => false;
}

class _PulsingBorder extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Color color;
  const _PulsingBorder(
      {required this.child, required this.enabled, required this.color});

  @override
  State<_PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<_PulsingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.1 + 0.3 * _ctrl.value),
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
