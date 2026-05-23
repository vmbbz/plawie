import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fllama/fllama.dart';
import '../models/node_frame.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';
import 'capabilities/camera_capability.dart';
import 'capabilities/canvas_capability.dart';
import 'capabilities/capability_handler.dart';
import 'capabilities/flash_capability.dart';
import 'capabilities/location_capability.dart';
import 'capabilities/screen_capability.dart';
import 'capabilities/sensor_capability.dart';
import 'capabilities/vibration_capability.dart';

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
  final String? mmProjUrl; // HuggingFace URL for the CLIP mmproj file
  final int? mmProjSizeMb; // Download size hint for the mmproj file

  /// True when the model architecture supports OpenAI-style tool/function calls.
  /// NDK direct mode uses this to label models that can participate in local
  /// tool experiments without promising full gateway parity.
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
    description:
        'Ultra-lightweight. Very fast but limited reasoning. Good for quick offline commands on 6 GB devices.',
    huggingFaceUrl:
        'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    fileSizeMb: 400,
    requiredRamMb: 1500,
    recommendedThreads: 4,
    quality: 'Minimum',
    contextWindow: 4096,
    supportsToolCalls: true,
  ),
  LocalLlmModel(
    id: 'qwen2.5-1.5b-instruct-q4_k_m',
    name: 'Qwen 2.5 1.5B Instruct (Q4_K_M)',
    description:
        'Recommended offline default. Better reasoning while staying realistic for 8-12 GB Android phones.',
    huggingFaceUrl:
        'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    fileSizeMb: 1000,
    requiredRamMb: 3000,
    recommendedThreads: 4,
    quality: 'Recommended',
    contextWindow: 4096,
    supportsToolCalls: true,
  ),
  LocalLlmModel(
    id: 'qwen2.5-3b-instruct-q4_k_m',
    name: 'Qwen 2.5 3B Instruct (Q4_K_M)',
    description:
        'Stronger offline reasoning. Requires 12 GB+ RAM and should be avoided during heavy Gateway work.',
    huggingFaceUrl:
        'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
    fileSizeMb: 1900,
    requiredRamMb: 4500,
    recommendedThreads: 6,
    quality: 'Optimal',
    contextWindow: 4096,
    supportsToolCalls: true,
  ),
  LocalLlmModel(
    id: 'smollm2-1.7b-instruct-q4_k_m',
    name: 'SmolLM2 1.7B Instruct (Q4_K_M)',
    description:
        'HuggingFace-trained speed-focused model. Good for simple offline tasks and fast responses.',
    huggingFaceUrl:
        'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf',
    fileSizeMb: 1100,
    requiredRamMb: 3000,
    recommendedThreads: 4,
    quality: 'Recommended',
    contextWindow: 4096,
    supportsToolCalls: true,
  ),

  // ── Vision / Multimodal Models ─────────────────────────────────────────────

  LocalLlmModel(
    id: 'qwen2-vl-2b-instruct-q4_k_m',
    name: 'Qwen2-VL 2B (Vision, Q4_K_M)',
    description:
        'Compact vision+text model. Understands images and text together. Needs ~3 GB RAM. Best choice for most Android phones.',
    huggingFaceUrl:
        'https://huggingface.co/bartowski/Qwen2-VL-2B-Instruct-GGUF/resolve/main/Qwen2-VL-2B-Instruct-Q4_K_M.gguf',
    mmProjUrl:
        'https://huggingface.co/bartowski/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-Qwen2-VL-2B-Instruct-f16.gguf',
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
    description:
        'Full-size LLaVA vision model. Strong image reasoning. Requires ~6 GB RAM — flagship phones only.',
    huggingFaceUrl:
        'https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/ggml-model-q4_k.gguf',
    mmProjUrl:
        'https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/mmproj-model-f16.gguf',
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
  idle, // no model / server not running
  downloading, // downloading model file
  installing, // reserved / unused — fllama activation uses `starting` directly
  starting, // starting llama-server process
  ready, // server up and responding
  error, // unrecoverable error
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
    this.threads = 1,
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
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
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

  bool get isDownloaded =>
      status == LocalLlmStatus.ready ||
      status == LocalLlmStatus.starting ||
      activeModelId != null;
  bool get isDownloading => status == LocalLlmStatus.downloading;
}

class _TrimmedLocalHistory {
  final List<Map<String, dynamic>> recent;
  final String? summary;

  const _TrimmedLocalHistory({
    required this.recent,
    this.summary,
  });
}

class _LocalToolInvocation {
  final String name;
  final Map<String, dynamic> args;
  final String label;

  const _LocalToolInvocation(this.name, this.args, this.label);
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
  // Restore persisted thread count immediately (prefs are synchronous after init).
  // PreferencesService.init() is called in main() before any service is used.
  LocalLlmState _state = LocalLlmState(
    threads: PreferencesService().llmThreadCount,
  );

