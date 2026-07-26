import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';
import 'native_env.dart';

typedef GifgrepCredentialsProvider = Future<Map<String, String?>> Function();

typedef GifgrepRunner = Future<NativeManagedCliRunResult> Function(
  String binName,
  List<String> args, {
  required Map<String, String> env,
  required int timeoutSeconds,
});

/// Bounded app-native execution adapter for the managed Android gifgrep binary.
///
/// Android cannot execute downloaded app-data ELF files through a normal shell.
/// [NativeBridge.runManagedCli] launches the verified binary through linker64,
/// keeping this path native-first without PRoot, Go, Homebrew, or node-pty.
class GifgrepCapability extends CapabilityHandler {
  GifgrepCapability({
    GifgrepCredentialsProvider? credentialsProvider,
    GifgrepRunner? runner,
  })  : _credentialsProvider = credentialsProvider ?? _readGifgrepCredentials,
        _runner = runner ?? NativeBridge.runManagedCli;

  final GifgrepCredentialsProvider _credentialsProvider;
  final GifgrepRunner _runner;

  @override
  String get name => 'gifgrep';

  @override
  List<String> get commands => const ['status', 'search', 'still', 'sheet'];

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
    final args = [
      'search',
      query,
      '--json',
      '--source',
      source,
      '--max',
      '$maxResults',
    ];
    final startedAt = DateTime.now();
    final result = await _runner(
      'gifgrep',
      args,
      env: env,
      timeoutSeconds: 25,
    );
    if (!result.ok) return _failure(result, args);

    final decoded = jsonDecode(result.stdout);
    if (decoded is! List) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_INVALID_OUTPUT',
        'message': 'gifgrep returned an unexpected search response.',
      });
    }
    final results = decoded
        .whereType<Map>()
        .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
        .take(maxResults)
        .toList(growable: false);
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

  Future<NodeFrame> _runLocalImage(
    String action,
    Map<String, dynamic> params,
  ) async {
    final rawInput =
        (params['inputPath'] ?? params['path'] ?? params['gif'])?.toString();
    if (rawInput == null || rawInput.trim().isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_INPUT_REQUIRED',
        'message': 'gifgrep.$action requires inputPath.',
      });
    }

    final filesDir = await NativeBridge.getFilesDir();
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

    final args = action == 'still'
        ? [
            'still',
            input,
            '--at',
            _safeDuration(params['at']?.toString()),
            '-o',
            output,
            '--quiet',
          ]
        : [
            'sheet',
            input,
            '--frames',
            '${_intValue(params['frames'], fallback: 12).clamp(1, 24)}',
            '--cols',
            '${_intValue(params['cols'], fallback: 4).clamp(1, 8)}',
            '-o',
            output,
            '--quiet',
          ];
    final result = await _runner(
      'gifgrep',
      args,
      env: const {},
      timeoutSeconds: 25,
    );
    if (!result.ok) return _failure(result, args);

    final outputFile = File(output);
    if (!await outputFile.exists()) {
      return NodeFrame.response('', error: {
        'code': 'GIFGREP_OUTPUT_MISSING',
        'message': 'gifgrep completed without producing the expected PNG.',
      });
    }
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-gifgrep-cli',
      'ready': true,
      'status': 'READY',
      'action': action,
      'inputPath': input,
      'outputPath': output,
      'mimeType': 'image/png',
      'bytes': await outputFile.length(),
    });
  }

  NodeFrame _failure(NativeManagedCliRunResult result, List<String> args) {
    final stderr = result.stderr.trim().isEmpty
        ? result.stdout.trim()
        : result.stderr.trim();
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

  static String _safeDuration(String? value) {
    final candidate = value?.trim() ?? '0s';
    return RegExp(r'^\d+(?:\.\d{1,3})?(?:ms|s|m)$').hasMatch(candidate)
        ? candidate
        : '0s';
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
