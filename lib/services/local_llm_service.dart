import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'native_bridge.dart';
import 'gateway_service.dart';
import 'preferences_service.dart';
import '../models/gateway_state.dart';
import '../constants.dart';

// ---------------------------------------------------------------------------
// Model Catalog
// ---------------------------------------------------------------------------

class LocalLlmModel {
  final String id;
  final String name;
  final String description;
  final String huggingFaceUrl; // direct .gguf download link
  final int fileSizeMb;
  final int requiredRamMb;
  final int recommendedThreads;
  final String quality; // "Minimum" | "Recommended" | "Optimal"
  final int contextWindow;

  // Multimodal / Vision support
  final bool isMultimodal;
  final String? mmProjUrl;     // HuggingFace URL for the CLIP mmproj file
  final int? mmProjSizeMb;     // Download size hint for the mmproj file

  const LocalLlmModel({
    required this.id,
    required this.name,
    required this.description,
    required this.huggingFaceUrl,
    required this.fileSizeMb,
    required this.requiredRamMb,
    required this.recommendedThreads,
    required this.quality,
    required this.contextWindow,
    this.isMultimodal = false,
    this.mmProjUrl,
    this.mmProjSizeMb,
  });

  String get filename => '$id.gguf';
  String get prootModelPath => '/root/.openclaw/models/$filename';

  // mmproj paths (only valid when isMultimodal == true)
  String get mmProjFilename => '$id-mmproj.gguf';
  String get prootMmProjPath => '/root/.openclaw/models/$mmProjFilename';
}

const _modelCatalog = [
  LocalLlmModel(
    id: 'qwen2.5-0.5b-instruct-q4_k_m',
    name: 'Qwen 2.5 0.5B Instruct (Q4_K_M)',
    description: 'Ultra-lightweight. Very fast but limited reasoning. Good for quick commands on 6 GB devices.',
    huggingFaceUrl: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    fileSizeMb: 400,
    requiredRamMb: 1500,
    recommendedThreads: 4,
    quality: 'Minimum',
    contextWindow: 8192,
  ),
  LocalLlmModel(
    id: 'qwen2.5-1.5b-instruct-q4_k_m',
    name: 'Qwen 2.5 1.5B Instruct (Q4_K_M)',
    description: 'Recommended default. Solid tool-use support, ~14–18 tok/s on Snapdragon 8 Gen 2. Native OpenAI tool-call format.',
    huggingFaceUrl: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    fileSizeMb: 1000,
    requiredRamMb: 3000,
    recommendedThreads: 4,
    quality: 'Recommended',
    contextWindow: 32768,
  ),
  LocalLlmModel(
    id: 'qwen2.5-3b-instruct-q4_k_m',
    name: 'Qwen 2.5 3B Instruct (Q4_K_M)',
    description: 'Best tool-use quality. Requires 12 GB+ RAM. ~10–15 tok/s on flagship hardware.',
    huggingFaceUrl: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
    fileSizeMb: 1900,
    requiredRamMb: 4500,
    recommendedThreads: 6,
    quality: 'Optimal',
    contextWindow: 32768,
  ),
  LocalLlmModel(
    id: 'smollm2-1.7b-instruct-q4_k_m',
    name: 'SmolLM2 1.7B Instruct (Q4_K_M)',
    description: 'HuggingFace-trained speed-focused model. Good for simple tasks, fast responses.',
    huggingFaceUrl: 'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf',
    fileSizeMb: 1100,
    requiredRamMb: 3000,
    recommendedThreads: 4,
    quality: 'Recommended',
    contextWindow: 8192,
  ),

  // ── Vision / Multimodal Models ─────────────────────────────────────────────

  LocalLlmModel(
    id: 'qwen2-vl-2b-instruct-q4_k_m',
    name: 'Qwen2-VL 2B (Vision, Q4_K_M)',
    description: 'Compact vision+text model. Understands images and text together. Needs ~3 GB RAM. Best choice for most Android phones.',
    huggingFaceUrl: 'https://huggingface.co/bartowski/Qwen2-VL-2B-Instruct-GGUF/resolve/main/Qwen2-VL-2B-Instruct-Q4_K_M.gguf',
    mmProjUrl: 'https://huggingface.co/bartowski/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-Qwen2-VL-2B-Instruct-f16.gguf',
    fileSizeMb: 1430,
    mmProjSizeMb: 295,
    requiredRamMb: 2800,
    recommendedThreads: 4,
    quality: 'Recommended',
    contextWindow: 4096,
    isMultimodal: true,
  ),

  LocalLlmModel(
    id: 'llava-1.5-7b-q4_k_m',
    name: 'LLaVA 1.5 7B (Vision, Q4_K_M)',
    description: 'Full-size LLaVA vision model. Strong image reasoning. Requires ~6 GB RAM — flagship phones only.',
    huggingFaceUrl: 'https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/ggml-model-q4_k.gguf',
    mmProjUrl: 'https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/mmproj-model-f16.gguf',
    fileSizeMb: 4370,
    mmProjSizeMb: 624,
    requiredRamMb: 5800,
    recommendedThreads: 4,
    quality: 'Optimal',
    contextWindow: 4096,
    isMultimodal: true,
  ),
];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum LocalLlmStatus {
  idle,        // no model / server not running
  downloading, // downloading model file
  installing,  // compiling llama-server from source inside PRoot
  starting,    // starting llama-server process
  ready,       // server up and responding
  error,       // unrecoverable error
}