  // fllama state — model path on host filesystem, active request ID for cancellation
  String? _activeModelPath;
  String? _activeMmprojPath;
  int? _activeRequestId;
  bool _isInferring = false;
  StreamController<String>? _activeChatController;
  final CameraCapability _cameraCapability = CameraCapability();
  final CanvasCapability _canvasCapability = CanvasCapability();
  final FlashCapability _flashCapability = FlashCapability();
  final LocationCapability _locationCapability = LocationCapability();
  final ScreenCapability _screenCapability = ScreenCapability();
  final SensorCapability _sensorCapability = SensorCapability();
  final VibrationCapability _vibrationCapability = VibrationCapability();

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

  /// Context window clamped to device-appropriate range for active model.
  /// Base: 1024 for mobile, but allows higher for powerful devices
  int get _activeContextSize {
    final baseContext = activeModel?.contextWindow ?? 4096;
    // For now, allow up to 4096 - users with powerful phones should benefit
    // TODO: Make this dynamic based on available memory
    return baseContext.clamp(512, 4096);
  }

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
      _state.status == LocalLlmStatus.ready &&
      (activeModel?.isMultimodal ?? false);

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
    if (_state.status == LocalLlmStatus.ready &&
        _state.activeModelId == model.id) {
      return;
    }
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

  /// Whether fllama inference is currently running (used by UI to disable slider).
  bool get isInferring => _isInferring;

  /// Update thread count. fllama applies it on the next inference call.
  Future<void> setThreads(int threads, {LocalLlmModel? currentModel}) async {
    _updateState(_state.copyWith(threads: threads.clamp(1, 16)));
    // Persist so the slider survives app restarts.
    final prefs = PreferencesService();
    await prefs.init();
    prefs.llmThreadCount = threads.clamp(1, 16);
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
      controller
          .add('[Error] Local LLM is not ready. Status: ${_state.status}');
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
    debugPrint(
        '[NDK] chat requested status=${_state.status.name} model=${_state.activeModelId ?? 'none'} history=${history.length} chars=${userMessage.length}');
    if (_state.status != LocalLlmStatus.ready || _activeModelPath == null) {
      controller
          .add('[Error] Local LLM is not ready. Status: ${_state.status}');
      debugPrint(
          '[NDK] chat rejected: local LLM not ready status=${_state.status.name}');
      controller.close();
      return controller.stream;
    }

    final directAnswer = _directLocalAnswer(userMessage);
    if (directAnswer != null) {
      debugPrint('[NDK] direct local answer served without inference');
      Future.microtask(() {
        if (!controller.isClosed) controller.add(directAnswer);
        if (!controller.isClosed) controller.close();
      });
      return controller.stream;
    }

    final directActions = _directLocalToolActions(userMessage);
    if (directActions.isNotEmpty) {
      debugPrint(
          '[NDK] direct local tool action(s): ${directActions.map((a) => a.name).join(', ')}');
      Future(() async {
        final responses = <String>[];
        for (final action in directActions) {
          final result =
              await _dispatchTool(action.name, jsonEncode(action.args));
          responses.add(_formatDirectToolResult(action, result));
        }
        if (!controller.isClosed) {
          controller.add(responses.join('\n\n'));
        }
        if (!controller.isClosed) controller.close();
      });
      return controller.stream;
    }

    if (_isInferring && _activeRequestId != null) {
      fllamaCancelInference(_activeRequestId!);
    }
    _activeChatController?.close();
    _activeChatController = controller;

    final tools = _toolsForMessage(userMessage);
    final trimmed = _trimHistory(
      history,
      userMessage,
      toolCount: tools.length,
    );
    final toolNames = tools.map((t) => t.name).join(', ');
    final messages = [
      Message(
          Role.system,
          'You are Plawie, a helpful AI assistant running locally on this Android device. '
          'Be concise and direct. '
          '${tools.isEmpty ? 'No native tool calls are attached for this turn; answer from normal reasoning only.' : 'Native tools attached for this turn: $toolNames. Use a tool only if it directly helps the user request.'}'),
      if (trimmed.summary != null && trimmed.summary!.isNotEmpty)
        Message(Role.system, trimmed.summary!),
      for (final m in trimmed.recent)
        Message(
          (m['role'] as String?) == 'assistant'
              ? Role.assistant
              : (m['role'] as String?) == 'system'
                  ? Role.system
                  : Role.user,
          (m['content'] as String?) ?? '',
        ),
      Message(Role.user, userMessage),
    ];
    debugPrint(
        '[NDK] tool gate selected=${tools.length}/${_localTools.length}${tools.isEmpty ? '' : ' names=$toolNames'}');
    _runChatTurn(messages, controller, tools: tools);
    return controller.stream;
  }

