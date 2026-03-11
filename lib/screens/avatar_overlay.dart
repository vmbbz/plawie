import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../widgets/vrm_avatar_widget.dart';

import 'dart:convert';

class AvatarOverlay extends StatefulWidget {
  const AvatarOverlay({super.key});

  @override
  State<AvatarOverlay> createState() => _AvatarOverlayState();
}

class _AvatarOverlayState extends State<AvatarOverlay> {
  double _speechIntensity = 0.0;
  bool _isThinking = false;
  String? _gesture;
  String _avatarFileName = 'default_avatar.vrm';

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (!mounted) return;
      try {
        Map<String, dynamic> data = {};
        if (event is String) {
          data = jsonDecode(event);
        } else if (event is Map) {
          data = Map<String, dynamic>.from(event);
        }

        if (data.isNotEmpty) {
          setState(() {
            if (data.containsKey('speechIntensity')) {
              _speechIntensity = (data['speechIntensity'] as num).toDouble();
            }
            if (data.containsKey('isThinking')) {
              _isThinking = data['isThinking'] as bool;
            }
            if (data.containsKey('gesture')) {
              _gesture = data['gesture'] as String;
            }
            if (data.containsKey('avatarFileName')) {
              _avatarFileName = data['avatarFileName'] as String;
            }
          });
        }
      } catch (e) {
        debugPrint('Overlay Listener Error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // A completely transparent scaffold ensures the Android home screen shows through
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Render the 3D scene. isOverlay=true triggers the Head Framing zoom.
          Positioned.fill(
            child: VrmAvatarWidget(
              avatarFileName: _avatarFileName,
              isOverlay: true, 
              speechIntensity: _speechIntensity,
              isThinking: _isThinking,
              gesture: _gesture,
            ),
          ),
          // A tiny close button in the top right
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () async {
                await FlutterOverlayWindow.closeOverlay();
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
