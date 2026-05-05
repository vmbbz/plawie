import 'package:flutter/material.dart';
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
          // Avatar logo
          Center(
            child: SvgPicture.asset(
              'assets/app_icon_official.svg',
              width: widget.size * 0.7,
              height: widget.size * 0.7,
              colorFilter: const ColorFilter.mode(
                Color(0xFF00C853), // Plawie Green
                BlendMode.srcIn,
              ),
            ),
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CircuitPainter extends CustomPainter {
  final bool isDark;

  CircuitPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000)).withOpacity(0.1)
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
    // Legacy - not used
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
