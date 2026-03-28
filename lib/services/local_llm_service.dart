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
    bool clearErrorMessage = false,
    int? threads,
    bool? isEnabled,
  }) {
    return LocalLlmState(
      status: status ?? this.status,
      activeModelId: activeModelId ?? this.activeModelId,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
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
class LocalLlmService {
  static final LocalLlmService _instance = LocalLlmService._internal();
  factory LocalLlmService() => _instance;
  LocalLlmService._internal() {
    // Monitor the gateway: if it crashes after local LLM is ready, reflect that.
    GatewayService().stateStream.listen((gwState) {
      if (_state.status == LocalLlmStatus.ready &&
          (gwState.status == GatewayStatus.stopped ||
           gwState.status == GatewayStatus.error)) {
        _updateState(_state.copyWith(
          status: LocalLlmStatus.error,
          errorMessage: 'Gateway stopped unexpectedly. Tap Start to reload the model.',
        ));
      }
    });
  }

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

  /// Download GGUF + ensure llama-server binary + start the server.
  Future<void> downloadAndStart(LocalLlmModel model) async {
    if (_state.status == LocalLlmStatus.downloading ||
        _state.status == LocalLlmStatus.starting ||
        _state.status == LocalLlmStatus.installing) {
      return;
    }

    // Prevent PRoot conflicts during gateway startup
    if (GatewayService().state.status == GatewayStatus.starting) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Gateway is still starting. Wait for "Gateway healthy" before starting local LLM.',
      ));
      return;
    }

    await _ensureModelDir();

    // Download model GGUF if needed
    if (!await _isModelInstalled(model)) {
      await _downloadModel(model);
      if (_state.status == LocalLlmStatus.error) return;
    }

    // Download mmproj for multimodal models
    if (model.isMultimodal && model.mmProjUrl != null) {
      if (!await _isMmProjInstalled(model)) {
        await _downloadMmProj(model);
        if (_state.status == LocalLlmStatus.error) return;
      }
    }

    await _startLlamaServer(model);
  }

  /// Start llama-server with an already-downloaded model.
  Future<void> startWithModel(LocalLlmModel model) async {
    // No-op if this exact model is already running.
    if (_state.status == LocalLlmStatus.ready && _state.activeModelId == model.id) return;
    if (!await _isModelInstalled(model)) {
      await downloadAndStart(model);
      return;
    }
    await _startLlamaServer(model);
  }

  /// Kill the llama-server tmux session and reset state.
  Future<void> stop() async {
    try {
      await NativeBridge.runInProot(
        'tmux kill-session -t llama-server 2>/dev/null; '
        'pkill -f "node.*local-server/server.js" 2>/dev/null || true',
        timeout: 5,
      );
    } catch (_) {}
    _updateState(_state.copyWith(
      status: LocalLlmStatus.idle,
      activeModelId: null,
      isEnabled: false,
    ));
  }

  /// Update thread count and restart if already running.
  Future<void> setThreads(int threads, {LocalLlmModel? currentModel}) async {
    _updateState(_state.copyWith(threads: threads));
    if (_state.status == LocalLlmStatus.ready && currentModel != null) {
      await stop();
      await _startLlamaServer(currentModel);
    }
  }

  /// Toggle local LLM on/off.
  Future<void> setEnabled(bool enabled, {String? modelId}) async {
    if (enabled && modelId != null) {
      final model = _modelCatalog.firstWhere((m) => m.id == modelId);
      await startWithModel(model);
    } else {
      await stop();
    }
  }

  /// Alias for startWithModel to satisfy UI expectations.
  Future<void> activateModel(LocalLlmModel model) => startWithModel(model);

  /// Test inference — streams directly from llama-server on :8081.
  /// No gateway involvement. No disabledUntil. No WS session race.
  Stream<String> testInference(String prompt) async* {
    if (_state.status != LocalLlmStatus.ready) {
      yield '[Error] Local LLM is not ready. Status: ${_state.status}';
      return;
    }
    final base = '${AppConstants.llamaServerUrl}/v1/chat/completions';
    try {
      final request = http.Request('POST', Uri.parse(base));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': 'local',
        'messages': [{'role': 'user', 'content': prompt}],
        'stream': true,
      });
      final response = await http.Client().send(request).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        yield '[Error] Inference failed (HTTP ${response.statusCode})';
        return;
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            final content = json['choices'][0]['delta']['content'] as String?;
            if (content != null) yield content;
          } catch (_) {}
        }
      }
    } catch (e) {
      yield '[Error] Connection failed: $e';
    }
  }

  /// Returns the raw JSON body from llama-server's /health endpoint,
  /// or an error string if the server is unreachable.
  Future<String> fetchServerHealth() async {
    try {
      final resp = await http
          .get(Uri.parse('${AppConstants.llamaServerUrl}/health'))
          .timeout(const Duration(seconds: 5));
      return 'HTTP ${resp.statusCode} — ${resp.body.trim()}';
    } catch (e) {
      return 'Unreachable: $e';
    }
  }

  /// Returns the last 30 lines of the llama-server log from inside PRoot.
  Future<String> fetchServerLogs() async {
    try {
      final out = await NativeBridge.runInProot(
        'tail -30 /root/.openclaw/llama-server.log 2>/dev/null || echo "(log empty)"',
        timeout: 8,
      );
      return out.trim().isEmpty ? '(log empty)' : out.trim();
    } catch (e) {
      return 'Could not read log: $e';
    }
  }

  /// Processes a list of JPEG frames extracted from a video clip.
  /// Sends each frame to the gateway's vision endpoint.
  Stream<String> analyseVideoFrames(List<Uint8List> frames, String summaryPrompt) async* {
    if (frames.isEmpty) {
      yield '[Error] No frames extracted from video.';
      return;
    }

    if (_state.status != LocalLlmStatus.ready) {
      yield '[Error] Local vision model is not running. Start it in Local LLM settings.';
      return;
    }

    _updateState(_state.copyWith(downloadProgress: 0.3));

    final base = '${AppConstants.llamaServerUrl}/v1/chat/completions';
    try {
      // Step 1: Send the visual summary request
      final resp = await http.post(
        Uri.parse(base),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'local-llm',
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': summaryPrompt},
                ...frames.map((f) => {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(f)}'}
                })
              ]
            },
          ],
          'stream': false,
          'max_tokens': 512,
        }),
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final content = ((json['choices'] as List?)?.first['message'] as Map?)?['content'] as String?;
        yield content ?? '[Error] Empty summary from model.';
      } else {
        yield '[Error] Summary request failed (HTTP ${resp.statusCode}).';
      }
    } catch (e) {
      yield '[Error] Summary error: $e';
    } finally {
      _updateState(_state.copyWith(downloadProgress: 1.0));
    }
  }

  /// Health check: probe llama-server's /health endpoint on :8081.
  /// Returns true only when the server is up and the model is fully loaded.
  Future<bool> isServerHealthy() async {
    try {
      final resp = await http
          .get(Uri.parse('${AppConstants.llamaServerUrl}/health'))
          .timeout(const Duration(seconds: 3));
      // llama-server returns {"status":"ok"} when the model is loaded.
      // Any 200 response means it's ready; non-200 means still loading.
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Check if given model file is already downloaded.
  Future<bool> isModelDownloaded(LocalLlmModel model) =>
      _isModelInstalled(model);

  // --------------------------------------------------------------------------
  // Private — Model Download
  // --------------------------------------------------------------------------

  Future<bool> _isModelInstalled(LocalLlmModel model) async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final hostPath = '$filesDir/rootfs${model.prootModelPath}';
      final file = File(hostPath);
      if (!await file.exists()) return false;
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
      final alreadyBytes = await tmpFile.exists() ? await tmpFile.length() : 0;

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      final request = await client.getUrl(Uri.parse(model.huggingFaceUrl))
          .timeout(const Duration(seconds: 30));
      if (alreadyBytes > 0) {
        request.headers.add('Range', 'bytes=$alreadyBytes-');
      }
      final response = await request.close().timeout(const Duration(seconds: 30));

      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
      } else {
        final isResume = response.statusCode == HttpStatus.partialContent; // 206
        if (response.statusCode != HttpStatus.ok && !isResume) {
          throw HttpException('Download failed: HTTP ${response.statusCode}');
        }

        final openMode = isResume ? FileMode.append : FileMode.write;
        final startOffset = isResume ? alreadyBytes : 0;
        final serverLength = response.contentLength != -1 ? response.contentLength : 0;
        final totalBytes = serverLength > 0 ? startOffset + serverLength : 0;
        int received = startOffset;

        final sink = tmpFile.openWrite(mode: openMode);
        try {
          await for (final chunk in response.timeout(const Duration(seconds: 60))) {
            sink.add(chunk);
            received += chunk.length;
            final progress = totalBytes > 0 ? received / totalBytes : 0.0;
            _updateState(_state.copyWith(
              downloadProgress: progress,
              errorMessage: 'Downloading: ${(received/1048576).toStringAsFixed(1)} MB',
            ));
          }
        } finally {
          await sink.close();
        }
      }

      _updateState(_state.copyWith(errorMessage: 'Installing model into PRoot...'));
      final filesDir = await NativeBridge.getFilesDir();
      final prootPath = '$filesDir/rootfs';
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
        errorMessage: 'Model download failed: $e',
      ));
    }
  }

  Future<bool> _isMmProjInstalled(LocalLlmModel model) async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final hostPath = '$filesDir/rootfs${model.prootMmProjPath}';
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
      errorMessage: 'Downloading vision projection file...',
    ));

    try {
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/${model.mmProjFilename}');
      final url = Uri.parse(model.mmProjUrl!);
      final request = await HttpClient().getUrl(url).timeout(const Duration(seconds: 20));
      final response = await request.close().timeout(const Duration(seconds: 20));

      final total = response.contentLength != -1 ? response.contentLength : 0;
      int received = 0;
      final sink = tmpFile.openWrite();
      try {
        await for (final chunk in response.timeout(const Duration(seconds: 60))) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) _updateState(_state.copyWith(downloadProgress: received / total));
        }
      } finally {
        await sink.close();
      }

      final filesDir = await NativeBridge.getFilesDir();
      final prootPath = '$filesDir/rootfs';
      final hostMmProjPath = '$prootPath${model.prootMmProjPath}';
      final targetDir = Directory('$prootPath/root/.openclaw/models');
      if (!await targetDir.exists()) await targetDir.create(recursive: true);
      await tmpFile.copy(hostMmProjPath);
      await tmpFile.delete();
      _updateState(_state.copyWith(downloadProgress: 1.0, errorMessage: null));
    } catch (e) {
      _updateState(_state.copyWith(status: LocalLlmStatus.error, errorMessage: 'Vision projection download failed: $e'));
    }
  }

  // --------------------------------------------------------------------------
  // Private — llama HTTP server (node-llama-cpp standalone)
  // --------------------------------------------------------------------------

  /// Host path of the embedded server script.
  /// Written to /root/.openclaw/ (always exists) — avoids creating new dirs from Flutter.
  Future<String> _llamaHttpServerScriptPath() async {
    final filesDir = await NativeBridge.getFilesDir();
    return '$filesDir/rootfs/root/.openclaw/llama-server.js';
  }

  /// True once npm install has completed (node_modules is present).
  Future<bool> _isLlamaHttpServerReady() async {
    final scriptPath = await _llamaHttpServerScriptPath();
    if (!File(scriptPath).existsSync()) return false;
    final filesDir = await NativeBridge.getFilesDir();
    return Directory(
      '$filesDir/rootfs/root/.openclaw/local-server/node_modules/node-llama-cpp',
    ).existsSync();
  }

  /// Write server.js + package.json to /root/.openclaw/ (guaranteed to exist),
  /// then let PRoot create the local-server subdir and run npm install inside it.
  Future<void> _setupLlamaHttpServer() async {
    _updateState(_state.copyWith(
      status: LocalLlmStatus.installing,
      downloadProgress: 0.0,
      errorMessage: 'Setting up llama HTTP server...',
    ));

    // Write both files into /root/.openclaw/ — this dir always exists (openclaw config lives here).
    final filesDir = await NativeBridge.getFilesDir();
    final openclawDir = '$filesDir/rootfs/root/.openclaw';

    await File('$openclawDir/llama-server.js').writeAsString(_llamaHttpServerScript);
    await File('$openclawDir/llama-pkg.json').writeAsString(
      '{"name":"llama-http-server","version":"1.0.0","dependencies":{"node-llama-cpp":"3"}}',
    );

    _updateState(_state.copyWith(
      downloadProgress: 0.1,
      errorMessage: 'Downloading node-llama-cpp ARM64 (~50 MB, one-time)...',
    ));

    // PRoot creates the subdir, copies package.json, and runs npm install.
    // Using PRoot's own mkdir guarantees the directory exists in PRoot's namespace.
    await NativeBridge.runInProot(
      'mkdir -p /root/.openclaw/local-server && '
      'cp /root/.openclaw/llama-pkg.json /root/.openclaw/local-server/package.json && '
      'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
      'cd /root/.openclaw/local-server && npm install 2>&1 | tail -10',
      timeout: 600,
    );

    _updateState(_state.copyWith(downloadProgress: 1.0, errorMessage: null));
  }

  Future<void> _ensureLlamaHttpServer() async {
    if (!await _isLlamaHttpServerReady()) await _setupLlamaHttpServer();
  }

  // Embedded server.js — no network fetch, written to PRoot rootfs at setup time.
  static const String _llamaHttpServerScript = r"""
'use strict';
const http = require('http');
const { getLlama, LlamaChatSession } = require('node-llama-cpp');

const PORT = parseInt(process.env.PORT || '8081');
const MODEL = process.argv[2];
const CTX = parseInt(process.env.CTX_SIZE || '2048');

if (!MODEL) { console.error('Usage: node server.js <model-path>'); process.exit(1); }

let ready = false, llama, model, ctx;

async function init() {
  llama = await getLlama();
  model = await llama.loadModel({ modelPath: MODEL });
  ctx = await model.createContext({ contextSize: CTX });
  ready = true;
  console.log('[llama-http] ready port=' + PORT);
}

http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: ready ? 'ok' : 'loading' }));
  }
  if (req.method === 'POST' && req.url === '/v1/chat/completions') {
    if (!ready) { res.writeHead(503); return res.end(JSON.stringify({ error: 'loading' })); }
    let body = '';
    req.on('data', d => body += d);
    req.on('end', async () => {
      try {
        const { messages, stream } = JSON.parse(body);
        const seq = ctx.getSequence();
        const session = new LlamaChatSession({ contextSequence: seq });
        const prompt = messages.filter(m => m.role === 'user').pop()?.content || '';
        if (stream) {
          res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' });
          await session.prompt(prompt, {
            onTextChunk(t) {
              res.write('data: ' + JSON.stringify({ choices: [{ delta: { content: t }, finish_reason: null }] }) + '\n\n');
            }
          });
          res.write('data: [DONE]\n\n');
          res.end();
        } else {
          const text = await session.prompt(prompt);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ choices: [{ message: { role: 'assistant', content: text } }] }));
        }
      } catch (e) { res.writeHead(500); res.end(JSON.stringify({ error: String(e) })); }
    });
    return;
  }
  res.writeHead(404); res.end();
}).listen(PORT, '127.0.0.1');

init().catch(e => { console.error('[llama-http] init failed:', e); process.exit(1); });
""";

  // --------------------------------------------------------------------------
  // Private — llama-server lifecycle
  // --------------------------------------------------------------------------

  Future<void> _startLlamaServer(LocalLlmModel model) async {
    _updateState(_state.copyWith(
      status: LocalLlmStatus.starting,
      downloadProgress: 0.1,
      clearErrorMessage: true,
    ));

    // Ensure node-llama-cpp HTTP server is installed (one-time npm install).
    try {
      await _ensureLlamaHttpServer();
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Failed to install llama HTTP server: $e',
      ));
      return;
    }

    _updateState(_state.copyWith(status: LocalLlmStatus.starting, downloadProgress: 0.3));

    // Kill any existing session before starting a new one.
    try {
      await NativeBridge.runInProot(
        'tmux kill-session -t llama-server 2>/dev/null; '
        'pkill -f "node.*local-server/server.js" 2>/dev/null || true',
        timeout: 5,
      );
    } catch (_) {}

    final ctxSize = model.contextWindow.clamp(512, 4096);
    final modelPath = model.prootModelPath;

    final launchCmd =
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'CTX_SIZE=$ctxSize PORT=${AppConstants.llamaServerPort} '
        'node /root/.openclaw/llama-server.js $modelPath';

    // Start in a detached tmux session so it survives PRoot foreground exit.
    final tmuxCmd =
        'mkdir -p /root/.openclaw && '
        'tmux new-session -d -s llama-server \'$launchCmd '
        '>> /root/.openclaw/llama-server.log 2>&1\'';

    try {
      await NativeBridge.runInProot(tmuxCmd, timeout: 10);
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Failed to start llama server: $e',
      ));
      return;
    }

    _updateState(_state.copyWith(downloadProgress: 0.5));

    // Poll /health until llama-server finishes loading the model.
    // The server only responds 200 once the GGUF is fully mapped into RAM.
    bool healthy = false;
    const maxAttempts = 120; // 2 min for large models on slow phones
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 1));
      _updateState(_state.copyWith(downloadProgress: 0.5 + (i * 0.5 / maxAttempts)));
      if (await isServerHealthy()) {
        healthy = true;
        break;
      }
    }

    if (!healthy) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'llama-server did not become healthy within 2 minutes.',
      ));
      return;
    }

    final prefs = PreferencesService();
    await prefs.init();
    prefs.configuredModel = 'local-llm/${model.id}';

    _updateState(_state.copyWith(
      status: LocalLlmStatus.ready,
      activeModelId: model.id,
      downloadProgress: 1.0,
    ));
  }
}
