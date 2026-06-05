import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'native_bridge.dart';

class NativeNodeSkillRunner {
  NativeNodeSkillRunner._();
  static final NativeNodeSkillRunner instance = NativeNodeSkillRunner._();

  static const host = '127.0.0.1';
  static const port = 18791;

  Future<Map<String, dynamic>> run(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    await NativeBridge.startNativeNodeSkillRunnerRuntime();
    final healthy = await _waitForHealth(
      timeout: const Duration(seconds: 8),
    );
    if (!healthy) {
      return const <String, dynamic>{
        'ok': false,
        'error': 'Native Node skill runner did not become healthy.',
        'errorCode': 'native_node_runner_unhealthy',
      };
    }

    final response = await http
        .post(
          Uri.parse('http://$host:$port/execute'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    final body = response.body.trim();
    Object? decoded;
    try {
      decoded = body.isEmpty ? const <String, dynamic>{} : jsonDecode(body);
    } catch (_) {
      decoded = <String, dynamic>{
        'ok': false,
        'error': 'Native Node runner returned non-JSON response.',
        'statusCode': response.statusCode,
        'body': body,
      };
    }
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{'ok': false, 'body': decoded};
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return map;
    }
    return {
      'ok': false,
      ...map,
      'statusCode': response.statusCode,
    };
  }

  Future<bool> _waitForHealth({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await http
            .get(Uri.parse('http://$host:$port/health'))
            .timeout(const Duration(milliseconds: 700));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['ok'] == true) return true;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    return false;
  }
}
