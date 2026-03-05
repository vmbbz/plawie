import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../app.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isThinking;

  const ChatBubble({
    super.key,
    required this.message,
    this.isThinking = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser 
              ? theme.colorScheme.primary.withOpacity(0.15) 
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(22).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(22),
            bottomLeft: isUser ? const Radius.circular(22) : const Radius.circular(4),
          ),
          border: Border.all(
            color: isUser 
                ? theme.colorScheme.primary.withOpacity(0.3) 
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? theme.colorScheme.primary : Colors.black).withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(22),
            bottomLeft: isUser ? const Radius.circular(22) : const Radius.circular(4),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: isThinking
                  ? const _TypingIndicator()
                  : Text(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 1,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.2;
            final double value = sin((_controller.value * 2 * pi) - delay);
            final double opacity = (value + 1) / 2;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2 + (0.8 * opacity)),
                boxShadow: [
                  if (opacity > 0.8)
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

class NebulaPainter extends CustomPainter {
  final double intensity; // 0.0 to 1.0 (isThinking)
  final double _time;
  static final List<_Particle> _particles = List.generate(20, (_) => _Particle());

  NebulaPainter(this.intensity) : _time = DateTime.now().millisecondsSinceEpoch / 1000.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42);

    for (var particle in _particles) {
      final double x = particle.x * size.width;
      final double y = particle.y * size.height;
      
      // Calculate pulse/float based on time and intensity
      final double pulse = sin(_time * particle.speed + particle.offset) * 0.5 + 0.5;
      final double scale = 1.0 + (intensity * 0.5 * pulse);
      final double opacity = (0.3 + (pulse * 0.4)) * (0.5 + intensity * 0.5);

      final Rect rect = Rect.fromCenter(
        center: Offset(x, y),
        width: particle.size * scale,
        height: particle.size * scale,
      );

      final gradient = RadialGradient(
        colors: [
          particle.color.withOpacity(opacity),
          particle.color.withOpacity(0),
        ],
      ).createShader(rect);

      paint.shader = gradient;
      canvas.drawCircle(Offset(x, y), particle.size * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant NebulaPainter oldDelegate) => true;
}

class _Particle {
  final double x = Random().nextDouble();
  final double y = Random().nextDouble();
  final double size = 50.0 + Random().nextDouble() * 150.0;
  final double speed = 0.5 + Random().nextDouble() * 1.5;
  final double offset = Random().nextDouble() * pi * 2;
  final Color color = [
    Colors.blue.withOpacity(0.2),
    Colors.purple.withOpacity(0.2),
    Colors.cyan.withOpacity(0.2),
    const Color(0xFF00C853).withOpacity(0.1), // AppColors.statusGreen
  ][Random().nextInt(4)];
}
