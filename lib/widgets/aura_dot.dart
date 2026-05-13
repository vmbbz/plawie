import 'package:flutter/material.dart';
import '../app.dart';

/// A sci-fi holographic dot that floats above the avatar's head.
/// It pulses with energy and expands into a minimal TTS menu when tapped.
class AuraDot extends StatefulWidget {
  final Offset position;
  final VoidCallback onTap;
  final bool isSpeaking;

  const AuraDot({
    super.key,
    required this.position,
    required this.onTap,
    this.isSpeaking = false,
  });

  @override
  State<AuraDot> createState() => _AuraDotState();
}

class _AuraDotState extends State<AuraDot> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.position == Offset.zero) return const SizedBox.shrink();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 50),
      left: widget.position.dx - 15,
      top: widget.position.dy - 15,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + (0.3 * _pulseController.value);
            final opacity = 0.4 + (0.4 * _pulseController.value);
            
            return Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.statusGreen.withValues(alpha: widget.isSpeaking ? 0.6 : 0.3),
                    blurRadius: 15 * scale,
                    spreadRadius: 2 * scale,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 8 * scale,
                  height: 8 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: opacity),
                    border: Border.all(
                      color: AppColors.statusGreen.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
