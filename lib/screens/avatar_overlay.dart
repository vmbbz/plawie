import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../widgets/vrm_avatar_widget.dart';

class AvatarOverlay extends StatefulWidget {
  const AvatarOverlay({super.key});

  @override
  State<AvatarOverlay> createState() => _AvatarOverlayState();
}

class _AvatarOverlayState extends State<AvatarOverlay> {
  @override
  Widget build(BuildContext context) {
    // A completely transparent scaffold ensures the Android home screen shows through
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Render the 3D scene. isOverlay=true triggers the Head Framing zoom.
          const Positioned.fill(
            child: VrmAvatarWidget(
              avatarFileName: 'default_avatar.vrm',
              isOverlay: true, 
              speechIntensity: 0.0,
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
