import 'package:flutter/material.dart';
import 'package:flutter_floatwing/flutter_floatwing.dart';
import 'package:flutter/scheduler.dart';
import '../widgets/vrm_avatar_widget.dart';

class AvatarOverlay extends StatefulWidget {
  final bool isFloating;
  const AvatarOverlay({super.key, this.isFloating = false});

  @override
  State<AvatarOverlay> createState() => _AvatarOverlayState();
}

class _AvatarOverlayState extends State<AvatarOverlay> {
  Window? _window;

  String _avatarFileName = 'default_avatar.vrm';
  double _speechIntensity = 0.0;
  bool _isThinking = false;
  String _gesture = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _window = Window.of(context);

      _window?.onData((source, name, data) async {
        if (data is Map<String, dynamic>) {
          setState(() {
            _speechIntensity = (data['speechIntensity'] as num?)?.toDouble() ?? 0.0;
            _isThinking = data['isThinking'] as bool? ?? false;
            _gesture = data['gesture'] as String? ?? '';
            _avatarFileName = data['avatarFileName'] as String? ?? _avatarFileName;
            _isListening = data['isListening'] as bool? ?? false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: VrmAvatarWidget(
              avatarFileName: _avatarFileName,
              isOverlay: true,
              speechIntensity: _speechIntensity,
              isThinking: _isThinking,
              gesture: _gesture,
            ),
          ),
          if (widget.isFloating)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _window?.close(),
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
          // Mic button (unchanged)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() => _isListening = !_isListening);
                  _window?.share({'isListening': _isListening});
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.redAccent.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: _isListening ? Colors.redAccent : Colors.white24, width: _isListening ? 2 : 1),
                  ),
                  child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}