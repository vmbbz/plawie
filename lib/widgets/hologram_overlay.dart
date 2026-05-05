import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/hologram_service.dart';
import '../app.dart';

/// Glassmorphic floating panel that renders Hologram payloads (images, canvas, web previews).
/// Mounts as a transparent widget in the chat Stack; becomes visible only when a payload arrives.
class HologramOverlay extends StatefulWidget {
  const HologramOverlay({super.key});

  @override
  State<HologramOverlay> createState() => _HologramOverlayState();
}

class _HologramOverlayState extends State<HologramOverlay> with SingleTickerProviderStateMixin {
  HologramPayload? _payload;
  StreamSubscription<HologramPayload?>? _sub;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  bool _fullscreen = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _sub = HologramService.instance.stream.listen((payload) {
      if (!mounted) return;
      if (payload == null) {
        _anim.reverse().then((_) { if (mounted) setState(() => _payload = null); });
      } else {
        setState(() => _payload = payload);
        _anim.forward();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _saveImage(String b64) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = base64Decode(b64);
      final dir = await getExternalStorageDirectory();
      final folder = Directory('${dir?.path ?? '/sdcard'}/OpenClaw');
      await folder.create(recursive: true);
      final file = File('${folder.path}/hologram_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path}', style: const TextStyle(fontSize: 12)),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_payload == null) return const SizedBox.shrink();

    final payload = _payload!;

    return FadeTransition(
      opacity: _fade,
      child: _fullscreen ? _buildFullscreen(payload) : _buildPanel(payload),
    );
  }

  Widget _buildPanel(HologramPayload payload) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      height: 260,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black.withValues(alpha: 0.75),
          border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.statusGreen.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              _buildContent(payload),
              _buildHeader(payload),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreen(HologramPayload payload) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.92),
        child: Stack(
          children: [
            Center(child: _buildContent(payload)),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: () => setState(() => _fullscreen = false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(HologramPayload payload) {
    if (payload.type == HologramType.image && payload.imageBase64 != null) {
      try {
        final bytes = base64Decode(payload.imageBase64!);
        return GestureDetector(
          onTap: () => setState(() => _fullscreen = !_fullscreen),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48));
      }
    }
    // Canvas / web preview — text placeholder (canvas WebView is separate overlay)
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            payload.type == HologramType.canvas ? Icons.computer : Icons.public,
            color: AppColors.statusGreen,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            payload.label ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(HologramPayload payload) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            Icon(
              payload.type == HologramType.image ? Icons.image_outlined : Icons.web,
              color: AppColors.statusGreen,
              size: 14,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                payload.label ?? _typeLabel(payload.type),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (payload.type == HologramType.image && payload.imageBase64 != null)
              GestureDetector(
                onTap: () => _saveImage(payload.imageBase64!),
                child: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54),
                      )
                    : const Icon(Icons.download_outlined, color: Colors.white54, size: 18),
              ),
            const SizedBox(width: 8),
            if (payload.type == HologramType.image)
              GestureDetector(
                onTap: () => setState(() => _fullscreen = !_fullscreen),
                child: const Icon(Icons.fullscreen, color: Colors.white54, size: 18),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: HologramService.instance.dismiss,
              child: const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(HologramType t) {
    switch (t) {
      case HologramType.image: return 'Image';
      case HologramType.canvas: return 'Canvas';
      case HologramType.webPreview: return 'Web Preview';
    }
  }
}