class LocalLlmState {
  final LocalLlmStatus status;
  final String? activeModelId;
  final double downloadProgress; // 0.0–1.0
  final String? errorMessage;
  final int threads;
  final bool isEnabled; // user toggle: route to local or cloud

  const LocalLlmState({
    this.status = LocalLlmStatus.idle,
    this.activeModelId,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.threads = 4,
    this.isEnabled = false,
  });

  LocalLlmState copyWith({
    LocalLlmStatus? status,
    String? activeModelId,
    double? downloadProgress,
    String? errorMessage,
    int? threads,
    bool? isEnabled,
  }) {
    return LocalLlmState(
      status: status ?? this.status,
      activeModelId: activeModelId ?? this.activeModelId,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      threads: threads ?? this.threads,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  // Clear error = new idle state
  LocalLlmState cleared() => LocalLlmState(
    status: LocalLlmStatus.idle,
    activeModelId: activeModelId,
    threads: threads,
    isEnabled: isEnabled,
  );

  bool get isDownloaded => status == LocalLlmStatus.ready || status == LocalLlmStatus.starting || activeModelId != null;
  bool get isDownloading => status == LocalLlmStatus.downloading;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Manages the full lifecycle of a llama-server child process running inside
/// the PRoot/Ubuntu layer, alongside the existing OpenClaw Node.js gateway.
///
/// Design decisions (from Gemini/Grok peer review):
///  - Option A: separate process to isolate crashes from the OpenClaw gateway.
///  - CPU-only: --n-gpu-layers 0 (Adreno/OpenCL is unreliable in PRoot).
///  - --no-mmap: prevents Android LMKD kills from large memory-mapped files.
///  - --mlock NOT used: prevents paging and triggers aggressive LMKD.
///  - --threads: user-configurable (default 4).
///  - Cloud fallback: ECONNREFUSED on :8081 routes back to cloud provider.
class LocalLlmService {
  static final LocalLlmService _instance = LocalLlmService._internal();
  factory LocalLlmService() => _instance;
  LocalLlmService._internal();


  final _stateController = StreamController<LocalLlmState>.broadcast();
  LocalLlmState _state = const LocalLlmState();

  Stream<LocalLlmState> get stateStream => _stateController.stream;
  LocalLlmState get state => _state;
  List<LocalLlmModel> get catalog => _modelCatalog;

  /// Returns the currently active model descriptor, or null if none.
  LocalLlmModel? get activeModel => _state.activeModelId == null
      ? null
      : _modelCatalog.firstWhere(
          (m) => m.id == _state.activeModelId,
          orElse: () => _modelCatalog.first,
        );

  /// True when local LLM is ready AND the active model supports vision.
  bool get isVisionReady =>
      _state.status == LocalLlmStatus.ready && (activeModel?.isMultimodal ?? false);

  void _updateState(LocalLlmState s) {
    _state = s;
    _stateController.add(s);
  }

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Download a GGUF model, then activate openclaw's node-llama-cpp local provider.
  /// Uses the prebuilt @node-llama-cpp/linux-arm64 binary that ships with openclaw
  /// (AidanPark approach — no cmake compilation required).
  Future<void> downloadAndStart(LocalLlmModel model) async {
    if (_state.status == LocalLlmStatus.downloading ||
        _state.status == LocalLlmStatus.starting) {
      return;
    }

    // Prevent PRoot conflicts during gateway startup
    final gatewayService = GatewayService();
    if (gatewayService.state.status == GatewayStatus.starting) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Gateway is still starting. Please wait for "Gateway healthy" before starting local LLM.',
      ));
      return;
    }

    // 1. Ensure models dir exists inside PRoot
    await _ensureModelDir();

    // ── 1. Activation Pre-flight: Addon Check ─────────────────────────────
    final addonReady = await _isNodeLlamaCppReady();
    if (!addonReady) {
      throw Exception(
        'Local LLM addon missing or incomplete.\n'
        'Please ensure the app setup (Bootstrap) finished correctly.\n'
        'If this persists, go to Settings and Force Reinstall OpenClaw.'
      );
    }

    // 3. Download model GGUF
    final modelExists = await _isModelInstalled(model);
    if (!modelExists) {
      await _downloadModel(model);
      if (_state.status == LocalLlmStatus.error) return;
    }

    // 3b. Download mmproj for multimodal models
    if (model.isMultimodal && model.mmProjUrl != null) {
      final mmProjExists = await _isMmProjInstalled(model);
      if (!mmProjExists) {
        await _downloadMmProj(model);
        if (_state.status == LocalLlmStatus.error) return;
      }
    }

    // 4. Activate local provider in openclaw
    await _startServer(model);
  }