  /// Trims history to fit within the active context window.
  /// Keeps the most recent messages — older ones are dropped first.
  _TrimmedLocalHistory _trimHistory(
    List<Map<String, dynamic>> history,
    String newMessage, {
    required int toolCount,
  }) {
    final modelId = _state.activeModelId ?? '';
    final tinyModel = modelId.contains('0.5b');
    final smallModel = tinyModel || modelId.contains('1.5b');
    const avgCharsPerToken = 3;
    final responseReserve = _responseTokenLimit;
    // Tool schemas and chat templates are real prompt tokens. Keep a larger
    // reserve for tiny models so 5+ turns degrade gracefully instead of
    // surfacing a context-overflow error to the user.
    final hasTools = toolCount > 0;
    final toolAndTemplateReserve = hasTools
        ? (tinyModel ? 900 : 800) + (toolCount * (tinyModel ? 90 : 70))
        : (tinyModel ? 520 : 650);
    final rawBudget =
        (_activeContextSize - responseReserve - toolAndTemplateReserve) *
            avgCharsPerToken;
    final budget = rawBudget.clamp(
      tinyModel ? 900 : 1600,
      tinyModel
          ? (hasTools ? 1800 : 2600)
          : (smallModel ? (hasTools ? 3600 : 5000) : 7200),
    );

    final maxRecentMessages =
        tinyModel ? (hasTools ? 4 : 6) : (smallModel ? 8 : 12);
    var chars = newMessage.length;
    final result = <Map<String, dynamic>>[];
    for (final msg in history.reversed) {
      if (result.length >= maxRecentMessages) break;
      final role = (msg['role'] as String?) ?? 'user';
      var content = (msg['content'] as String?) ?? '';
      if (content.trim().isEmpty) continue;
      final perMessageCap = role == 'assistant'
          ? (tinyModel ? 420 : 900)
          : (tinyModel ? 320 : 700);
      content = _truncateForPrompt(content, perMessageCap);
      chars += content.length;
      if (chars > budget) break;
      result.insert(0, {'role': role, 'content': content});
    }

    final keptCount = result.length;
    final olderCount = history.length - keptCount;
    String? summary;
    if (olderCount > 0) {
      final older = history.take(olderCount).toList();
      summary = _summarizeDroppedHistory(older, tiny: tinyModel);
    }

    debugPrint(
        '[NDK] context packed model=$modelId kept=$keptCount dropped=${olderCount.clamp(0, history.length)} budgetChars=$budget tools=$toolCount newChars=${newMessage.length}');
    return _TrimmedLocalHistory(recent: result, summary: summary);
  }

  int get _responseTokenLimit {
    final modelId = _state.activeModelId ?? '';
    if (modelId.contains('0.5b')) return 384;
    if (modelId.contains('1.5b') || modelId.contains('1.7b')) return 512;
    if (modelId.contains('3b')) return 640;
    return 768;
  }

  String _truncateForPrompt(String input, int maxChars) {
    final clean = input
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\x00.*?\x00'), '')
        .trim();
    if (clean.length <= maxChars) return clean;
    return '${clean.substring(0, maxChars - 24).trim()} ... [truncated]';
  }

  String? _summarizeDroppedHistory(List<Map<String, dynamic>> older,
      {required bool tiny}) {
    if (older.isEmpty) return null;
    final maxItems = tiny ? 4 : 6;
    final maxChars = tiny ? 520 : 900;
    final items = older
        .where((m) => ((m['content'] as String?) ?? '').trim().isNotEmpty)
        .toList();
    if (items.isEmpty) return null;
    final selected = items.length > maxItems
        ? items.sublist(items.length - maxItems)
        : items;
    final lines = <String>[];
    for (final msg in selected) {
      final role = ((msg['role'] as String?) ?? 'user') == 'assistant'
          ? 'Assistant'
          : 'User';
      lines.add(
          '$role: ${_truncateForPrompt((msg['content'] as String?) ?? '', 140)}');
    }
    final summary = lines.join(' ');
    return 'Earlier conversation, compressed for mobile context: '
        '${_truncateForPrompt(summary, maxChars)}';
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
    Tool(
      name: 'device_battery',
      jsonSchema: '{"type":"object","properties":{},"required":[]}',
      description: 'Returns Android battery level and charging state.',
    ),
    Tool(
      name: 'camera_snap',
      jsonSchema:
          '{"type":"object","properties":{"facing":{"type":"string","enum":["back","front"]}},"required":[]}',
      description: 'Takes a photo with the Android camera.',
    ),
    Tool(
      name: 'camera_list',
      jsonSchema: '{"type":"object","properties":{},"required":[]}',
      description: 'Lists available Android cameras.',
    ),
    Tool(
      name: 'location_get',
      jsonSchema: '{"type":"object","properties":{},"required":[]}',
      description: 'Gets the current GPS location if permission is granted.',
    ),
    Tool(
      name: 'flash_set',
      jsonSchema:
          '{"type":"object","properties":{"action":{"type":"string","enum":["on","off","toggle","status"]}},"required":["action"]}',
      description: 'Controls or checks the Android flashlight.',
    ),
    Tool(
      name: 'haptic_vibrate',
      jsonSchema:
          '{"type":"object","properties":{"durationMs":{"type":"integer","minimum":50,"maximum":2000}},"required":[]}',
      description: 'Vibrates the phone briefly.',
    ),
    Tool(
      name: 'sensor_list',
      jsonSchema: '{"type":"object","properties":{},"required":[]}',
      description: 'Lists available sensor names.',
    ),
    Tool(
      name: 'sensor_read',
      jsonSchema:
          '{"type":"object","properties":{"sensor":{"type":"string","enum":["accelerometer","gyroscope","magnetometer","barometer"]}},"required":[]}',
      description: 'Reads a phone sensor.',
    ),
    Tool(
      name: 'screen_record',
      jsonSchema:
          '{"type":"object","properties":{"durationMs":{"type":"integer","minimum":1000,"maximum":10000}},"required":[]}',
      description: 'Records the screen after Android user consent.',
    ),
    Tool(
      name: 'canvas_navigate',
      jsonSchema:
          '{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}',
      description: 'Opens a URL in the in-app canvas panel.',
    ),
    Tool(
      name: 'canvas_snapshot',
      jsonSchema: '{"type":"object","properties":{},"required":[]}',
      description: 'Captures a snapshot of the in-app canvas panel.',
    ),
    Tool(
      name: 'avatar_gesture',
      jsonSchema:
          '{"type":"object","properties":{"gesture":{"type":"string"}},"required":["gesture"]}',
      description: 'Makes the Plawie avatar play a gesture.',
    ),
    Tool(
      name: 'avatar_emotion',
      jsonSchema:
          '{"type":"object","properties":{"emotion":{"type":"string"}},"required":["emotion"]}',
      description: 'Sets the Plawie avatar facial emotion.',
    ),
  ];

