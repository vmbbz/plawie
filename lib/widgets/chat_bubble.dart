// ignore_for_file: unused_import, unused_local_variable
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final isGifgrep = !isUser &&
        (message.toolEvents?.any(
                (event) => event.name.toLowerCase().contains('gifgrep')) ??
            false);
    final gifPreviewUris = isGifgrep
        ? _gifPreviewUris(message).take(1).toList(growable: false)
        : const <Uri>[];
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
            bottomRight:
                isUser ? const Radius.circular(4) : const Radius.circular(22),
            bottomLeft:
                isUser ? const Radius.circular(22) : const Radius.circular(4),
          ),
          border: Border.all(
            color: isUser
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? theme.colorScheme.primary : Colors.black)
                  .withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22).copyWith(
            bottomRight:
                isUser ? const Radius.circular(4) : const Radius.circular(22),
            bottomLeft:
                isUser ? const Radius.circular(22) : const Radius.circular(4),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.black.withValues(
                  alpha:
                      0.2), // Added a slight dark tint so text pops over bright avatars
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
                          if (message.text.isNotEmpty)
                            const SizedBox(height: 8),
                        ],
                        // gifgrep often returns a bare provider URL instead of
                        // markdown image syntax. Render the first direct media
                        // URL in the message so the result is visibly present
                        // in Plawie's chat card (not mistaken for external PiP).
                        if (isGifgrep) ...[
                          ...gifPreviewUris.map(
                            (uri) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _RemoteMediaPreview(
                                uri: uri,
                                alt: 'GIF preview',
                              ),
                            ),
                          ),
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
                              data: _compactGifLinks(message.text, isGifgrep),
                              selectable: true,
                              onTapLink: (text, href, title) {
                                final uri =
                                    href == null ? null : Uri.tryParse(href);
                                if (uri != null && uri.scheme == 'https') {
                                  unawaited(launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  ));
                                }
                              },
                              sizedImageBuilder: (config) =>
                                  _RemoteMediaPreview(
                                      uri: config.uri, alt: config.alt),
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.4),
                                h1: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                                h2: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                                h3: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                                strong: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                em: const TextStyle(
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic),
                                code: TextStyle(
                                  color: Colors.cyanAccent.shade100,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.08),
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.1)),
                                ),
                                codeblockPadding: const EdgeInsets.all(12),
                                blockquoteDecoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                        width: 3),
                                  ),
                                ),
                                listBullet:
                                    const TextStyle(color: Colors.white70),
                                a: const TextStyle(
                                    color: Colors.cyanAccent,
                                    decoration: TextDecoration.underline),
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

  static String _compactGifLinks(String text, bool isGifgrep) {
    if (!isGifgrep) return text;
    return text.replaceAllMapped(
      RegExp(r'(?<![\(\[])https://[^\s)>]+'),
      (match) => '[Play GIF](${match.group(0)})',
    );
  }

  static Iterable<Uri> _gifPreviewUris(ChatMessage message) sync* {
    final candidates = <String>[];
    for (final event in message.toolEvents ?? const <ChatToolEvent>[]) {
      final result = event.result;
      if (result == null) continue;
      // Prefer the provider's small animated preview URL. It is faster and
      // less likely to be rejected by a CDN than the full-size original.
      try {
        final decoded = jsonDecode(result);
        if (decoded is Map && decoded['results'] is List) {
          for (final item in decoded['results']!) {
            if (item is Map) {
              final preview = item['previewUrl'];
              final original = item['url'];
              if (preview is String) candidates.add(preview);
              if (original is String) candidates.add(original);
            }
          }
        }
      } catch (_) {
        // The text URL fallback below handles non-JSON tool results.
      }
      candidates.add(result);
    }
    candidates.add(message.text);

    final seen = <String>{};
    for (final source in candidates) {
      for (final match in RegExp(r'https://[^\s)>"}]+').allMatches(source)) {
        final candidate = match.group(0)!.replaceFirst(RegExp(r'[.,]+$'), '');
        final uri = Uri.tryParse(candidate);
        if (uri == null || uri.host.isEmpty || uri.scheme != 'https') continue;
        final host = uri.host.toLowerCase();
        final isGifProvider = host == 'giphy.com' ||
            host.endsWith('.giphy.com') ||
            host == 'klipy.com' ||
            host.endsWith('.klipy.com');
        if (!isGifProvider || !seen.add(uri.toString())) continue;
        yield uri;
      }
    }
  }
}