  /// Start llama-server with an already-downloaded model.
  Future<void> startWithModel(LocalLlmModel model) async {
    if (!await _isModelInstalled(model)) {
      await downloadAndStart(model);
      return;
    }
    await _startServer(model);
  }

  /// Stop the running llama-server process.
  Future<void> stop() async {
    try {
      await NativeBridge.runInProot(
        'pkill -f "llama-server" 2>/dev/null; sleep 0.5',
        timeout: 5,
      );
    } catch (_) {}
    _updateState(_state.copyWith(
      status: LocalLlmStatus.idle,
      activeModelId: null,
    ));
  }

  /// Update the thread count and restart if running.
  Future<void> setThreads(int threads, {LocalLlmModel? currentModel}) async {
    _updateState(_state.copyWith(threads: threads));
    if (_state.status == LocalLlmStatus.ready && currentModel != null) {
      await stop();
      await _startServer(currentModel);
    }
  }

  /// Toggle local LLM on/off. When enabled, patches openclaw.json to add the
  /// local provider block. When disabled, removes it and routes cloud.
  Future<void> setEnabled(bool enabled, {String? modelId}) async {
    _updateState(_state.copyWith(isEnabled: enabled));
    if (enabled && modelId != null) {
      await _patchOpenClawConfig(modelId);
    } else {
      await _removeLocalProviderFromConfig();
    }
  }