  /// Fast deterministic answers for questions the app can answer better than a
  /// tiny model. This avoids spending local context on bookkeeping questions.
  String? _directLocalAnswer(String userMessage) {
    final lower = userMessage.toLowerCase();
    final asksTools = (lower.contains('tool') ||
            lower.contains('capabilit') ||
            lower.contains('what can you do')) &&
        (lower.contains('what') ||
            lower.contains('which') ||
            lower.contains('list') ||
            lower.contains('show') ||
            lower.contains('can you'));
    if (!asksTools) return null;

    return 'I can use these on-device native tools in NDK Direct mode:\n\n'
        '- get_current_datetime: current local date/time\n'
        '- device_battery: battery level and charging state\n'
        '- camera_snap and camera_list: camera capture and camera discovery\n'
        '- location_get: GPS location when permission is granted\n'
        '- flash_set: torch on/off/toggle/status\n'
        '- haptic_vibrate: phone vibration\n'
        '- sensor_list and sensor_read: accelerometer, gyroscope, magnetometer, barometer\n'
        '- screen_record: short screen recording after Android consent\n'
        '- canvas_navigate and canvas_snapshot: in-app web canvas actions\n'
        '- avatar_gesture and avatar_emotion: Plawie avatar expression controls\n\n'
        'For full OpenClaw cloud/plugin skills, use a gateway-backed provider. '
        'For private offline device actions, stay on NDK Direct.';
  }

