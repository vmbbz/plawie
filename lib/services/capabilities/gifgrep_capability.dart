import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';
import 'native_env.dart';
import '../gifgrep_contract.dart';
import '../tool_media_event_bus.dart';

typedef GifgrepCredentialsProvider = Future<Map<String, String?>> Function();

typedef GifgrepRunner = Future<NativeManagedCliRunResult> Function(
  String binName,
  List<String> args, {
  required Map<String, String> env,
  required int timeoutSeconds,
});

typedef GifgrepFilesDirProvider = Future<String> Function();

typedef GifgrepLocalRenderer = Future<Map<String, dynamic>> Function(
  Uint8List bytes, {
  required String action,
  required int atMs,
  required int frames,
  required int cols,
});

typedef GifgrepProviderSearch = Future<List<Map<String, dynamic>>> Function(
  String source,
  String query,
  int limit,
  Map<String, String> env,
);

/// Bounded app-native execution adapter for the managed Android gifgrep binary.
///
/// Android cannot execute downloaded app-data ELF files through a normal shell.
/// [NativeBridge.runManagedCli] launches the verified binary through linker64,
/// keeping online search native-first without PRoot, Go, Homebrew, or node-pty.
/// The upstream 0.3.0 CLI only implements search despite its skill document
/// advertising still/sheet commands, so those local operations are rendered
/// in a bounded Dart isolate from app-owned GIF files.
class GifgrepCapability extends CapabilityHandler {
  GifgrepCapability({
    GifgrepCredentialsProvider? credentialsProvider,
    GifgrepRunner? runner,
    GifgrepFilesDirProvider? filesDirProvider,
    GifgrepLocalRenderer? localRenderer,
    GifgrepProviderSearch? providerSearch,
    bool useNativeProviderSearch = true,
  })  : _credentialsProvider = credentialsProvider ?? _readGifgrepCredentials,
        _runner = runner ?? NativeBridge.runManagedCli,
        _filesDirProvider = filesDirProvider ?? NativeBridge.getFilesDir,
        _localRenderer = localRenderer ?? _renderGifLocally,
        _providerSearch = providerSearch ?? _fetchProviderSearch,
        _useNativeProviderSearch = useNativeProviderSearch;

  final GifgrepCredentialsProvider _credentialsProvider;
  final GifgrepRunner _runner;
  final GifgrepFilesDirProvider _filesDirProvider;
  final GifgrepLocalRenderer _localRenderer;
  final GifgrepProviderSearch _providerSearch;
  final bool _useNativeProviderSearch;

  static const int _maxInputBytes = 20 * 1024 * 1024;

  @override
  String get name => 'gifgrep';