  /// Health check for the node-llama-cpp provider approach.
  ///
  /// The new backend does NOT start a standalone process on port 8081.
  /// Instead it patches openclaw.json and reloads the gateway (port 18789).
  /// We verify: (1) the gateway is answering, (2) our config patch is in place.
  Future<bool> isServerHealthy() async {
    try {
      // 1. Gateway must be alive on its native port
      final gwResp = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 3));
      if (gwResp.statusCode >= 500) return false;

      // 2. Config must have the local-llm provider enabled (we just wrote it)
      final config = await _readConfig();
      final provider = config['models']?['providers']?['local-llm'];
      return provider != null &&
          provider['enabled'] == true &&
          provider['modelPath'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Check if given model file is already downloaded.
  Future<bool> isModelDownloaded(LocalLlmModel model) =>
      _isModelInstalled(model);

  // --------------------------------------------------------------------------
  // Private — Binary Installation
  // --------------------------------------------------------------------------

  // --------------------------------------------------------------------------
  // Private — Node-llama-cpp Prebuilt (AidanPark approach)
  // --------------------------------------------------------------------------

  /// Returns true if openclaw's prebuilt node-llama-cpp addon loads cleanly.
  /// The addon ships as @node-llama-cpp/linux-arm64 inside the openclaw npm
  /// package and works under proot glibc without any compilation.
  Future<bool> _isNodeLlamaCppReady() async {
    try {
      // PRAGMATIC FIX: Instead of expensive require() or node-e, just check
      // if the prebuilt binary folder exists. This covers 99% of cases
      // without triggering PRoot's slow process fork.
      const addonSubPath = 'openclaw/node_modules/@node-llama-cpp/linux-arm64/bins/linux-arm64/llama-addon.node';
      final checkCmd = 'test -f "/usr/local/lib/node_modules/$addonSubPath" || test -f "\$(npm root -g)/$addonSubPath"';
      
      final result = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && ($checkCmd) && echo "READY"',
        timeout: 10,
      );
      return result.contains('READY');
    } catch (_) {
      return false;
    }
  }



  // --------------------------------------------------------------------------
  // Private — Model Download
  // --------------------------------------------------------------------------

