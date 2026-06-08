import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

typedef McPorterConfigProvider = Future<McPorterConfig?> Function();

class McPorterConfig {
  final String endpoint;
  final String token;

  const McPorterConfig({
    required this.endpoint,
    required this.token,
  });

  bool get isValid {
    final uri = Uri.tryParse(endpoint.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        token.trim().isNotEmpty;
  }
}

class McPorterCapability extends CapabilityHandler {
  McPorterCapability({
    http.Client? client,
    McPorterConfigProvider? configProvider,
  })  : _client = client ?? http.Client(),
        _configProvider = configProvider ?? _readNativeMcPorterConfig;

  final http.Client _client;
  final McPorterConfigProvider _configProvider;

  @override
  String get name => 'mcporter';

  @override
  List<String> get commands => const ['health'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'mcporter.health') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown MCPorter command: $command',
      });
    }

    final config = await _configProvider();
    if (config == null || !config.isValid) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_MCPORTER_CONFIG',
        'message':
            'Set MCPORTER_ENDPOINT and MCPORTER_TOKEN in the Native OpenClaw environment before using MCPorter tools.',
      });
    }

    final endpoint = _healthUri(config.endpoint);
    try {
      final startedAt = DateTime.now();
      final response = await _client.get(
        endpoint,
        headers: {
          'Authorization': 'Bearer ${config.token.trim()}',
          'Accept': 'application/json',
          'User-Agent': 'OpenClaw-Android',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return NodeFrame.response('', error: {
          'code': 'MCPORTER_HTTP_ERROR',
          'message': 'MCPorter returned HTTP ${response.statusCode}.',
          'statusCode': response.statusCode,
        });
      }
      final json = _jsonMap(response.body);
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      final servers = json['servers'];
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-mcporter-rest',
        'action': 'health',
        'endpointHost': endpoint.host,
        'ok': json['ok'] == true || json['status']?.toString() == 'ok',
        'status': json['status']?.toString(),
        'version': json['version']?.toString(),
        if (servers is List) 'serverCount': servers.length,
        'elapsedMs': elapsedMs,
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'MCPORTER_TIMEOUT',
        'message': 'MCPorter request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'MCPORTER_ERROR',
        'message': error.toString(),
      });
    }
  }

  static Uri _healthUri(String endpoint) {
    final uri = Uri.parse(endpoint.trim());
    if (uri.path.trim().isEmpty || uri.path == '/') {
      return uri.replace(path: '/health');
    }
    return uri;
  }

  static String _canonicalCommand(
    String command,
    Map<String, dynamic> params,
  ) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '.');
    final action = params['action']?.toString().trim().toLowerCase();
    return switch (normalized) {
      'mcporter' ||
      'mcporter.health' ||
      'mcporter.status' ||
      'health' ||
      'status' =>
        action == null ||
                action.isEmpty ||
                action == 'health' ||
                action == 'status'
            ? 'mcporter.health'
            : normalized,
      _ => normalized,
    };
  }

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('MCPorter response was not an object.');
  }

  static Future<McPorterConfig?> _readNativeMcPorterConfig() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final envFile = File(path.join(
        filesDir,
        'native-node-embedded',
        'native-home',
        '.openclaw',
        '.env',
      ));
      if (!await envFile.exists()) return null;
      final env = await envFile.readAsString();
      final endpoint = _readDotEnvKey(env, 'MCPORTER_ENDPOINT');
      final token = _readDotEnvKey(env, 'MCPORTER_TOKEN');
      if (endpoint == null || token == null) return null;
      return McPorterConfig(endpoint: endpoint, token: token);
    } catch (_) {
      return null;
    }
  }

  static String? _readDotEnvKey(String text, String key) {
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final equals = line.indexOf('=');
      if (equals <= 0) continue;
      final name = line.substring(0, equals).trim();
      if (name != key) continue;
      var value = line.substring(equals + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      return value.trim().isEmpty ? null : value.trim();
    }
    return null;
  }
}
