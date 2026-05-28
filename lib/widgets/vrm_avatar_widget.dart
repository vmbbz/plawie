import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../app.dart';
import '../services/vrm_asset_server.dart';

class VrmAvatarController {
  Future<Map<String, dynamic>> Function(Map<String, dynamic> command)? _play;

  Future<Map<String, dynamic>> playGestureCommand(
      Map<String, dynamic> command) {
    final play = _play;
    if (play == null) {
      return Future.value({
        'status': 'unavailable',
        'reason': 'Avatar renderer is not attached.',
      });
    }
    return play(command);
  }

  void _attach(
      Future<Map<String, dynamic>> Function(Map<String, dynamic>) play) {
    _play = play;
  }

  void _detach(
      Future<Map<String, dynamic>> Function(Map<String, dynamic>) play) {
    if (_play == play) _play = null;
  }
}

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

  /// Agent-controlled gesture mode: 'normal' | 'expressive' | 'dance' | 'subtle'
  final String? gestureMode;
  final Function(String)? onLog;
  final Function(Map<String, dynamic>)? onGestureResult;
  final VrmAvatarController? controller;
  final Function(Offset)? onHeadUpdate;
  final bool isOverlay;
  final bool isPip;

  const VrmAvatarWidget({
    super.key,
    this.isThinking = false,
    this.speechIntensity = 0.0,
    this.avatarFileName = 'gemini.vrm',
    this.isCinematic = false,
    this.glowIntensity = 0.0,
    this.gesture,
    this.gestureMode,
    this.onLog,
    this.onGestureResult,
    this.controller,
    this.onHeadUpdate,
    this.isOverlay = false,
    this.isPip = false,
  });

  @override
  State<VrmAvatarWidget> createState() => _VrmAvatarWidgetState();
}

