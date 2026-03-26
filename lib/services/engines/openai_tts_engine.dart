import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'tts_engine.dart';

/// Uses OpenAI /v1/audio/speech for high-quality cloud TTS.
/// Reuses the OpenAI API key already stored in openclaw.json / PreferencesService.
class OpenAiTtsEngine implements TtsEngine {
  final String apiKey;
  final String voice;
  final String model;
  final AudioPlayer _player = AudioPlayer();

  @override
  String get id => 'openai';

  @override
  String get label => 'OpenAI TTS';

  @override
  bool get isReady => apiKey.isNotEmpty;

  @override
  Function? onStart;

  @override
  Function? onComplete;

  OpenAiTtsEngine({required this.apiKey, this.voice = 'coral', this.model = 'gpt-4o-mini-tts'}) {
    _player.onPlayerComplete.listen((_) => onComplete?.call());
  }

  @override
  Future<void> speak(String text, {double speed = 1.0}) async {
    if (!isReady || text.trim().isEmpty) {
      onComplete?.call();
      return;
    }
    try {
      onStart?.call();
      // OpenAI speed range: 0.25–4.0
      final openaiSpeed = speed.clamp(0.25, 4.0);
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: '{"model":"$model","input":${_jsonString(text)},"voice":"$voice","speed":$openaiSpeed}',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('OpenAI TTS ${response.statusCode}: ${response.body}');
      }

      final bytes = Uint8List.fromList(response.bodyBytes);
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('OpenAiTTS error: $e');
      onComplete?.call();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    onComplete?.call();
  }

  String _jsonString(String s) {
    final escaped = s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
    return '"$escaped"';
  }
}
