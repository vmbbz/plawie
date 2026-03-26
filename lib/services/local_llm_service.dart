import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'native_bridge.dart';
import 'gateway_service.dart';
import '../models/gateway_state.dart';

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

  static const int _llamaPort = 8081;
  static const String _llamaHost = '127.0.0.1';

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

  /// Download a GGUF model, then start llama-server if not already running.
  /// OPTIMIZED: Prevents PRoot conflicts by checking gateway status first
  Future<void> downloadAndStart(LocalLlmModel model) async {
    if (_state.status == LocalLlmStatus.downloading ||
        _state.status == LocalLlmStatus.starting) {
      return;
    }

    // NEW: Prevent PRoot conflicts during gateway startup
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

    // 3b. Download mmproj file for multimodal models (CLIP projection weights)
    if (model.isMultimodal && model.mmProjUrl != null) {
      final mmProjExists = await _isMmProjInstalled(model);
      if (!mmProjExists) {
        await _downloadMmProj(model);
        if (_state.status == LocalLlmStatus.error) return;
      }
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

    try {
      // NEW: Enhanced CPU detection and multi-version binary selection
      final cpuInfo = await NativeBridge.runInProot('cat /proc/cpuinfo');
      final binaryUrl = _getOptimalBinaryUrl(cpuInfo);
      
      _updateState(_state.copyWith(
        errorMessage: 'Detected CPU: ${cpuInfo.split('\n').first}\nDownloading compatible binary...',
      ));

      // Enhanced installation script with CPU-specific optimization
      const installScript = r'''
set -e

echo "[llama.cpp] Detecting CPU capabilities..."
CPU_INFO="$1"
BINARY_URL="$2"

# Parse ARM version and features for optimal binary selection
if echo "$CPU_INFO" | grep -q "armv8.2"; then
    CMAKE_FLAGS="-march=armv8.2-a"
elif echo "$CPU_INFO" | grep -q "armv8.1"; then
    CMAKE_FLAGS="-march=armv8.1-a"
elif echo "$CPU_INFO" | grep -q "armv8"; then
    CMAKE_FLAGS="-march=armv8-a"
elif echo "$CPU_INFO" | grep -q "armv7"; then
    CMAKE_FLAGS="-march=armv7-a"
else
    CMAKE_FLAGS="-march=armv8-a"  # Conservative fallback
fi

echo "[llama.cpp] Using CPU flags: $CMAKE_FLAGS"
echo "[llama.cpp] Downloading binary: $BINARY_URL"

# Create directory
mkdir -p /root/.openclaw/bin

# Download with multiple fallbacks
if command -v curl >/dev/null 2>&1; then
    curl -L -o "/root/.openclaw/bin/llama-server" "$BINARY_URL" || {
        echo "ERROR: Failed to download binary"
        exit 1
    }
else
    wget -O "/root/.openclaw/bin/llama-server" "$BINARY_URL" || {
        echo "ERROR: Failed to download binary"
        exit 1
    }
fi

# Make executable and verify
chmod +x "/root/.openclaw/bin/llama-server"
if [[ ! -x "/root/.openclaw/bin/llama-server" ]]; then
    echo "ERROR: Failed to make binary executable"
    exit 1
fi

# Install Android-compatible dependencies
echo "[llama.cpp] Installing runtime dependencies..."
apt-get update -qq && apt-get install -y --no-install-recommends \
    libgomp1 \
    libatomic1 \
    libc6-dev \
    libgcc-s1 \
    libstdc++6 \
    libblas3 \
    liblapack3 \
    ca-certificates \
    curl \
    wget 2>&1 | tail -5

# Verify dependencies
ldd "/root/.openclaw/bin/llama-server" > /tmp/llama-deps.txt
if grep -q "not found" /tmp/llama-deps.txt; then
    echo "ERROR: Missing dependencies detected"
    cat /tmp/llama-deps.txt
    exit 1
fi

# Test binary with compatibility check
echo "[llama.cpp] Testing binary compatibility..."
"/root/.openclaw/bin/llama-server" --help >/dev/null 2>&1 || {
    echo "ERROR: Binary test failed - possible CPU incompatibility"
    echo "Try: Manual compilation with device-specific flags"
    exit 1
}

echo ">>> LLAMA_SERVER_INSTALL_COMPLETE"
''';

      _updateState(_state.copyWith(downloadProgress: 0.2));

      // runInProot runs the command via /bin/sh -c "..." — positional args ($1, $2) are never set.
      // Inline CPU_INFO and BINARY_URL directly as variable assignments at the top of the script.
      final cleanedCpuInfo = cpuInfo.replaceAll('\n', ' ').replaceAll('"', '').replaceAll("'", '');
      final fullScript = installScript
          .replaceFirst('CPU_INFO="\$1"', 'CPU_INFO="$cleanedCpuInfo"')
          .replaceFirst('BINARY_URL="\$2"', 'BINARY_URL="$binaryUrl"');

      await NativeBridge.runInProot(fullScript, timeout: 600); // 10 minutes max
      _updateState(_state.copyWith(downloadProgress: 1.0));
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage:
            'llama-server installation failed. This might be due to:\n'
            '1. Network issues downloading binary\n'
            '2. Missing runtime dependencies\n'
            '3. CPU architecture incompatibility\n'
            '4. Insufficient memory or storage\n\n'
            'Error details: $e\n\n'
            'Try: Check device compatibility and free up storage space.',
      ));
    }
  }

  // Enhanced binary URL selection based on CPU detection
  String _getOptimalBinaryUrl(String cpuInfo) {
    // Multi-version binary mapping for maximum compatibility
    final Map<String, String> binaryMap = {
      'armv8.2-a': 'https://github.com/ggerganov/llama.cpp/releases/download/b3170/llama-server-android-arm64-v8.2a',
      'armv8.1-a': 'https://github.com/ggerganov/llama.cpp/releases/download/b3170/llama-server-android-arm64-v8.1a', 
      'armv8-a': 'https://github.com/ggerganov/llama.cpp/releases/download/b3170/llama-server-android-arm64',
      'armv7-a': 'https://github.com/ggerganov/llama.cpp/releases/download/b3170/llama-server-android-armv7',
    };

    // Detect ARM version and features
    if (cpuInfo.contains('armv8.2')) return binaryMap['armv8.2-a']!;
    if (cpuInfo.contains('armv8.1')) return binaryMap['armv8.1-a']!;
    if (cpuInfo.contains('armv8')) return binaryMap['armv8-a']!;
    if (cpuInfo.contains('armv7')) return binaryMap['armv7-a']!;
    
    // Fallback to most compatible
    return binaryMap['armv8-a']!;
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

      final url = Uri.parse(model.huggingFaceUrl);
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 20);
      
      final request = await httpClient.getUrl(url).timeout(const Duration(seconds: 20));
      // Follow redirects automatically by default, but let's be explicit if needed
      // HttpClient follows up to 5 redirects by default.
      
      final response = await request.close().timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw HttpException('Model download failed: HTTP ${response.statusCode}');
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

      // Copy model into PRoot filesystem using mapped host path
      final appSupportDir = await getApplicationSupportDirectory();
      final prootPath = '${appSupportDir.path}/rootfs';
      final hostProotModelPath = '$prootPath${model.prootModelPath}';
      
      // Ensure target directory exists on the host side
      final targetDir = Directory('$prootPath/root/.openclaw/models');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      await tmpFile.copy(hostProotModelPath);
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
  // Private — MmProj (multimodal CLIP projection) helpers
  // --------------------------------------------------------------------------

  Future<bool> _isMmProjInstalled(LocalLlmModel model) async {
    try {
      final result = await NativeBridge.runInProot(
        'test -f "${model.prootMmProjPath}" && echo "exists"',
        timeout: 5,
      );
      return result.trim() == 'exists';
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

  Future<void> _startServer(LocalLlmModel model) async {
    _updateState(_state.copyWith(status: LocalLlmStatus.starting));

    // Kill any stale instance first
    try {
      await NativeBridge.runInProot(
        'pkill -f "llama-server" 2>/dev/null; sleep 0.3',
        timeout: 5,
      );
    } catch (_) {}

    // Build the launch command with proper library path and Android optimizations
    final cmdParts = [
      '/root/.openclaw/bin/llama-server',
      '--model "${model.prootModelPath}"',
      '--host $_llamaHost',
      '--port $_llamaPort',
      '--ctx-size ${model.contextWindow.clamp(512, 4096)}', // Capped: 8192+ causes OOM under Android LMKD
      '--threads ${_state.threads}',
      '--n-gpu-layers 0', // CPU-only - more stable on Android
      // --no-mmap removed: forces entire model into malloc buffer, doubles memory pressure under LMKD
      // --mlock removed: requires CAP_IPC_LOCK kernel capability; proot does not grant it → EPERM crash
      '--batch-size 256', // Reduced from 512 for Android memory safety
      '--ubatch-size 256', // Reduced from 512 for Android memory safety
      '--log-disable', // Reduce log overhead
    ];

    // Append mmproj for multimodal/vision models (enables image_url content in chat completions)
    if (model.isMultimodal && model.mmProjUrl != null) {
      cmdParts.add('--mmproj "${model.prootMmProjPath}"');
    }

    final cmd = cmdParts.join(' ');

    // Launch with proper error handling and environment
    try {
      _updateState(_state.copyWith(downloadProgress: 0.1));
      
      // Create startup script with proper error handling
      final startupScript = '''
#!/bin/bash
set -e

echo "[llama-server] Starting with optimized Android settings..."

# Set up library paths for ARM64
export LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu:\$LD_LIBRARY_PATH"

# Optimize for Android memory management  
export OMP_NUM_THREADS=1
THREADS=${_state.threads}
export GOMP_CPU_AFFINITY="0-\$((\$THREADS - 1))"

# Start server with error checking
echo "[llama-server] Executing: $cmd"

# Use nohup to keep server alive, but also check if it starts properly
nohup bash -c '$cmd' > /root/.openclaw/llama-server.log 2>&1 &
SERVER_PID=\$!

# Give it a moment to start
sleep 2

# Check if process is actually running
if ! kill -0 \$SERVER_PID 2>/dev/null; then
  echo "[llama-server] ERROR: Process died immediately"
  exit 1
fi

echo "[llama-server] Started successfully with PID: \$SERVER_PID"
echo \$SERVER_PID > /root/.openclaw/llama-server.pid
''';

      await NativeBridge.runInProot(startupScript, timeout: 15);
      _updateState(_state.copyWith(downloadProgress: 0.3));
      
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Failed to start llama-server: $e\n\n'
            'This could be due to:\n'
            '1. Missing library dependencies\n'
            '2. Insufficient memory\n'
            '3. Corrupted binary installation\n\n'
            'Try: Reinstall the local LLM component.',
      ));
      return;
    }

    // Poll health endpoint with progressive timeout
    bool healthy = false;
    final maxAttempts = 30; // 30 seconds total
    final progressIncrement = 0.7 / maxAttempts;
    
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 1));
      _updateState(_state.copyWith(downloadProgress: 0.3 + (i * progressIncrement)));
      
      if (await isServerHealthy()) {
        healthy = true;
        break;
      }
      
      // Early check for common failure patterns
      if (i == 5) {
        try {
          final log = await NativeBridge.runInProot(
            'tail -20 /root/.openclaw/llama-server.log 2>/dev/null || echo "No log file"',
            timeout: 5,
          );
          if (log.contains('error') || log.contains('Error') || log.contains('ERROR')) {
            _updateState(_state.copyWith(
              status: LocalLlmStatus.error,
              errorMessage: 'llama-server failed to start. Log shows:\n${
                log.split('\n').where((line) => 
                  line.contains('error') || line.contains('Error') || line.contains('ERROR')
                ).take(3).join('\n')
              }',
            ));
            return;
          }
        } catch (_) {}
      }
    }

    if (!healthy) {
      // Get diagnostic information
      String diagnostic = '';
      try {
        diagnostic = await NativeBridge.runInProot(
          'echo "=== Process Status ===" && ps aux | grep llama-server || echo "No process" && '
          'echo "=== Log Tail ===" && tail -10 /root/.openclaw/llama-server.log 2>/dev/null || echo "No log"',
          timeout: 10,
        );
      } catch (_) {
        diagnostic = 'Could not retrieve diagnostics';
      }
      
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'llama-server did not respond within ${maxAttempts}s.\n\n'
            'Diagnostic information:\n$diagnostic\n\n'
            'Common solutions:\n'
            '1. Try with a smaller model (0.5B instead of 1.5B/3B)\n'
            '2. Reduce thread count in settings\n'
            '3. Free up device memory by closing other apps\n'
            '4. Reinstall the local LLM component',
      ));
      return;
    }

    _updateState(_state.copyWith(
      status: LocalLlmStatus.ready,
      activeModelId: model.id,
      downloadProgress: 1.0,
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

    const base = 'http://127.0.0.1:8081/v1/chat/completions';
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
