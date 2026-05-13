import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../app.dart';

class InstallingLogo extends StatefulWidget {
  final double size;
  const InstallingLogo({super.key, required this.size});

  @override
  State<InstallingLogo> createState() => _InstallingLogoState();
}

class _InstallingLogoState extends State<InstallingLogo> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _lightningController;
  late Animation<double> _lightningAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _blinkAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 90),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.1), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 1.0), weight: 5),
    ]).animate(_blinkController);

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _lightningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
    _lightningAnimation = Tween<double>(begin: 0, end: 1).animate(_lightningController);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _bounceController.dispose();
    _lightningController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(widget.size * 0.2),
              border: Border.all(
                color: AppColors.statusGreen.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.statusGreen.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.size * 0.2),
              child: Stack(
                children: [
                  // Circuit Background
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: CircuitPainter(isDark: isDark),
                  ),
                  
                  // Blinking Eyes
                  AnimatedBuilder(
                    animation: _blinkAnimation,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          // Left Eye
                          Positioned(
                            top: widget.size * 0.3,
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Right Eye
                          Positioned(
                            top: widget.size * 0.3,
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Mouth
                  Positioned(
                    bottom: widget.size * 0.35,
                    left: widget.size * 0.4,
                    right: widget.size * 0.4,
                    height: widget.size * 0.04,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.statusGreen.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Animated Lightning Feet
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: widget.size * 0.3,
                    child: AnimatedBuilder(
                      animation: _lightningAnimation,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Transform.rotate(
                              angle: -0.1 + (_lightningAnimation.value * 0.2),
                              child: SizedBox(
                                width: widget.size * 0.2,
                                height: widget.size * 0.2,
                                child: CustomPaint(painter: LightningBoltPainter()),
                              ),
                            ),
                            Transform.rotate(
                              angle: 0.1 - (_lightningAnimation.value * 0.2),
                              child: SizedBox(
                                width: widget.size * 0.2,
                                height: widget.size * 0.2,
                                child: CustomPaint(painter: LightningBoltPainter()),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
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
  CircuitPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.statusGreen.withOpacity(0.1)
      ..strokeWidth = 1.0;

    final path = Path();
    for (double y = size.height * 0.1; y < size.height * 0.9; y += size.height * 0.2) {
      path.moveTo(size.width * 0.1, y);
      path.lineTo(size.width * 0.9, y);
    }
    for (double x = size.width * 0.1; x < size.width * 0.9; x += size.width * 0.2) {
      path.moveTo(x, size.height * 0.1);
      path.lineTo(x, size.height * 0.9);
    }
    canvas.drawPath(path, paint);
    
    for (double x = size.width * 0.1; x < size.width * 0.9; x += size.width * 0.2) {
      for (double y = size.height * 0.1; y < size.height * 0.9; y += size.height * 0.2) {
        canvas.drawCircle(Offset(x, y), 2, paint..color = AppColors.statusGreen.withOpacity(0.2));
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class LightningBoltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.statusGreen
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.3, size.height * 0.4);
    path.lineTo(size.width * 0.7, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height);
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, Paint()
      ..color = AppColors.statusGreen.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
