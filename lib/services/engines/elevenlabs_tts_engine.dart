import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'tts_engine.dart';

/// Streams audio from ElevenLabs text-to-speech API.
/// Requires an API key stored in PreferencesService.elevenLabsApiKey.
class ElevenLabsTtsEngine implements TtsEngine {
  final String apiKey;
  final String voiceId;
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;

  @override
  String get id => 'elevenlabs';

  @override
  String get label => 'ElevenLabs';

  @override
  bool get isReady => _ready && apiKey.isNotEmpty;

  @override
  Function? onStart;

  @override
  Function? onComplete;

  ElevenLabsTtsEngine({required this.apiKey, required this.voiceId}) {
    _ready = apiKey.isNotEmpty;
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
      // ElevenLabs speed is called "speed" in voice_settings, range 0.7–1.2
      final elevenlabsSpeed = speed.clamp(0.7, 1.2);
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId'),
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: '{"text":${_jsonString(text)},"model_id":"eleven_monolingual_v1","voice_settings":{"speed":$elevenlabsSpeed,"stability":0.5,"similarity_boost":0.75}}',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('ElevenLabs ${response.statusCode}: ${response.body}');
      }

      final bytes = Uint8List.fromList(response.bodyBytes);
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('ElevenLabsTTS error: $e');
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
