import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// GlassCard — Liquid frosted glass card matching the Main Chat aesthetic.
///
/// Two-layer effect:
///   Layer 1: BackdropFilter blur (blurs whatever is BEHIND the card — the nebula/avatar)
///   Layer 2: semi-transparent black inner tint → gives "black patch in frosted glass" feel
///
/// Usage:
///   GlassCard(child: YourContent())
///   GlassCard(accentColor: AppColors.statusGreen, child: ...)
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? accentColor; // if set: border glows with this color
  final double blurStrength;
  final Color? innerTint; // override the inner black tint

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
    this.accentColor,
    this.blurStrength = 12,
    this.innerTint,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = accentColor != null
        ? accentColor!.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // Outer glow / shadow
        boxShadow: [
          BoxShadow(
            color: accentColor != null
                ? accentColor!.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: borderColor, width: accentColor != null ? 1.5 : 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
          child: Container(
            padding: padding,
            // Layer 1: very faint white glass
            color: Colors.white.withValues(alpha: 0.06),
            child: Stack(
              children: [
                // Layer 2: black inner tint ("black patch" in glass)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius - 2),
                      gradient: RadialGradient(
                        center: Alignment.topLeft,
                        radius: 1.5,
                        colors: [
                          (innerTint ?? Colors.black).withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Use inside a Scaffold body as the bottom layer.
class NebulaBg extends StatefulWidget {
  const NebulaBg({super.key});

  @override
  State<NebulaBg> createState() => _NebulaBgState();
}

class _NebulaBgState extends State<NebulaBg> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Very serene, slow-moving plasma effect
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep space base gradient (dark/black base)
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.4,
              colors: [Color(0xFF040A10), Colors.black],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        // Plasma light blobs that slowly rotate and drift using AnimatedBuilder
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _DynamicPlasmaPainter(_controller.value),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Dynamic moving version of the nebula with dark greenish/bluish spots and tiny stars
class _DynamicPlasmaPainter extends CustomPainter {
  final double progress;

  _DynamicPlasmaPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // We add slow drifting circles of dark, subtle green/bluish combinations
    final hOffset = math.sin(progress * 2 * math.pi);
    final vOffset = math.cos(progress * 2 * math.pi);
    final hOffset2 = math.cos(progress * 2 * math.pi);
    final vOffset2 = math.sin(progress * 2 * math.pi);

    final blobs = [
      // (x, y, radius, color)
      (0.15 + (hOffset * 0.1), 0.2 + (vOffset * 0.1), 220.0, const Color(0xFF00B4D8)), // Cyan
      (0.8 - (hOffset2 * 0.1), 0.15 + (vOffset2 * 0.1), 200.0, const Color(0xFF1565C0)), // Blue
      (0.5 + (vOffset * 0.1), 0.5 - (hOffset * 0.1), 260.0, const Color(0xFF00C853)), // Greenish
      (0.2 - (vOffset2 * 0.1), 0.8 + (hOffset2 * 0.1), 240.0, const Color(0xFF0A2239)), // Dark bluish
      (0.9 + (hOffset * 0.15), 0.7 - (vOffset * 0.1), 180.0, const Color(0xFF132A3B)), // Midnight Blue
    ];

    for (final (x, y, size_, color) in blobs) {
      final center = Offset(x * size.width, y * size.height);
      final rect = Rect.fromCenter(center: center, width: size_ * 2, height: size_ * 2);
      
      // Pulse size slightly
      final pulsedSize = size_ * (1.0 + 0.05 * math.sin(progress * math.pi * 4));

      paint.shader = RadialGradient(
        colors: [color.withValues(alpha: 0.18), Colors.transparent], // Very subtle opacity
      ).createShader(rect);
      canvas.drawCircle(center, pulsedSize, paint);
    }
    
    // Tiny drifting spot particles overlay (spotted effect)
    final random = math.Random(42);
    paint.shader = null;
    paint.color = Colors.white.withValues(alpha: 0.15);
    for(int i = 0; i < 40; i++) {
        double sx = random.nextDouble() + (hOffset * 0.03);
        double sy = random.nextDouble() + (vOffset * 0.03);
        
        // Wrap around logic
        if (sx > 1.0) sx -= 1.0; 
        if (sx < 0.0) sx += 1.0;
        if (sy > 1.0) sy -= 1.0; 
        if (sy < 0.0) sy += 1.0;
        
        canvas.drawCircle(Offset(sx * size.width, sy * size.height), random.nextDouble() * 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DynamicPlasmaPainter oldDelegate) => oldDelegate.progress != progress;
}
