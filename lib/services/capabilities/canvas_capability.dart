import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/node_frame.dart';
import 'capability_handler.dart';

/// Canvas capability — backs `canvas.navigate`, `canvas.eval`, `canvas.snapshot`
/// using a WebViewController provided by the chat screen.
///
/// The chat screen creates the controller, shows it as an overlay panel,
/// and calls [setController] so that incoming gateway commands can drive it.
///
/// If no controller has been set, commands return a friendly error telling the
/// AI that canvas is available but not yet activated on the current screen.
class CanvasCapability extends CapabilityHandler {
  CanvasCapability._();
  static final CanvasCapability instance = CanvasCapability._();
  // Keep the default constructor so existing `CanvasCapability()` call sites still compile,
  // but they all return the same singleton.
  factory CanvasCapability() => instance;

  WebViewController? _controller;
  Completer<void>? _pageLoadCompleter;

  /// Called by the chat screen once its canvas WebView controller is ready.
  void setController(WebViewController controller) {
    _controller = controller;
    // Listen for page load events so canvas.navigate can await navigation
    _controller!.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) => _pageLoadCompleter?.complete(),
      onWebResourceError: (err) =>
          _pageLoadCompleter?.completeError(err.description),
    ));
  }

  void clearController() => _controller = null;

  /// Fired whenever the canvas becomes visible/hidden. Chat screen can listen.
  static Function(bool visible)? onVisibilityChanged;

  /// Fired after canvas.snapshot so chat can attach the image to the bot reply.
  static Function(String base64, String mimeType)? onSnapshotTaken;

  @override
  String get name => 'canvas';

  @override
  List<String> get commands => ['navigate', 'eval', 'snapshot'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    if (_controller == null) {
      return NodeFrame.response('', error: {
        'code': 'CANVAS_NOT_READY',
        'message':
            'Canvas is available but not active on the current screen. '
            'The user must be on the Chat page for canvas commands to work.',
      });
    }

    switch (command) {
      case 'canvas.navigate':
        return _navigate(params);
      case 'canvas.eval':
        return _eval(params);
      case 'canvas.snapshot':
        return _snapshot(params);
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown canvas command: $command',
        });
    }
  }

  Future<NodeFrame> _navigate(Map<String, dynamic> params) async {
    final url = params['url'] as String?;
    if (url == null || url.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'canvas.navigate requires a "url" parameter.',
      });
    }
    try {
      // Show the canvas panel
      onVisibilityChanged?.call(true);

      _pageLoadCompleter = Completer<void>();
      final uri = Uri.tryParse(url);
      if (uri == null) throw Exception('Invalid URL: $url');
      await _controller!.loadRequest(uri);

      // Wait for page to finish loading (max 15 s)
      await _pageLoadCompleter!.future.timeout(const Duration(seconds: 15));
      final currentUrl = await _controller!.currentUrl();
      return NodeFrame.response('', payload: {
        'status': 'navigated',
        'url': currentUrl ?? url,
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'NAVIGATE_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _eval(Map<String, dynamic> params) async {
    final js = params['js'] as String? ?? params['code'] as String?;
    if (js == null || js.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'canvas.eval requires a "js" parameter with JavaScript code.',
      });
    }
    try {
      final result = await _controller!
          .runJavaScriptReturningResult(js)
          .timeout(const Duration(seconds: 10));
      return NodeFrame.response('', payload: {
        'result': result.toString(),
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'EVAL_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _snapshot(Map<String, dynamic> params) async {
    try {
      // Use JS canvas API to capture the page as a PNG data URL
      const captureJs = '''
        (function() {
          try {
            var canvas = document.createElement('canvas');
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
            var ctx = canvas.getContext('2d');
            // For simple pages: draw background color
            ctx.fillStyle = getComputedStyle(document.body).backgroundColor || '#ffffff';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            return canvas.toDataURL('image/png').replace('data:image/png;base64,','');
          } catch(e) { return 'ERROR:' + e.message; }
        })()
      ''';
      final result = await _controller!
          .runJavaScriptReturningResult(captureJs)
          .timeout(const Duration(seconds: 10));
      final resultStr = result.toString().replaceAll('"', '');
      if (resultStr.startsWith('ERROR:')) {
        return NodeFrame.response('', error: {
          'code': 'SNAPSHOT_ERROR',
          'message': resultStr.replaceFirst('ERROR:', '').trim(),
        });
      }
      // Notify chat screen to attach this as an image in the bot reply
      onSnapshotTaken?.call(resultStr, 'image/png');
      return NodeFrame.response('', payload: {
        'base64': resultStr,
        'mimeType': 'image/png',
        'width': await _controller!.runJavaScriptReturningResult('window.innerWidth'),
        'height': await _controller!.runJavaScriptReturningResult('window.innerHeight'),
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SNAPSHOT_ERROR',
        'message': '$e',
      });
    }
  }
}
