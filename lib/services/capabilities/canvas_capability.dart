import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/node_frame.dart';
import '../canvas_screenshot_channel.dart';
import '../tool_media_event_bus.dart';
import 'capability_handler.dart';

/// Canvas capability — backs `canvas.navigate`, `canvas.eval`, `canvas.snapshot`,
/// `canvas.present`, and `canvas.hide` using a WebViewController provided by the chat screen.
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
  int? _viewId;
  String? _pluginSurfaceUrl;

  static const _canvasHostPath = '/__openclaw__/canvas';
  static const _pluginCapabilityPath = '/__openclaw__/cap/';
  static const _fallbackGatewayOrigin = 'http://127.0.0.1:18789';

  /// Called by the chat screen once its canvas WebView controller is ready.
  void setController(WebViewController controller) {
    _controller = controller;
    _controller!.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (url) {
        final completer = _pageLoadCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
        if (isCanvasSurfaceUrl(url)) {
          unawaited(_centerCanvasVisual());
        }
        _blockExternalApiCalls();
      },
      onHttpError: (err) {
        final statusCode = err.response?.statusCode;
        if (statusCode == null || statusCode < 400) return;
        final completer = _pageLoadCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            'Canvas HTTP error $statusCode${statusCode == 401 ? ' (Unauthorized)' : ''}',
          );
        }
      },
      onWebResourceError: (err) {
        final completer = _pageLoadCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(err.description);
        }
      },
    ));
  }

  void clearController() => _controller = null;

  /// Node-scoped Gateway URL for protected plugin surfaces, supplied by the
  /// OpenClaw node connect handshake as `pluginSurfaceUrls.canvas`.
  void setPluginSurfaceUrl(String? url) {
    final trimmed = url?.trim() ?? '';
    _pluginSurfaceUrl = trimmed.isEmpty ? null : trimmed;
  }

  /// Block external API calls from canvas HTML content.
  Future<void> _blockExternalApiCalls() async {
    try {
      await _controller!.runJavaScript('''
        (function(){
          var origFetch = window.fetch;
          window.fetch = function(url, opts) {
            var u = (typeof url==='string')?url:(url&&url.toString())||'';
            if(u&&!u.startsWith('http://localhost')&&!u.startsWith('http://127.0.0.1')&&!u.startsWith('data:')&&!u.startsWith('blob:')&&!u.startsWith('file:')){
              throw new Error('Blocked: '+u);
            }
            return origFetch.call(this,url,opts);
          };
          var origOpen=XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open=function(m,u){
            var us=(typeof u==='string')?u:(u&&u.toString())||'';
            if(us&&!us.startsWith('http://localhost')&&!us.startsWith('http://127.0.0.1')&&!us.startsWith('data:')&&!us.startsWith('blob:')&&!us.startsWith('file:')){
              throw new Error('Blocked: '+us);
            }
            return origOpen.apply(this,arguments);
          };
        })();
      ''');
    } catch (_) {}
  }

  /// Canvas tool pages commonly contain one SVG/image/canvas as their entire
  /// body. Browser defaults place that element at (0, 0), which is correct for
  /// a document but not for a presentation surface. Apply this only to the
  /// protected local canvas surface; external navigations must retain their
  /// own layout and interaction model.
  Future<void> _centerCanvasVisual() async {
    try {
      await _controller!.runJavaScript(canvasVisualCenteringScript);
    } catch (_) {
      // Layout enhancement must never turn a successfully loaded canvas into
      // a tool error.
    }
  }

  /// Kept as a public getter so the DOM contract is covered without requiring
  /// a platform WebView in unit tests.
  String get canvasVisualCenteringScript => _canvasVisualCenteringScript;

  static const _canvasVisualCenteringScript = r'''
    (function() {
      var body = document.body;
      if (!body) return;
      var children = Array.prototype.filter.call(
        body.children,
        function(child) {
          var tag = (child.tagName || '').toLowerCase();
          return tag !== 'script' && tag !== 'style' && tag !== 'link';
        }
      );
      if (children.length !== 1) return;

      var root = children[0];
      var target = root;
      var rootTag = (root.tagName || '').toLowerCase();
      if (root.children.length === 1) {
        var nestedTag = (root.firstElementChild.tagName || '').toLowerCase();
        if (['svg', 'img', 'canvas', 'video'].indexOf(nestedTag) !== -1) {
          target = root.firstElementChild;
        }
      }
      var targetTag = (target.tagName || '').toLowerCase();
      if (['svg', 'img', 'canvas', 'video'].indexOf(targetTag) === -1) return;

      var html = document.documentElement;
      html.style.width = '100%';
      html.style.height = '100%';
      html.style.margin = '0';
      body.style.width = '100%';
      body.style.minHeight = '100vh';
      body.style.margin = '0';
      body.style.boxSizing = 'border-box';
      body.style.display = 'flex';
      body.style.alignItems = 'center';
      body.style.justifyContent = 'center';
      body.style.overflow = 'auto';
      root.style.maxWidth = '100%';
      root.style.maxHeight = '100%';
      if (rootTag === 'div') {
        root.style.display = 'flex';
        root.style.alignItems = 'center';
        root.style.justifyContent = 'center';
      }
      target.style.maxWidth = '100%';
      target.style.maxHeight = '100%';
      target.style.objectFit = 'contain';
      target.style.margin = 'auto';
    })();
  ''';

  bool isCanvasSurfaceUrl(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) return false;
    return _isCanvasPath(parsed.path) ||
        parsed.path.contains(_canvasHostPath) ||
        _isPluginScopedPath(parsed.path);
  }

  /// Set the platform view ID for PixelCopy screenshot capture.
  void setViewId(int? id) => _viewId = id;

  /// Fired whenever the canvas becomes visible/hidden. Chat screen can listen.
  static Function(bool visible)? onVisibilityChanged;

  /// Called when a canvas tool arrives before the Chat page has created its
  /// WebView. This lets Chat keep the browser overlay lazy so idle sessions
  /// do not hold an extra Android WebView/GL context all day.
  static Future<WebViewController> Function()? onActivationRequested;

  /// Optional widget capture hook registered by the chat screen (RepaintBoundary).
  static Future<Uint8List?> Function()? onCaptureScreenshot;

  @override
  String get name => 'canvas';

  @override
  List<String> get commands =>
      ['present', 'hide', 'navigate', 'eval', 'snapshot'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    if (!await _ensureControllerReady()) {
      return NodeFrame.response('', error: {
        'code': 'CANVAS_NOT_READY',
        'message': 'Canvas is available but not active on the current screen. '
            'The user must be on the Chat page for canvas commands to work.',
      });
    }

    switch (command) {
      case 'canvas.present':
        return _present(params);
      case 'canvas.hide':
        return _hide(params);
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

  Future<bool> _ensureControllerReady() async {
    if (_controller != null) return true;
    final activate = onActivationRequested;
    if (activate == null) return false;
    try {
      setController(await activate());
      return _controller != null;
    } catch (_) {
      return false;
    }
  }

  Future<NodeFrame> _present(Map<String, dynamic> params) async {
    final url = (params['url'] as String?) ?? (params['target'] as String?);
    try {
      onVisibilityChanged?.call(true);
      if (url != null && url.isNotEmpty) {
        final uri = resolveCanvasUrl(url);
        _pageLoadCompleter = Completer<void>();
        await _controller!.loadRequest(uri);
        await _pageLoadCompleter!.future.timeout(const Duration(seconds: 15));
      }
      return NodeFrame.response('', payload: {
        'ok': true,
        'status': 'presented',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'PRESENT_ERROR',
        'message': '$e',
      });
    }
  }

  Future<NodeFrame> _hide(Map<String, dynamic> params) async {
    onVisibilityChanged?.call(false);
    return NodeFrame.response('', payload: {
      'ok': true,
      'status': 'hidden',
    });
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
      final uri = resolveCanvasUrl(url);
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
    final js = params['js'] as String? ??
        params['code'] as String? ??
        params['script'] as String? ??
        params['javascript'] as String? ??
        params['expression'] as String?;
    if (js == null || js.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message':
            'canvas.eval requires a "js" parameter with JavaScript code.',
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

  Future<Uint8List?> _captureNativeWebViewScreenshot() async {
    // Try platform channel first (PixelCopy — real WebView capture)
    if (_viewId != null) {
      final bytes = await CanvasScreenshotChannel.captureScreenshot(_viewId!);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }
    // Fallback: existing RepaintBoundary hook
    final capture = onCaptureScreenshot;
    if (capture == null) return null;
    try {
      return await capture();
    } catch (_) {
      return null;
    }
  }

  Future<NodeFrame> _snapshot(Map<String, dynamic> params) async {
    try {
      final nativeBytes = await _captureNativeWebViewScreenshot();
      if (nativeBytes != null && nativeBytes.isNotEmpty) {
        final base64 = base64Encode(nativeBytes);
        ToolMediaEventBus.instance.publish(ToolMediaEvent(
          source: 'canvas.snapshot',
          base64: base64,
          mimeType: 'image/png',
        ));
        return NodeFrame.response('', payload: {
          'base64': base64,
          'mimeType': 'image/png',
          'width': await _controller!
              .runJavaScriptReturningResult('window.innerWidth'),
          'height': await _controller!
              .runJavaScriptReturningResult('window.innerHeight'),
          'attachedImage': true,
          'timestamp': DateTime.now().toIso8601String(),
          'capture': 'native-webview',
        });
      }

      const captureJs = '''
        (function() {
          try {
            var canvas = document.createElement('canvas');
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
            var ctx = canvas.getContext('2d');
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

      ToolMediaEventBus.instance.publish(ToolMediaEvent(
        source: 'canvas.snapshot',
        base64: resultStr,
        mimeType: 'image/png',
      ));
      return NodeFrame.response('', payload: {
        'base64': resultStr,
        'mimeType': 'image/png',
        'width': await _controller!
            .runJavaScriptReturningResult('window.innerWidth'),
        'height': await _controller!
            .runJavaScriptReturningResult('window.innerHeight'),
        'attachedImage': true,
        'timestamp': DateTime.now().toIso8601String(),
        'note': 'JS_FALLBACK - native WebView capture unavailable',
      });
    } catch (e) {
      return NodeFrame.response('', error: {
        'code': 'SNAPSHOT_ERROR',
        'message': '$e',
      });
    }
  }

  Uri resolveCanvasUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) {
      throw FormatException('canvas URL cannot be empty');
    }

    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid URL: $url');
    }

    if (_isPluginScopedPath(parsed.path)) {
      return _absoluteUri(parsed);
    }

    final isCanvasPath = _isCanvasPath(parsed.path);
    final isLocalGateway =
        !parsed.hasScheme || _isLoopbackGatewayHost(parsed.host);
    if (!isCanvasPath || !isLocalGateway) {
      return _absoluteUri(parsed);
    }

    final surfaceUri = _pluginSurfaceUri;
    if (surfaceUri == null) {
      throw StateError(
        'Canvas plugin surface is unavailable. Reconnect the Android node '
        'to refresh its scoped canvas URL.',
      );
    }

    final surfacePath = surfaceUri.path.replaceFirst(RegExp(r'/+$'), '');
    return surfaceUri.replace(
      path: '$surfacePath${parsed.path}',
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
    );
  }

  Uri? get _pluginSurfaceUri {
    final raw = _pluginSurfaceUrl;
    if (raw == null || raw.isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }
    if (!_isPluginScopedPath(parsed.path)) return null;
    return parsed.replace(query: null, fragment: null);
  }

  Uri _absoluteUri(Uri uri) {
    if (uri.hasScheme) return uri;
    if (uri.path.startsWith('/')) {
      return Uri.parse('$_fallbackGatewayOrigin${uri.toString()}');
    }
    return uri;
  }

  bool _isCanvasPath(String path) =>
      path == _canvasHostPath || path.startsWith('$_canvasHostPath/');

  bool _isPluginScopedPath(String path) =>
      path == _pluginCapabilityPath.replaceFirst(RegExp(r'/$'), '') ||
      path.startsWith(_pluginCapabilityPath);

  bool _isLoopbackGatewayHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == '127.0.0.1' ||
        normalized == 'localhost' ||
        normalized == '::1';
  }
}
