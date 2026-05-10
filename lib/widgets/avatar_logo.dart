import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../app.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _flickerController;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _flickerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));

    _rotateAnimation = Tween<double>(begin: -0.03, end: 0.03).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
    ));

    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 0.8, curve: Curves.easeInOut),
    ));

    if (widget.animated) {
      _controller.repeat(reverse: true);
      _flickerController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _flickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _flickerController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Transform.scale(
            scale: _pulseAnimation.value,
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [AppColors.darkSurface, AppColors.darkSurfaceAlt, AppColors.darkBg]
                        : [const Color(0xFFF8F9FA), const Color(0xFFE8EAED), const Color(0xFFDADCE0)],
                  ),
                  borderRadius: BorderRadius.circular(widget.size * 0.2),
                  border: Border.all(
                    color: isDark 
                        ? AppColors.statusGreen.withOpacity(0.2)
                        : AppColors.lightBorder.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (widget.showGlow)
                      BoxShadow(
                        color: AppColors.statusGreen.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.size * 0.2),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CircuitPainter(
                            isDark: isDark,
                            animation: _flickerController.value,
                          ),
                        ),
                      ),
                      Center(
                        child: SvgPicture.asset(
                          'assets/app_icon_official.svg',
                          width: widget.size * 0.65,
                          height: widget.size * 0.65,
                          colorFilter: const ColorFilter.mode(
                            AppColors.statusGreen,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CircuitPainter extends CustomPainter {
  final bool isDark;
  final double animation;

  CircuitPainter({required this.isDark, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..style = PaintingStyle.fill;

    // Grid dots with random lighting (denser grid for more detail)
    for (double x = size.width * 0.1; x < size.width * 0.95; x += size.width * 0.15) {
      for (double y = size.height * 0.1; y < size.height * 0.95; y += size.height * 0.15) {
        // Pseudo-random lighting based on x, y and animation
        // Use a more complex seed to break the linear patterns
        final dotSeed = (x * 43.0 + y * 17.0 + (x * y * 0.1)) % 1.0;
        
        // Dynamic intensity based on animation and the unique seed
        final intensity = (0.5 + 0.5 * math.sin(animation * 2 * math.pi + dotSeed * 10)).clamp(0.0, 1.0);
        final isGlowing = intensity > 0.7;
        
        if (isGlowing) {
          final glowAlpha = (intensity - 0.7) / 0.3;
          dotPaint.color = AppColors.statusGreen.withValues(alpha: 0.5 * glowAlpha);
          canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
          
          final glowPaint = Paint()
            ..color = AppColors.statusGreen.withValues(alpha: 0.25 * glowAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          canvas.drawCircle(Offset(x, y), 4.5, glowPaint);
        } else {
          dotPaint.color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CircuitPainter oldDelegate) => oldDelegate.animation != animation;
}

class LightningBoltPainter extends CustomPainter {
  final bool isDark;
  final bool isLeft;

  LightningBoltPainter({required this.isDark, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    // Legacy - not used
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
