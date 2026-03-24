import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Lightweight local HTTP server that serves Flutter assets from `assets/vrm/`.
///
/// This is needed because Android WebView's `flutter-assets://` scheme does NOT
/// support `fetch()` or ES module `import()` — only the initial HTML load works.
/// By serving from `http://127.0.0.1:PORT/`, all JS imports, VRM file loads,
/// and VRMA animation fetches work normally via standard HTTP.
class VrmAssetServer {
  static final VrmAssetServer _instance = VrmAssetServer._internal();
  factory VrmAssetServer() => _instance;
  VrmAssetServer._internal();

  HttpServer? _server;
  int? _port;

  /// The localhost URL base, e.g. `http://127.0.0.1:8234`
  String? get origin => _port != null ? 'http://127.0.0.1:$_port' : null;

  /// Start the server on a random free port.
  Future<void> start() async {
    if (_server != null) return; // Already running

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;

    _server!.listen(_handleRequest, onError: (e) {
      _server = null;
      _port = null;
    });
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Strip leading slash: "/avatar_scene.html" → "avatar_scene.html"
    var path = request.uri.path;
    if (path.startsWith('/')) path = path.substring(1);
    if (path.isEmpty) path = 'avatar_scene.html';

    // Map to Flutter asset path
    final assetPath = 'assets/vrm/$path';

    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Determine MIME type
      final mimeType = _mimeTypeFor(path);

      request.response.statusCode = 200;
      request.response.headers.set('Content-Type', mimeType);
      request.response.headers.set('Content-Length', bytes.length.toString());
      // Allow CORS for module imports
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Cache-Control', 'no-cache');
      request.response.add(bytes);
    } catch (e) {
      request.response.statusCode = 404;
      request.response.write('Not found: $assetPath');
    }

    await request.response.close();
  }

  static String _mimeTypeFor(String path) {
    if (path.endsWith('.html')) return 'text/html; charset=utf-8';
    if (path.endsWith('.js') || path.endsWith('.mjs')) return 'application/javascript; charset=utf-8';
    if (path.endsWith('.json')) return 'application/json; charset=utf-8';
    if (path.endsWith('.css')) return 'text/css; charset=utf-8';
    if (path.endsWith('.vrm')) return 'model/gltf-binary';
    if (path.endsWith('.vrma')) return 'model/gltf-binary';
    if (path.endsWith('.glb')) return 'model/gltf-binary';
    if (path.endsWith('.gltf')) return 'model/gltf+json';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.svg')) return 'image/svg+xml';
    if (path.endsWith('.wasm')) return 'application/wasm';
    return 'application/octet-stream';
  }

  /// Stop the server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }
}
