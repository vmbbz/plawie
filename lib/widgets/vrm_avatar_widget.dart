import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../app.dart';
import '../services/vrm_asset_server.dart';

/// Renders a VRM 3D avatar using WebView + Three.js + @pixiv/three-vrm.
///
/// Uses a local HTTP server to serve assets (avatar_scene.html, JS modules,
/// VRM/VRMA files) because Android WebView's `flutter-assets://` scheme does
/// NOT support `fetch()` or ES module `import()` needed by Three.js.
class VrmAvatarWidget extends StatefulWidget {
  final bool isThinking;
  final double speechIntensity;
  final String avatarFileName;
  final bool isCinematic;
  final double glowIntensity;
  final String? gesture;
  final Function(String)? onLog;
  final bool isOverlay;
  final bool isPip;

  const VrmAvatarWidget({
    super.key,
    this.isThinking = false,
    this.speechIntensity = 0.0,
    this.avatarFileName = 'default_avatar.vrm',
    this.isCinematic = false,
    this.glowIntensity = 0.0,
    this.gesture,
    this.onLog,
    this.isOverlay = false,
    this.isPip = false,
  });

  @override
  State<VrmAvatarWidget> createState() => _VrmAvatarWidgetState();
}

class _VrmAvatarWidgetState extends State<VrmAvatarWidget> {
  late final WebViewController _controller;
  final VrmAssetServer _server = VrmAssetServer();
  bool _isReady = false;
  // Fallback timer: re-nudges the JS to send READY if the first attempt was
  // missed due to a PlawieBridge injection race on some Android WebView versions.
  Timer? _readyFallbackTimer;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            widget.onLog?.call('WebView Resource Error: ${error.description} (code ${error.errorCode})');
          },
        ),
      )
      ..addJavaScriptChannel(
        'PlawieBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'READY') {
            if (mounted) {
              // Cancel fallback timer — JS bridge is confirmed working
              _readyFallbackTimer?.cancel();
              setState(() => _isReady = true);
              _controller.runJavaScript("window.loadVrmAvatar('${widget.avatarFileName}');");
              _syncState();
            }
          }
          // Propagate all logs to parent
          if (widget.onLog != null) {
            widget.onLog!(message.message);
          }
        },
      )
      ..addJavaScriptChannel(
        'ConsoleLog',
        onMessageReceived: (JavaScriptMessage message) {
          widget.onLog?.call('JS → ${message.message}');
        },
      );

    // Relax Android WebView restrictions
    if (_controller.platform is AndroidWebViewController) {
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      // ignore: invalid_use_of_visible_for_testing_member
      AndroidWebViewController.enableDebugging(true);
    }

    // Start the local HTTP server, then load the HTML from it
    _startServerAndLoad();

    // Fallback: if READY isn't received within 5 s, nudge the JS to retry.
    // Handles edge cases where the PlawieBridge polling in HTML misses the window.
    _readyFallbackTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _isReady) {
        timer.cancel();
        return;
      }
      // Ask JS to re-send READY if the bridge is now available
      _controller.runJavaScript('''
        if (window.PlawieBridge && !window._readySent) {
          window._readySent = true;
          window.PlawieBridge.postMessage('READY');
        }
      ''');
    });
  }

  @override
  void dispose() {
    _readyFallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _startServerAndLoad() async {
    try {
      await _server.start();
      
      final params = <String, String>{};
      if (widget.isOverlay) params['overlay'] = 'true';
      if (widget.isPip) params['pip'] = 'true';
      
      final uri = Uri.parse('${_server.origin}/avatar_scene.html').replace(queryParameters: params);
      widget.onLog?.call('VRM Server active at ${_server.origin}');

      // Load from localhost HTTP
      _controller.loadRequest(uri);

      // Inject console bridging after a short delay to let page start loading
      Future.delayed(const Duration(milliseconds: 500), () {
        _controller.runJavaScript('''
          window.addEventListener('error', (e) => {
            if (window.ConsoleLog) ConsoleLog.postMessage('ERROR: ' + e.message + ' @ ' + e.filename + ':' + e.lineno + ':' + e.colno);
          });
          const origLog = console.log;
          const origErr = console.error;
          console.log = (...a) => { if (window.ConsoleLog) ConsoleLog.postMessage(a.map(x=>String(x)).join(' ')); origLog(...a); };
          console.error = (...a) => { if (window.ConsoleLog) ConsoleLog.postMessage('JS ERROR: '+a.map(x=>String(x)).join(' ')); origErr(...a); };
        ''');
      });
    } catch (e) {
      widget.onLog?.call('VRM Server Error: $e');
    }
  }

  @override
  void didUpdateWidget(VrmAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isReady) {
      if (oldWidget.isThinking != widget.isThinking ||
          oldWidget.speechIntensity != widget.speechIntensity ||
          oldWidget.isCinematic != widget.isCinematic ||
          oldWidget.glowIntensity != widget.glowIntensity ||
          oldWidget.isPip != widget.isPip ||
          oldWidget.avatarFileName != widget.avatarFileName) {
        if (oldWidget.avatarFileName != widget.avatarFileName) {
          _controller.runJavaScript("window.loadVrmAvatar('${widget.avatarFileName}');");
        }
        if (widget.gesture != null && widget.gesture != oldWidget.gesture) {
          _controller.runJavaScript("window.playGesture('${widget.gesture}');");
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
      if (window.setGlowIntensity) window.setGlowIntensity(${widget.glowIntensity});
      if (window.setPipMode) window.setPipMode(${widget.isPip});
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTapDown: (details) {
            if (widget.isPip) return; // Don't intercept taps in PiP to allow mic button interaction
            final x = details.localPosition.dx;
            final y = details.localPosition.dy;
            _controller.runJavaScript('if (window.setTapTarget) window.setTapTarget($x, $y);');
          },
          child: WebViewWidget(controller: _controller),
        ),
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