  @override
  List<String> get commands => GifgrepContract.actions;

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command);
    if (!commands.map((action) => 'gifgrep.$action').contains(canonical)) {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown gifgrep command: $command',
      });
    }

    try {
      return switch (canonical) {
        'gifgrep.status' => _runStatus(),
        'gifgrep.search' => _runSearch(params),
        'gifgrep.still' => _runLocalImage('still', params),
        'gifgrep.sheet' => _runLocalImage('sheet', params),
        _ => throw StateError('Unreachable gifgrep command: $canonical'),
      };
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_TIMEOUT',
        'message': 'gifgrep timed out after 25 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<NodeFrame> _runStatus() async {
    final result = await _runner(
      'gifgrep',
      const ['--version'],
      env: const {},
      timeoutSeconds: 10,
    );
    if (!result.ok) return _failure(result, const ['--version']);
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-gifgrep-cli',
      'ready': true,
      'status': 'READY',
      'version': result.stdout.trim(),
      'searchConfiguration': 'optional_provider_key',
      'localOperations': const ['still', 'sheet'],
      'localOperationsRuntime': 'app-native-dart-gif',
    });
  }

  Future<NodeFrame> _runSearch(Map<String, dynamic> params) async {
    final query = (params['query'] ?? params['text'])
        ?.toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (query == null || query.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_QUERY_REQUIRED',
        'message': 'gifgrep.search requires a query.',
      });
    }
    if (query.length > 160) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_QUERY_TOO_LONG',
        'message': 'gifgrep.search queries are limited to 160 characters.',
      });
    }

    final credentials = await _credentialsProvider();
    final giphyKey = credentials['GIPHY_API_KEY']?.trim();
    final klipyKey = credentials['KLIPY_API_KEY']?.trim();
    final requestedSource =
        params['source']?.toString().trim().toLowerCase() ?? 'auto';
    if (!const {'auto', 'giphy', 'klipy', 'tenor'}.contains(requestedSource)) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_SOURCE_INVALID',
        'message': 'gifgrep source must be auto, giphy, klipy, or tenor.',
      });
    }

    final source = switch (requestedSource) {
      'auto' when giphyKey?.isNotEmpty == true => 'giphy',
      'auto' when klipyKey?.isNotEmpty == true => 'klipy',
      _ => requestedSource,
    };
    final sourceConfigured = switch (source) {
      'giphy' => giphyKey?.isNotEmpty == true,
      'klipy' || 'tenor' => klipyKey?.isNotEmpty == true,
      _ => false,
    };
    if (!sourceConfigured) {
      final requiredKey = source == 'giphy'
          ? 'GIPHY_API_KEY'
          : source == 'auto'
              ? 'GIPHY_API_KEY or KLIPY_API_KEY'
              : 'KLIPY_API_KEY';
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_PROVIDER_CONFIG_REQUIRED',
        'message':
            'gifgrep is installed and ready. Online search requires $requiredKey in the Native OpenClaw environment; no reinstall is needed.',
        'runtimeReady': true,
        'installationRequired': false,
      });
    }

    final maxResults =
        _intValue(params['max'] ?? params['limit'], fallback: 5).clamp(1, 10);
    final env = <String, String>{
      if (giphyKey?.isNotEmpty == true) 'GIPHY_API_KEY': giphyKey!,
      if (klipyKey?.isNotEmpty == true) 'KLIPY_API_KEY': klipyKey!,
    };
    final startedAt = DateTime.now();
    late final List<Map<String, dynamic>> results;
    if (_useNativeProviderSearch) {
      try {
        results = await _providerSearch(source, query, maxResults, env)
            .timeout(const Duration(seconds: 15));
      } on TimeoutException {
        return NodeFrame.response('', error: {
          'code': 'GIFGREP_TIMEOUT',
          'message':
              'gifgrep $source provider request timed out after 15 seconds.',
        });
      } catch (error) {
        final detail = _redactSensitiveText(error.toString(), env.values);
        debugPrint('[GIFGREP] $source provider request failed detail=$detail');
        return NodeFrame.response('', error: {
          'code': 'GIFGREP_PROVIDER_ERROR',
          'message': 'gifgrep $source provider request failed.',
          if (detail.isNotEmpty) 'detail': detail,
        });
      }
    } else {
      final args = [
        'search',
        query,
        '--json',
        '--source',
        source,
        '--max',
        '$maxResults',
      ];
      final result = await _runner(
        'gifgrep',
        args,
        env: env,
        timeoutSeconds: 25,
      );
      if (!result.ok) {
        return _failure(result, args, sensitiveValues: env.values);
      }
      final decoded = jsonDecode(result.stdout);
      if (decoded is! List) {
        return NodeFrame.response('', error: {
          'code': 'GIFGREP_INVALID_OUTPUT',
          'message': 'gifgrep returned an unexpected search response.',
        });
      }
      results = decoded
          .whereType<Map>()
          .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
          .take(maxResults)
          .toList(growable: false);
    }
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-gifgrep-cli',
      'ready': true,
      'status': 'READY',
      'query': query,
      'source': source,
      'count': results.length,
      'results': results,
      'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
    });
  }

  static Future<List<Map<String, dynamic>>> _fetchProviderSearch(
    String source,
    String query,
    int limit,
    Map<String, String> env,
  ) async {
    final normalized = source == 'tenor' ? 'klipy' : source;
    final key = env[normalized == 'giphy' ? 'GIPHY_API_KEY' : 'KLIPY_API_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError(
          'missing ${normalized == 'giphy' ? 'GIPHY_API_KEY' : 'KLIPY_API_KEY'}');
    }

    final uri = normalized == 'giphy'
        ? Uri.https('api.giphy.com', '/v1/gifs/search', {
            'q': query,
            'api_key': key,
            'limit': '$limit',
            'rating': 'g',
          })
        : Uri.https('api.klipy.com', '/v2/search', {
            'q': query,
            'key': key,
            'limit': '$limit',
            'contentfilter': 'low',
            'media_filter': 'gif,tinygif,mediumgif,nanogif,preview',
          });
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'gifgrep';
    try {
      final request = await client.getUrl(uri);
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final decoded = jsonDecode(body);
      return normalized == 'giphy'
          ? _parseGiphyResults(decoded)
          : _parseKlipyResults(decoded);
    } finally {
      client.close(force: true);
    }
  }

  static List<Map<String, dynamic>> _parseGiphyResults(Object? decoded) {
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) {
      throw const FormatException('GIPHY returned invalid data.');
    }
    return data
        .whereType<Map>()
        .map((raw) {
          final images = raw['images'];
          final original = images is Map ? images['original'] : null;
          final fixed = images is Map ? images['fixed_width_small'] : null;
          final preview = images is Map ? images['preview_gif'] : null;
          final originalMap =
              original is Map ? original : const <Object?, Object?>{};
          final fixedMap = fixed is Map ? fixed : const <Object?, Object?>{};
          final previewMap =
              preview is Map ? preview : const <Object?, Object?>{};
          final url = originalMap['url']?.toString() ?? '';
          if (url.isEmpty) return null;
          return <String, dynamic>{
            'id': raw['id']?.toString() ?? '',
            'title': raw['title']?.toString() ?? raw['id']?.toString() ?? '',
            'url': url,
            'previewUrl':
                (fixedMap['url'] ?? previewMap['url'] ?? url).toString(),
            'width': _parseProviderInt(originalMap['width']),
            'height': _parseProviderInt(originalMap['height']),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _parseKlipyResults(Object? decoded) {
    final data = decoded is Map ? decoded['results'] : null;
    if (data is! List) {
      throw const FormatException('Klipy returned invalid results.');
    }
    return data
        .whereType<Map>()
        .map((raw) {
          final formats = raw['media_formats'];
          if (formats is! Map) return null;
          Map? media;
          for (final name in const [
            'gif',
            'mediumgif',
            'tinygif',
            'nanogif',
            'preview'
          ]) {
            final candidate = formats[name];
            if (candidate is Map &&
                candidate['url']?.toString().isNotEmpty == true) {
              media = candidate;
              break;
            }
          }
          if (media == null) return null;
          final dims = media['dims'];
          return <String, dynamic>{
            'id': raw['id']?.toString() ?? '',
            'title': raw['title']?.toString() ??
                raw['content_description']?.toString() ??
                raw['id']?.toString() ??
                '',
            'url': media['url'].toString(),
            'previewUrl': media['url'].toString(),
            'tags': raw['tags'],
            'width': dims is List && dims.isNotEmpty
                ? _parseProviderInt(dims[0])
                : 0,
            'height': dims is List && dims.length > 1
                ? _parseProviderInt(dims[1])
                : 0,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static int _parseProviderInt(Object? value) =>
      int.tryParse(value?.toString() ?? '') ?? 0;

  Future<NodeFrame> _runLocalImage(
    String action,
    Map<String, dynamic> params,
  ) async {
    final rawInput = (params['inputPath'] ??
            params['mediaPath'] ??
            params['path'] ??
            params['gif'])
        ?.toString();
    if (rawInput == null || rawInput.trim().isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_INPUT_REQUIRED',
        'message': 'gifgrep.$action requires inputPath.',
      });
    }

    final filesDir = await _filesDirProvider();
    final nativeHome =
        path.join(filesDir, 'native-node-embedded', 'native-home');
    final input = await _resolveExistingAppFile(
      rawInput,
      filesDir: filesDir,
      nativeHome: nativeHome,
    );
    if (input == null) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_INPUT_INVALID',
        'message':
            'gifgrep input must be an existing file inside the app-owned files directory.',
      });
    }

    final outputDir =
        Directory(path.join(nativeHome, '.openclaw', 'canvas', 'gifgrep'));
    await outputDir.create(recursive: true);
    final requestedOutput = params['outputPath']?.toString().trim();
    final output = requestedOutput?.isNotEmpty == true
        ? _resolveAppOutput(
            requestedOutput!,
            filesDir: filesDir,
            nativeHome: nativeHome,
          )
        : path.join(
            outputDir.path,
            '$action-${DateTime.now().microsecondsSinceEpoch}.png',
          );
    if (output == null) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_OUTPUT_INVALID',
        'message':
            'gifgrep output must stay inside the app-owned files directory.',
      });
    }
    await Directory(path.dirname(output)).create(recursive: true);

    final inputFile = File(input);
    final inputBytes = await inputFile.length();
    if (inputBytes > _maxInputBytes) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_INPUT_TOO_LARGE',
        'message': 'Local GIF operations are limited to 20 MB inputs.',
        'inputBytes': inputBytes,
      });
    }

    final requestedFrames =
        _intValue(params['frames'], fallback: 12).clamp(1, 24);
    final requestedCols = _intValue(params['cols'], fallback: 4).clamp(1, 8);
    final rawAtMs = params['atMs'];
    final atMs = rawAtMs is num
        ? rawAtMs.toInt().clamp(0, 10 * 60 * 1000).toInt()
        : _durationMs(params['at']?.toString());
    late final Map<String, dynamic> rendered;
    try {
      rendered = await _localRenderer(
        await inputFile.readAsBytes(),
        action: action,
        atMs: atMs,
        frames: requestedFrames,
        cols: requestedCols,
      ).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_TIMEOUT',
        'message': 'Local GIF rendering timed out after 25 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_LOCAL_RENDER_ERROR',
        'message': error.toString(),
      });
    }

    final pngBytes = rendered['pngBytes'];
    if (pngBytes is! Uint8List || pngBytes.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_INVALID_OUTPUT',
        'message': 'Local GIF rendering did not produce a valid PNG payload.',
      });
    }

    final outputFile = File(output);
    await outputFile.writeAsBytes(pngBytes, flush: true);
    if (!await outputFile.exists()) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_OUTPUT_MISSING',
        'message': 'Local GIF rendering completed without the expected PNG.',
      });
    }
    final base64 = base64Encode(pngBytes);
    ToolMediaEventBus.instance.publish(ToolMediaEvent(
      source: 'gifgrep.$action',
      base64: base64,
      mimeType: 'image/png',
    ));
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-dart-gif',
      'ready': true,
      'status': 'READY',
      'action': action,
      'inputPath': input,
      'outputPath': output,
      'mimeType': 'image/png',
      'base64': base64,
      'base64Bytes': base64.length,
      'attachedImage': true,
      'bytes': await outputFile.length(),
      'sourceFrames': rendered['sourceFrames'],
      'renderedFrames': rendered['renderedFrames'],
      if (action == 'still') 'atMs': atMs,
      if (action == 'sheet') ...{
        'requestedFrames': requestedFrames,
        'columns': requestedCols,
      },
    });
  }

  NodeFrame _failure(
    NativeManagedCliRunResult result,
    List<String> args, {
    Iterable<String> sensitiveValues = const <String>[],
  }) {
    final rawStderr = result.stderr.trim().isEmpty
        ? result.stdout.trim()
        : result.stderr.trim();
    final stderr = _redactSensitiveText(rawStderr, sensitiveValues);
    return NodeFrame.response('', error: {
      'code': result.exitCode == 124
          ? 'GIFGREP_TIMEOUT'
          : 'GIFGREP_EXIT_${result.exitCode}',
      'message':
          'gifgrep ${args.first} failed with exit code ${result.exitCode}.',
      'exitCode': result.exitCode,
      if (stderr.isNotEmpty) 'stderr': stderr,
    });
  }

  /// Native CLI failures can echo the provider URL, including its query
  /// string. Never return a configured provider secret to the Gateway/agent
  /// stream or chat UI, even when the failure comes from a third-party binary.
  static String _redactSensitiveText(
    String value,
    Iterable<String> sensitiveValues,
  ) {
    var sanitized = value;
    for (final secret in sensitiveValues) {
      final trimmed = secret.trim();
      if (trimmed.isNotEmpty) {
        sanitized = sanitized.replaceAll(trimmed, '<redacted>');
      }
    }
    // Also cover provider errors that reconstruct a URL or expose a secret
    // through a key-like query parameter without preserving the exact env
    // value in the same error string.
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        r'((?:api[_-]?key|access[_-]?token|auth[_-]?token|token)=)([^&\s"}]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}<redacted>',
    );
    return sanitized;
  }

  static Future<Map<String, String?>> _readGifgrepCredentials() async => {
        'GIPHY_API_KEY': await NativeEnv.readFirst(const ['GIPHY_API_KEY']),
        'KLIPY_API_KEY': await NativeEnv.readFirst(const ['KLIPY_API_KEY']),
      };

  static String _canonicalCommand(String command) {
    final normalized =
        command.trim().toLowerCase().replaceAll('_', '.').replaceAll(' ', '.');
    if (normalized == 'gifgrep') return 'gifgrep.status';
    if (normalized.startsWith('gifgrep.')) return normalized;
    return 'gifgrep.$normalized';
  }

  static int _intValue(Object? value, {required int fallback}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  static int _durationMs(String? value) {
    final candidate = value?.trim().toLowerCase() ?? '0s';
    final match =
        RegExp(r'^(\d+(?:\.\d{1,3})?)(ms|s|m)$').firstMatch(candidate);
    if (match == null) return 0;
    final amount = double.tryParse(match.group(1)!) ?? 0;
    final multiplier = switch (match.group(2)) {
      'm' => 60000,
      's' => 1000,
      _ => 1,
    };
    return (amount * multiplier).round().clamp(0, 10 * 60 * 1000);
  }

  static Future<String?> _resolveExistingAppFile(
    String raw, {
    required String filesDir,
    required String nativeHome,
  }) async {
    final expanded = _expandPath(raw, nativeHome);
    final file = File(expanded);
    if (!await file.exists()) return null;
    final canonicalRoot = await Directory(filesDir).resolveSymbolicLinks();
    final canonical = await file.resolveSymbolicLinks();
    return path.isWithin(canonicalRoot, canonical) ? canonical : null;
  }

  static String? _resolveAppOutput(
    String raw, {
    required String filesDir,
    required String nativeHome,
  }) {
    final canonicalRoot = path.normalize(path.absolute(filesDir));
    final output = path.normalize(path.absolute(_expandPath(raw, nativeHome)));
    return path.isWithin(canonicalRoot, output) ? output : null;
  }

  static String _expandPath(String raw, String nativeHome) {
    final value = raw.trim();
    if (value == '~') return nativeHome;
    if (value.startsWith('~/')) {
      return path.join(nativeHome, value.substring(2));
    }
    return path.isAbsolute(value) ? value : path.join(nativeHome, value);
  }
}