class _RemoteMediaPreview extends StatelessWidget {
  final Uri uri;
  final String? alt;

  const _RemoteMediaPreview({required this.uri, this.alt});

  void _open(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: _RemoteMediaImage(
                  uri: uri,
                  fit: BoxFit.contain,
                  errorLabel: 'Preview unavailable',
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
                child: IconButton(
                  tooltip: 'Close preview',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
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
    return GestureDetector(
      onTap: () => _open(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            _RemoteMediaImage(
              uri: uri,
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
              errorLabel: 'Preview unavailable · tap to open',
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 3),
                      Text('PLAY',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads provider media through the app-native HTTP stack, then decodes it in
/// Flutter. This keeps gifgrep previews independent from Android's direct CDN
/// image resolver and still preserves animated GIF frames in Image.memory.
class _RemoteMediaImage extends StatefulWidget {
  final Uri uri;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String errorLabel;

  const _RemoteMediaImage({
    required this.uri,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.errorLabel,
  });

  @override
  State<_RemoteMediaImage> createState() => _RemoteMediaImageState();
}

class _RemoteMediaImageState extends State<_RemoteMediaImage> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _download().timeout(const Duration(seconds: 20));
  }

  Future<Uint8List> _download() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(widget.uri).timeout(
            const Duration(seconds: 15),
          );
      request.headers.set(HttpHeaders.userAgentHeader, 'Plawie/1.0');
      final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('media HTTP ${response.statusCode}',
            uri: widget.uri);
      }
      final chunks = <int>[];
      await for (final chunk in response) {
        chunks.addAll(chunk);
        if (chunks.length > 12 * 1024 * 1024) {
          throw const FormatException('media preview exceeds 12 MB');
        }
      }
      return Uint8List.fromList(chunks);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: widget.width,
            height: widget.height ?? 190,
            color: Colors.black45,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.errorLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        if (!snapshot.hasData) {
          return SizedBox(
            width: widget.width,
            height: widget.height ?? 190,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'GIF preview',
        );
      },
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
          final pics = Directory(
              '${dir.parent.parent.parent.parent.path}/Pictures/OpenClaw');
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
                          child: Icon(Icons.download_rounded,
                              color: Colors.white, size: 24),
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
                          child: Icon(Icons.close_rounded,
                              color: Colors.white, size: 24),
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
              child: const Icon(Icons.open_in_full_rounded,
                  color: Colors.white, size: 16),
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
                  const Icon(Icons.psychology_outlined,
                      size: 14, color: Colors.white38),
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
    final color = isCall ? Colors.amber : AppColors.statusGreen;
    final icon = isCall ? Icons.build_outlined : Icons.check_circle_outline;
    final label =
        isCall ? 'Tool  ${widget.event.name}' : 'Result  ${widget.event.name}';

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
            onTap: detail != null
                ? () => setState(() => _expanded = !_expanded)
                : null,
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
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3),
                    ),
                  ),
                  if (detail != null)
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                        size: 14, color: color.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
          if (_expanded && detail != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                detail,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.7),
                    fontFamily: 'monospace',
                    height: 1.4),
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

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
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
  static final List<_Particle> _particles =
      List.generate(20, (_) => _Particle());

  NebulaPainter(this.intensity)
      : _time = DateTime.now().millisecondsSinceEpoch / 1000.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42);

    for (var particle in _particles) {
      final double x = particle.x * size.width;
      final double y = particle.y * size.height;

      // Calculate pulse/float based on time and intensity
      final double pulse =
          sin(_time * particle.speed + particle.offset) * 0.5 + 0.5;
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