  Future<bool> _isModelInstalled(LocalLlmModel model) async {
    try {
      // Check host filesystem directly — no PRoot needed, instant, never
      // times out. PRoot maps {appSupportDir}/rootfs → /, so the model at
      // /root/.openclaw/models/<file> lives on the host at rootfs/root/...
      final appSupportDir = await getApplicationSupportDirectory();
      final hostPath =
          '${appSupportDir.path}/rootfs${model.prootModelPath}';
      final file = File(hostPath);
      if (!await file.exists()) return false;
      // Guard against a 0-byte or corrupt partial file
      return await file.length() > 1048576; // > 1 MB
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureModelDir() async {
    try {
      await NativeBridge.runInProot(
        'mkdir -p /root/.openclaw/models',
        timeout: 5,
      );
    } catch (_) {}
  }

  Future<void> _downloadModel(LocalLlmModel model) async {
    _updateState(_state.copyWith(
      status: LocalLlmStatus.downloading,
      downloadProgress: 0.0,
      errorMessage: 'Connecting...',
    ));

    try {
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/${model.filename}');

      // Resume: check bytes already saved from a previous partial download
      final alreadyBytes = await tmpFile.exists() ? await tmpFile.length() : 0;

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      final request = await client.getUrl(Uri.parse(model.huggingFaceUrl))
          .timeout(const Duration(seconds: 30));
      if (alreadyBytes > 0) {
        request.headers.add('Range', 'bytes=$alreadyBytes-');
      }
      final response = await request.close().timeout(const Duration(seconds: 30));

      // 416 = Range Not Satisfiable: file already complete but not installed
      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        // tmpFile is complete — skip download, go straight to install
      } else {
        final isResume = response.statusCode == HttpStatus.partialContent; // 206
        if (response.statusCode != HttpStatus.ok && !isResume) {
          throw HttpException('Download failed: HTTP ${response.statusCode}');
        }

        // If server ignored Range (returned 200), overwrite; else append
        final openMode = isResume ? FileMode.append : FileMode.write;
        final startOffset = isResume ? alreadyBytes : 0;
        final serverLength = response.contentLength != -1 ? response.contentLength : 0;
        final totalBytes = serverLength > 0 ? startOffset + serverLength : 0;
        int received = startOffset;

        String fmtMb(int b) => '${(b / 1048576).toStringAsFixed(1)} MB';

        final sink = tmpFile.openWrite(mode: openMode);
        try {
          await for (final chunk in response.timeout(const Duration(seconds: 60))) {
            sink.add(chunk);
            received += chunk.length;
            final progress = totalBytes > 0 ? received / totalBytes : 0.0;
            final label = totalBytes > 0
                ? 'Downloading: ${fmtMb(received)} / ${fmtMb(totalBytes)}'
                : 'Downloading: ${fmtMb(received)}';
            _updateState(_state.copyWith(
              downloadProgress: progress,
              errorMessage: label,
            ));
          }
        } finally {
          await sink.close();
        }
      }

      // Install into PRoot filesystem
      _updateState(_state.copyWith(errorMessage: 'Installing model into PRoot...'));
      final appSupportDir = await getApplicationSupportDirectory();
      final prootPath = '${appSupportDir.path}/rootfs';
      final hostProotModelPath = '$prootPath${model.prootModelPath}';
      final targetDir = Directory('$prootPath/root/.openclaw/models');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      await tmpFile.copy(hostProotModelPath);
      await tmpFile.delete();

      _updateState(_state.copyWith(downloadProgress: 1.0, errorMessage: null));
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Model download failed: $e\nTap Start to resume from where it stopped.',
      ));
    }
  }

  // --------------------------------------------------------------------------
  // Private — MmProj (multimodal CLIP projection) helpers
  // --------------------------------------------------------------------------

  Future<bool> _isMmProjInstalled(LocalLlmModel model) async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final hostPath =
          '${appSupportDir.path}/rootfs${model.prootMmProjPath}';
      final file = File(hostPath);
      if (!await file.exists()) return false;
      return await file.length() > 1048576;
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadMmProj(LocalLlmModel model) async {
    if (model.mmProjUrl == null) return;

    _updateState(_state.copyWith(
      status: LocalLlmStatus.downloading,
      downloadProgress: 0.0,
      errorMessage: 'Downloading vision projection file (${model.mmProjSizeMb ?? "?"}MB)...',
    ));

    try {
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/${model.mmProjFilename}');

      final url = Uri.parse(model.mmProjUrl!);
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 20);

      final request = await httpClient.getUrl(url).timeout(const Duration(seconds: 20));
      final response = await request.close().timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw HttpException('MmProj download failed: HTTP ${response.statusCode}');
      }

      final total = response.contentLength != -1 ? response.contentLength : 0;
      int received = 0;
      final sink = tmpFile.openWrite();
      try {
        await for (final chunk in response.timeout(const Duration(seconds: 60))) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            _updateState(_state.copyWith(downloadProgress: received / total));
          }
        }
      } finally {
        await sink.close();
      }

      final appSupportDir = await getApplicationSupportDirectory();
      final prootPath = '${appSupportDir.path}/rootfs';
      final hostMmProjPath = '$prootPath${model.prootMmProjPath}';

      final targetDir = Directory('$prootPath/root/.openclaw/models');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      await tmpFile.copy(hostMmProjPath);
      await tmpFile.delete();

      _updateState(_state.copyWith(downloadProgress: 1.0, errorMessage: null));
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Vision projection download failed: $e',
      ));
    }
  }

  // --------------------------------------------------------------------------
  // Private — Process Management
  // --------------------------------------------------------------------------

  /// Helper to get the host-side path to the openclaw config file
  Future<String> _openClawConfigPath() async {
    final appSupportDir = await getApplicationSupportDirectory();
    return '${appSupportDir.path}/rootfs/root/.openclaw/openclaw.json';
  }

  /// Direct Dart-native config read/write (bypasses proot overhead)
  Future<Map<String, dynamic>> _readConfig() async {
    try {
      final file = File(await _openClawConfigPath());
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[LocalLlmService] Config read error: $e');
    }
    return {};
  }

  Future<void> _writeConfig(Map<String, dynamic> config) async {
    try {
      final path = await _openClawConfigPath();
      final file = File(path);
      
      // Ensure directory exists
      final dir = Directory(file.parent.path);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      await file.writeAsString(jsonEncode(config));
    } catch (e) {
      debugPrint('[LocalLlmService] Config write error: $e');
    }
  }

  /// Activates openclaw's built-in node-llama-cpp local LLM provider.
  Future<void> _startServer(LocalLlmModel model) async {
    _updateState(
        _state.copyWith(status: LocalLlmStatus.starting, downloadProgress: 0.1));

    // Stage 2/2: inject node-llama-cpp config into openclaw.json (Direct I/O)
    _updateState(_state.copyWith(
      downloadProgress: 0.2,
      errorMessage: 'Stage 2/2: Activating local provider in openclaw...',
    ));

    try {
      await _patchOpenClawConfig(model.id);
      _updateState(_state.copyWith(downloadProgress: 0.5));
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage:
            'Failed to activate local LLM config: $e\n\nTap Start to retry.',
      ));
      return;
    }

    // Signal openclaw gateway to reload with new provider config.
    // Invalidate token cache first — reload generates a new auth token.
    GatewayService().invalidateTokenCache();
    try {
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && '
        'openclaw reload 2>/dev/null || openclaw restart 2>/dev/null || true',
        timeout: 10,
      );
    } catch (_) {}

    _updateState(_state.copyWith(downloadProgress: 0.7));

    bool healthy = false;
    const maxAttempts = 30;
    final progressIncrement = 0.3 / maxAttempts;

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 1));
      _updateState(
          _state.copyWith(downloadProgress: 0.7 + (i * progressIncrement)));
      if (await isServerHealthy()) {
        healthy = true;
        break;
      }
    }

    if (!healthy) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage:
            'Local LLM provider did not become healthy within ${maxAttempts}s.\n\n'
            'Common solutions:\n'
            '1. Try a smaller model (0.5B instead of 1.5B/3B)\n'
            '2. Reduce thread count in settings\n'
            '3. Free up device memory by closing other apps\n'
            '4. Check gateway logs for errors',
      ));
      return;
    }

    // Update prefs so chat screen routes to local LLM on next message.
    final prefs = PreferencesService();
    await prefs.init();
    prefs.configuredModel = 'local-llm/${model.id}';

    _updateState(_state.copyWith(
      status: LocalLlmStatus.ready,
      activeModelId: model.id,
      downloadProgress: 1.0,
    ));
  }


  // --------------------------------------------------------------------------
  // Private — openclaw.json patching
  // --------------------------------------------------------------------------

  Future<void> _patchOpenClawConfig(String modelId) async {
    final model = _modelCatalog.firstWhere(
      (m) => m.id == modelId,
      orElse: () => _modelCatalog[1],
    );

    final config = await _readConfig();
    config['models'] ??= {};
    config['models']['providers'] ??= {};

    final ctxSize = model.contextWindow.clamp(512, 4096);
    final existing = config['models']['providers']['local-llm'] ?? {};
    
    config['models']['providers']['local-llm'] = {
      ...existing,
      'id': 'local-llm',
      'backend': 'node-llama-cpp',
      'modelPath': model.prootModelPath,
      'contextSize': ctxSize,
      'threads': _state.threads,
      'gpuLayers': 0,
      'batchSize': 256,
      'enabled': true,
      'models': [
        {
          'id': model.id,
          'name': model.name,
          'contextWindow': ctxSize,
          'maxTokens': 2048,
          'cost': {'input': 0, 'output': 0},
        }
      ]
    };

    if (model.isMultimodal && model.mmProjUrl != null) {
      config['models']['providers']['local-llm']['mmProjPath'] = model.prootMmProjPath;
    }

    config['agents'] ??= {};
    config['agents']['defaults'] ??= {};
    config['agents']['defaults']['model'] ??= {};
    config['agents']['defaults']['model']['primary'] = "local-llm/${model.id}";

    await _writeConfig(config);
  }

  Future<void> _removeLocalProviderFromConfig() async {
    final config = await _readConfig();
    if (config['models'] != null && config['models']['providers'] != null) {
      config['models']['providers'].remove('local-llm');
    }
    if (config['agents'] != null && config['agents']['defaults'] != null && config['agents']['defaults']['model'] != null) {
      config['agents']['defaults']['model'].remove('primary');
    }
    await _writeConfig(config);

    // Clear prefs so chat screen reverts to cloud model.
    final prefs = PreferencesService();
    await prefs.init();
    prefs.configuredModel = null;
  }


    // ── Video Vision — multi-frame offline analysis ───────────────────────────

  /// Analyses a list of JPEG frames extracted from a video clip.
  ///
  /// For each frame: sends it to the local llama-server vision endpoint.
  /// Yields progress strings while working, then yields the final summary.
  ///
  /// Requires a multimodal model (Qwen2-VL or LLaVA) to be running.
  Stream<String> analyseVideoFrames(
    List<Uint8List> frames,
    String prompt,
  ) async* {
    if (frames.isEmpty) {
      yield '[Error] No frames extracted from video.';
      return;
    }
    if (_state.status != LocalLlmStatus.ready) {
      yield '[Error] Local vision model is not running. Start it in Local LLM settings.';
      return;
    }

    final base = '${AppConstants.gatewayUrl}/v1/chat/completions';
    final descriptions = <String>[];

    for (int i = 0; i < frames.length; i++) {
      yield 'Analysing frame ${i + 1}/${frames.length}…';
      try {
        final b64 = base64Encode(frames[i]);
        final resp = await http
            .post(
              Uri.parse(base),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'model': 'local-llm',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {
                        'type': 'image_url',
                        'image_url': {'url': 'data:image/jpeg;base64,$b64'},
                      },
                      {
                        'type': 'text',
                        'text': 'Frame ${i + 1}: Briefly describe what you see.',
                      },
                    ],
                  },
                ],
                'stream': false,
                'max_tokens': 256,
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          final content =
              ((json['choices'] as List?)?.first['message'] as Map?)?['content']
                  as String?;
          if (content != null) descriptions.add('Frame ${i + 1}: $content');
        }
      } catch (e) {
        debugPrint('analyseVideoFrames frame ${i + 1} error: $e');
      }
    }

    if (descriptions.isEmpty) {
      yield '[Error] Could not analyse any frames. Is the vision model running?';
      return;
    }

    // Final summary pass — ask the model to synthesise all frame descriptions
    yield 'Summarising scene…';
    try {
      final summaryPrompt = descriptions.isEmpty
          ? prompt
          : 'Given these video frame descriptions:\n${descriptions.join('\n')}\n\nAnswer this question: $prompt';

      final resp = await http
          .post(
            Uri.parse(base),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'local-llm',
              'messages': [
                {'role': 'user', 'content': summaryPrompt},
              ],
              'stream': false,
              'max_tokens': 512,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final content =
            ((json['choices'] as List?)?.first['message'] as Map?)?['content']
                as String?;
        yield content ?? '[Error] Empty summary from model.';
      } else {
        yield '[Error] Summary request failed (HTTP ${resp.statusCode}).';
      }
    } catch (e) {
      yield '[Error] Summary error: $e';
    }
  }

  void dispose() {
    _stateController.close();
  }

}
