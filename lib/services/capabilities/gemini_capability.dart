import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/node_frame.dart';
import 'capability_handler.dart';
import 'native_env.dart';

typedef GeminiApiKeyProvider = Future<String?> Function();

class GeminiCapability extends CapabilityHandler {
  GeminiCapability({
    http.Client? client,
    GeminiApiKeyProvider? apiKeyProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _apiKeyProvider = apiKeyProvider ?? _readNativeGeminiApiKey,
        _baseUri =
            baseUri ?? Uri.parse('https://generativelanguage.googleapis.com');

  static const int _defaultLimit = 10;
  static const int _maxLimit = 50;
  static const int _maxPromptChars = 4000;
  static const int _maxResponseChars = 12000;
  static const String _defaultModel = 'gemini-2.0-flash';

  final http.Client _client;
  final GeminiApiKeyProvider _apiKeyProvider;
  final Uri _baseUri;

  @override
  String get name => 'gemini';

  @override
  List<String> get commands => const ['models', 'generate'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'gemini.models' && canonical != 'gemini.generate') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown Gemini command: $command',
      });
    }

    final apiKey = (await _apiKeyProvider())?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_GEMINI_API_KEY',
        'message':
            'Set GEMINI_API_KEY in the Native OpenClaw environment before using Gemini tools.',
      });
    }

    try {
      return switch (canonical) {
        'gemini.generate' => await _handleGenerate(apiKey, params),
        _ => await _handleModels(apiKey, params),
      };
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'GEMINI_TIMEOUT',
        'message': 'Gemini request timed out after 20 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'GEMINI_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<NodeFrame> _handleModels(
    String apiKey,
    Map<String, dynamic> params,
  ) async {
    final limit = _intParam(params['limit'], _defaultLimit, 1, _maxLimit);
    final startedAt = DateTime.now();
    final response = await _client
        .get(
          _baseUri.replace(
            path: '/v1beta/models',
            queryParameters: {
              'key': apiKey,
              'pageSize': '$limit',
            },
          ),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _httpError(response);
    }
    final json = _jsonMap(response.body);
    final models = (json['models'] is List ? json['models'] as List : const [])
        .whereType<Map>()
        .take(limit)
        .map((model) => _modelPreview(Map<String, dynamic>.from(model)))
        .toList(growable: false);
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-gemini-rest',
      'action': 'models',
      'count': models.length,
      'models': models,
      'elapsedMs': elapsedMs,
    });
  }

  Future<NodeFrame> _handleGenerate(
    String apiKey,
    Map<String, dynamic> params,
  ) async {
    final prompt = (params['prompt'] ?? params['text'])?.toString().trim();
    if (prompt == null || prompt.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PROMPT',
        'message': 'gemini.generate requires prompt or text.',
      });
    }
    final model = _modelName(params['model']);
    final startedAt = DateTime.now();
    final response = await _client
        .post(
          _baseUri.replace(
            path: '/v1beta/models/$model:generateContent',
            queryParameters: {'key': apiKey},
          ),
          headers: {
            ..._headers(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': _bounded(prompt, _maxPromptChars)},
                ],
              },
            ],
            'generationConfig': {
              'maxOutputTokens':
                  _intParam(params['maxOutputTokens'], 512, 1, 2048),
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _httpError(response);
    }
    final json = _jsonMap(response.body);
    final text = _extractGeneratedText(json);
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-gemini-rest',
      'action': 'generate',
      'model': model,
      'text': _bounded(text, _maxResponseChars),
      'charCount': text.length,
      'elapsedMs': elapsedMs,
    });
  }

  NodeFrame _httpError(http.Response response) {
    return NodeFrame.response('', error: {
      'code': 'GEMINI_HTTP_ERROR',
      'message': 'Gemini returned HTTP ${response.statusCode}.',
      'statusCode': response.statusCode,
    });
  }

  static String _canonicalCommand(
    String command,
    Map<String, dynamic> params,
  ) {
    final normalized =
        command.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    final action = params['action']?.toString().trim().toLowerCase();
    if (action == 'generate' || action == 'prompt') return 'gemini.generate';
    if (action == 'models' || action == 'status' || action == 'list') {
      return 'gemini.models';
    }
    return switch (normalized) {
      'gemini' ||
      'gemini.models' ||
      'gemini-models' ||
      'gemini.status' ||
      'gemini-status' ||
      'models' ||
      'status' =>
        'gemini.models',
      'gemini.generate' || 'gemini-generate' || 'generate' => 'gemini.generate',
      _ => normalized,
    };
  }

  static Map<String, String> _headers() => {
        'Accept': 'application/json',
        'User-Agent': 'OpenClaw-Android',
      };

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Gemini response was not a JSON object.');
  }

  static Map<String, dynamic> _modelPreview(Map<String, dynamic> model) => {
        'name': model['name']?.toString(),
        'baseModelId': model['baseModelId']?.toString(),
        'displayName': model['displayName']?.toString(),
        'description': _bounded(model['description']?.toString() ?? '', 240),
        if (model['supportedGenerationMethods'] is List)
          'supportedGenerationMethods':
              (model['supportedGenerationMethods'] as List)
                  .map((value) => value.toString())
                  .take(8)
                  .toList(growable: false),
      };

  static String _extractGeneratedText(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final first = candidates.first;
    if (first is! Map) return '';
    final content = first['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List) return '';
    return parts
        .whereType<Map>()
        .map((part) => part['text']?.toString() ?? '')
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  static String _modelName(dynamic value) {
    final raw = value?.toString().trim();
    final candidate = raw == null || raw.isEmpty
        ? _defaultModel
        : raw.replaceFirst(RegExp(r'^models/'), '');
    if (RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(candidate)) return candidate;
    return _defaultModel;
  }

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

  static Future<String?> _readNativeGeminiApiKey() =>
      NativeEnv.readFirst(const ['GEMINI_API_KEY', 'GOOGLE_API_KEY']);
}
