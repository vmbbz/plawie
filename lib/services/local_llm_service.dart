import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:fllama/fllama.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';

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

  /// True when the model architecture supports OpenAI-style tool/function calls
  /// AND the Ollama Modelfile template for this model includes {{ .Tools }}.
  /// Used to:
  ///   - Inject the chat template when registering with Ollama (full gateway routing)
  ///   - Filter the gateway primary model picker (non-tool models show CHAT ONLY)
  ///   - Route chat via gateway agent loop vs. direct Ollama HTTP
  final bool supportsToolCalls;

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
    this.supportsToolCalls = false,
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
    supportsToolCalls: true,
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
    supportsToolCalls: true,
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
  installing,  // reserved / unused — fllama activation uses `starting` directly
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

/// Manages the fllama inference engine lifecycle.
/// Downloads GGUF models, activates them, and runs inference directly via the
/// fllama NDK plugin (llama.cpp compiled into the APK — no PRoot, no HTTP server).
class LocalLlmService {
  static final LocalLlmService _instance = LocalLlmService._internal();
  factory LocalLlmService() => _instance;
  LocalLlmService._internal();

  final _stateController = StreamController<LocalLlmState>.broadcast();
  LocalLlmState _state = const LocalLlmState();

  // fllama state — model path on host filesystem, active request ID for cancellation
  String? _activeModelPath;
  String? _activeMmprojPath;
  int? _activeRequestId;
  bool _isInferring = false;
  StreamController<String>? _activeChatController;

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

  /// Context window clamped to a safe range for the active model.
  int get _activeContextSize =>
      (activeModel?.contextWindow ?? 4096).clamp(512, 8192);

  /// Mirrors fllamaChat() but injects numThreads from the user's thread setting.
  /// fllamaChat() hard-codes numThreads=2 and never exposes it via OpenAiRequest.
  FllamaInferenceRequest _buildInferenceRequest(OpenAiRequest req) {
    return FllamaInferenceRequest(
      contextSize: req.contextSize,
      input: '', // C++ reads openAiRequestJsonString directly; input is unused
      maxTokens: req.maxTokens,
      modelPath: req.modelPath,
      modelMmprojPath: req.mmprojPath,
      numGpuLayers: req.numGpuLayers,
      penaltyFrequency: req.frequencyPenalty,
      penaltyRepeat: req.presencePenalty,
      temperature: req.temperature,
      topP: req.topP,
      numThreads: _state.threads,
      openAiRequestJsonString: req.toJsonString(),
    );
  }

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