  List<_LocalToolInvocation> _directLocalToolActions(String userMessage) {
    final lower = userMessage.toLowerCase();
    final actions = <_LocalToolInvocation>[];
    bool hasAny(Iterable<String> words) => words.any(lower.contains);
    void add(String name, Map<String, dynamic> args, String label) {
      if (actions.any((a) => a.name == name)) return;
      actions.add(_LocalToolInvocation(name, args, label));
    }

    final asksToDoSomething = hasAny([
      'take',
      'snap',
      'capture',
      'get',
      'show',
      'turn',
      'toggle',
      'switch',
      'vibrate',
      'buzz',
      'open',
      'record',
      'read',
      'list',
      'what',
      'where',
    ]);
    if (!asksToDoSomething) return const <_LocalToolInvocation>[];

    if (hasAny(['time', 'date', 'today', 'now'])) {
      add('get_current_datetime', const {}, 'current date/time');
    }
    if (hasAny(['battery', 'charging', 'charge level'])) {
      add('device_battery', const {}, 'battery status');
    }
    if (hasAny(['camera list', 'list cameras', 'available cameras'])) {
      add('camera_list', const {}, 'camera list');
    } else if (hasAny(['camera', 'photo', 'picture', 'selfie', 'snapshot'])) {
      add(
          'camera_snap',
          {
            if (hasAny(['front', 'selfie'])) 'facing': 'front',
            if (hasAny(['back', 'rear'])) 'facing': 'back',
          },
          'camera snapshot');
    }
    if (hasAny(['location', 'gps', 'where am i', 'coordinates'])) {
      add('location_get', const {}, 'current location');
    }
    if (hasAny(['flashlight', 'torch', 'flash light'])) {
      final action = hasAny(['off', 'disable', 'turn off'])
          ? 'off'
          : hasAny(['status', 'state'])
              ? 'status'
              : hasAny(['toggle'])
                  ? 'toggle'
                  : 'on';
      add('flash_set', {'action': action}, 'flashlight $action');
    }
    if (hasAny(['vibrate', 'haptic', 'buzz'])) {
      add('haptic_vibrate', const {'durationMs': 300}, 'haptic vibration');
    }
    if (hasAny([
      'sensor',
      'accelerometer',
      'gyroscope',
      'magnetometer',
      'barometer'
    ])) {
      if (hasAny(['list', 'available sensors'])) {
        add('sensor_list', const {}, 'sensor list');
      } else {
        final sensor = hasAny(['gyroscope'])
            ? 'gyroscope'
            : hasAny(['magnetometer'])
                ? 'magnetometer'
                : hasAny(['barometer'])
                    ? 'barometer'
                    : 'accelerometer';
        add('sensor_read', {'sensor': sensor}, '$sensor reading');
      }
    }
    if (hasAny(['screen record', 'record screen', 'screen recording'])) {
      add('screen_record', const {'durationMs': 5000}, 'screen recording');
    }
    if (hasAny(['avatar', 'gesture', 'wave', 'nod', 'bow'])) {
      final gesture = hasAny(['bow'])
          ? 'bow'
          : hasAny(['nod'])
              ? 'nod'
              : 'wave';
      add('avatar_gesture', {'gesture': gesture}, 'avatar gesture');
    }
    if (hasAny(['emotion', 'smile', 'happy', 'sad', 'angry', 'surprised'])) {
      final emotion = hasAny(['sad'])
          ? 'sad'
          : hasAny(['angry'])
              ? 'angry'
              : hasAny(['surprised'])
                  ? 'surprised'
                  : 'happy';
      add('avatar_emotion', {'emotion': emotion}, 'avatar emotion');
    }

    final urlMatch = RegExp(r'https?://\S+').firstMatch(userMessage);
    if (urlMatch != null &&
        hasAny(['open', 'navigate', 'website', 'url', 'canvas'])) {
      add('canvas_navigate', {'url': urlMatch.group(0)!}, 'canvas navigation');
    }

    return actions;
  }

  String _formatDirectToolResult(
      _LocalToolInvocation action, String resultJson) {
    try {
      final decoded = jsonDecode(resultJson);
      if (decoded is! Map) {
        return 'Done: ${action.label}.';
      }
      final data = Map<String, dynamic>.from(decoded);
      final ok = data['ok'] == true || data['success'] == true;
      final error = data['error'];
      if (!ok && error != null) {
        final message = error is Map
            ? (error['message'] ?? error['code'] ?? error).toString()
            : error.toString();
        return 'I tried ${action.label}, but it failed: $message';
      }

      final result = data['result'] is Map
          ? Map<String, dynamic>.from(data['result'] as Map)
          : data;
      switch (action.name) {
        case 'get_current_datetime':
          return 'Current device time: ${data['datetime']}.';
        case 'device_battery':
          return 'Battery: ${data['level'] ?? result['level'] ?? 'unknown'}% '
              '(${(data['isCharging'] ?? result['isCharging']) == true ? 'charging' : 'not charging'}).';
        case 'camera_snap':
          return 'Captured a photo${result['width'] != null ? ' (${result['width']}x${result['height']})' : ''}.';
        case 'camera_list':
          return 'Available cameras: ${jsonEncode(result['cameras'] ?? const [])}.';
        case 'location_get':
          return 'Location: lat=${result['lat']}, lng=${result['lng']}, accuracy=${result['accuracy']}m.';
        case 'flash_set':
          return 'Flashlight is ${result['on'] == true ? 'on' : 'off'}.';
        case 'haptic_vibrate':
          return 'Vibrated the phone.';
        case 'sensor_list':
          return 'Available sensors: ${(result['sensors'] as List?)?.join(', ') ?? 'unknown'}.';
        case 'sensor_read':
          return 'Sensor reading: ${_compactToolJson(result)}.';
        case 'screen_record':
          return 'Screen recording captured.';
        case 'canvas_navigate':
          return 'Opened ${result['url'] ?? action.args['url']} in the canvas.';
        case 'avatar_gesture':
          return 'Played avatar gesture: ${action.args['gesture']}.';
        case 'avatar_emotion':
          return 'Set avatar emotion: ${action.args['emotion']}.';
        default:
          return 'Done: ${action.label}.';
      }
    } catch (_) {
      return 'Done: ${action.label}.';
    }
  }

  String _compactToolJson(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    for (final key in ['base64', 'imageBase64', 'bytes']) {
      if (copy[key] is String) {
        copy[key] = '[${(copy[key] as String).length} chars]';
      }
    }
    return jsonEncode(copy);
  }

