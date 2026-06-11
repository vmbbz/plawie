import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../models/gateway_state.dart';
import '../providers/gateway_provider.dart';
import '../services/gateway_url_display.dart';
import '../screens/logs_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class GatewayControls extends StatelessWidget {
  const GatewayControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GatewayProvider>(
      builder: (context, provider, _) {
        final state = provider.state;
        final isBooting = state.status == GatewayStatus.starting;
        final accent = _statusColor(state.status);
        final fill = _statusFill(state.status);
        final dashboardUrl = state.dashboardUrl ?? AppConstants.gatewayUrl;
        final displayDashboardUrl = gatewayDisplayUrl(dashboardUrl);

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                fill,
                Color.lerp(fill, accent, 0.16)!,
                const Color(0xFF071014),
              ],
              stops: const [0.0, 0.54, 1.0],
            ),
            border: Border.all(
              color: accent.withValues(alpha: state.isStopped ? 0.14 : 0.30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 24,
                spreadRadius: -14,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'GATEWAY',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                  _statusBadge(state.status),
                ],
              ),
              if (state.isRunning) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.link_rounded,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        displayDashboardUrl,
                        style: GoogleFonts.firaCode(
                          color: Colors.white.withValues(alpha: 0.64),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Clipboard.setData(ClipboardData(text: dashboardUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('URL copied to clipboard'),
                            backgroundColor: AppColors.statusGreen,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.copy_all_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.42)),
                      ),
                    ),
                  ],
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  state.errorMessage!,
                  style:
                      const TextStyle(color: AppColors.statusRed, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final primary =
                      state.isStopped || state.status == GatewayStatus.error
                          ? _buildControlBtn(
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
                            )
                          : _buildControlBtn(
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
                                  : AppColors.statusRed.withValues(alpha: 0.82),
                              isPrimary: true,
                            );

                  final logs = _buildControlBtn(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LogsScreen()),
                      );
                    },
                    icon: Icons.analytics_outlined,
                    label: 'LOGS',
                    color: Colors.white70,
                    isPrimary: false,
                  );

                  if (constraints.maxWidth < 310) {
                    return Column(
                      children: [
                        primary,
                        const SizedBox(height: 10),
                        logs,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: primary),
                      const SizedBox(width: 12),
                      Expanded(child: logs),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(GatewayStatus status) {
    return switch (status) {
      GatewayStatus.running => AppColors.statusGreen,
      GatewayStatus.starting => AppColors.statusAmber,
      GatewayStatus.error => AppColors.statusRed,
      GatewayStatus.stopped => Colors.white54,
    };
  }

  Color _statusFill(GatewayStatus status) {
    return switch (status) {
      GatewayStatus.running => const Color(0xFF0D2B26),
      GatewayStatus.starting => const Color(0xFF2E2A15),
      GatewayStatus.error => const Color(0xFF2B1316),
      GatewayStatus.stopped => const Color(0xFF121A1F),
    };
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
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
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
    return _GatewayActionButton(
      onTap: onTap,
      icon: icon,
      label: label,
      color: color,
      isPrimary: isPrimary,
    );
  }
}

class _GatewayActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;
  final bool isPrimary;

  const _GatewayActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    required this.isPrimary,
  });

  @override
  State<_GatewayActionButton> createState() => _GatewayActionButtonState();
}

class _GatewayActionButtonState extends State<_GatewayActionButton>
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
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? widget.color.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isPrimary
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.20),
                      blurRadius: 18,
                      spreadRadius: -8,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon,
                  color: widget.isPrimary ? Colors.white : widget.color,
                  size: 17),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
