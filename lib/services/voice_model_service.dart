import 'dart:async';
import 'dart:io';
import 'native_bridge.dart';
import 'openclaw_service.dart';

/// Represents a downloadable voice model for Sherpa-ONNX.
class VoiceModel {
  final String id;
  final String name;
  final String description;
  final String url;
  final String configUrl;

  VoiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.configUrl,
  });
}

/// Service to manage on-demand download of TTS voice models into the active
/// OpenClaw runtime home.
class VoiceModelService {
  static final VoiceModelService _instance = VoiceModelService._internal();
  factory VoiceModelService() => _instance;
  VoiceModelService._internal();

  final List<VoiceModel> availableModels = [
    VoiceModel(
      id: 'en_US-lessac-high',
      name: 'Lessac (Professional)',
      description: 'Authoritative and clear professional voice.',
      url:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx',
      configUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx.json',
    ),
    VoiceModel(
      id: 'en_US-amy-medium',
      name: 'Amy (Friendly)',
      description: 'Warm, expressive and friendly tone.',
      url:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx',
      configUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx.json',
    ),
    VoiceModel(
      id: 'en_US-ryan-high',
      name: 'Ryan (Neutral)',
      description: 'Stable and clear male voice for general use.',
      url:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx',
      configUrl:
          'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx.json',
    ),
  ];

  /// Checks if a specific model exists in the active runtime filesystem.
  Future<bool> isModelDownloaded(String modelId) async {
    final file = File('${await _ttsModelDir()}/$modelId.onnx');
    return file.exists();
  }

  /// Downloads a voice model directly into the active runtime home.
  Future<void> downloadModel(
      VoiceModel model, Function(double progress) onProgress) async {
    final targetDir = await _ttsModelDir();
    await Directory(targetDir).create(recursive: true);

    // Step 1: Download .onnx.json (Config)
    await _downloadFile(
      model.configUrl,
      '$targetDir/${model.id}.onnx.json',
      (_) {},
    );

    // Step 2: Download .onnx (Model)
    onProgress(0.1);
    await _downloadFile(
      model.url,
      '$targetDir/${model.id}.onnx',
      (value) => onProgress(0.1 + (value * 0.9)),
    );
    onProgress(1.0);
  }

  /// Deletes a model to free up space.
  Future<void> deleteModel(String modelId) async {
    final dir = await _ttsModelDir();
    for (final path in <String>[
      '$dir/$modelId.onnx',
      '$dir/$modelId.onnx.json',
    ]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<String> _ttsModelDir() async {
    final filesDir = await NativeBridge.getFilesDir();
    final nativeOwner = await OpenClawCommandService.isNativeOwnerSelected();
    return nativeOwner
        ? '$filesDir/native-node-embedded/native-home/.openclaw/models/tts'
        : '$filesDir/rootfs/ubuntu/root/.openclaw/models/tts';
  }

  Future<void> _downloadFile(
    String url,
    String targetPath,
    void Function(double progress) onProgress,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed: HTTP ${response.statusCode}',
            uri: Uri.parse(url));
      }
      final file = File(targetPath);
      await Directory(file.parent.path).create(recursive: true);
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength > 0 ? response.contentLength : null;
      try {
        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);
          if (total != null) onProgress((received / total).clamp(0, 1));
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }
}