  /// Selects only the tool schemas that the current message plausibly needs.
  ///
  /// Passing every tool on every turn burns context and confuses small models.
  /// Adaptive gating keeps normal chat light while still enabling tools for
  /// explicit device requests.
  List<Tool> _toolsForMessage(String userMessage) {
    final lower = userMessage.toLowerCase();
    final selected = <String>{};

    bool hasAny(Iterable<String> words) => words.any(lower.contains);

    if (hasAny(['time', 'date', 'today', 'now'])) {
      selected.add('get_current_datetime');
    }
    if (hasAny(['battery', 'charging', 'charge level'])) {
      selected.add('device_battery');
    }
    if (hasAny(['camera', 'photo', 'picture', 'selfie', 'snapshot'])) {
      selected.addAll(['camera_snap', 'camera_list']);
    }
    if (hasAny(['location', 'gps', 'where am i', 'coordinates'])) {
      selected.add('location_get');
    }
    if (hasAny(['flashlight', 'torch', 'flash light'])) {
      selected.add('flash_set');
    }
    if (hasAny(['vibrate', 'haptic', 'buzz'])) {
      selected.add('haptic_vibrate');
    }
    if (hasAny([
      'sensor',
      'accelerometer',
      'gyroscope',
      'magnetometer',
      'barometer'
    ])) {
      selected.addAll(['sensor_list', 'sensor_read']);
    }
    if (hasAny(['screen record', 'record screen', 'screen recording'])) {
      selected.add('screen_record');
    }
    if (hasAny(['open url', 'open website', 'web canvas', 'navigate to'])) {
      selected.addAll(['canvas_navigate', 'canvas_snapshot']);
    }
    if (hasAny(['avatar', 'gesture', 'wave', 'emotion', 'smile', 'face'])) {
      selected.addAll(['avatar_gesture', 'avatar_emotion']);
    }
    if (selected.isEmpty &&
        hasAny(['use a tool', 'call a tool', 'native tool'])) {
      selected.addAll([
        'get_current_datetime',
        'device_battery',
        'location_get',
        'flash_set',
      ]);
    }

    if (selected.isEmpty) return const <Tool>[];
    return _localTools.where((tool) => selected.contains(tool.name)).toList();
  }

