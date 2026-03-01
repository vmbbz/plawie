import 'package:flutter/material.dart';
import '../app.dart';

class AvatarLogo extends StatefulWidget {
  final double size;
  final bool animated;
  final bool showGlow;

  const AvatarLogo({
    super.key,
    this.size = 64,
    this.animated = true,
    this.showGlow = true,
  });

  @override
  State<AvatarLogo> createState() => _AvatarLogoState();
}

class _AvatarLogoState extends State<AvatarLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _blinkAnimation;
  late Animation<double> _clawAnimation;
  late Animation<double> _lightningAnimation;

  @override
  void initState() {
    super.initState();
    
    if (widget.animated) {
      _controller = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      );

      _floatAnimation = Tween<double>(
        begin: -5,
        end: 5,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(
        begin: 1.0,
        end: 1.05,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ));

      _rotateAnimation = Tween<double>(
        begin: -0.05,
        end: 0.05,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ));

      // Blinking animation - quick close, slow open (faster)
      _blinkAnimation = Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.7, curve: Curves.easeInOut),
      ));

      // Claw animation - snap open and close
      _clawAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 0.9, curve: Curves.elasticOut),
      ));

      // Lightning animation - movement and glow (faster)
      _lightningAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 0.85, curve: Curves.easeInOut),
      ));

      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    if (widget.animated) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget avatar = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.darkSurface,
                  AppColors.darkSurfaceAlt,
                  AppColors.darkBg,
                ]
              : [
                  const Color(0xFFF8F9FA),
                  const Color(0xFFE8EAED),
                  const Color(0xFFDADCE0),
                ],
        ),
        borderRadius: BorderRadius.circular(widget.size * 0.15),
        border: Border.all(
          color: isDark 
              ? AppColors.darkBorder.withOpacity(0.3)
              : AppColors.lightBorder.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          if (widget.showGlow)
            BoxShadow(
              color: AppColors.statusGreen.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: Stack(
        children: [
          // Background circuit pattern
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitPainter(isDark: isDark),
            ),
          ),
          // Avatar face
          Center(
            child: _buildAvatarFace(isDark),
          ),
        ],
      ),
    );

    if (widget.animated) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: Transform.scale(
              scale: _pulseAnimation.value,
              child: Transform.rotate(
                angle: _rotateAnimation.value,
                child: child,
              ),
            ),
          );
        },
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildAvatarFace(bool isDark) {
    return Stack(
      children: [
        // Head (make it bigger and more centered)
        Positioned(
          top: widget.size * 0.1,
          left: widget.size * 0.2,
          right: widget.size * 0.2,
          height: widget.size * 0.4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.inverseText.withOpacity(0.95),
                        AppColors.inverseText.withOpacity(0.8),
                      ]
                    : [
                        AppColors.darkBg.withOpacity(0.95),
                        AppColors.darkBg.withOpacity(0.8),
                      ],
              ),
              borderRadius: BorderRadius.circular(widget.size * 0.15),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? Colors.black.withOpacity(0.4)
                      : Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        // Blinking Eyes (make them bigger and cuter)
        AnimatedBuilder(
          animation: _blinkAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                // Left Eye
                Positioned(
                  top: widget.size * 0.22,
                  left: widget.size * 0.3,
                  width: widget.size * 0.1,
                  height: widget.size * 0.1 * _blinkAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.statusGreen.withOpacity(0.6),
                          blurRadius: 6,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Eye
                Positioned(
                  top: widget.size * 0.22,
                  right: widget.size * 0.3,
                  width: widget.size * 0.1,
                  height: widget.size * 0.1 * _blinkAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.statusGreen.withOpacity(0.6),
                          blurRadius: 6,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        // Cute mouth (smaller and higher)
        Positioned(
          bottom: widget.size * 0.4,
          left: widget.size * 0.4,
          right: widget.size * 0.4,
          height: widget.size * 0.04,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  AppColors.statusGreen.withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(widget.size * 0.02),
            ),
          ),
        ),
        // Left Lightning Bolt Foot
        Positioned(
          top: widget.size * 0.5,
          left: widget.size * 0.25,
          width: widget.size * 0.15,
          height: widget.size * 0.25,
          child: AnimatedBuilder(
            animation: _lightningAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: -0.2 + (_lightningAnimation.value * 0.1),
                child: CustomPaint(
                  painter: LightningBoltPainter(isDark: isDark, isLeft: true),
                ),
              );
            },
          ),
        ),
        // Right Lightning Bolt Foot
        Positioned(
          top: widget.size * 0.5,
          right: widget.size * 0.25,
          width: widget.size * 0.15,
          height: widget.size * 0.25,
          child: AnimatedBuilder(
            animation: _lightningAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: 0.2 - (_lightningAnimation.value * 0.1),
                child: CustomPaint(
                  painter: LightningBoltPainter(isDark: isDark, isLeft: false),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CircuitPainter extends CustomPainter {
  final bool isDark;

  CircuitPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? AppColors.inverseText : AppColors.darkBg).withOpacity(0.1)
      ..strokeWidth = 1.0;

    // Draw circuit-like patterns
    final path = Path();
    
    // Horizontal lines
    for (double y = size.height * 0.1; y < size.height * 0.9; y += size.height * 0.15) {
      path.moveTo(size.width * 0.1, y);
      path.lineTo(size.width * 0.3, y);
      path.moveTo(size.width * 0.7, y);
      path.lineTo(size.width * 0.9, y);
    }

    // Vertical lines
    for (double x = size.width * 0.1; x < size.width * 0.9; x += size.width * 0.15) {
      path.moveTo(x, size.height * 0.1);
      path.lineTo(x, size.height * 0.3);
      path.moveTo(x, size.height * 0.7);
      path.lineTo(x, size.height * 0.9);
    }

    // Dots at intersections
    for (double x = size.width * 0.1; x < size.width * 0.9; x += size.width * 0.15) {
      for (double y = size.height * 0.1; y < size.height * 0.9; y += size.height * 0.15) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LightningBoltPainter extends CustomPainter {
  final bool isDark;
  final bool isLeft;

  LightningBoltPainter({required this.isDark, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.statusGreen.withOpacity(0.9)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = AppColors.statusGreen.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Draw lightning bolt shape
    final path = Path();
    
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;
    
    // Lightning bolt shape - zigzag pattern
    path.moveTo(centerX, centerY - size.height * 0.3);
    
    // Main bolt - top to middle
    path.lineTo(centerX - size.width * 0.15, centerY);
    path.lineTo(centerX + size.width * 0.1, centerY + size.height * 0.1);
    path.lineTo(centerX - size.width * 0.1, centerY + size.height * 0.3);
    
    // Bottom point
    path.lineTo(centerX, centerY + size.height * 0.4);
    
    // Close the path for fill
    path.lineTo(centerX + size.width * 0.05, centerY + size.height * 0.3);
    path.lineTo(centerX - size.width * 0.05, centerY + size.height * 0.1);
    path.lineTo(centerX + size.width * 0.15, centerY);
    path.close();
    
    // Draw the lightning bolt
    canvas.drawPath(path, paint);
    canvas.drawPath(path, fillPaint);
    
    // Add glow effect
    final glowPaint = Paint()
      ..color = AppColors.statusGreen.withOpacity(0.4)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawPath(path, glowPaint);
    
    // Add inner detail lines for more detail
    final detailPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    // Inner lightning detail
    final detailPath = Path();
    detailPath.moveTo(centerX, centerY - size.height * 0.2);
    detailPath.lineTo(centerX - size.width * 0.08, centerY + size.height * 0.05);
    detailPath.lineTo(centerX + size.width * 0.05, centerY + size.height * 0.15);
    detailPath.lineTo(centerX, centerY + size.height * 0.25);
    
    canvas.drawPath(detailPath, detailPaint);
    
    // Add small electric sparks
    final sparkPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    // Small sparks around the bolt
    canvas.drawCircle(
      Offset(centerX - size.width * 0.2, centerY - size.height * 0.1),
      size.width * 0.03,
      sparkPaint,
    );
    canvas.drawCircle(
      Offset(centerX + size.width * 0.2, centerY + size.height * 0.1),
      size.width * 0.03,
      sparkPaint,
    );
    canvas.drawCircle(
      Offset(centerX - size.width * 0.15, centerY + size.height * 0.35),
      size.width * 0.02,
      sparkPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
