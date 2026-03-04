import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../app.dart';

class VrmAvatarWidget extends StatefulWidget {
  final bool isThinking;
  final double speechIntensity;
  final String avatarFileName;
  final bool isCinematic;
  final Function(String)? onLog;

  const VrmAvatarWidget({
    super.key,
    this.isThinking = false,
    this.speechIntensity = 0.0,
    this.avatarFileName = 'gemini.vrm',
    this.isCinematic = false,
    this.onLog,
  });

  @override
  State<VrmAvatarWidget> createState() => _VrmAvatarWidgetState();
}

class _VrmAvatarWidgetState extends State<VrmAvatarWidget> {
  late final WebViewController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'ClawaBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'READY') {
            if (mounted) {
              setState(() => _isReady = true);
              _controller.runJavaScript("window.loadVrmAvatar('${widget.avatarFileName}');");
              _syncState();
            }
          } else if (widget.onLog != null) {
            widget.onLog!(message.message);
          }
        },
      )
      ..loadFlutterAsset('assets/vrm/avatar_scene.html');
      
    // Relax Android specific WebView file load restrictions to allow loading assets natively
    if (_controller.platform is AndroidWebViewController) {
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setAllowFileAccess(true);
      androidController.setAllowContentAccess(true);
      // Let it access its own file contents more freely
      AndroidWebViewController.enableDebugging(true);
    }
  }

  @override
  void didUpdateWidget(VrmAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isReady) {
      if (oldWidget.isThinking != widget.isThinking ||
          oldWidget.speechIntensity != widget.speechIntensity ||
          oldWidget.isCinematic != widget.isCinematic ||
          oldWidget.avatarFileName != widget.avatarFileName) {
        if (oldWidget.avatarFileName != widget.avatarFileName) {
          _controller.runJavaScript("window.loadVrmAvatar('${widget.avatarFileName}');");
        }
        _syncState();
      }
    }
  }

  void _syncState() {
    _controller.runJavaScript('''
      if (window.setThinking) window.setThinking(${widget.isThinking});
      if (window.setSpeechIntensity) window.setSpeechIntensity(${widget.speechIntensity});
      if (window.setCinematicMode) window.setCinematicMode(${widget.isCinematic});
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_isReady)
          const Center(
            child: CircularProgressIndicator(
              color: AppColors.statusGreen,
            ),
          ),
      ],
    );
  }
}