class _VrmAvatarWidgetState extends State<VrmAvatarWidget>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  final VrmAssetServer _server = VrmAssetServer();
  bool _isReady = false;
  int _gestureSequence = 0;
  final Map<String, Completer<Map<String, dynamic>>> _gestureCompleters = {};
  final List<Map<String, dynamic>> _deferredGestureCommands = [];
  // Fallback timer: re-nudges the JS to send READY if the first attempt was
  // missed due to a PlawieBridge injection race on some Android WebView versions.
  Timer? _readyFallbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(_playGestureCommand);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            widget.onLog?.call(
                'WebView Resource Error: ${error.description} (code ${error.errorCode})');
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
              _controller.runJavaScript(
                  "window.loadVrmAvatar('${widget.avatarFileName}');");
              _syncState();
              _flushDeferredGestureCommands();
            }
          }
          if (message.message.startsWith('GESTURE_RESULT:')) {
            _handleGestureResult(message.message.substring(15));
          }
          if (message.message.startsWith('HEAD:')) {
            final parts = message.message.split(':');
            if (parts.length == 3) {
              final x = double.tryParse(parts[1]) ?? 0.0;
              final y = double.tryParse(parts[2]) ?? 0.0;
              widget.onHeadUpdate?.call(Offset(x, y));
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
      final androidController =
          _controller.platform as AndroidWebViewController;
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
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._detach(_playGestureCommand);
    _readyFallbackTimer?.cancel();
    for (final completer in _gestureCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete({
          'status': 'failed',
          'reason': 'Avatar renderer disposed.',
        });
      }
    }
    _gestureCompleters.clear();
    unawaited(_controller
        .runJavaScript(
            'if (window.disposePlawieAvatar) window.disposePlawieAvatar();')
        .catchError((_) {}));
    unawaited(_controller.loadRequest(Uri.parse('about:blank')).catchError(
          (_) {},
        ));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final pause = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
    unawaited(_controller
        .runJavaScript(
            'if (window.setRenderPaused) window.setRenderPaused($pause);')
        .catchError((_) {}));
  }

  Future<void> _startServerAndLoad() async {
    try {
      await _server.start();

      final params = <String, String>{};
      if (widget.isOverlay) params['overlay'] = 'true';
      if (widget.isPip) params['pip'] = 'true';

      final uri = Uri.parse('${_server.origin}/avatar_scene.html')
          .replace(queryParameters: params);
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
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_playGestureCommand);
      widget.controller?._attach(_playGestureCommand);
    }
    if (!_isReady) return;

    // Gesture and gestureMode are checked independently so they always fire
    // even when no other widget property changed — the old code gated these
    // inside an unrelated if-block which silently dropped most gesture calls.
    if (widget.gesture != null && widget.gesture != oldWidget.gesture) {
      unawaited(_playGestureCommand({'gesture': widget.gesture}));
    }
    if (widget.gestureMode != null &&
        widget.gestureMode != oldWidget.gestureMode) {
      _controller
          .runJavaScript("window.setGestureMode('${widget.gestureMode}');");
    }

    if (oldWidget.avatarFileName != widget.avatarFileName) {
      _controller
          .runJavaScript("window.loadVrmAvatar('${widget.avatarFileName}');");
    }

    if (oldWidget.isThinking != widget.isThinking ||
        oldWidget.speechIntensity != widget.speechIntensity ||
        oldWidget.isCinematic != widget.isCinematic ||
        oldWidget.glowIntensity != widget.glowIntensity ||
        oldWidget.isPip != widget.isPip) {
      _syncState();
    }
  }

  void _syncState() {
    final modeJs = widget.gestureMode != null
        ? "if (window.setGestureMode) window.setGestureMode('${widget.gestureMode}');"
        : '';
    _controller.runJavaScript('''
      if (window.setThinking) window.setThinking(${widget.isThinking});
      if (window.setSpeechIntensity) window.setSpeechIntensity(${widget.speechIntensity});
      if (window.setCinematicMode) window.setCinematicMode(${widget.isCinematic});
      if (window.setGlowIntensity) window.setGlowIntensity(${widget.glowIntensity});
      if (window.setPipMode) window.setPipMode(${widget.isPip});
      $modeJs
    ''');
  }

  Future<Map<String, dynamic>> _playGestureCommand(
      Map<String, dynamic> rawCommand) {
    final command = Map<String, dynamic>.from(rawCommand);
    final id = (command['id']?.toString().trim().isNotEmpty ?? false)
        ? command['id'].toString()
        : 'gesture_${DateTime.now().millisecondsSinceEpoch}_${_gestureSequence++}';
    command['id'] = id;

    final completer = Completer<Map<String, dynamic>>();
    _gestureCompleters[id] = completer;

    if (_isReady) {
      _sendGestureCommand(command);
    } else {
      _deferredGestureCommands.add(command);
      widget.onLog?.call('GESTURE_RESULT:${jsonEncode({
            'id': id,
            'status': 'queued',
            'reason': 'Avatar WebView is still loading.',
          })}');
    }

    return completer.future;
  }

  void _flushDeferredGestureCommands() {
    if (!_isReady || _deferredGestureCommands.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_deferredGestureCommands);
    _deferredGestureCommands.clear();
    for (final command in pending) {
      _sendGestureCommand(command);
    }
  }

  void _sendGestureCommand(Map<String, dynamic> command) {
    final payload = jsonEncode(command);
    unawaited(_controller.runJavaScript('''
      if (window.playGestureCommand) {
        window.playGestureCommand($payload);
      } else if (window.playGesture) {
        window.playGesture(${jsonEncode(command['gesture']?.toString() ?? '')});
      }
    ''').catchError((e) {
      final id = command['id']?.toString();
      if (id != null) {
        _completeGesture(id, {
          'id': id,
          'status': 'failed',
          'reason': 'Failed to invoke avatar JavaScript: $e',
        });
      }
    }));
  }

  void _handleGestureResult(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) return;
      final result = Map<String, dynamic>.from(decoded);
      widget.onGestureResult?.call(result);
      final id = result['id']?.toString();
      final status = result['status']?.toString();
      if (id == null || status == 'queued') return;
      _completeGesture(id, result);
    } catch (e) {
      widget.onLog?.call('WARN: Gesture result parse failed: $e');
    }
  }

  void _completeGesture(String id, Map<String, dynamic> result) {
    final completer = _gestureCompleters.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTapDown: (details) {
            if (widget.isPip) {
              return; // Don't intercept taps in PiP to allow mic button interaction
            }
            final x = details.localPosition.dx;
            final y = details.localPosition.dy;
            _controller.runJavaScript(
                'if (window.setTapTarget) window.setTapTarget($x, $y);');
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
