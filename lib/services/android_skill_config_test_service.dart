import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'android_skill_config_test_plan.dart';

class AndroidSkillConfigTestResult {
  final bool ok;
  final String message;
  final String safeSummary;

  const AndroidSkillConfigTestResult({
    required this.ok,
    required this.message,
    required this.safeSummary,
  });

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'message': message,
        'safeSummary': safeSummary,
      };
}

class AndroidSkillConfigTestService {
  final Uri baseUri;
  final http.Client _client;

  AndroidSkillConfigTestService({
    Uri? baseUri,
    http.Client? client,
  })  : baseUri = baseUri ?? Uri.parse('http://127.0.0.1:8765'),
        _client = client ?? http.Client();

  Future<AndroidSkillConfigTestResult> run(
    AndroidSkillConfigTestPlan plan,
  ) async {
    try {
      final response = await _client
          .post(
            baseUri.replace(path: '/api/tools/execute'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': plan.toolName,
              'input': plan.input,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final decoded = _jsonMap(response.body);
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (decoded['success'] == true || decoded['ok'] == true);
      return AndroidSkillConfigTestResult(
        ok: ok,
        message:
            '${plan.successActionLabel} check ${ok ? 'passed' : 'failed'}.',
        safeSummary: _safeSummary(decoded),
      );
    } catch (error) {
      return AndroidSkillConfigTestResult(
        ok: false,
        message: '${plan.successActionLabel} check failed.',
        safeSummary: _redact(error.toString()),
      );
    }
  }
}

Map<String, dynamic> _jsonMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {'result': decoded};
}

String _safeSummary(Map<String, dynamic> decoded) {
  final error = decoded['error'];
  if (error != null) return _redact(_errorMessage(error));

  final payload = decoded['payload'];
  final source = payload is Map ? Map<String, dynamic>.from(payload) : decoded;
  final selected = <String, dynamic>{};
  for (final entry in source.entries) {
    final key = entry.key.toString();
    if (_sensitiveKey(key) || key == 'success' || key == 'ok') continue;
    final value = entry.value;
    if (value == null || value is Map || value is Iterable) continue;
    selected[key] = value.toString();
    if (selected.length >= 8) break;
  }
  if (selected.isEmpty) selected['result'] = 'No public fields returned.';
  return _redact(jsonEncode(selected));
}

String _errorMessage(dynamic error) {
  if (error is Map) {
    return error['message']?.toString() ?? error.toString();
  }
  final text = error.toString();
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return decoded['message']?.toString() ?? decoded.toString();
    }
  } catch (_) {}
  return text;
}

bool _sensitiveKey(String key) {
  final normalized = key.toLowerCase();
  return normalized.contains('token') ||
      normalized.contains('secret') ||
      normalized.contains('password') ||
      normalized.contains('authorization') ||
      normalized.contains('api_key') ||
      normalized.contains('apikey');
}

String _redact(String value) {
  return value
      .replaceAll(RegExp(r'xox[baprs]-[A-Za-z0-9-]+'), '[secret]')
      .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._-]+'), 'Bearer [secret]');
}
