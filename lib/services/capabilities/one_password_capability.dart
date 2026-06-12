import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/node_frame.dart';
import 'capability_handler.dart';
import 'native_env.dart';

typedef OnePasswordConnectConfigProvider = Future<OnePasswordConnectConfig?>
    Function();

class OnePasswordConnectConfig {
  final Uri host;
  final String token;

  const OnePasswordConnectConfig({
    required this.host,
    required this.token,
  });
}

class OnePasswordCapability extends CapabilityHandler {
  OnePasswordCapability({
    http.Client? client,
    OnePasswordConnectConfigProvider? configProvider,
  })  : _client = client ?? http.Client(),
        _configProvider = configProvider ?? _readNativeConnectConfig;

  static const int _defaultLimit = 10;
  static const int _maxLimit = 50;

  final http.Client _client;
  final OnePasswordConnectConfigProvider _configProvider;

  @override
  String get name => '1password';

  @override
  List<String> get commands => const ['vaults'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != '1password.vaults') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown 1Password command: $command',
      });
    }

    final config = await _configProvider();
    if (config == null || config.token.trim().isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_ONEPASSWORD_CONNECT_CONFIG',
        'message':
            'Set OP_CONNECT_HOST and OP_CONNECT_TOKEN for the Android 1Password Connect adapter. OP_SERVICE_ACCOUNT_TOKEN is supported by the op CLI path, not direct REST.',
      });
    }

    try {
      return await _handleVaults(config, params);
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'ONEPASSWORD_TIMEOUT',
        'message': '1Password Connect request timed out after 15 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'ONEPASSWORD_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<NodeFrame> _handleVaults(
    OnePasswordConnectConfig config,
    Map<String, dynamic> params,
  ) async {
    final limit = _intParam(params['limit'], _defaultLimit, 1, _maxLimit);
    final startedAt = DateTime.now();
    final response = await _client.get(
      _connectUri(config.host, '/v1/vaults'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${config.token}',
        'User-Agent': 'OpenClaw-Android',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return NodeFrame.response('', error: {
        'code': 'ONEPASSWORD_HTTP_ERROR',
        'message': '1Password Connect returned HTTP ${response.statusCode}.',
        'statusCode': response.statusCode,
      });
    }
    final vaults = _vaultList(response.body)
        .take(limit)
        .map(_vaultPreview)
        .toList(growable: false);
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-1password-connect-rest',
      'action': 'vaults',
      'count': vaults.length,
      'vaults': vaults,
      'elapsedMs': elapsedMs,
    });
  }

  static String _canonicalCommand(
    String command,
    Map<String, dynamic> params,
  ) {
    final normalized =
        command.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    final action = params['action']?.toString().trim().toLowerCase();
    if (action == 'vaults' || action == 'status' || action == 'list') {
      return '1password.vaults';
    }
    return switch (normalized) {
      '1password' ||
      'onepassword' ||
      'op' ||
      '1password.vaults' ||
      'onepassword.vaults' ||
      'op.vaults' ||
      'vaults' ||
      'status' =>
        '1password.vaults',
      _ => normalized,
    };
  }

  static Uri _connectUri(Uri host, String endpoint) {
    final basePath = host.path.endsWith('/')
        ? host.path.substring(0, host.path.length - 1)
        : host.path;
    final suffix = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return host.replace(path: '$basePath/$suffix');
  }

  static List<Map<String, dynamic>> _vaultList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    if (decoded is Map && decoded['vaults'] is List) {
      return (decoded['vaults'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    throw const FormatException('1Password vault response was not a list.');
  }

  static Map<String, dynamic> _vaultPreview(Map<String, dynamic> vault) => {
        'id': vault['id']?.toString(),
        'name': vault['name']?.toString(),
        if (vault['description'] != null)
          'description': _bounded(vault['description'].toString(), 240),
        if (vault['attributeVersion'] != null)
          'attributeVersion': vault['attributeVersion'],
      };

  static int _intParam(dynamic value, int fallback, int min, int max) {
    final parsed = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };
    return (parsed ?? fallback).clamp(min, max).toInt();
  }

  static String _bounded(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return value.substring(0, maxChars);
  }

  static Future<OnePasswordConnectConfig?> _readNativeConnectConfig() async {
    final hostText = await NativeEnv.readFirst(const [
      'OP_CONNECT_HOST',
      'ONEPASSWORD_CONNECT_HOST',
    ]);
    final token = await NativeEnv.readFirst(const [
      'OP_CONNECT_TOKEN',
      'ONEPASSWORD_CONNECT_TOKEN',
    ]);
    final host = hostText == null ? null : Uri.tryParse(hostText.trim());
    if (host == null ||
        host.host.isEmpty ||
        (host.scheme != 'https' && host.scheme != 'http') ||
        token == null ||
        token.trim().isEmpty) {
      return null;
    }
    return OnePasswordConnectConfig(host: host, token: token.trim());
  }
}