  /// Download GGUF + activate via fllama.
  Future<void> downloadAndStart(LocalLlmModel model) async {
    if (_state.status == LocalLlmStatus.downloading ||
        _state.status == LocalLlmStatus.starting ||
        _state.status == LocalLlmStatus.installing) {
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

    await _activateFllama(model);
  }

  /// Activate fllama with an already-downloaded model.
  Future<void> startWithModel(LocalLlmModel model) async {
    // No-op if this exact model is already running.
    if (_state.status == LocalLlmStatus.ready && _state.activeModelId == model.id) return;
    if (!await _isModelInstalled(model)) {
      await downloadAndStart(model);
      return;
    }
    await _activateFllama(model);
  }

  /// Stop the active fllama inference and reset state.
  Future<void> stop() async {
    if (_activeRequestId != null) {
      fllamaCancelInference(_activeRequestId!);
      _activeRequestId = null;
    }
    _activeChatController?.close();
    _activeChatController = null;
    _isInferring = false;
    _activeModelPath = null;
    _activeMmprojPath = null;
    _updateState(_state.copyWith(
      status: LocalLlmStatus.idle,
      activeModelId: null,
      isEnabled: false,
    ));
  }

  /// Update thread count — fllama auto-detects threads; just persist the preference.
  Future<void> setThreads(int threads, {LocalLlmModel? currentModel}) async {
    _updateState(_state.copyWith(threads: threads));
    // fllama re-reads contextSize on next inference call; no restart needed.
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

  /// Test inference — runs directly via fllama (no HTTP, no PRoot).
  Stream<String> testInference(String prompt) {
    final controller = StreamController<String>();
    if (_state.status != LocalLlmStatus.ready || _activeModelPath == null) {
      controller.add('[Error] Local LLM is not ready. Status: ${_state.status}');
      controller.close();
      return controller.stream;
    }
    // Cancel any in-flight request before starting a new one.
    if (_isInferring && _activeRequestId != null) {
      fllamaCancelInference(_activeRequestId!);
    }
    _isInferring = true;
    String lastResponse = '';
    fllamaInference(
      _buildInferenceRequest(OpenAiRequest(
        maxTokens: 512,
        messages: [Message(Role.user, prompt)],
        modelPath: _activeModelPath!,
        mmprojPath: _activeMmprojPath,
        numGpuLayers: 99,
        contextSize: _activeContextSize,
        temperature: 0.7,
      )),
      (response, jsonString, done) {
        final delta = response.substring(lastResponse.length);
        lastResponse = response;
        if (delta.isNotEmpty && !controller.isClosed) controller.add(delta);
        if (done) {
          _isInferring = false;
          if (!controller.isClosed) controller.close();
        }
      },
    ).then((id) => _activeRequestId = id);
    return controller.stream;
  }

  /// Full chat with conversation history — used by GatewayService for local-llm routing.
  /// Supports multi-turn local tool calls (get_current_datetime, etc.) with depth limit 3.
  /// [history] is a list of {role, content} maps (OpenAI format).
  Stream<String> chat(List<Map<String, dynamic>> history, String userMessage) {
    final controller = StreamController<String>();
    if (_state.status != LocalLlmStatus.ready || _activeModelPath == null) {
      controller.add('[Error] Local LLM is not ready. Status: ${_state.status}');
      controller.close();
      return controller.stream;
    }
    if (_isInferring && _activeRequestId != null) {
      fllamaCancelInference(_activeRequestId!);
    }
    _activeChatController?.close();
    _activeChatController = controller;

    final trimmed = _trimHistory(history, userMessage);
    final messages = [
      Message(Role.system,
          'You are Plawie, a helpful AI assistant running locally on this Android device. '
          'Be concise and direct.'),
      for (final m in trimmed)
        Message(
          (m['role'] as String?) == 'assistant' ? Role.assistant
              : (m['role'] as String?) == 'system' ? Role.system
              : Role.user,
          (m['content'] as String?) ?? '',
        ),
      Message(Role.user, userMessage),
    ];
    _runChatTurn(messages, controller);
    return controller.stream;
  }

  /// Trims history to fit within the active context window.
  /// Keeps the most recent messages — older ones are dropped first.
  List<Map<String, dynamic>> _trimHistory(
      List<Map<String, dynamic>> history, String newMessage) {
    const avgCharsPerToken = 4;
    // Reserve 1024 tokens for the response + 100 for system prompt overhead.
    final budget = (_activeContextSize - 1024 - 100) * avgCharsPerToken;
    var chars = newMessage.length;
    final result = <Map<String, dynamic>>[];
    for (final msg in history.reversed) {
      chars += (msg['content'] as String? ?? '').length;
      if (chars > budget) break;
      result.insert(0, msg);
    }
    return result;
  }

  // --------------------------------------------------------------------------
  // Tool-use (8.8)
  // --------------------------------------------------------------------------

  static final _localTools = [
    Tool(
      name: 'get_current_datetime',
      jsonSchema: '{"type":"object","properties":{},"required":[]}',
      description: 'Returns the current date and time on the device.',
    ),
  ];

  String _dispatchLocalTool(String name, String argumentsJson) {
    switch (name) {
      case 'get_current_datetime':
        return jsonEncode({'datetime': DateTime.now().toIso8601String()});
      default:
        return jsonEncode({'error': 'Unknown tool: $name'});
    }
  }

  /// Runs one inference turn with local tools.  Streams text deltas to
  /// [controller], then on completion checks for tool calls.  If the model
  /// requested tool calls, dispatches them and recurses (depth-limited to 3).
  Future<void> _runChatTurn(
      List<Message> messages,
      StreamController<String> controller,
      {int depth = 0}) async {
    if (depth > 3 || controller.isClosed) return;
    _isInferring = true;

    // Per-turn tool call accumulator (index → {name, arguments, id}).
    final accToolCalls = <int, Map<String, String>>{};
    String finishReason = '';
    String lastResponse = '';
    final completer = Completer<void>();

    await fllamaInference(
      _buildInferenceRequest(OpenAiRequest(
        maxTokens: 1024,
        messages: messages,
        modelPath: _activeModelPath!,
        mmprojPath: _activeMmprojPath,
        numGpuLayers: 99,
        contextSize: _activeContextSize,
        temperature: 0.7,
        tools: _localTools,
        toolChoice: ToolChoice.auto,
      )),
      (response, jsonString, done) {
        // Stream text deltas as they arrive.
        final delta = response.substring(lastResponse.length);
        lastResponse = response;
        if (delta.isNotEmpty && !controller.isClosed) controller.add(delta);

        // Accumulate tool_calls from each streaming JSON chunk.
        if (jsonString.isNotEmpty) {
          try {
            final raw = jsonDecode(jsonString);
            final chunks = raw is List ? raw : [raw];
            for (final c in chunks) {
              if (c is! Map<String, dynamic>) continue;
              final choices = c['choices'] as List<dynamic>? ?? [];
              if (choices.isEmpty) continue;
              final choice = choices.first as Map<String, dynamic>;
              final reason = choice['finish_reason'] as String?;
              if (reason != null && reason.isNotEmpty) finishReason = reason;
              final deltaMap = choice['delta'] as Map<String, dynamic>? ?? {};
              final tcList = deltaMap['tool_calls'] as List<dynamic>?;
              if (tcList != null) {
                for (final tc in tcList) {
                  if (tc is! Map<String, dynamic>) continue;
                  final idx = tc['index'] as int? ?? 0;
                  accToolCalls.putIfAbsent(idx, () => {'name': '', 'arguments': '', 'id': ''});
                  final fn = tc['function'] as Map<String, dynamic>? ?? {};
                  if (fn['name'] is String && (fn['name'] as String).isNotEmpty) {
                    accToolCalls[idx]!['name'] = fn['name'] as String;
                  }
                  if (fn['arguments'] is String) {
                    accToolCalls[idx]!['arguments'] =
                        accToolCalls[idx]!['arguments']! + (fn['arguments'] as String);
                  }
                  if (tc['id'] is String) {
                    accToolCalls[idx]!['id'] = tc['id'] as String;
                  }
                }
              }
            }
          } catch (_) {}
        }

        if (done) {
          _isInferring = false;
          completer.complete();
        }
      },
    ).then((id) => _activeRequestId = id);

    await completer.future;
    if (controller.isClosed) return;

    // No tool calls → inference is complete.
    if (finishReason != 'tool_calls' || accToolCalls.isEmpty) {
      controller.close();
      return;
    }

    // Build tool_calls list in OpenAI wire format and dispatch each tool.
    final sorted = accToolCalls.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final toolCallsList = sorted.map((e) => <String, dynamic>{
      'id': e.value['id'],
      'type': 'function',
      'function': {
        'name': e.value['name'],
        'arguments': e.value['arguments'],
      },
    }).toList();
    final toolResultMessages = sorted.map((e) => Message(
      Role.tool,
      _dispatchLocalTool(e.value['name']!, e.value['arguments']!),
      toolResponseName: e.value['name'],
    )).toList();

    final updated = [
      ...messages,
      Message(Role.assistant, '', toolCalls: toolCallsList),
      ...toolResultMessages,
    ];
    await _runChatTurn(updated, controller, depth: depth + 1);
  }

  /// Returns fllama engine status (replaces HTTP health probe).
  Future<String> fetchServerHealth() async {
    final status = _state.status.name;
    final model = _state.activeModelId ?? 'none';
    return 'fllama — status: $status, model: $model, path: ${_activeModelPath ?? 'n/a'}';
  }

  /// Returns fllama state info (replaces PRoot log tail).
  Future<String> fetchServerLogs() async {
    return 'fllama inference engine (no external log).\n'
        'Status: ${_state.status.name}\n'
        'Model: ${_state.activeModelId ?? 'none'}\n'
        'Host path: ${_activeModelPath ?? 'n/a'}\n'
        'Mmproj: ${_activeMmprojPath ?? 'n/a'}';
  }

  /// Processes a list of JPEG frames via fllama vision inference.
  Stream<String> analyseVideoFrames(List<Uint8List> frames, String summaryPrompt) async* {
    if (frames.isEmpty) {
      yield '[Error] No frames extracted from video.';
      return;
    }
    if (_state.status != LocalLlmStatus.ready || _activeModelPath == null) {
      yield '[Error] Local vision model is not running. Start it in Local LLM settings.';
      return;
    }
    if (_isInferring && _activeRequestId != null) {
      fllamaCancelInference(_activeRequestId!);
    }
    _isInferring = true;
    _updateState(_state.copyWith(downloadProgress: 0.3));
    try {
      // fllama expects the HTML <img src="data:..."> format — confirmed from
      // fllama's own example app. The C++ side parses this tag to extract and
      // embed the image when mmprojPath is set.
      final base64Image = base64Encode(frames.first);
      final visionPrompt =
          '<img src="data:image/jpeg;base64,$base64Image">\n\n$summaryPrompt';
      final completer = Completer<String>();
      await fllamaInference(
        _buildInferenceRequest(OpenAiRequest(
          maxTokens: 512,
          messages: [Message(Role.user, visionPrompt)],
          modelPath: _activeModelPath!,
          mmprojPath: _activeMmprojPath,
          numGpuLayers: 99,
          contextSize: _activeContextSize,
          temperature: 0.3,
        )),
        (response, jsonString, done) {
          if (done) {
            _isInferring = false;
            if (!completer.isCompleted) completer.complete(response);
          }
        },
      );
      final result = await completer.future.timeout(const Duration(seconds: 60));
      yield result;
    } catch (e) {
      _isInferring = false;
      yield '[Error] Vision analysis failed: $e';
    } finally {
      _updateState(_state.copyWith(downloadProgress: 1.0));
    }
  }

  /// Health check via fllama state (no HTTP probe needed).
  Future<bool> isServerHealthy() async {
    return _state.status == LocalLlmStatus.ready;
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
  // Private — fllama activation (no PRoot, no HTTP server)
  // --------------------------------------------------------------------------

  /// Store host model paths and flip state to ready — fllama needs no server process.
  Future<void> _activateFllama(LocalLlmModel model) async {
    _updateState(_state.copyWith(
      status: LocalLlmStatus.starting,
      downloadProgress: 0.5,
      clearErrorMessage: true,
    ));

    try {
      final filesDir = await NativeBridge.getFilesDir();
      final prootRoot = '$filesDir/rootfs';

      _activeModelPath = '$prootRoot${model.prootModelPath}';
      _activeMmprojPath = model.isMultimodal
          ? '$prootRoot${model.prootMmProjPath}'
          : null;

      if (!File(_activeModelPath!).existsSync()) {
        throw Exception('Model file not found: $_activeModelPath');
      }
      // Non-fatal: mmproj missing → text-only fallback
      if (_activeMmprojPath != null && !File(_activeMmprojPath!).existsSync()) {
        _activeMmprojPath = null;
      }

      final prefs = PreferencesService();
      await prefs.init();
      prefs.configuredModel = 'local-llm/${model.id}';

      _updateState(_state.copyWith(
        status: LocalLlmStatus.ready,
        activeModelId: model.id,
        downloadProgress: 1.0,
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Failed to activate fllama: $e',
      ));
    }
  }
}
