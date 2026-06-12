import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/node_frame.dart';
import 'capability_handler.dart';
import 'native_env.dart';

typedef SagApiKeyProvider = Future<String?> Function();

class SagCapability extends CapabilityHandler {
  SagCapability({
    http.Client? client,
    SagApiKeyProvider? apiKeyProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _apiKeyProvider = apiKeyProvider ?? _readNativeSagApiKey,
        _baseUri = baseUri ?? Uri.parse('https://api.elevenlabs.io');

  static const int _defaultLimit = 10;
  static const int _maxLimit = 50;
  static const int _maxSpeechTextChars = 1000;
  static const String _defaultModel = 'eleven_multilingual_v2';
  static const String _defaultOutputFormat = 'mp3_44100_128';

  final http.Client _client;
  final SagApiKeyProvider _apiKeyProvider;
  final Uri _baseUri;

  @override
  String get name => 'sag';

  @override
  List<String> get commands => const ['voices', 'speak'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'sag.voices' && canonical != 'sag.speak') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown SAG command: $command',
      });
    }

    final apiKey = (await _apiKeyProvider())?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_SAG_API_KEY',
        'message':
            'Set ELEVENLABS_API_KEY or SAG_API_KEY in the Native OpenClaw environment before using SAG speech tools.',
      });
    }

    try {
      return switch (canonical) {
        'sag.speak' => await _handleSpeak(apiKey, params),
        _ => await _handleVoices(apiKey, params),
      };
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'SAG_TIMEOUT',
        'message': 'SAG/ElevenLabs request timed out after 20 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'SAG_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<NodeFrame> _handleVoices(
    String apiKey,
    Map<String, dynamic> params,
  ) async {
    final limit = _intParam(params['limit'], _defaultLimit, 1, _maxLimit);
    final startedAt = DateTime.now();
    final response = await _client
        .get(
          _baseUri.replace(
            path: '/v2/voices',
            queryParameters: {
              'page_size': '$limit',
            },
          ),
          headers: _headers(apiKey),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _httpError(response);
    }
    final json = _jsonMap(response.body);
    final voices = (json['voices'] is List ? json['voices'] as List : const [])
        .whereType<Map>()
        .take(limit)
        .map((voice) => _voicePreview(Map<String, dynamic>.from(voice)))
        .toList(growable: false);
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-elevenlabs-rest',
      'action': 'voices',
      'count': voices.length,
      'totalCount': json['total_count'],
      'voices': voices,
      'elapsedMs': elapsedMs,
    });
  }

  Future<NodeFrame> _handleSpeak(
    String apiKey,
    Map<String, dynamic> params,
  ) async {
    final text = (params['text'] ?? params['prompt'])?.toString().trim();
    if (text == null || text.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_TEXT',
        'message': 'sag.speak requires text.',
      });
    }
    final voiceId = (params['voiceId'] ?? params['voice_id'])
        ?.toString()
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (voiceId == null || voiceId.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_VOICE_ID',
        'message': 'sag.speak requires voiceId from sag.voices.',
      });
    }
    final outputFormat =
        params['outputFormat']?.toString().trim() ?? _defaultOutputFormat;
    final startedAt = DateTime.now();
    final response = await _client
        .post(
          _baseUri.replace(
            path: '/v1/text-to-speech/$voiceId',
            queryParameters: {'output_format': outputFormat},
          ),
          headers: {
            ..._headers(apiKey),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'text': _bounded(text, _maxSpeechTextChars),
            'model_id': params['modelId']?.toString().trim().isNotEmpty == true
                ? params['modelId'].toString().trim()
                : _defaultModel,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _httpError(response);
    }
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    return NodeFrame.response('', payload: {
      'runtime': 'app-native-elevenlabs-rest',
      'action': 'speak',
      'voiceId': voiceId,
      'outputFormat': outputFormat,
      'audioBase64': base64Encode(response.bodyBytes),
      'audioBytes': response.bodyBytes.length,
      'elapsedMs': elapsedMs,
    });
  }

  NodeFrame _httpError(http.Response response) {
    return NodeFrame.response('', error: {
      'code': 'SAG_HTTP_ERROR',
      'message': 'SAG/ElevenLabs returned HTTP ${response.statusCode}.',
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
    if (action == 'speak' || action == 'tts' || action == 'speech') {
      return 'sag.speak';
    }
    if (action == 'voices' || action == 'status' || action == 'list') {
      return 'sag.voices';
    }
    return switch (normalized) {
      'sag' ||
      'sag.voices' ||
      'sag-voices' ||
      'sag.status' ||
      'sag-status' ||
      'voices' ||
      'status' =>
        'sag.voices',
      'sag.speak' ||
      'sag-speak' ||
      'sag.tts' ||
      'sag-tts' ||
      'speak' ||
      'tts' =>
        'sag.speak',
      _ => normalized,
    };
  }

  static Map<String, String> _headers(String apiKey) => {
        'Accept': 'application/json',
        'User-Agent': 'OpenClaw-Android',
        'xi-api-key': apiKey,
      };

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('SAG/ElevenLabs response was not an object.');
  }

  static Map<String, dynamic> _voicePreview(Map<String, dynamic> voice) => {
        'voiceId': voice['voice_id']?.toString(),
        'name': voice['name']?.toString(),
        'category': voice['category']?.toString(),
        if (voice['labels'] is Map)
          'labels': Map<String, dynamic>.from(voice['labels'] as Map),
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

  static Future<String?> _readNativeSagApiKey() =>
      NativeEnv.readFirst(const ['ELEVENLABS_API_KEY', 'SAG_API_KEY']);
}
