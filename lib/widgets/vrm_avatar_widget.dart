import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app.dart';

class VrmAvatarWidget extends StatefulWidget {
  final bool isThinking;
  final double speechIntensity;
  final String modelFileName;
  final bool isCinematic;

  const VrmAvatarWidget({
    super.key,
    this.isThinking = false,
    this.speechIntensity = 0.0,
    this.modelFileName = 'gemini.vrm',
    this.isCinematic = false,
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
              _controller.runJavaScript("window.loadVrmModel('${widget.modelFileName}');");
              _syncState();
            }
          }
        },
      )
      ..loadFlutterAsset('assets/vrm/avatar_scene.html');

  @override
  void didUpdateWidget(VrmAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isReady) {
      if (oldWidget.isThinking != widget.isThinking ||
          oldWidget.speechIntensity != widget.speechIntensity ||
          oldWidget.isCinematic != widget.isCinematic ||
          oldWidget.modelFileName != widget.modelFileName) {
        if (oldWidget.modelFileName != widget.modelFileName) {
          _controller.runJavaScript("window.loadVrmModel('${widget.modelFileName}');");
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
