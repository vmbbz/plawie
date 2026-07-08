import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Lightweight local HTTP server that serves Flutter assets from `assets/vrm/`.
///
/// This is needed because Android WebView's `flutter-assets://` scheme does NOT
/// support `fetch()` or ES module `import()` — only the initial HTML load works.
/// By serving from `http://127.0.0.1:PORT/`, all JS imports, VRM file loads,
/// and VRMA animation fetches work normally via standard HTTP.
///
/// For `.vrm` requests the server first checks `<documents>/vrm_cache/` so that
/// VRMs downloaded via [VrmDownloadService] are automatically served without any
/// change to [VrmAvatarWidget] or the avatar HTML/JS layer.
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

    // Ensure default avatar is cached. gemini.vrm is no longer bundled —
    // download it on first launch so the WebView renderer doesn't 404.
    await _ensureDefaultVrmDownloaded();
  }

  Future<void> _ensureDefaultVrmDownloaded() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final cached = File('${docs.path}/vrm_cache/gemini.vrm');
      if (await cached.exists()) return;
      final url = Uri.parse(
        'https://github.com/vmbbz/plawie/releases/download/'
        'vrm-pack-v/gemini.vrm',
      );
      final request = await HttpClient().getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('[VRM] gemini.vrm download failed: HTTP ${response.statusCode}');
        return;
      }
      await cached.parent.create(recursive: true);
      await response.pipe(cached.openWrite());
      debugPrint('[VRM] gemini.vrm downloaded to cache (${await cached.length()} bytes)');
    } catch (e) {
      debugPrint('[VRM] gemini.vrm auto-download error: $e');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Strip leading slash: "/avatar_scene.html" → "avatar_scene.html"
    var path = request.uri.path;
    if (path.startsWith('/')) path = path.substring(1);
    if (path.isEmpty) path = 'avatar_scene.html';

    final mimeType = _mimeTypeFor(path);

    // For VRM files, check the local download cache first so users get their
    // downloaded cloud avatars without any changes to the WebView/JS layer.
    if (path.endsWith('.vrm')) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final local = File('${docs.path}/vrm_cache/$path');
        if (await local.exists()) {
          final bytes = await local.readAsBytes();
          request.response.statusCode = 200;
          request.response.headers.set('Content-Type', mimeType);
          request.response.headers
              .set('Content-Length', bytes.length.toString());
          request.response.headers.set('Access-Control-Allow-Origin', '*');
          request.response.headers.set('Cache-Control', 'no-cache');
          request.response.add(bytes);
          await request.response.close();
          return;
        }
      } catch (_) {}
    }

    // Fall back to bundled Flutter assets (animations and JS libs are still
    // bundled; VRM models are downloaded to vrm_cache at first use).
    try {
      final data = await rootBundle.load('assets/vrm/$path');
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      request.response.statusCode = 200;
      request.response.headers.set('Content-Type', mimeType);
      request.response.headers.set('Content-Length', bytes.length.toString());
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Cache-Control', 'no-cache');
      request.response.add(bytes);
    } catch (e) {
      request.response.statusCode = 404;
      request.response.write('Not found: assets/vrm/$path');
    }

    await request.response.close();
  }

  static String _mimeTypeFor(String path) {
    if (path.endsWith('.html')) return 'text/html; charset=utf-8';
    if (path.endsWith('.js') || path.endsWith('.mjs')) {
      return 'application/javascript; charset=utf-8';
    }
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
