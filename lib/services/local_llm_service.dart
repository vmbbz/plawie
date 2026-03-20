import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'native_bridge.dart';

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
  });

  String get filename => '$id.gguf';
  String get prootModelPath => '/root/.openclaw/models/$filename';
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

  static const int _llamaPort = 8081;
  static const String _llamaHost = '127.0.0.1';

  final _stateController = StreamController<LocalLlmState>.broadcast();
  LocalLlmState _state = const LocalLlmState();

  Stream<LocalLlmState> get stateStream => _stateController.stream;
  LocalLlmState get state => _state;
  List<LocalLlmModel> get catalog => _modelCatalog;

  void _updateState(LocalLlmState s) {
    _state = s;
    _stateController.add(s);
  }

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Download a GGUF model, then start llama-server if not already running.
  Future<void> downloadAndStart(LocalLlmModel model) async {
    if (_state.status == LocalLlmStatus.downloading ||
        _state.status == LocalLlmStatus.starting) {
      return;
    }

    // 1. Ensure models dir exists inside PRoot
    await _ensureModelDir();

    // 2. Check if binary exists, download if not
    final binaryExists = await _isBinaryInstalled();
    if (!binaryExists) {
      await _compileBinary();
      if (_state.status == LocalLlmStatus.error) return;
    }

    // 3. Download model
    final modelExists = await _isModelInstalled(model);
    if (!modelExists) {
      await _downloadModel(model);
      if (_state.status == LocalLlmStatus.error) return;
    }

    // 4. Start server
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

  /// Health check — returns true if llama-server is responding.
  Future<bool> isServerHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_llamaHost:$_llamaPort/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
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

  Future<bool> _isBinaryInstalled() async {
    try {
      final result = await NativeBridge.runInProot(
        'test -x /root/.openclaw/bin/llama-server && echo "exists"',
        timeout: 5,
      );
      return result.trim() == 'exists';
    } catch (_) {
      return false;
    }
  }

  Future<void> _compileBinary() async {
    _updateState(_state.copyWith(
      status: LocalLlmStatus.installing,
      downloadProgress: 0.0,
    ));

    // One-time compile inside PRoot Ubuntu. This takes 10-25 min on a
    // mid-range Snapdragon. After that, the binary at
    // /root/.openclaw/bin/llama-server persists across app restarts.
    //
    // We build only the llama-server target (not the whole project) to
    // minimise compile time.
    const buildScript = r'''
set -e
echo "[llama.cpp] Installing build deps..."
apt-get update -qq && apt-get install -y --no-install-recommends \
  cmake make g++ git ca-certificates 2>&1 | tail -5

echo "[llama.cpp] Cloning repository (shallow)..."
rm -rf /tmp/llama-build
git clone --depth 1 https://github.com/ggerganov/llama.cpp /tmp/llama-build

echo "[llama.cpp] Configuring cmake..."
cmake -B /tmp/llama-build/build \
  -S /tmp/llama-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  2>&1 | tail -5

echo "[llama.cpp] Building llama-server (this takes a while)..."
cmake --build /tmp/llama-build/build \
  --target llama-server \
  --config Release \
  -j4 2>&1 | tail -10

echo "[llama.cpp] Installing binary..."
mkdir -p /root/.openclaw/bin
cp /tmp/llama-build/build/bin/llama-server /root/.openclaw/bin/llama-server
chmod +x /root/.openclaw/bin/llama-server
rm -rf /tmp/llama-build
echo "[llama.cpp] Done."
''';

    try {
      // Long timeout: compiling on ARM64 / 4 threads can take up to 30 min
      // on older devices. Progress is indeterminate during compile.
      _updateState(_state.copyWith(downloadProgress: 0.1));
      await NativeBridge.runInProot(buildScript, timeout: 1800);
      _updateState(_state.copyWith(downloadProgress: 1.0));
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage:
            'llama-server compile failed. Ensure PRoot/Ubuntu is set up and '
            'you have a working internet connection.\n\nError: $e',
      ));
    }
  }


  // --------------------------------------------------------------------------
  // Private — Model Download
  // --------------------------------------------------------------------------

  Future<bool> _isModelInstalled(LocalLlmModel model) async {
    try {
      final result = await NativeBridge.runInProot(
        'test -f "${model.prootModelPath}" && echo "exists"',
        timeout: 5,
      );
      return result.trim() == 'exists';
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
    ));

    try {
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/${model.filename}');

      final request = http.Request('GET', Uri.parse(model.huggingFaceUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw HttpException('Model download failed: HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = tmpFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _updateState(_state.copyWith(downloadProgress: received / total));
        }
      }
      await sink.close();

      // Copy model into PRoot filesystem
      await NativeBridge.runInProot(
        'cp "${tmpFile.path}" "${model.prootModelPath}"',
        timeout: 60,
      );
      await tmpFile.delete();

      _updateState(_state.copyWith(downloadProgress: 1.0));
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Model download failed: $e',
      ));
    }
  }

  // --------------------------------------------------------------------------
  // Private — Process Management
  // --------------------------------------------------------------------------

  Future<void> _startServer(LocalLlmModel model) async {
    _updateState(_state.copyWith(status: LocalLlmStatus.starting));

    // Kill any stale instance first
    try {
      await NativeBridge.runInProot(
        'pkill -f "llama-server" 2>/dev/null; sleep 0.3',
        timeout: 5,
      );
    } catch (_) {}

    // Build the launch command.
    // Key flags per peer review:
    //   --no-mmap   : prevent LMKD kills from large memory-mapped files
    //   --n-gpu-layers 0 : CPU-only (Adreno OpenCL unreliable in PRoot)
    //   --mlock NOT set  : would trigger aggressive Android LMKD
    final cmd = [
      '/root/.openclaw/bin/llama-server',
      '--model "${model.prootModelPath}"',
      '--host $_llamaHost',
      '--port $_llamaPort',
      '--ctx-size ${model.contextWindow}',
      '--threads ${_state.threads}',
      '--n-gpu-layers 0',
      '--no-mmap',
      '--log-disable',
    ].join(' ');

    // Launch in background; nohup keeps it alive after the shell exits
    try {
      await NativeBridge.runInProot(
        'nohup $cmd > /root/.openclaw/llama-server.log 2>&1 &',
        timeout: 10,
      );
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Failed to start llama-server: $e',
      ));
      return;
    }

    // Poll health endpoint for up to 30 seconds
    bool healthy = false;
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (await isServerHealthy()) {
        healthy = true;
        break;
      }
    }

    if (!healthy) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'llama-server did not respond within 30 s. '
            'Check /root/.openclaw/llama-server.log inside PRoot.',
      ));
      return;
    }

    _updateState(_state.copyWith(
      status: LocalLlmStatus.ready,
      activeModelId: model.id,
      downloadProgress: 0.0,
    ));

    // Auto-patch openclaw.json to route through localhost
    await _patchOpenClawConfig(model.id);
  }

  // --------------------------------------------------------------------------
  // Private — openclaw.json patching
  // --------------------------------------------------------------------------

  Future<void> _patchOpenClawConfig(String modelId) async {
    // Find the model metadata
    final model = _modelCatalog.firstWhere(
      (m) => m.id == modelId,
      orElse: () => _modelCatalog[1], // default to 1.5B
    );

    // Inject local provider using the same Node.js script pattern as
    // gateway_service._configureGateway() to stay consistent.
    final modelJson = jsonEncode({
      'id': model.id,
      'name': model.name,
      'contextWindow': model.contextWindow,
      'maxTokens': 4096,
      'cost': {'input': 0, 'output': 0},
    });

    final script = '''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (!c.models) c.models = {};
if (!c.models.providers) c.models.providers = {};

// Merge mode: keep existing cloud providers, add local on top
const existing = c.models.providers["local-llm"] || {};
c.models.providers["local-llm"] = {
  ...existing,
  id: "local-llm",
  baseUrl: "http://127.0.0.1:$_llamaPort/v1",
  api: "openai-completions",
  apiKey: "local",
  models: [$modelJson]
};

// Set local model as the primary default
if (!c.agents) c.agents = {};
if (!c.agents.defaults) c.agents.defaults = {};
if (!c.agents.defaults.model) c.agents.defaults.model = {};
c.agents.defaults.model.primary = "local-llm/${model.id}";

fs.writeFileSync(p, JSON.stringify(c, null, 2));
process.stdout.write("ok");
''';

    try {
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && node -e ${_shellEscape(script)}',
        timeout: 10,
      );
    } catch (e) {
      // Non-fatal — model still runs, user can route manually
    }
  }

  Future<void> _removeLocalProviderFromConfig() async {
    const script = '''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (c.models && c.models.providers) {
  delete c.models.providers["local-llm"];
}
// Restore default primary model
if (c.agents && c.agents.defaults && c.agents.defaults.model) {
  delete c.agents.defaults.model.primary;
}
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    try {
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && node -e ${_shellEscape(script)}',
        timeout: 10,
      );
    } catch (_) {}
  }

  String _shellEscape(String s) {
    // Wrap in single quotes, escaping any embedded single quotes
    final escaped = s.replaceAll("'", "'\\''");
    return "'$escaped'";
  }

  void dispose() {
    _stateController.close();
  }
}
