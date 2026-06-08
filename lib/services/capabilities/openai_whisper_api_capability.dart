import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../models/node_frame.dart';
import '../native_bridge.dart';
import 'capability_handler.dart';

typedef OpenAiApiKeyProvider = Future<String?> Function();

class OpenAiWhisperApiCapability extends CapabilityHandler {
  OpenAiWhisperApiCapability({
    http.Client? client,
    OpenAiApiKeyProvider? apiKeyProvider,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _apiKeyProvider = apiKeyProvider ?? _readNativeOpenAiApiKey,
        _baseUri = baseUri ?? Uri.parse('https://api.openai.com');

  static const int _maxAudioBytes = 25 * 1024 * 1024;
  static const int _maxTextChars = 12000;
  static const String _defaultModel = 'gpt-4o-mini-transcribe';
  static const Set<String> _allowedModels = {
    'gpt-4o-transcribe',
    'gpt-4o-mini-transcribe',
    'whisper-1',
  };
  static const Set<String> _allowedExtensions = {
    '.flac',
    '.m4a',
    '.mp3',
    '.mp4',
    '.mpeg',
    '.mpga',
    '.ogg',
    '.wav',
    '.webm',
  };

  final http.Client _client;
  final OpenAiApiKeyProvider _apiKeyProvider;
  final Uri _baseUri;

  @override
  String get name => 'openai-whisper-api';

  @override
  List<String> get commands => const ['transcribe'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command, params);
    if (canonical != 'openai-whisper-api.transcribe') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown OpenAI Whisper API command: $command',
      });
    }

    final apiKey = (await _apiKeyProvider())?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_OPENAI_API_KEY',
        'message':
            'Set OPENAI_API_KEY in the Native OpenClaw environment before using OpenAI transcription tools.',
      });
    }

    final audioBase64 =
        (params['audioBase64'] ?? params['audio_base64'])?.toString().trim();
    if (audioBase64 == null || audioBase64.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_AUDIO',
        'message': 'openai-whisper-api.transcribe requires audioBase64.',
      });
    }

    final bytes = _decodeAudio(audioBase64);
    if (bytes == null || bytes.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'INVALID_AUDIO_BASE64',
        'message': 'audioBase64 must be valid base64-encoded audio bytes.',
      });
    }
    if (bytes.length > _maxAudioBytes) {
      return NodeFrame.response('', error: {
        'code': 'AUDIO_TOO_LARGE',
        'message':
            'audioBase64 exceeds the 25 MB app-native transcription limit.',
        'maxBytes': _maxAudioBytes,
      });
    }

    final filename = _filename(params['filename']);
    final model = _model(params['model']);
    try {
      final startedAt = DateTime.now();
      final request = http.MultipartRequest(
        'POST',
        _baseUri.replace(path: '/v1/audio/transcriptions'),
      )
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'User-Agent': 'OpenClaw-Android',
        })
        ..fields['model'] = model
        ..fields['response_format'] = 'json'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ));

      final language = params['language']?.toString().trim();
      if (language != null && language.isNotEmpty) {
        request.fields['language'] = language;
      }
      final prompt = params['prompt']?.toString().trim();
      if (prompt != null && prompt.isNotEmpty) {
        request.fields['prompt'] = _bounded(prompt, 1000);
      }

      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        return NodeFrame.response('', error: {
          'code': 'OPENAI_TRANSCRIPTION_HTTP_ERROR',
          'message':
              'OpenAI transcription returned HTTP ${streamed.statusCode}.',
          'statusCode': streamed.statusCode,
          if (body.trim().isNotEmpty) 'responsePreview': _bounded(body, 600),
        });
      }

      final json = _jsonMap(body);
      final text = json['text']?.toString() ?? '';
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      return NodeFrame.response('', payload: {
        'runtime': 'app-native-openai-transcription-rest',
        'action': 'transcribe',
        'model': model,
        'filename': filename,
        'audioBytes': bytes.length,
        'text': _bounded(text, _maxTextChars),
        'charCount': text.length,
        'elapsedMs': elapsedMs,
      });
    } on TimeoutException {
      return NodeFrame.response('', error: {
        'code': 'OPENAI_TRANSCRIPTION_TIMEOUT',
        'message': 'OpenAI transcription timed out after 60 seconds.',
      });
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'OPENAI_TRANSCRIPTION_ERROR',
        'message': error.toString(),
      });
    }
  }

  static String _canonicalCommand(
    String command,
    Map<String, dynamic> params,
  ) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '-');
    final action = params['action']?.toString().trim().toLowerCase();
    return switch (normalized) {
      'openai-whisper-api' ||
      'openai-whisper-api.transcribe' ||
      'openai-whisper-api-transcribe' ||
      'transcribe' =>
        action == null || action.isEmpty || action == 'transcribe'
            ? 'openai-whisper-api.transcribe'
            : normalized,
      _ => normalized,
    };
  }

  static List<int>? _decodeAudio(String value) {
    try {
      final cleaned =
          value.contains(',') ? value.substring(value.indexOf(',') + 1) : value;
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  static String _filename(dynamic value) {
    final raw = value?.toString().trim();
    final safe = raw == null || raw.isEmpty
        ? 'audio.wav'
        : raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final extension = path.extension(safe).toLowerCase();
    if (_allowedExtensions.contains(extension)) return safe;
    return '$safe.wav';
  }

  static String _model(dynamic value) {
    final model = value?.toString().trim();
    if (model != null && _allowedModels.contains(model)) return model;
    return _defaultModel;
  }

  static String _bounded(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return value.substring(0, maxChars);
  }

  static Map<String, dynamic> _jsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException(
        'OpenAI transcription response was not an object.');
  }

  static Future<String?> _readNativeOpenAiApiKey() async {
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
      return _readDotEnvKey(await envFile.readAsString(), 'OPENAI_API_KEY');
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
