import 'package:flutter/material.dart';
import '../app.dart';

/// A sci-fi holographic dot that floats above the avatar's head.
/// It features a sharp, glass-like 2D aesthetic and reacts to interactions.
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
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
      duration: const Duration(milliseconds: 80), // Snappy movement tracking
      left: widget.position.dx - 15,
      top: widget.position.dy - 15,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            // Pulse logic for "alive" feel
            final pulseValue = _pulseController.value;
            final scale = _isPressed ? 0.85 : (1.0 + (0.15 * pulseValue));
            
            // Interaction colors: White translucent (glass)
            final baseColor = Colors.white.withValues(alpha: _isPressed ? 0.8 : 0.15);
            final borderColor = Colors.white.withValues(alpha: _isPressed ? 1.0 : 0.4);
            
            // Holographic bloom (glow)
            // Cyan holographic pulse when speaking or pressed
            final energyColor = const Color(0xFF00FFFF).withValues(alpha: 0.6 + (0.4 * pulseValue));
            final idleColor = Colors.white.withValues(alpha: 0.2 + (0.2 * pulseValue));
            final glowColor = (widget.isSpeaking || _isPressed) ? energyColor : idleColor;

            return Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow (Bloom)
                  Container(
                    width: (widget.isSpeaking || _isPressed ? 18 : 12) * scale,
                    height: (widget.isSpeaking || _isPressed ? 18 : 12) * scale,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: glowColor.alpha * 0.5),
                          blurRadius: (widget.isSpeaking || _isPressed ? 15 : 8) * scale,
                          spreadRadius: (widget.isSpeaking || _isPressed ? 2 : 0) * scale,
                        ),
                      ],
                    ),
                  ),
                  
                  // The "Glass" Node
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 7 * scale,
                    height: 7 * scale,
                    decoration: BoxDecoration(
                      color: baseColor,
                      boxShadow: [
                        if (widget.isSpeaking || _isPressed)
                          BoxShadow(
                            color: energyColor.withValues(alpha: 0.8),
                            blurRadius: 4,
                          ),
                      ],
                      border: Border.all(
                        color: borderColor,
                        width: 0.5, // Ultra-thin "sharp" edge
                      ),
                      borderRadius: BorderRadius.zero, 
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
