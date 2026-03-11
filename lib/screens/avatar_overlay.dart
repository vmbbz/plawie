import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_floatwing/flutter_floatwing.dart';
import '../widgets/vrm_avatar_widget.dart';
import 'dart:convert';

class AvatarOverlay extends StatefulWidget {
  final bool isFloating;
  const AvatarOverlay({super.key, this.isFloating = false});

  @override
  State<AvatarOverlay> createState() => _AvatarOverlayState();
}

class _AvatarOverlayState extends State<AvatarOverlay> {
  Window? _window;
  
  // State variables for synchronization
  double _speechIntensity = 0.0;
  bool _isThinking = false;
  String _gesture = "idle";
  String _avatarFileName = "default_avatar.vrm";
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the Window object is accessible via context
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _window = Window.of(context);
      
      // flutter_floatwing 0.3.1 registers data handlers via a method call, not a Stream
      _window?.onData((source, name, data) {
        if (!mounted) return null;
        _handleDataSync(data);
        return null; // Return null as we don't need to return a value to the sender
      });
    });
  }

  void _handleDataSync(dynamic event) {
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
          if (data.containsKey('isListening')) {
            _isListening = data['isListening'] as bool;
          }
        });
      }
    } catch (e) {
      debugPrint('Overlay Sync Error: $e');
    }
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
          if (widget.isFloating)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  _window?.close();
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
            
          // Interactive Microphone Button
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  // Fire action back to main isolate
                  _window?.share({'action': 'toggle_mic'});
                  // Optimistically update UI
                  setState(() => _isListening = !_isListening);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isListening 
                        ? Colors.redAccent.withValues(alpha: 0.8) 
                        : Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening ? Colors.redAccent : Colors.white24,
                      width: _isListening ? 2 : 1,
                    ),
                    boxShadow: [
                      if (_isListening)
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none, 
                    color: Colors.white, 
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