  /// Dispatches a tool call through native app capabilities only.
  /// Gateway/partner plugins intentionally stay out of NDK mode so local chat
  /// cannot wedge the OpenClaw gateway while the phone is under inference load.
  Future<String> _dispatchTool(String name, String argumentsJson) async {
    Map<String, dynamic> args;
    try {
      final decoded = argumentsJson.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(argumentsJson);
      args = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (e) {
      return jsonEncode({'ok': false, 'error': 'Invalid tool JSON: $e'});
    }
    debugPrint('[NDK] dispatch tool name=$name args=${jsonEncode(args)}');

    switch (name) {
      case 'get_current_datetime':
        return jsonEncode({'datetime': DateTime.now().toIso8601String()});
      case 'device_battery':
        return _postAgentSkill(
            '/api/device/control', {'action': 'get_battery'});
      case 'camera_snap':
        return _dispatchCapability(
          _cameraCapability,
          'camera.snap',
          args,
          withPermission: true,
        );
      case 'camera_list':
        return _dispatchCapability(_cameraCapability, 'camera.list', args);
      case 'location_get':
        return _dispatchCapability(
          _locationCapability,
          'location.get',
          args,
          withPermission: true,
        );
      case 'flash_set':
        final action = (args['action'] as String?) ?? 'toggle';
        final command = switch (action) {
          'on' => 'flash.on',
          'off' => 'flash.off',
          'status' => 'flash.status',
          _ => 'flash.toggle',
        };
        return _dispatchCapability(
          _flashCapability,
          command,
          args,
          withPermission: true,
        );
      case 'haptic_vibrate':
        return _dispatchCapability(
          _vibrationCapability,
          'haptic.vibrate',
          args,
        );
      case 'sensor_list':
        return _dispatchCapability(_sensorCapability, 'sensor.list', args);
      case 'sensor_read':
        return _dispatchCapability(
          _sensorCapability,
          'sensor.read',
          args,
          withPermission: true,
        );
      case 'screen_record':
        return _dispatchCapability(_screenCapability, 'screen.record', args);
      case 'canvas_navigate':
        return _dispatchCapability(_canvasCapability, 'canvas.navigate', args);
      case 'canvas_snapshot':
        return _dispatchCapability(_canvasCapability, 'canvas.snapshot', args);
      case 'avatar_gesture':
        return _postAgentSkill('/api/avatar/control', {
          'action': 'play_gesture',
          'gesture': args['gesture'] ?? args['name'] ?? 'wave',
        });
      case 'avatar_emotion':
        return _postAgentSkill('/api/avatar/control', {
          'action': 'set_emotion',
          'emotion': args['emotion'] ?? args['name'] ?? 'happy',
        });
      default:
        return jsonEncode({
          'ok': false,
          'error':
              'Unknown local tool "$name". Available local tools are compact native tools only.',
        });
    }
  }

  Future<String> _dispatchCapability(
    CapabilityHandler handler,
    String command,
    Map<String, dynamic> args, {
    bool withPermission = false,
  }) async {
    try {
      final frame = withPermission
          ? await handler.handleWithPermission(command, args)
          : await handler.handle(command, args);
      return _frameToToolJson(command, frame);
    } catch (e) {
      return jsonEncode({'ok': false, 'tool': command, 'error': '$e'});
    }
  }

  Future<String> _postAgentSkill(
      String route, Map<String, dynamic> body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1:8765$route'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final payload = await utf8.decodeStream(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return payload;
      }
      return jsonEncode({
        'ok': false,
        'status': response.statusCode,
        'error': payload,
      });
    } catch (e) {
      return jsonEncode({'ok': false, 'error': 'AgentSkillServer failed: $e'});
    } finally {
      client.close(force: true);
    }
  }

  String _frameToToolJson(String command, NodeFrame frame) {
    if (frame.isError) {
      return jsonEncode({
        'ok': false,
        'tool': command,
        'error': frame.error,
      });
    }
    return jsonEncode({
      'ok': true,
      'tool': command,
      'result': frame.payload ?? <String, dynamic>{},
    });
  }

  /// Runs one inference turn with local tools.  Streams text deltas to
  /// [controller], then on completion checks for tool calls.  If the model
  /// requested tool calls, dispatches them and recurses (depth-limited to 3).
  Future<void> _runChatTurn(
      List<Message> messages, StreamController<String> controller,
      {int depth = 0, List<Tool>? tools}) async {
    if (depth > 3 || controller.isClosed) return;
    _isInferring = true;
    final startedAt = Stopwatch()..start();
    final effectiveTools = tools ?? _localTools;
    final toolCount = effectiveTools.length;
    debugPrint(
        '[NDK] fllama turn start depth=$depth model=${_state.activeModelId ?? 'unknown'} messages=${messages.length} tools=$toolCount threads=${_state.threads} ctx=$_activeContextSize');

    // Per-turn tool call accumulator (index → {name, arguments, id}).
    final accToolCalls = <int, Map<String, String>>{};
    String finishReason = '';
    String lastResponse = '';
    final completer = Completer<void>();

    try {
      await fllamaInference(
        _buildInferenceRequest(OpenAiRequest(
          maxTokens: _responseTokenLimit,
          messages: messages,
          modelPath: _activeModelPath!,
          mmprojPath: _activeMmprojPath,
          numGpuLayers: 99,
          contextSize: _activeContextSize,
          temperature: 0.7,
          tools: effectiveTools,
          toolChoice: effectiveTools.isEmpty ? null : ToolChoice.auto,
        )),
        (response, jsonString, done) {
          // Stream text deltas as they arrive.
          final delta = response.substring(lastResponse.length);
          lastResponse = response;

          // fllama surfaces context-overflow as a text response containing "exceeds ... tokens".
          // Catch it early and replace with a user-friendly message.
          if (delta.isNotEmpty &&
              delta.contains('exceeds') &&
              delta.contains('context')) {
            if (!controller.isClosed) {
              controller.add('[Error] This turn is still too large for the '
                  'active local model after mobile context compaction. '
                  'Please shorten the latest request or switch to the 1.5B/3B '
                  'local model for a larger working memory.');
              _isInferring = false;
              controller.close();
            }
            if (!completer.isCompleted) completer.complete();
            return;
          }

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
                    accToolCalls.putIfAbsent(
                        idx, () => {'name': '', 'arguments': '', 'id': ''});
                    final fn = tc['function'] as Map<String, dynamic>? ?? {};
                    if (fn['name'] is String &&
                        (fn['name'] as String).isNotEmpty) {
                      accToolCalls[idx]!['name'] = fn['name'] as String;
                    }
                    if (fn['arguments'] is String) {
                      accToolCalls[idx]!['arguments'] =
                          accToolCalls[idx]!['arguments']! +
                              (fn['arguments'] as String);
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
            if (!completer.isCompleted) completer.complete();
          }
        },
      ).then((id) => _activeRequestId = id);
    } catch (e) {
      _isInferring = false;
      debugPrint(
          '[NDK] fllama turn failed after ${startedAt.elapsedMilliseconds}ms: $e');
      if (!controller.isClosed) {
        controller.add('[Error] Local NDK inference failed: $e');
        controller.close();
      }
      if (!completer.isCompleted) completer.complete();
      return;
    }

    await completer.future;
    if (controller.isClosed) return;

    // No tool calls → inference is complete.
    if (finishReason != 'tool_calls' || accToolCalls.isEmpty) {
      debugPrint(
          '[NDK] fllama turn complete depth=$depth ms=${startedAt.elapsedMilliseconds} chars=${lastResponse.length} finish=${finishReason.isEmpty ? 'stop' : finishReason}');
      controller.close();
      return;
    }
    debugPrint(
        '[NDK] fllama requested ${accToolCalls.length} tool call(s) depth=$depth ms=${startedAt.elapsedMilliseconds}');

    // Build tool_calls list in OpenAI wire format and dispatch each tool.
    final sorted = accToolCalls.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final toolCallsList = sorted
        .map((e) => <String, dynamic>{
              'id': e.value['id'],
              'type': 'function',
              'function': {
                'name': e.value['name'],
                'arguments': e.value['arguments'],
              },
            })
        .toList();
    final toolResultMessages =
        await Future.wait(sorted.map((e) async => Message(
              Role.tool,
              await _dispatchTool(e.value['name']!, e.value['arguments']!),
              toolResponseName: e.value['name'],
            )));

    final updated = [
      ...messages,
      Message(Role.assistant, '', toolCalls: toolCallsList),
      ...toolResultMessages,
    ];
    await _runChatTurn(updated, controller, depth: depth + 1, tools: tools);
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
  Stream<String> analyseVideoFrames(
      List<Uint8List> frames, String summaryPrompt) async* {
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
      final result =
          await completer.future.timeout(const Duration(seconds: 60));
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
      final request = await client
          .getUrl(Uri.parse(model.huggingFaceUrl))
          .timeout(const Duration(seconds: 30));
      if (alreadyBytes > 0) {
        request.headers.add('Range', 'bytes=$alreadyBytes-');
      }
      final response =
          await request.close().timeout(const Duration(seconds: 30));

      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
      } else {
        final isResume =
            response.statusCode == HttpStatus.partialContent; // 206
        if (response.statusCode != HttpStatus.ok && !isResume) {
          throw HttpException('Download failed: HTTP ${response.statusCode}');
        }

        final openMode = isResume ? FileMode.append : FileMode.write;
        final startOffset = isResume ? alreadyBytes : 0;
        final serverLength =
            response.contentLength != -1 ? response.contentLength : 0;
        final totalBytes = serverLength > 0 ? startOffset + serverLength : 0;
        int received = startOffset;

        final sink = tmpFile.openWrite(mode: openMode);
        try {
          await for (final chunk
              in response.timeout(const Duration(seconds: 60))) {
            sink.add(chunk);
            received += chunk.length;
            final progress = totalBytes > 0 ? received / totalBytes : 0.0;
            _updateState(_state.copyWith(
              downloadProgress: progress,
              errorMessage:
                  'Downloading: ${(received / 1048576).toStringAsFixed(1)} MB',
            ));
          }
        } finally {
          await sink.close();
        }
      }

      _updateState(
          _state.copyWith(errorMessage: 'Installing model into PRoot...'));
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
      final request =
          await HttpClient().getUrl(url).timeout(const Duration(seconds: 20));
      final response =
          await request.close().timeout(const Duration(seconds: 20));

      final total = response.contentLength != -1 ? response.contentLength : 0;
      int received = 0;
      final sink = tmpFile.openWrite();
      try {
        await for (final chunk
            in response.timeout(const Duration(seconds: 60))) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            _updateState(_state.copyWith(downloadProgress: received / total));
          }
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
      _updateState(_state.copyWith(
          status: LocalLlmStatus.error,
          errorMessage: 'Vision projection download failed: $e'));
    }
  }

  // --------------------------------------------------------------------------
  // Private — fllama activation (no PRoot, no HTTP server)
  // --------------------------------------------------------------------------

  /// Store host model paths and flip state to ready — fllama needs no server process.
  Future<void> _activateFllama(LocalLlmModel model) async {
    final contextSize = model.contextWindow.clamp(512, 4096);
    debugPrint(
        '[NDK] activating fllama model=${model.id} sizeMb=${model.fileSizeMb} threads=${_state.threads} ctx=$contextSize');
    _updateState(_state.copyWith(
      status: LocalLlmStatus.starting,
      downloadProgress: 0.5,
      clearErrorMessage: true,
    ));

    try {
      final filesDir = await NativeBridge.getFilesDir();
      final prootRoot = '$filesDir/rootfs';

      _activeModelPath = '$prootRoot${model.prootModelPath}';
      _activeMmprojPath =
          model.isMultimodal ? '$prootRoot${model.prootMmProjPath}' : null;

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
      debugPrint(
          '[NDK] fllama ready model=${model.id} path=$_activeModelPath mmproj=${_activeMmprojPath ?? 'none'}');
    } catch (e) {
      debugPrint('[NDK] fllama activation failed: $e');
      _updateState(_state.copyWith(
        status: LocalLlmStatus.error,
        errorMessage: 'Failed to activate fllama: $e',
      ));
    }
  }
}
