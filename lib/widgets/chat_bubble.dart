// ignore_for_file: unused_import, unused_local_variable
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
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

  /// Approximate word count for display in the Reasoning chip header.
  static int _wordCount(String text) =>
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

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
              ? theme.colorScheme.primary.withValues(alpha: 0.15) 
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(22),
            bottomLeft: isUser ? const Radius.circular(22) : const Radius.circular(4),
          ),
          border: Border.all(
            color: isUser 
                ? theme.colorScheme.primary.withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? theme.colorScheme.primary : Colors.black).withValues(alpha: 0.1),
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
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2), // Added a slight dark tint so text pops over bright avatars
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: isThinking
                  ? const _TypingIndicator()
                  : Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Collapsible Reasoning section (Qwen/DeepSeek <think> blocks) ──
                        // Shown only for assistant messages that emitted <think>…</think>
                        // reasoning tokens. Collapsed by default to keep chat clean.
                        if (!isUser && message.hasThinkContent) ...[
                          _ReasoningTile(thinkContent: message.thinkContent!),
                          const SizedBox(height: 8),
                        ],
                        // ── Tool call / result chips ──
                        if (!isUser && message.hasToolEvents) ...[
                          ...message.toolEvents!.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _ToolEventChip(event: e),
                          )),
                          const SizedBox(height: 4),
                        ],
                        // Image thumbnail shown above text when message carries an image
                        if (message.hasImage) ...[
                          _ImageThumbnail(
                            base64Data: message.imageBase64!,
                            mimeType: message.imageMimeType ?? 'image/jpeg',
                          ),
                          if (message.text.isNotEmpty) const SizedBox(height: 8),
                        ],
                        // Text / markdown content
                        if (message.text.isNotEmpty)
                          if (isUser)
                            Text(
                              message.text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                                letterSpacing: 0.2,
                              ),
                            )
                          else
                            MarkdownBody(
                              data: message.text,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                                h1: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                h3: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                em: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                                code: TextStyle(
                                  color: Colors.cyanAccent.shade100,
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                codeblockPadding: const EdgeInsets.all(12),
                                blockquoteDecoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 3),
                                  ),
                                ),
                                listBullet: const TextStyle(color: Colors.white70),
                                a: const TextStyle(color: Colors.cyanAccent, decoration: TextDecoration.underline),
                              ),
                            ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable image thumbnail. Tap → fullscreen InteractiveViewer with download button.
class _ImageThumbnail extends StatelessWidget {
  final String base64Data;
  final String mimeType;

  const _ImageThumbnail({required this.base64Data, required this.mimeType});

  Future<void> _download(BuildContext context) async {
    try {
      final bytes = base64Decode(base64Data);
      final ext = mimeType.contains('png') ? 'png' : 'jpg';
      final ts = DateTime.now().millisecondsSinceEpoch;

      // Try external Pictures first, fall back to app documents
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
        if (dir != null) {
          final pics = Directory('${dir.parent.parent.parent.parent.path}/Pictures/OpenClaw');
          await pics.create(recursive: true);
          dir = pics;
        }
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }

      final file = File('${dir!.path}/openclaw_$ts.$ext');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path.split('/').last}'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showFullscreen(BuildContext context) {
    final bytes = base64Decode(base64Data);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full-screen pinch-to-zoom image
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: Row(
                  children: [
                    // Download button
                    Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _download(ctx),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.download_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.of(ctx).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(base64Data);
    return GestureDetector(
      onTap: () => _showFullscreen(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 180,
              gaplessPlayback: true,
            ),
          ),
          // Small expand hint icon
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible "Reasoning" section shown above assistant replies when the model
/// emitted `<think>…</think>` blocks (e.g. Qwen, DeepSeek reasoning models).
/// Collapsed by default so it doesn't clutter the chat; tap to expand.
class _ReasoningTile extends StatefulWidget {
  final String thinkContent;
  const _ReasoningTile({required this.thinkContent});

  @override
  State<_ReasoningTile> createState() => _ReasoningTileState();
}

class _ReasoningTileState extends State<_ReasoningTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final wordCount = ChatBubble._wordCount(widget.thinkContent);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — always visible, tap to toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.psychology_outlined, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  Text(
                    'Reasoning  ·  $wordCount words',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.white30,
                  ),
                ],
              ),
            ),
          ),
          // Expandable body with the raw thinking text
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                widget.thinkContent.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white38,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Collapsible chip showing a tool call (amber) or tool result (green).
class _ToolEventChip extends StatefulWidget {
  final ChatToolEvent event;
  const _ToolEventChip({required this.event});

  @override
  State<_ToolEventChip> createState() => _ToolEventChipState();
}

class _ToolEventChipState extends State<_ToolEventChip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isCall = widget.event.type == 'tool_use';
    final color = isCall ? Colors.amber : Colors.greenAccent;
    final icon = isCall ? Icons.build_outlined : Icons.check_circle_outline;
    final label = isCall ? 'Tool  ${widget.event.name}' : 'Result  ${widget.event.name}';

    final detail = isCall
        ? (widget.event.input?.isNotEmpty == true
            ? const JsonEncoder.withIndent('  ').convert(widget.event.input)
            : null)
        : widget.event.result;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: detail != null ? () => setState(() => _expanded = !_expanded) : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                    ),
                  ),
                  if (detail != null)
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 14, color: color.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
          if (_expanded && detail != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                detail,
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7), fontFamily: 'monospace', height: 1.4),
              ),
            ),
        ],
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
                color: Colors.white.withValues(alpha: 0.2 + (0.8 * opacity)),
                boxShadow: [
                  if (opacity > 0.8)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
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
          particle.color.withValues(alpha: opacity),
          particle.color.withValues(alpha: 0),
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
    Colors.blue.withValues(alpha: 0.2),
    Colors.purple.withValues(alpha: 0.2),
    Colors.cyan.withValues(alpha: 0.2),
    const Color(0xFF00C853).withValues(alpha: 0.1), // AppColors.statusGreen
  ][Random().nextInt(4)];
}
