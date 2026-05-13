import 'dart:async';
import 'native_bridge.dart';

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

/// Service to manage on-demand download of TTS voice models into PRoot.
class VoiceModelService {
  static final VoiceModelService _instance = VoiceModelService._internal();
  factory VoiceModelService() => _instance;
  VoiceModelService._internal();

  final List<VoiceModel> availableModels = [
    VoiceModel(
      id: 'en_US-lessac-high',
      name: 'Lessac (Professional)',
      description: 'Authoritative and clear professional voice.',
      url: 'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx',
      configUrl: 'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx.json',
    ),
    VoiceModel(
      id: 'en_US-amy-medium',
      name: 'Amy (Friendly)',
      description: 'Warm, expressive and friendly tone.',
      url: 'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx',
      configUrl: 'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx.json',
    ),
    VoiceModel(
      id: 'en_US-ryan-high',
      name: 'Ryan (Neutral)',
      description: 'Stable and clear male voice for general use.',
      url: 'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx',
      configUrl: 'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx.json',
    ),
  ];

  /// Checks if a specific model exists in the PRoot filesystem.
  Future<bool> isModelDownloaded(String modelId) async {
    final path = '/root/.openclaw/models/tts/$modelId.onnx';
    final result = await NativeBridge.runInProot('test -f $path && echo "EXISTS"');
    return result.contains('EXISTS');
  }

  /// Downloads a voice model directly into the PRoot environment using curl.
  /// This avoids proxying large bytes through the Flutter layer.
  Future<void> downloadModel(VoiceModel model, Function(double progress) onProgress) async {
    final targetDir = '/root/.openclaw/models/tts';
    await NativeBridge.runInProot('mkdir -p $targetDir');

    // Step 1: Download .onnx.json (Config)
    await NativeBridge.runInProot(
      'curl -L -o $targetDir/${model.id}.onnx.json ${model.configUrl}'
    );

    // Step 2: Download .onnx (Model)
    // Note: We use a simple command here. Real progress would require parsing curl output
    // but for now we'll do a simple fire-and-forget or long-running command.
    onProgress(0.1);
    await NativeBridge.runInProot(
      'curl -L -o $targetDir/${model.id}.onnx ${model.url}'
    );
    onProgress(1.0);
  }

  /// Deletes a model to free up space.
  Future<void> deleteModel(String modelId) async {
    final path = '/root/.openclaw/models/tts/$modelId.onnx';
    final configPath = '/root/.openclaw/models/tts/$modelId.onnx.json';
    await NativeBridge.runInProot('rm -f $path $configPath');
  }
}
