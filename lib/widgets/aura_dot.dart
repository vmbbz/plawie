import 'package:flutter/material.dart';

/// Holographic orb for quick voice/persona access.
///
/// Design: a small circular core surrounded by a breathing orbit ring and
/// a soft bloom glow. Subtle at rest, cyan-lit when the avatar is speaking.
/// Tap it to open the Voice Persona modal.
class AuraDot extends StatefulWidget {
  final Offset position;
  final VoidCallback onTap;
  final bool isSpeaking;
  final Offset anchorOffset;
  final Color? statusColor;

  const AuraDot({
    super.key,
    required this.position,
    required this.onTap,
    this.isSpeaking = false,
    this.anchorOffset = const Offset(0, -50),
    this.statusColor,
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
      duration: const Duration(milliseconds: 1800),
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

    // 44×44 hit target; visually centred around the requested anchor.
    const double hitSize = 44.0;
    const double coreR = 5.0; // core dot radius
    const double ringR = 13.0; // orbit ring radius

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 80),
      left: widget.position.dx + widget.anchorOffset.dx - hitSize / 2,
      top: widget.position.dy + widget.anchorOffset.dy - hitSize / 2,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final pulse = _pulseController.value;
            final active = widget.isSpeaking || _isPressed;
            final scale = _isPressed ? 0.80 : (1.0 + 0.10 * pulse);
            final accentColor = widget.statusColor ?? Colors.cyanAccent;

            // Core colour — cyan tint when active, translucent white at rest
            final coreColor = active
                ? Color.lerp(
                    Colors.white.withValues(alpha: 0.6),
                    accentColor.withValues(alpha: 0.9),
                    pulse,
                  )!
                : (widget.statusColor ?? Colors.white).withValues(
                    alpha: widget.statusColor == null
                        ? 0.28 + 0.10 * pulse
                        : 0.58 + 0.12 * pulse);

            // Orbit ring breathes gently; brightens cyan when active
            final ringOpacity =
                active ? 0.50 + 0.28 * pulse : 0.18 + 0.08 * pulse;
            final ringColor = widget.statusColor ??
                (active ? Colors.cyanAccent : Colors.white);

            // Bloom glow
            final glowAlpha =
                active ? 0.30 + 0.22 * pulse : 0.06 + 0.05 * pulse;
            final glowColor = (widget.statusColor ??
                    (active ? Colors.cyanAccent : Colors.white))
                .withValues(alpha: glowAlpha);

            return SizedBox(
              width: hitSize,
              height: hitSize,
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    width: ringR * 2 + 8,
                    height: ringR * 2 + 8,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Bloom — soft glow behind the ring
                        Container(
                          width: ringR * 2 + 8,
                          height: ringR * 2 + 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: glowColor,
                                blurRadius: active ? 20 : 10,
                                spreadRadius: active ? 3 : 0,
                              ),
                            ],
                          ),
                        ),

                        // Orbit ring
                        Container(
                          width: ringR * 2,
                          height: ringR * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ringColor.withValues(alpha: ringOpacity),
                              width: 0.9,
                            ),
                          ),
                        ),

                        // Core orb
                        Container(
                          width: coreR * 2,
                          height: coreR * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: coreColor,
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color:
                                          accentColor.withValues(alpha: 0.55),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
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
