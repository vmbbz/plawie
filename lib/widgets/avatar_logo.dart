import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import '../app.dart';

class AvatarLogo extends StatefulWidget {
  final double size;
  final bool animated;
  final bool showGlow;
  final bool isGatewayRunning;
  final bool isInstalling;

  const AvatarLogo({
    super.key,
    this.size = 64,
    this.animated = true,
    this.showGlow = true,
    this.isGatewayRunning = true,
    this.isInstalling = false,
  });

  @override
  State<AvatarLogo> createState() => _AvatarLogoState();
}

class _AvatarLogoState extends State<AvatarLogo> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _flickerController;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

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

    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));

    _rotateAnimation =
        Tween<double>(begin: -0.03, end: 0.03).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
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

    // Mode selection:
    // - If gateway is running OR user is installing, show the high-fidelity Green SVG with light effects.
    // - Otherwise (Initial state), show the premium PNG logo.
    final showSvg = widget.isGatewayRunning || widget.isInstalling;

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
                        ? [
                            AppColors.darkSurface,
                            AppColors.darkSurfaceAlt,
                            AppColors.darkBg
                          ]
                        : [
                            const Color(0xFFF8F9FA),
                            const Color(0xFFE8EAED),
                            const Color(0xFFDADCE0)
                          ],
                  ),
                  borderRadius: BorderRadius.circular(widget.size * 0.2),
                  border: Border.all(
                    color: isDark
                        ? AppColors.statusGreen
                            .withValues(alpha: showSvg ? 0.25 : 0.1)
                        : AppColors.lightBorder.withValues(alpha: 0.3),
                    width: showSvg ? 1.5 : 1,
                  ),
                  boxShadow: [
                    if (widget.showGlow)
                      BoxShadow(
                        color: AppColors.statusGreen
                            .withValues(alpha: showSvg ? 0.35 : 0.15),
                        blurRadius: showSvg ? 40 : 25,
                        spreadRadius: showSvg ? 6 : 2,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.size * 0.2),
                  child: Stack(
                    children: [
                      if (showSvg)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CircuitPainter(
                              isDark: isDark,
                              animation: _flickerController.value,
                            ),
                          ),
                        ),
                      Center(
                        child: showSvg
                            ? SvgPicture.asset(
                                'assets/app_icon_official.svg',
                                width: widget.size * 0.65,
                                height: widget.size * 0.65,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.statusGreen,
                                  BlendMode.srcIn,
                                ),
                              )
                            : Transform.scale(
                                scale:
                                    1.5, // Keep the zoomed high-fidelity PNG look
                                child: Image.asset(
                                  'assets/ic_launcher.png',
                                  width: widget.size,
                                  height: widget.size,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
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

    for (double x = size.width * 0.1;
        x < size.width * 0.95;
        x += size.width * 0.15) {
      for (double y = size.height * 0.1;
          y < size.height * 0.95;
          y += size.height * 0.15) {
        final dotSeed = (x * 43.0 + y * 17.0 + (x * y * 0.1)) % 1.0;
        final intensity =
            (0.5 + 0.5 * math.sin(animation * 2 * math.pi + dotSeed * 10))
                .clamp(0.0, 1.0);
        final isGlowing = intensity > 0.7;

        if (isGlowing) {
          final glowAlpha = (intensity - 0.7) / 0.3;
          dotPaint.color =
              AppColors.statusGreen.withValues(alpha: 0.5 * glowAlpha);
          canvas.drawCircle(Offset(x, y), 2.2, dotPaint);

          final glowPaint = Paint()
            ..color = AppColors.statusGreen.withValues(alpha: 0.25 * glowAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
          canvas.drawCircle(Offset(x, y), 4.5, glowPaint);
        } else {
          dotPaint.color =
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CircuitPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