Future<Map<String, dynamic>> _renderGifLocally(
  Uint8List bytes, {
  required String action,
  required int atMs,
  required int frames,
  required int cols,
}) {
  return compute(_renderGifPayload, <String, dynamic>{
    'bytes': bytes,
    'action': action,
    'atMs': atMs,
    'frames': frames,
    'cols': cols,
  });
}

@visibleForTesting
Map<String, dynamic> renderGifPayloadForTesting(Map<String, dynamic> payload) =>
    _renderGifPayload(payload);

Map<String, dynamic> _renderGifPayload(Map<String, dynamic> payload) {
  final bytes = payload['bytes'];
  if (bytes is! Uint8List || bytes.isEmpty) {
    throw const FormatException('Input is not a GIF payload.');
  }
  final action = payload['action']?.toString();
  if (action != 'still' && action != 'sheet') {
    throw ArgumentError.value(action, 'action', 'must be still or sheet');
  }

  final decoder = image.GifDecoder();
  final info = decoder.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) {
    throw const FormatException('Input is not a valid GIF image.');
  }
  if (info.width > 4096 || info.height > 4096) {
    throw const FormatException('GIF dimensions exceed the 4096px limit.');
  }
  if (info.numFrames <= 0 || info.numFrames > 300) {
    throw const FormatException('GIF frame count must be between 1 and 300.');
  }
  final decodePixels = info.width * info.height * info.numFrames;
  if (decodePixels > 24000000) {
    throw const FormatException(
      'GIF decode workload exceeds the 24-million-pixel safety limit.',
    );
  }

  final decoded = decoder.decode(bytes);
  if (decoded == null || decoded.numFrames == 0) {
    throw const FormatException('GIF frames could not be decoded.');
  }

  if (action == 'still') {
    final requestedAtMs = (payload['atMs'] as num?)?.toInt() ?? 0;
    var elapsedMs = 0;
    var selectedIndex = decoded.numFrames - 1;
    for (var index = 0; index < decoded.numFrames; index++) {
      final frame = decoded.getFrame(index);
      final durationMs = frame.frameDuration > 0 ? frame.frameDuration : 100;
      if (requestedAtMs < elapsedMs + durationMs) {
        selectedIndex = index;
        break;
      }
      elapsedMs += durationMs;
    }
    final still =
        image.Image.from(decoded.getFrame(selectedIndex), noAnimation: true);
    return <String, dynamic>{
      'pngBytes': image.encodePng(still),
      'sourceFrames': decoded.numFrames,
      'renderedFrames': 1,
      'selectedFrame': selectedIndex,
    };
  }

  final requestedFrames =
      ((payload['frames'] as num?)?.toInt() ?? 12).clamp(1, 24);
  final columns =
      ((payload['cols'] as num?)?.toInt() ?? 4).clamp(1, requestedFrames);
  final sampleCount = requestedFrames.clamp(1, decoded.numFrames);
  final indices = <int>[];
  for (var sample = 0; sample < sampleCount; sample++) {
    final index = sampleCount == 1
        ? 0
        : ((decoded.numFrames - 1) * sample / (sampleCount - 1)).round();
    if (indices.isEmpty || indices.last != index) indices.add(index);
  }

  final cellWidth = info.width.clamp(1, 320);
  final cellHeight =
      (cellWidth * info.height / info.width).round().clamp(1, 320);
  const padding = 4;
  final rows = (indices.length / columns).ceil();
  final sheet = image.Image(
    width: columns * cellWidth + (columns + 1) * padding,
    height: rows * cellHeight + (rows + 1) * padding,
    numChannels: 4,
  );
  image.fill(
    sheet,
    color: image.ColorRgba8(16, 20, 24, 255),
  );
  for (var sample = 0; sample < indices.length; sample++) {
    final source = image.Image.from(
      decoded.getFrame(indices[sample]),
      noAnimation: true,
    );
    final frame = image.copyResize(
      source,
      width: cellWidth,
      height: cellHeight,
    );
    final column = sample % columns;
    final row = sample ~/ columns;
    image.compositeImage(
      sheet,
      frame,
      dstX: padding + column * (cellWidth + padding),
      dstY: padding + row * (cellHeight + padding),
    );
  }
  return <String, dynamic>{
    'pngBytes': image.encodePng(sheet),
    'sourceFrames': decoded.numFrames,
    'renderedFrames': indices.length,
  };
}
