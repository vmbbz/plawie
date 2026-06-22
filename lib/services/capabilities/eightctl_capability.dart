import 'dart:async';
import 'dart:convert';

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';
import 'native_env.dart';

typedef EightCtlCredentialsProvider = Future<Map<String, String?>> Function();

typedef EightCtlRunner = Future<NativeManagedCliRunResult> Function(
  String binName,
  List<String> args, {
  required Map<String, String> env,
  required int timeoutSeconds,
});

class EightCtlCapability extends CapabilityHandler {
  EightCtlCapability({
    EightCtlCredentialsProvider? credentialsProvider,
    EightCtlRunner? runner,
  })  : _credentialsProvider =
            credentialsProvider ?? _readNativeEightCtlCredentials,
        _runner = runner ?? NativeBridge.runManagedCli;

  final EightCtlCredentialsProvider _credentialsProvider;
  final EightCtlRunner _runner;

  @override
  String get name => 'eightctl';

  @override
  List<String> get commands => const ['status', 'whoami', 'device-info'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'eightctl.status' &&
        canonical != 'eightctl.whoami' &&
        canonical != 'eightctl.device-info') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown eightctl command: $command',
      });
    }

    final credentials = await _credentialsProvider();
    final email = credentials['EIGHTCTL_EMAIL']?.trim();
    final password = credentials['EIGHTCTL_PASSWORD']?.trim();
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_EIGHTCTL_CONFIG',
        'message':
            'Set EIGHTCTL_EMAIL and EIGHTCTL_PASSWORD before using Eight Sleep tools.',
      });
    }

    final env = <String, String>{
      'EIGHTCTL_EMAIL': email,
      'EIGHTCTL_PASSWORD': password,
      for (final key in const [
        'EIGHTCTL_USER_ID',
        'EIGHTCTL_DEVICE_ID',
        'EIGHTCTL_CLIENT_ID',
        'EIGHTCTL_CLIENT_SECRET',
        'EIGHTCTL_TIMEZONE',
      ])
        if (credentials[key]?.trim().isNotEmpty == true)
          key: credentials[key]!.trim(),
    };
    final args = _argsFor(canonical);

    try {
      final startedAt = DateTime.now();
      final result = await _runner(
        'eightctl',
        args,
        env: env,
        timeoutSeconds: 25,
      );
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      if (!result.ok) {
        return NodeFrame.response('', error: {
          'code': result.exitCode == 124
              ? 'EIGHTCTL_TIMEOUT'
              : 'EIGHTCTL_EXIT_${result.exitCode}',
          'message':
              'eightctl ${args.first} failed with exit code ${result.exitCode}.',
          'exitCode': result.exitCode,
          'stderr': _redact(
            result.stderr.trim().isEmpty ? result.stdout : result.stderr,
            env.values,
          ),
        });
      }

      final stdout = result.stdout.trim();
      final decoded = _tryDecodeJson(stdout);
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-eightctl-cli',
        'action': canonical.split('.').last,
        'configured': true,
        'connected': true,
        'ready': true,
        'status': 'READY',
        'command': 'eightctl ${args.take(2).join(' ')}',
        'json': decoded != null,
        'elapsedMs': elapsedMs,
        ..._safeSummary(decoded, stdout, env.values),
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'EIGHTCTL_TIMEOUT',
        'message': 'eightctl request timed out after 25 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'EIGHTCTL_ERROR',
        'message': _redact(error.toString(), env.values),
      });
    }
  }

  static List<String> _argsFor(String canonical) {
    return switch (canonical) {
      'eightctl.whoami' => const ['whoami', '--output', 'json', '--quiet'],
      'eightctl.device-info' => const [
          'device',
          'info',
          '--output',
          'json',
          '--quiet'
        ],
      _ => const ['status', '--output', 'json', '--quiet'],
    };
  }

  static String _canonicalCommand(
    String command,
    Map<String, dynamic> params,
  ) {
    final normalized =
        command.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    final action = params['action']?.toString().trim().toLowerCase();
    if (action == 'whoami' || action == 'me') return 'eightctl.whoami';
    if (action == 'device-info' || action == 'device' || action == 'devices') {
      return 'eightctl.device-info';
    }
    if (action == 'status' || action == 'check' || action == 'health') {
      return 'eightctl.status';
    }
    return switch (normalized) {
      'eightctl' ||
      'eightctl.status' ||
      'eightctl-status' ||
      'status' ||
      'health' =>
        'eightctl.status',
      'eightctl.whoami' ||
      'eightctl-whoami' ||
      'whoami' ||
      'me' =>
        'eightctl.whoami',
      'eightctl.device-info' ||
      'eightctl-device-info' ||
      'device-info' ||
      'device' =>
        'eightctl.device-info',
      _ => normalized,
    };
  }

  static Object? _tryDecodeJson(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      final start = body.indexOf(RegExp(r'[\{\[]'));
      if (start < 0) return null;
      try {
        return jsonDecode(body.substring(start));
      } catch (_) {
        return null;
      }
    }
  }

  static Map<String, dynamic> _safeSummary(
    Object? decoded,
    String stdout,
    Iterable<String> secrets,
  ) {
    if (decoded is Map) {
      final map = decoded.map((key, value) => MapEntry('$key', value));
      return {
        'topLevelKeys': map.keys.take(8).toList(growable: false).join(','),
        if (_countList(map, const ['targets', 'devices', 'pods', 'users']) !=
            null)
          'itemCount':
              _countList(map, const ['targets', 'devices', 'pods', 'users']),
        if (_boolValue(map, const ['online', 'connected', 'ready']) != null)
          'remoteOnline':
              _boolValue(map, const ['online', 'connected', 'ready']),
      };
    }
    if (decoded is List) {
      return {'itemCount': decoded.length};
    }
    if (stdout.trim().isNotEmpty) {
      return {'textPreview': _redact(_preview(stdout), secrets)};
    }
    return {'textPreview': 'eightctl completed without public output.'};
  }

  static int? _countList(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is List) return value.length;
    }
    return null;
  }

  static bool? _boolValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
    }
    return null;
  }

  static String _preview(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.length <= 240
        ? normalized
        : '${normalized.substring(0, 240)}...';
  }

  static String _redact(String value, Iterable<String?> secrets) {
    var redacted = value.replaceAll(
      RegExp(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
          caseSensitive: false),
      '[email]',
    );
    for (final secret in secrets) {
      final clean = secret?.trim();
      if (clean == null || clean.length < 3) continue;
      redacted = redacted.replaceAll(clean, '[secret]');
    }
    return redacted;
  }

  static Future<Map<String, String?>> _readNativeEightCtlCredentials() async {
    final result = <String, String?>{};
    for (final key in const [
      'EIGHTCTL_EMAIL',
      'EIGHTCTL_PASSWORD',
      'EIGHTCTL_USER_ID',
      'EIGHTCTL_DEVICE_ID',
      'EIGHTCTL_CLIENT_ID',
      'EIGHTCTL_CLIENT_SECRET',
      'EIGHTCTL_TIMEZONE',
    ]) {
      result[key] = await NativeEnv.readFirst([key]);
    }
    return result;
  }
}
