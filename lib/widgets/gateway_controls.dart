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
    // We no longer rely strictly on theme colors for the background,
    // so we force liquid aesthetics with custom containers
    return Consumer<GatewayProvider>(
      builder: (context, provider, _) {
        final state = provider.state;

        return GlassCard(
          padding: const EdgeInsets.all(24),
          accentColor: state.isRunning ? AppColors.statusGreen : null,
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
                      const Icon(Icons.link_rounded, color: Colors.white38, size: 14),
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
                          final url = state.dashboardUrl ?? AppConstants.gatewayUrl;
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('URL copied to clipboard'),
                              backgroundColor: AppColors.statusGreen,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Icon(Icons.copy_all_rounded, size: 16, color: Colors.white.withValues(alpha: 0.4)),
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
                    style: const TextStyle(color: AppColors.statusRed, fontSize: 12),
                  ),
                ),
              Row(
                children: [
                  if (state.isStopped || state.status == GatewayStatus.error)
                    Expanded(
                      flex: 1,
                      child: _buildControlBtn(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          provider.start();
                        },
                        icon: Icons.play_arrow_rounded,
                        label: 'START',
                        color: state.status == GatewayStatus.error ? AppColors.statusRed : AppColors.statusGreen,
                        isPrimary: true,
                      ),
                    ),
                  if (state.isRunning || state.status == GatewayStatus.starting)
                    Expanded(
                      flex: 1,
                      child: _buildControlBtn(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          provider.stop();
                        },
                        icon: Icons.stop_rounded,
                        label: 'STOP',
                        color: AppColors.statusRed.withValues(alpha: 0.8),
                        isPrimary: true, // Make STOP primary/soft-red per request
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildControlBtn(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LogsScreen()),
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
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.transparent, // Remove shaded background
          gradient: isPrimary ? LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary ? null : Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: isPrimary ? [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : [],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isPrimary ? Colors.white : color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
