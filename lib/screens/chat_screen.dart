import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import '../services/tts_service.dart';
import '../services/native_bridge.dart';
import '../services/video_capture_service.dart';
import '../utils/video_frame_extractor.dart';
import '../models/agent_info.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../services/preferences_service.dart';
import '../services/product_telemetry_event.dart';
import '../services/product_telemetry_service.dart';
import '../services/paid_provider_proxy_models.dart';
import '../services/paid_provider_turn_authorization_service.dart';
import '../services/speech_text_normalizer.dart';
import '../services/voice_session_controller.dart';
import '../services/native_speech_input_service.dart';
import '../providers/gateway_provider.dart';
import '../models/gateway_state.dart';
import '../widgets/vrm_avatar_widget.dart';

import 'dart:ui';
import '../models/chat_message.dart';
import '../services/chat_persistence_service.dart';
import '../widgets/chat_bubble.dart';
import 'avatar_forge_page.dart';
import '../services/skills_service.dart';
import '../services/local_llm_service.dart';
import '../services/model_provider_catalog.dart';
import '../services/model_tool_compatibility_probe.dart';
import '../services/paid_provider_tool_probe_authorization.dart';
import '../services/canonical_model_selection.dart';
import '../services/dynamic_model_catalog.dart';
import '../services/wallet_funded_provider_readiness.dart';
import '../services/provider_balance_service.dart';
import '../widgets/dynamic_model_picker_panel.dart';
import '../widgets/wallet_funded_provider_actions.dart';
import '../widgets/aura_dot.dart';
import '../services/gateway_service.dart';
import '../services/agent_skill_server.dart';
import '../services/avatar_gesture_catalog.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/capabilities/canvas_capability.dart';
import '../services/chat_runtime_service.dart';
import '../services/gifgrep_media_store.dart';
import '../services/hologram_service.dart';
import 'management/skills/gifgrep_config_sheet.dart';
import '../services/tool_media_event_bus.dart';
import '../widgets/hologram_overlay.dart';
import 'management/local_llm_screen.dart';
import 'base_screen.dart';
import 'web_dashboard_screen.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

enum _GatewayTtsHealth { normal, processing, degraded, failed }

class ChatScreen extends StatefulWidget {
  final bool autoStartVoice;

  const ChatScreen({super.key, this.autoStartVoice = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _logScrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ChatPersistenceService _persistence = ChatPersistenceService();
  final ChatRuntimeService _chatRuntime = ChatRuntimeService();
  final VrmAvatarController _avatarController = VrmAvatarController();

  // Scaffold key to allow opening the end drawer from anywhere (e.g. PopupMenu overlays)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isThinking = false;
  double _speechIntensity = 0.0;
  bool _isGenerating = false;
  bool _isReady = false;

  // Diagnostics
  final List<String> _diagnosticLogs = [];
  bool _showDiagnostics = false;

  // Voice Pipeline (Kokoro TTS / Local VITS)
  final TtsService _tts = TtsService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final NativeSpeechInputService _nativeSpeechInput =
      NativeSpeechInputService();
  final VoiceSessionController _voiceSession = VoiceSessionController();
  bool _isListening = false;
  bool _usingNativeSpeechFallback = false;
  bool _nativeSpeechStopRequested = false;
  bool _nativeSpeechFinishedBeforeUiState = false;
  String? _nativeSpeechPendingText;
  bool _isTalkRelayCaptureActive = false;
  String? _currentGesture;
  String? _currentGestureMode;
  String? _talkRelaySessionId;
  bool _talkRelayReady = false;
  bool _talkRelaySupported = false;
  DateTime? _talkRelaySupportCheckedAt;
  StreamSubscription<Uint8List>? _talkAudioStreamSub;
  StreamSubscription<Map<String, dynamic>>? _talkEventSub;
  Future<void> _talkAudioSendChain = Future<void>.value();
  Timer? _talkRelayFinalizationTimer;
  bool _talkRelayTurnAwaitingTranscript = false;
  Timer? _backgroundVoiceStopTimer;
  Timer? _continuousListeningTimer;
  bool _continuousSessionArmed = false;
  bool _wakeWordActivationInFlight = false;
  bool _wakeWordSuspendedForVoice = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  int? _talkAssistantMessageIndex;
  String _talkAssistantTextBuffer = '';

  // Streaming TTS state
  String _ttsSentenceBuffer = '';
  bool _isTtsSpeaking = false;
  final List<String> _ttsQueue = [];
  final Set<String> _queuedTtsKeys = <String>{};
  _GatewayTtsHealth _gatewayTtsHealth = _GatewayTtsHealth.normal;
  String? _gatewayTtsHealthMessage;
  DateTime? _lastGatewayTtsNoticeAt;
  String? _gatewaySessionKey;

  String _selectedAvatar = 'gemini.vrm';
  String _agentName = 'Plawie';
  CanonicalModelSelection _selectedModelSelection =
      CanonicalModelSelection.fromModelId(
        ModelProviderCatalog.defaultCloudFallbackModel,
      );
  String get _selectedModel => _selectedModelSelection.namespacedModelId;
  set _selectedModel(String value) {
    _selectedModelSelection = CanonicalModelSelection.fromModelId(value);
  }

  // Cloud model to fall back to when a local NDK model stops.
  // Set at load time from onboarding provider; updated when user picks a cloud model.
  String _cloudFallbackModel = ModelProviderCatalog.defaultCloudFallbackModel;

  // Vision / image attachment state
  String? _pendingImageBase64; // base64 of photo waiting to be sent
  bool _isTakingPhoto = false; // true while camera shutter is in flight

  // Video attachment state
  String? _pendingVideoBase64; // base64 of recorded clip waiting to be sent
  bool _isRecordingVideo = false;

  // Compact quick-menu projection of the cached live catalog. The full
  // searchable catalog remains available through Browse provider models.
  List<DynamicModelRecord> _availableDynamicModels =
      const <DynamicModelRecord>[];
  DynamicCatalogSnapshot? _availableDynamicCatalog;

  // Dynamic agents fetched from the gateway
  List<AgentInfo> _dynamicAgents = [];

  final List<String> _availableAvatars = ['gemini.vrm'];

  // Wake word subscription
  StreamSubscription<String>? _hotwordSub;
  // Auto-sync model when local LLM starts/stops
  StreamSubscription<LocalLlmState>? _localLlmSub;
  LocalLlmState _localLlmState = const LocalLlmState();
  bool _localChatModeEnabled = false;
  // Gateway state sync — keeps stale prefs from leaking into the model picker.
  StreamSubscription<GatewayState>? _gatewaySub;
  // Live gateway activity bridge for the in-chat diagnostics panel.
  StreamSubscription<String>? _gatewayActivitySub;
  // Skills event bus — tracks executing/executed/error states
  StreamSubscription? _skillsSub;
  StreamSubscription<ChatConfigurationRequest>? _configurationRequestSub;
  StreamSubscription<ToolMediaEvent>? _toolMediaSub;

  // Latest camera.snap base64 captured by AI tool call — attached to bot message after stream ends
  String? _pendingAiSnapBase64;
  String? _pendingAiSnapMimeType;

  // Canvas overlay state
  WebViewController? _canvasController;
  final GlobalKey _canvasRepaintKey = GlobalKey();
  bool _canvasVisible = false;

  static const MethodChannel _pipChannel = MethodChannel('vrm/pip_mode');
  bool _isPipMode = false;
  bool _isChatCollapsed = false; // Expanded by default
  bool _chatPinnedToBottom = true;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleChatScroll);
    _chatRuntime.addListener(_syncChatRuntimeState);
    _configurationRequestSub = _chatRuntime.configurationRequests.listen(
      _handleConfigurationRequest,
    );
    unawaited(GifgrepMediaStore.initialize());
    // Wire AgentSkillServer callbacks so agent-controlled avatar changes
    // reflect immediately in the live chat UI (singleton shares state with main()).
    AgentSkillServer.instance.onAvatarChanged = (file) {
      if (mounted) setState(() => _selectedAvatar = file);
    };
    AgentSkillServer.instance.onAvatarGestureRequested =
        _handleAvatarGestureRequest;
    AgentSkillServer.instance.onGesturePlayed = (gesture) {
      unawaited(_handleAvatarGestureRequest({'gesture': gesture}));
    };
    AgentSkillServer.instance.onGestureModeChanged = (mode) {
      if (mounted) setState(() => _currentGestureMode = mode);
    };
    AgentSkillServer.instance.onEmotionSet =
        (_) {}; // handled by avatar_scene.html
    // Canvas WebView is created lazily on first tool use. Keeping it out of
    // idle chat avoids holding a second Android WebView/GL context all day.
    CanvasCapability.onActivationRequested = _ensureCanvasController;
    CanvasCapability.onVisibilityChanged = (visible) async {
      if (visible) {
        // Canvas is presented above the chat tray. Do not leave the IME open
        // underneath it: resizeToAvoidBottomInset is intentionally disabled
        // for the avatar/WebView, so an open keyboard makes the panel overlap
        // the app bar and steals the close-button hit area.
        FocusManager.instance.primaryFocus?.unfocus();
        await _ensureCanvasController();
      }
      if (mounted) setState(() => _canvasVisible = visible);
    };
    CanvasCapability.onCaptureScreenshot = _captureCanvasScreenshot;
    _toolMediaSub = ToolMediaEventBus.instance.stream.listen((event) {
      _pendingAiSnapBase64 = event.base64;
      _pendingAiSnapMimeType = event.mimeType;
    });
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadPreferences();
    _localLlmSub = LocalLlmService().stateStream.listen((llmState) {
      if (!mounted) return;
      setState(() => _localLlmState = llmState);

      if ((_localChatModeEnabled == false ||
              llmState.status == LocalLlmStatus.idle) &&
          ModelProviderCatalog.isDirectLocalModelId(_selectedModel)) {
        setState(() => _selectedModel = _cloudFallbackModel);
        PreferencesService().configuredModel = _cloudFallbackModel;
      }
    });
    // React to gateway model changes. Legacy ollama/* preferences are migrated
    // out here so returning users do not get routed to the deprecated daemon.
    _gatewaySub = GatewayService().stateStream.listen((_) {
      if (!mounted) return;
      bool localModeEnabled = _localChatModeEnabled;
      try {
        localModeEnabled = PreferencesService().localChatModeEnabled;
      } catch (_) {}
      if (localModeEnabled != _localChatModeEnabled) {
        setState(() => _localChatModeEnabled = localModeEnabled);
      }

      final prefsModel = PreferencesService().configuredModel;
      if (prefsModel != null &&
          prefsModel.isNotEmpty &&
          prefsModel != _selectedModel) {
        final canonical = ModelProviderCatalog.canonicalizeModelId(prefsModel);
        if (canonical != prefsModel) {
          PreferencesService().configuredModel = canonical;
        }
        if (ModelProviderCatalog.isDirectLocalModelId(canonical) &&
            !localModeEnabled) {
          setState(() => _selectedModel = _cloudFallbackModel);
          PreferencesService().configuredModel = _cloudFallbackModel;
          return;
        }
        // Trust the persisted model selection. The previous check against
        // A stale catalog must never erase the user's persisted selection,
        // especially after a Gateway restart. Only override local models that
        // are not ready.
        if (!ModelProviderCatalog.isDirectLocalModelId(canonical) ||
            (ModelProviderCatalog.isDirectLocalModelId(canonical) &&
                LocalLlmService().state.status == LocalLlmStatus.ready)) {
          final storedSelection = PreferencesService().configuredModelSelection;
          setState(
            () => _selectedModelSelection =
                storedSelection?.matchesModelId(canonical) == true
                ? storedSelection!
                : CanonicalModelSelection.fromModelId(canonical),
          );
        }
      }
    });
    _initVoiceParams();
    _loadChatHistory();
    // Fetch gateway agents after first frame — gateway may not be ready yet
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDynamicAgents());
    _wireGatewayDiagnostics();

    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPModeChanged') {
        final bool isPip = call.arguments as bool;
        if (!mounted) return;
        _voiceSession.updateSurface(
          isPip ? VoiceSessionSurface.pip : VoiceSessionSurface.fullScreen,
        );
        setState(() => _isPipMode = isPip);
        // Moving between full screen and PiP changes the presentation surface,
        // not the voice session. Keep an active capture alive and let the
        // native action reflect the authoritative Flutter state.
        _updatePipMicIcon();
      } else if (call.method == 'toggleMicFromPip') {
        // Native PIP mic button was tapped — toggle voice listening
        _addDiagnosticLog('PIP Mic button tapped (native RemoteAction)');
        await _toggleListeningAsync();
        // Update the native PIP icon to reflect new listening state
        _updatePipMicIcon();
      }
    });

    // --- OpenClaw Skills Event Bus ---
    _skillsSub = SkillsService().events.listen((event) {
      if (!mounted) return;
      if (event.type == SkillsEventType.executing) {
        _addDiagnosticLog('Skill executing: ${event.skillId}');
        // Only set thinking state — gesture is handled by avatar_scene.html's
        // auto-gesture system. Forcing 'pose'/'ready' here conflicts with VRMA
        // clips already playing and causes the avatar to jump.
        setState(() {
          _isThinking = true;
        });
      } else if (event.type == SkillsEventType.executed ||
          event.type == SkillsEventType.error) {
        _addDiagnosticLog('Skill finished: ${event.skillId}');
        setState(() {
          _isThinking = false;
        });
      } else if (event.type == SkillsEventType.toggled) {
        _addDiagnosticLog(
          'Skill toggled: ${event.skillId} — pushing updated catalog to gateway',
        );
        GatewayService().reregisterSkills();
      }
    });
  }

  Future<Map<String, dynamic>> _handleAvatarGestureRequest(
    Map<String, dynamic> request,
  ) async {
    final command = Map<String, dynamic>.from(request);
    if (command['steps'] is List ||
        command['action']?.toString().toLowerCase() == 'sequence') {
      return _handleAvatarSequenceRequest(command);
    }

    final gesture =
        command['gesture'] ??
        command['name'] ??
        command['value'] ??
        command['text'];
    if (gesture == null || gesture.toString().trim().isEmpty) {
      return {
        'status': 'failed',
        'reason': 'avatar.gesture requires a gesture name.',
      };
    }
    final explicitAsset =
        command['assetPath'] ?? command['path'] ?? command['vrmaPath'];
    final resolved = AvatarGestureCatalog.resolve(explicitAsset ?? gesture);
    command['gesture'] = resolved.gesture;
    command['assetPath'] = explicitAsset?.toString().trim().isNotEmpty == true
        ? explicitAsset.toString()
        : resolved.assetPath;
    command['source'] ??= 'chat-screen-avatar-control';
    final normalizedGesture = command['gesture'].toString().toLowerCase();
    final normalizedPath = command['assetPath'].toString().toLowerCase();
    final hasDuration =
        command['durationMs'] != null ||
        command['duration_ms'] != null ||
        command['duration'] != null;
    if (!hasDuration) {
      if (normalizedGesture.contains('dance') ||
          normalizedPath.contains('dance')) {
        command['durationMs'] = 60000;
      } else if (_isSittingGestureRequest(normalizedGesture) ||
          _isSittingGestureRequest(normalizedPath)) {
        command['durationMs'] = 30000;
      }
    }
    if ((_isSittingGestureRequest(normalizedGesture) ||
            _isSittingGestureRequest(normalizedPath)) &&
        command['interrupt'] == null) {
      command['interrupt'] = true;
    }
    debugPrint('[AVATAR] Gesture request: ${jsonEncode(command)}');

    final started = await _avatarController
        .playGestureCommand(command)
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            return {
              'status': 'queued',
              'gesture': command['gesture'],
              'path': command['assetPath'],
              'reason':
                  'Avatar renderer accepted the request but has not started it yet.',
            };
          },
        );

    _addDiagnosticLog(
      'Avatar gesture ${started['status']}: ${started['gesture'] ?? command['gesture']} path=${started['path'] ?? command['assetPath']} bones=${started['humanBoneCount'] ?? '-'} tracks=${started['trackCount'] ?? '-'}',
    );
    debugPrint('[AVATAR] Gesture result: ${jsonEncode(started)}');
    return started;
  }

  Future<Map<String, dynamic>> _handleAvatarSequenceRequest(
    Map<String, dynamic> request,
  ) async {
    final rawSteps = request['steps'];
    if (rawSteps is! List || rawSteps.isEmpty) {
      return {
        'status': 'failed',
        'reason': 'avatar.sequence requires a non-empty steps array.',
      };
    }

    final steps = <Map<String, dynamic>>[];
    for (var i = 0; i < rawSteps.length; i += 1) {
      final raw = rawSteps[i];
      final step = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{'gesture': raw.toString()};
      final gesture =
          step['gesture'] ??
          step['name'] ??
          step['value'] ??
          step['text'] ??
          step['assetPath'] ??
          step['path'] ??
          step['vrmaPath'];
      if (gesture == null || gesture.toString().trim().isEmpty) {
        return {
          'status': 'failed',
          'reason': 'avatar.sequence step ${i + 1} requires a gesture name.',
          'failedStep': i + 1,
        };
      }

      final explicitAsset =
          step['assetPath'] ?? step['path'] ?? step['vrmaPath'];
      final resolved = AvatarGestureCatalog.resolve(explicitAsset ?? gesture);
      step['gesture'] = resolved.gesture;
      step['assetPath'] = explicitAsset?.toString().trim().isNotEmpty == true
          ? explicitAsset.toString()
          : resolved.assetPath;
      step['source'] ??=
          request['source']?.toString() ?? 'chat-screen-avatar-sequence';
      if (i == 0 && request['interruptCurrent'] == true) {
        step['interrupt'] = true;
      }

      final normalizedGesture = step['gesture'].toString().toLowerCase();
      final normalizedPath = step['assetPath'].toString().toLowerCase();
      final hasDuration =
          step['durationMs'] != null ||
          step['duration_ms'] != null ||
          step['duration'] != null;
      if (!hasDuration) {
        if (normalizedGesture.contains('dance') ||
            normalizedPath.contains('dance')) {
          step['durationMs'] = 60000;
        } else if (_isSittingGestureRequest(normalizedGesture) ||
            _isSittingGestureRequest(normalizedPath)) {
          step['durationMs'] = 30000;
        }
      }
      steps.add(step);
    }

    debugPrint('[AVATAR] Sequence request: ${jsonEncode(steps)}');
    final firstResult = await _handleAvatarGestureRequest({
      ...steps.first,
      'sequenceStep': 1,
      'sequenceStepCount': steps.length,
    });
    if (!_isAvatarGestureStarted(firstResult)) {
      return {
        'status': 'failed',
        'reason': 'avatar.sequence step 1 did not start.',
        'failedStep': 1,
        'steps': [
          {'step': 1, ...firstResult},
        ],
      };
    }

    if (steps.length > 1) {
      unawaited(_runAvatarSequenceTail(steps, firstResult));
    }

    final scheduledSteps = <Map<String, dynamic>>[
      {'step': 1, ...firstResult},
      for (var i = 1; i < steps.length; i += 1)
        {
          'step': i + 1,
          'status': 'scheduled',
          'gesture': steps[i]['gesture'],
          'path': steps[i]['assetPath'],
          if (steps[i]['durationMs'] != null)
            'durationMs': steps[i]['durationMs'],
        },
    ];
    _addDiagnosticLog(
      'Avatar sequence started: steps=${steps.length} first=${firstResult['gesture'] ?? steps.first['gesture']}',
    );
    return {
      'status': 'started',
      'gesture': 'sequence',
      'stepCount': steps.length,
      'steps': scheduledSteps,
    };
  }

  Future<void> _runAvatarSequenceTail(
    List<Map<String, dynamic>> steps,
    Map<String, dynamic> firstResult,
  ) async {
    var previousResult = firstResult;
    for (var i = 1; i < steps.length; i += 1) {
      final holdMs = _avatarStepHoldMs(steps[i - 1], previousResult);
      if (holdMs > 0) {
        await Future.delayed(Duration(milliseconds: holdMs));
      }
      final result = await _handleAvatarGestureRequest({
        ...steps[i],
        'sequenceStep': i + 1,
        'sequenceStepCount': steps.length,
      });
      _addDiagnosticLog(
        'Avatar sequence step ${i + 1} ${result['status']}: ${result['gesture'] ?? steps[i]['gesture']}',
      );
      if (!_isAvatarGestureStarted(result)) {
        break;
      }
      previousResult = result;
    }
  }

  bool _isAvatarGestureStarted(Map<String, dynamic> result) {
    final status = result['status']?.toString().toLowerCase();
    return status == 'started' || status == 'completed';
  }

  int _avatarStepHoldMs(
    Map<String, dynamic> step,
    Map<String, dynamic> result,
  ) {
    final value =
        _intFromAvatarMap(step, const [
          'durationMs',
          'duration_ms',
          'duration',
        ]) ??
        _intFromAvatarMap(result, const [
          'durationMs',
          'duration_ms',
          'duration',
        ]);
    if (value == null || value <= 0) return 0;
    return value.clamp(250, 120000).toInt();
  }

  int? _intFromAvatarMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is num) return value.round();
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool _isSittingGestureRequest(String value) {
    return value.contains('sit') || value.contains('seated');
  }

  Future<void> _loadChatHistory() async {
    await _chatRuntime.init();
    await _persistence.init();
    await _chatRuntime.reloadActiveSession();
    _gatewaySessionKey = _persistence.activeGatewaySessionKey;
    final prefs = PreferencesService();
    await prefs.init();
    _agentName = prefs.agentName;

    if (mounted) {
      _syncChatRuntimeState(scrollInstantly: true);
      _scrollToBottom(instant: true);
    }
  }

  void _syncChatRuntimeState({bool scrollInstantly = false}) {
    if (!mounted) return;
    final wasGenerating = _isGenerating;
    final wasTtsSpeaking = _isTtsSpeaking;
    setState(() {
      _messages
        ..clear()
        ..addAll(_chatRuntime.messages);
      for (final log in _chatRuntime.diagnostics) {
        if (!_diagnosticLogs.contains(log)) {
          _diagnosticLogs.add(log);
        }
      }
      if (_diagnosticLogs.length > 200) {
        _diagnosticLogs.removeRange(0, _diagnosticLogs.length - 200);
      }
      _isThinking = _chatRuntime.isThinking;
      _isGenerating = _chatRuntime.isGenerating;
      _isTtsSpeaking = _chatRuntime.isTtsSpeaking;
      _gatewayTtsHealth = _runtimeTtsHealthToScreen(_chatRuntime.ttsHealth);
      _gatewayTtsHealthMessage = _chatRuntime.ttsHealthMessage;
    });
    if (!_isListening) {
      final currentVoicePhase = _voiceSession.state.phase;
      final nextVoicePhase = _isTtsSpeaking
          ? VoiceSessionPhase.speaking
          : _isThinking
          ? VoiceSessionPhase.thinking
          : !_isGenerating &&
                (currentVoicePhase == VoiceSessionPhase.thinking ||
                    currentVoicePhase == VoiceSessionPhase.speaking)
          ? VoiceSessionPhase.idle
          : null;
      if (nextVoicePhase != null &&
          nextVoicePhase != _voiceSession.state.phase) {
        _voiceSession.setPhase(nextVoicePhase);
        _updatePipMicIcon();
      }
    }
    final turnOrPlaybackFinished =
        (wasGenerating && !_isGenerating) ||
        (wasTtsSpeaking && !_isTtsSpeaking);
    if (turnOrPlaybackFinished &&
        !_isGenerating &&
        !_isTtsSpeaking &&
        !_tts.isSpeaking) {
      if (_continuousModeEnabled && _continuousSessionArmed) {
        _scheduleContinuousListening();
      } else {
        unawaited(_resumeWakeWordIfNeeded());
      }
    }
    if (_chatPinnedToBottom ||
        scrollInstantly ||
        _isGenerating ||
        wasGenerating) {
      _scrollToBottom(instant: scrollInstantly);
    }
  }

  /// Fetches available agents from the gateway and populates the model menu.
  /// Called once after first frame; safe to call again when gateway reconnects.
  Future<void> _fetchDynamicAgents() async {
    if (!mounted) return;
    try {
      final gw = context.read<GatewayProvider>();
      final agents = await gw.fetchAgents();
      if (mounted && agents.isNotEmpty) {
        setState(() => _dynamicAgents = agents);
      }
    } catch (_) {
      // Gateway not ready — agents remain empty; will be populated on next health check
    }
  }

  Future<void> _saveChatHistory() async {
    await _chatRuntime.persistNow();
  }

  void _loadPreferences() async {
    final prefs = PreferencesService();
    await prefs.init();
    final cachedCatalog = await DynamicModelCatalogRepository().loadOrBundled();
    final quickModels = _quickModelsForMenu(cachedCatalog);
    final storedConfigured = prefs.configuredModel;
    final localModeEnabled = prefs.localChatModeEnabled;
    final canonicalConfigured = storedConfigured == null
        ? null
        : ModelProviderCatalog.canonicalizeModelId(storedConfigured);
    final storedSelection = prefs.configuredModelSelection;
    if (storedConfigured != null &&
        canonicalConfigured != null &&
        canonicalConfigured != storedConfigured) {
      prefs.configuredModel = canonicalConfigured;
    }
    if (mounted) {
      setState(() {
        _availableDynamicCatalog = cachedCatalog;
        _availableDynamicModels = quickModels;
        _agentName = prefs.agentName;
        _selectedAvatar = prefs.selectedAvatar;
        _localChatModeEnabled = localModeEnabled;

        // Restore the last explicitly-chosen cloud model as the fallback.
        final savedCloud = prefs.lastCloudModel;
        if (savedCloud != null &&
            savedCloud.isNotEmpty &&
            !ModelProviderCatalog.isDirectLocalModelId(savedCloud)) {
          _cloudFallbackModel = ModelProviderCatalog.canonicalizeModelId(
            savedCloud,
          );
        } else {
          // Only derive the cloud fallback from the onboarding-chosen
          // provider when the user has not yet explicitly picked a cloud
          // model. This prevents the onboarding default from clobbering a
          // later user selection on every app restart.
          final provider = prefs.apiProvider;
          if (provider != null &&
              provider.isNotEmpty &&
              !provider.startsWith('local')) {
            _cloudFallbackModel = GatewayService().getModelForProvider(
              provider,
            );
          }
        }

        // Load the user's configured model (from setup or settings).
        // The persisted configuredModel is the single source of truth —
        // trust it over the compact catalog menu, which may still be loading
        // during a cold restart.
        final configured = canonicalConfigured;
        if (configured != null && configured.isNotEmpty) {
          final isLocal = ModelProviderCatalog.isDirectLocalModelId(configured);
          final localReady =
              isLocal && LocalLlmService().state.status == LocalLlmStatus.ready;
          if (isLocal && !localModeEnabled) {
            _selectedModel = _cloudFallbackModel;
            prefs.configuredModel = _cloudFallbackModel;
          } else if (isLocal && !localReady) {
            _selectedModel = _cloudFallbackModel;
            prefs.configuredModel = _cloudFallbackModel;
          } else {
            // Trust the persisted model — it was explicitly saved by the
            // user via the settings/chat dropdown. Do not fall back to
            // _cloudFallbackModel just because the catalog has not refreshed
            // yet.
            _selectedModelSelection =
                storedSelection?.matchesModelId(configured) == true
                ? storedSelection!
                : CanonicalModelSelection.fromModelId(configured);
            if (!isLocal) {
              prefs.lastCloudModel = configured;
            }
          }
        }
      });
    }
  }

  List<DynamicModelRecord> _quickModelsForMenu(DynamicCatalogSnapshot catalog) {
    final quick = <DynamicModelRecord>[];
    for (final provider in catalog.providers) {
      final models = provider.models
          .where(
            (model) => model.liveAvailable && model.supportsToolCalls != false,
          )
          .toList();
      models.sort((a, b) {
        if (a.providerCreatedAt != null && b.providerCreatedAt != null) {
          final byDate = b.providerCreatedAt!.compareTo(a.providerCreatedAt!);
          if (byDate != 0) return byDate;
        } else if (a.providerCreatedAt != null) {
          return -1;
        } else if (b.providerCreatedAt != null) {
          return 1;
        }
        final readiness = _toolReadinessRank(
          b.toolReadiness,
        ).compareTo(_toolReadinessRank(a.toolReadiness));
        if (readiness != 0) return readiness;
        if (a.recommended != b.recommended) {
          return a.recommended ? -1 : 1;
        }
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
      quick.addAll(models.take(3));
    }
    return quick;
  }

  int _toolReadinessRank(ModelToolReadiness readiness) => switch (readiness) {
    ModelToolReadiness.loopVerified => 4,
    ModelToolReadiness.schemaAccepted => 3,
    ModelToolReadiness.providerAdvertised => 2,
    ModelToolReadiness.unknown => 1,
    ModelToolReadiness.incompatible => 0,
  };

  void _addDiagnosticLog(String log) {
    if (!mounted) return;
    setState(() {
      _diagnosticLogs.add(
        '[${DateTime.now().toLocal().toString().split(' ')[1]}] $log',
      );
      if (_diagnosticLogs.length > 200) {
        _diagnosticLogs.removeRange(0, _diagnosticLogs.length - 200);
      }

      // Auto-show diagnostics on first error - REMOVED for better UX
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _wireGatewayDiagnostics() {
    final gateway = GatewayService();
    for (final event in gateway.recentActivity) {
      if (_shouldShowGatewayDiagnostic(event)) {
        _addDiagnosticLog('GW ${_sanitizeGatewayDiagnostic(event)}');
      }
    }
    _gatewayActivitySub = gateway.chatActivityStream.listen((event) {
      if (!mounted || !_shouldShowGatewayDiagnostic(event)) return;
      _addDiagnosticLog('GW ${_sanitizeGatewayDiagnostic(event)}');
    });
  }

  bool _shouldShowGatewayDiagnostic(String event) {
    final lower = event.toLowerCase();
    const prefixes = [
      '[chat]',
      '[node]',
      '[health]',
      '[sess]',
      '[skills]',
      '[tts]',
      '[avatar]',
      '[vrma]',
      '[model]',
      '[warn]',
      '[error]',
      '[native-shadow]',
      '[native-dryrun]',
      '[native-canary]',
      '[native-canary-direct]',
      '[native-primary-canary]',
      '[native-stream-canary]',
      '[native-route-skeleton]',
      '[native-provider-shell]',
      '[native-provider-builder]',
      '[native-transport-shim]',
      '[native-provider-live]',
      '[native-stream-parity]',
      '[native-tool-plan]',
      '[native-tool-dispatch]',
      '[native-dart-bridge]',
      '[native-dart-bridge-order]',
      '[native-dart-bridge-haptic]',
      '[native-dart-bridge-readonly]',
      '[native-dart-bridge-avatar]',
      '[native-runtime-select]',
      '[native-port-bind]',
      '[native-node-embedded]',
      '[native-smoke]',
    ];
    if (prefixes.any((prefix) => lower.startsWith(prefix))) return true;

    const needles = [
      'chat.send',
      'first token',
      'rate limit',
      'model-fetch',
      'stale',
      'file lock',
      'queued_work_without_active_run',
      'talk.speak',
      'talk provider',
      'avatar gesture',
      'vrma',
      'node required',
      'missing node',
      'tools.allow',
      'websocket',
      'event_loop',
      'liveness warning',
      'handshake timeout',
      'direct canary',
      'dry-run',
      'native-node-embedded',
    ];
    return needles.any((needle) => lower.contains(needle));
  }

  String _sanitizeGatewayDiagnostic(String event) {
    var output = event;
    output = output.replaceAllMapped(
      RegExp(
        r'\b(api[_-]?key|authorization|bearer|deviceToken|token)\b\s*[:=]\s*[^,\s})]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=<redacted>',
    );
    output = output.replaceAll(
      RegExp(r'sk-[A-Za-z0-9_-]{10,}', caseSensitive: false),
      'sk-<redacted>',
    );
    if (output.length > 800) {
      output = '${output.substring(0, 800)}...';
    }
    return output;
  }

  Future<void> _syncOverlayState() async {
    // Ported to Native PiP - no-op for now as PiP uses the same activity
  }

  Future<WebViewController> _ensureCanvasController() async {
    final existing = _canvasController;
    if (existing != null) return existing;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _canvasController = controller;
    CanvasCapability().setController(controller);
    CanvasCapability().setViewId(
      0,
    ); // signal canvas ready; native side finds WebView by hierarchy
    await controller.loadRequest(Uri.parse('about:blank'));
    if (mounted) setState(() {});
    return controller;
  }

  Future<Uint8List?> _captureCanvasScreenshot() async {
    final renderObject = _canvasRepaintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  bool get _continuousModeEnabled {
    try {
      return PreferencesService().continuousMode;
    } catch (_) {
      return false;
    }
  }

  String get _wakeWordMode {
    try {
      return PreferencesService().wakeWordMode;
    } catch (_) {
      return 'off';
    }
  }

  bool get _voiceSurfaceCanCapture =>
      _isPipMode || _appLifecycleState == AppLifecycleState.resumed;

  Future<void> _handleWakeWordDetected() async {
    if (!mounted ||
        _wakeWordActivationInFlight ||
        _wakeWordMode == 'off' ||
        _isGenerating ||
        _chatRuntime.isGenerating ||
        _isListening ||
        _voiceSession.state.captureActive ||
        _voiceSession.state.captureStartBlocked) {
      return;
    }

    _wakeWordActivationInFlight = true;
    try {
      _addDiagnosticLog('Wake word "Plawie" detected — activating voice turn');
      await _startListening(owner: VoiceCaptureOwner.wakeWord);
    } finally {
      _wakeWordActivationInFlight = false;
    }
  }

  /// Release the wake-word recognizer before any foreground/PiP voice capture
  /// begins. Android exposes one microphone; two native recognizers must never
  /// race for it. The mode remains persisted so it can be restored after the
  /// current turn finishes.
  Future<void> _pauseWakeWordForVoice() async {
    final prefs = PreferencesService();
    await prefs.init();
    if (prefs.wakeWordMode == 'off') return;

    _wakeWordSuspendedForVoice = true;
    try {
      if (await NativeBridge.isHotwordRunning()) {
        await NativeBridge.stopHotword();
        _addDiagnosticLog('Wake word paused while voice capture owns mic.');
      }
    } catch (e) {
      _addDiagnosticLog('Wake word pause failed: $e');
    }
  }

  Future<void> _resumeWakeWordIfNeeded({bool force = false}) async {
    if (!mounted || !_wakeWordSuspendedForVoice) return;

    final prefs = PreferencesService();
    await prefs.init();
    final mode = prefs.wakeWordMode;
    if (mode == 'off') {
      _wakeWordSuspendedForVoice = false;
      return;
    }
    if ((!force && _continuousModeEnabled) ||
        _isListening ||
        _voiceSession.state.captureActive ||
        _isGenerating ||
        _chatRuntime.isGenerating ||
        _isTtsSpeaking ||
        _tts.isSpeaking) {
      return;
    }
    if (!_voiceSurfaceCanCapture && mode != 'always') return;

    // Claim the handoff before the await so duplicate runtime/TTS callbacks
    // cannot start two HotwordService instances.
    _wakeWordSuspendedForVoice = false;
    try {
      final started = await NativeBridge.setHotwordMode(mode);
      if (!started) {
        _wakeWordSuspendedForVoice = true;
        _addDiagnosticLog('Wake word could not resume (mode: $mode).');
      } else {
        _addDiagnosticLog('Wake word resumed (mode: $mode).');
      }
    } catch (e) {
      _wakeWordSuspendedForVoice = true;
      _addDiagnosticLog('Wake word resume failed: $e');
    }
  }

  /// Return ownership to the idle wake-word service when a voice capture did
  /// not produce a turn. Silence is a normal boundary, not a reason to start
  /// an unbounded recognizer retry loop. Continuous Mode is re-armed after a
  /// successful turn, but an empty capture returns to wake-word standby (or
  /// an idle mic when wake-word mode is off) so a quiet room stays quiet.
  Future<void> _recoverVoiceInputToWakeWord({required String reason}) async {
    _addDiagnosticLog(reason);
    if (_isTalkRelayCaptureActive) {
      await _stopTalkRelayCapture();
      if (mounted) _publishListeningState(false);
    }

    _continuousSessionArmed = false;
    await _resumeWakeWordIfNeeded(force: true);
  }

  Future<void> _initVoiceParams() async {
    // Permission check for recorder is handled at start-time
    _tts.init();
    final prefs = PreferencesService();
    await prefs.init();
    // Subscribe to wake word events from HotwordService (no-op if service not running)
    _hotwordSub = NativeBridge.hotwordEvents.listen(
      (event) {
        if (event == 'wake_word_detected') unawaited(_handleWakeWordDetected());
      },
      onError: (_) {
        /* service not running — ignore */
      },
    );

    final wakeMode = prefs.wakeWordMode;
    if (wakeMode != 'off' && !widget.autoStartVoice) {
      final started = await NativeBridge.setHotwordMode(wakeMode);
      _addDiagnosticLog(
        started
            ? 'Wake word service started (mode: $wakeMode)'
            : 'Wake word service failed to start (mode: $wakeMode)',
      );
    }

    if (widget.autoStartVoice && wakeMode != 'off') {
      // The Dashboard consumed the wake event and stopped the detector before
      // opening this route. Start the actual command capture once Flutter has
      // a mounted voice surface, so the spoken command is not lost during the
      // route transition.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_startListening(owner: VoiceCaptureOwner.wakeWord));
        }
      });
    }

    _tts.onStart = () {
      if (mounted) {
        _voiceSession.setPhase(VoiceSessionPhase.speaking);
        setState(() {
          _speechIntensity = 0.8;
        });
        _syncOverlayState();
        _updatePipMicIcon();
      }
    };

    _tts.onComplete = () {
      if (mounted) {
        _setTtsProcessing(false);
        _processNextTtsInQueue();

        // Only close mouth and reset gesture when the entire queue is drained
        if (_ttsQueue.isEmpty && _ttsSentenceBuffer.isEmpty) {
          if (!_isListening && !_isGenerating) {
            _voiceSession.setPhase(VoiceSessionPhase.idle);
          }
          setState(() {
            _speechIntensity = 0.0;
            _currentGesture = null;
          });
          _syncOverlayState();
          _updatePipMicIcon();

          // Continuous mode: wait 500ms then restart listening automatically.
          if (_continuousModeEnabled &&
              _continuousSessionArmed &&
              !_isGenerating) {
            _scheduleContinuousListening();
          } else {
            unawaited(_resumeWakeWordIfNeeded());
          }
        }
      }
    };
  }

  /// Strips markdown, symbols, URLs, emojis, and other non-speech content so
  /// the TTS engine reads clean natural prose without pronouncing formatting.
  String _stripAssistantControlMarkers(String text) {
    var t = text;
    t = t.replaceAll(
      RegExp(
        r'\((?:gesture|image|tool|action)\s*:[^)]*\)\s*',
        caseSensitive: false,
      ),
      '',
    );
    t = t.replaceAll(
      RegExp(
        r'^\s*(?:gesture|image|tool|action)\s*:\s*.*$',
        caseSensitive: false,
        multiLine: true,
      ),
      '',
    );
    return t.trimRight();
  }

  String _sanitizeForTts(String text) {
    return SpeechTextNormalizer.normalize(text);
  }

  void _enqueueTtsFromStream(String chunk) {
    _ttsSentenceBuffer += chunk;

    // Split on sentence boundaries — including end-of-buffer punctuation with no trailing space
    final sentenceEnd = RegExp(r'[.!?]+\s+|[.!?]+$|[\n]+');
    while (sentenceEnd.hasMatch(_ttsSentenceBuffer)) {
      final match = sentenceEnd.firstMatch(_ttsSentenceBuffer)!;
      final sentence = _ttsSentenceBuffer.substring(0, match.end);
      _ttsSentenceBuffer = _ttsSentenceBuffer.substring(match.end);

      final clean = _sanitizeForTts(sentence);
      final key = SpeechTextNormalizer.dedupeKey(clean);
      if (clean.isNotEmpty && key.isNotEmpty && _queuedTtsKeys.add(key)) {
        _ttsQueue.add(clean);
        _processNextTtsInQueue();
      }
    }
  }

  void _setGatewayTtsHealth(
    _GatewayTtsHealth health, {
    String? message,
    bool notify = true,
  }) {
    if (!mounted) return;
    final changed =
        _gatewayTtsHealth != health || _gatewayTtsHealthMessage != message;
    setState(() {
      _gatewayTtsHealth = health;
      _gatewayTtsHealthMessage = message;
    });
    if (!notify ||
        health == _GatewayTtsHealth.normal ||
        health == _GatewayTtsHealth.processing ||
        message == null) {
      return;
    }
    final now = DateTime.now();
    final last = _lastGatewayTtsNoticeAt;
    if (!changed &&
        last != null &&
        now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastGatewayTtsNoticeAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: switch (health) {
          _GatewayTtsHealth.failed => AppColors.statusRed,
          _GatewayTtsHealth.processing => Colors.cyanAccent,
          _ => AppColors.statusAmber,
        },
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  _GatewayTtsHealth _runtimeTtsHealthToScreen(ChatRuntimeTtsHealth health) {
    switch (health) {
      case ChatRuntimeTtsHealth.normal:
        return _GatewayTtsHealth.normal;
      case ChatRuntimeTtsHealth.processing:
        return _GatewayTtsHealth.normal;
      case ChatRuntimeTtsHealth.degraded:
        return _GatewayTtsHealth.degraded;
      case ChatRuntimeTtsHealth.failed:
        return _GatewayTtsHealth.failed;
    }
  }

  bool get _isGatewayTtsUnavailable =>
      _gatewayTtsHealth == _GatewayTtsHealth.degraded ||
      _gatewayTtsHealth == _GatewayTtsHealth.failed;

  Color? _gatewayTtsAuraColor() {
    switch (_gatewayTtsHealth) {
      case _GatewayTtsHealth.normal:
      case _GatewayTtsHealth.processing:
        return null;
      case _GatewayTtsHealth.degraded:
        return AppColors.statusAmber;
      case _GatewayTtsHealth.failed:
        return AppColors.statusRed;
    }
  }

  Color _chatNobTtsColor() {
    switch (_gatewayTtsHealth) {
      case _GatewayTtsHealth.normal:
      case _GatewayTtsHealth.processing:
        return AppColors.statusGreen;
      case _GatewayTtsHealth.degraded:
        return AppColors.statusAmber;
      case _GatewayTtsHealth.failed:
        return AppColors.statusRed;
    }
  }

  List<Color> _chatNobGradientColors(ThemeData theme) {
    final color = _chatNobTtsColor();
    if (!_isGatewayTtsUnavailable) {
      return [
        AppColors.statusGreen.withValues(alpha: 0.95),
        theme.colorScheme.primary.withValues(alpha: 0.82),
      ];
    }
    return [
      color.withValues(alpha: 0.96),
      Color.lerp(color, Colors.black, 0.28)!.withValues(alpha: 0.88),
    ];
  }

  void _setTtsProcessing(bool value) {
    final nextHealth = _gatewayTtsHealth == _GatewayTtsHealth.processing
        ? _GatewayTtsHealth.normal
        : _gatewayTtsHealth;
    if (_isTtsSpeaking == value && _gatewayTtsHealth == nextHealth) return;
    if (mounted) {
      setState(() {
        _isTtsSpeaking = value;
        _gatewayTtsHealth = nextHealth;
        if (nextHealth == _GatewayTtsHealth.normal) {
          _gatewayTtsHealthMessage = null;
        }
      });
    } else {
      _isTtsSpeaking = value;
      _gatewayTtsHealth = nextHealth;
    }
  }

  Future<void> _processNextTtsInQueue() async {
    if (_isTtsSpeaking || _ttsQueue.isEmpty || _tts.isSpeaking) return;
    _setTtsProcessing(true);
    final sentence = _ttsQueue.removeAt(0);
    try {
      if (!mounted) {
        _setTtsProcessing(false);
        return;
      }
      if (ModelProviderCatalog.isLocalModelId(_selectedModel)) {
        await _tts.speak(sentence);
        return;
      }
      final gatewayProvider = Provider.of<GatewayProvider>(
        context,
        listen: false,
      );
      final playback = await gatewayProvider.speakTextViaTalk(sentence);
      if (playback.played) {
        _setGatewayTtsHealth(_GatewayTtsHealth.normal, notify: false);
      }
      if (!playback.played && playback.allowNativeFallback) {
        // Resilient fallback path for unavailable or transient Gateway Talk.
        _setGatewayTtsHealth(
          _GatewayTtsHealth.degraded,
          message:
              playback.displayMessage ??
              'Gateway voice is unavailable on this runtime; using local system TTS.',
        );
        await _tts.speak(sentence);
        if (!_tts.isSpeaking) {
          _setTtsProcessing(false);
          _processNextTtsInQueue();
        }
      } else if (!playback.played && playback.displayMessage != null) {
        _addDiagnosticLog(
          'Gateway Talk voice ${playback.status}: ${playback.displayMessage}',
        );
        final degraded = playback.status.contains('backoff');
        _setGatewayTtsHealth(
          degraded ? _GatewayTtsHealth.degraded : _GatewayTtsHealth.failed,
          message: playback.displayMessage!,
        );
        _setTtsProcessing(false);
        _processNextTtsInQueue();
      } else if (!playback.played) {
        // Backoff/skip responses (for example temporary Talk suppression) must
        // release the queue lock, otherwise viseme + speech state can freeze.
        _setGatewayTtsHealth(
          _GatewayTtsHealth.degraded,
          message: 'Gateway voice skipped playback (${playback.status}).',
        );
        _setTtsProcessing(false);
        _processNextTtsInQueue();
      }
    } catch (e) {
      // Guarantee _isTtsSpeaking is cleared on error so queue isn't permanently jammed
      _addDiagnosticLog('Gateway Talk voice exception: $e');
      _setGatewayTtsHealth(
        _GatewayTtsHealth.failed,
        message: 'Gateway voice failed: $e',
      );
      _setTtsProcessing(false);
      _processNextTtsInQueue();
    }
  }

  Future<void> _flushTtsQueue() async {
    final clean = _sanitizeForTts(_ttsSentenceBuffer);
    final key = SpeechTextNormalizer.dedupeKey(clean);
    if (clean.isNotEmpty && key.isNotEmpty && _queuedTtsKeys.add(key)) {
      _ttsQueue.add(clean);
      _processNextTtsInQueue();
    }
    _ttsSentenceBuffer = '';
  }

  List<Map<String, dynamic>> _conversationHistoryBeforePendingReply() {
    // _handleSubmit appends the current user message and then an empty
    // assistant placeholder before building history. Exclude both here, then
    // pass the current text separately to avoid duplicating the latest user turn
    // and burning local context twice as fast.
    final endExclusive = _messages.length >= 2
        ? _messages.length - 2
        : _messages.length;
    return _messages
        .take(endExclusive)
        .where((m) => m.text.trim().isNotEmpty)
        .map(
          (m) => <String, dynamic>{
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.text,
          },
        )
        .toList();
  }

  void _scrollToBottom({bool instant = false}) {
    _chatPinnedToBottom = true;
    _scheduleScrollToBottom(instant: instant, remainingAttempts: 8);
  }

  void _scheduleScrollToBottom({
    required bool instant,
    required int remainingAttempts,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) {
          if (remainingAttempts > 0) {
            _scheduleScrollToBottom(
              instant: instant,
              remainingAttempts: remainingAttempts - 1,
            );
          }
          return;
        }

        final position = _scrollController.position;
        final max = position.maxScrollExtent;
        if (!max.isFinite) return;
        final target = max.clamp(position.minScrollExtent, max).toDouble();

        if ((position.pixels - target).abs() > 1.0) {
          if (instant || remainingAttempts > 4) {
            _scrollController.jumpTo(target);
          } else {
            unawaited(
              _scrollController.animateTo(
                target,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              ),
            );
          }
        }

        if (remainingAttempts > 0) {
          _scheduleScrollToBottom(
            instant: instant,
            remainingAttempts: remainingAttempts - 1,
          );
        }
      });
    });
  }

  void _handleChatScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _chatPinnedToBottom = position.maxScrollExtent - position.pixels < 96.0;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_chatPinnedToBottom || !_isChatCollapsed) {
      _scrollToBottom(instant: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Vision — camera capture
  // ---------------------------------------------------------------------------

  Future<void> _takePicture() async {
    if (_isTakingPhoto) return;
    setState(() => _isTakingPhoto = true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No camera available on this device.'),
            ),
          );
        }
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
      );
      await controller.initialize();
      final file = await controller.takePicture();
      await controller.dispose();

      final bytes = await File(file.path).readAsBytes();
      await File(file.path).delete().catchError((_) => File(file.path));

      if (mounted) {
        setState(() => _pendingImageBase64 = base64Encode(bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Video — clip record + duration picker
  // ---------------------------------------------------------------------------

  Future<void> _recordVideo({int durationMs = 5000}) async {
    if (_isRecordingVideo) return;
    setState(() => _isRecordingVideo = true);
    try {
      final bytes = await VideoCaptureService.recordClip(
        durationMs: durationMs,
      );
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video capture failed. Check camera permissions.'),
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _pendingVideoBase64 = base64Encode(bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Video error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isRecordingVideo = false);
    }
  }

  Future<void> _showVideoDurationPicker() async {
    final options = {'3s': 3000, '5s': 5000, '10s': 10000, '30s': 30000};
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Video Duration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...options.entries.map(
              (e) => ListTile(
                title: Text(e.key, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, e.value),
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await _recordVideo(durationMs: chosen);
    }
  }

  // ---------------------------------------------------------------------------

  bool _shouldUseGatewaySessionBindingForMessage({
    required String text,
    required bool isLocalModelSelected,
    required bool hasMediaAttachment,
  }) {
    // OpenClaw's current mobile gateway reliably dispatches chat on its
    // default agent session. Dedicated mobile session keys can be accepted by
    // sessions.create but then stall in "queued_work_without_active_run".
    // Flutter still keeps per-chat history locally, so we avoid binding the
    // gateway lane until the upstream session dispatcher is proven stable.
    return false;
  }

  bool _isUnsafeGatewaySessionKey(String? key) {
    final normalized = key?.trim().toLowerCase() ?? '';
    return normalized.isEmpty ||
        normalized == 'main' ||
        normalized == 'agent:main:main';
  }

  bool _isRecoverableGatewaySessionFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('stale_session_state') ||
        lower.contains('file lock stale') ||
        lower.contains('queued_work_without_active_run') ||
        lower.contains('session file repaired') ||
        lower.contains('agent cleanup timed out');
  }

  Future<void> _handleSubmit(
    String text, {
    bool explicitToolCompatibilityProbe = false,
  }) async {
    if (explicitToolCompatibilityProbe &&
        !ModelToolCompatibilityProbe.isProbe(text)) {
      throw StateError(
        'Only the app-owned compatibility prompt can enter probe mode.',
      );
    }
    if (explicitToolCompatibilityProbe &&
        (_pendingImageBase64 != null || _pendingVideoBase64 != null)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remove the pending photo or video before running the read-only tool test.',
          ),
        ),
      );
      return;
    }
    if ((text.trim().isEmpty &&
            _pendingImageBase64 == null &&
            _pendingVideoBase64 == null) ||
        _chatRuntime.isGenerating) {
      return;
    }

    PaidProviderTurnLease? paidProviderTurnLease;
    PaidProviderId? paidProvider;
    for (final candidate in PaidProviderId.values) {
      if (_selectedModel.startsWith('${candidate.wireName}/')) {
        paidProvider = candidate;
        break;
      }
    }
    if (paidProvider != null) {
      try {
        final conversationId = _persistence.activeSessionId?.trim() ?? '';
        paidProviderTurnLease = PaidProviderTurnAuthorizationService.instance
            .authorizeForegroundUserTurn(
              conversationId: conversationId,
              provider: paidProvider,
              modelId: _selectedModel,
            );
      } on PaidProviderTurnAuthorizationException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
      if (explicitToolCompatibilityProbe) {
        PaidProviderToolProbeAuthorization.instance.authorize(
          provider: paidProvider,
          modelId: _selectedModel,
        );
      }
    }

    _voiceSession.setPhase(VoiceSessionPhase.thinking);
    final imageBase64 = _pendingImageBase64;
    final videoBase64 = _pendingVideoBase64;
    FocusManager.instance.primaryFocus?.unfocus();
    _textController.clear();
    setState(() {
      _pendingImageBase64 = null;
      _pendingVideoBase64 = null;
      _speechIntensity = 0.0;
    });
    _syncOverlayState();
    _updatePipMicIcon();
    _scrollToBottom();

    unawaited(
      _chatRuntime.sendMessage(
        text: text,
        model: _selectedModel,
        imageBase64: imageBase64,
        videoBase64: videoBase64,
        paidProviderTurnLease: paidProviderTurnLease,
        explicitToolCompatibilityProbe: explicitToolCompatibilityProbe,
      ),
    );
  }

  bool _gifgrepConfigSheetOpen = false;

  Future<void> _handleConfigurationRequest(
    ChatConfigurationRequest request,
  ) async {
    if (!mounted || request.skillId != 'gifgrep' || _gifgrepConfigSheetOpen) {
      return;
    }
    _gifgrepConfigSheetOpen = true;
    try {
      await showGifgrepConfigSheet(context);
    } finally {
      _gifgrepConfigSheetOpen = false;
    }
  }

  Future<void> _importGif() async {
    try {
      final path = await GifgrepMediaStore.importGif();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null
                ? 'GIF import cancelled.'
                : 'GIF imported. Ask gifgrep for a still or contact sheet.',
          ),
          backgroundColor: path == null
              ? AppColors.statusAmber
              : AppColors.statusGreen,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GIF import failed: $error'),
          backgroundColor: AppColors.statusRed,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _handleSubmitLegacy(String text) async {
    if ((text.trim().isEmpty &&
            _pendingImageBase64 == null &&
            _pendingVideoBase64 == null) ||
        _isGenerating) {
      return;
    }

    // Stop any in-progress TTS and clear the queue so the previous response
    // doesn't keep playing while the user has already sent a new message.
    _tts.stop();
    _ttsQueue.clear();
    _queuedTtsKeys.clear();
    _ttsSentenceBuffer = '';
    _setTtsProcessing(false);
    // Also stop unified TTS (handles both local and gateway audio)
    _tts.stop();
    setState(() => _speechIntensity = 0.0);

    // Capture and clear pending attachments before any async gaps
    final imageBase64 = _pendingImageBase64;
    final videoBase64 = _pendingVideoBase64;
    _textController.clear();
    setState(() {
      _pendingImageBase64 = null;
      _pendingVideoBase64 = null;
      _messages.add(
        ChatMessage(
          text: text.trim().isEmpty && videoBase64 != null
              ? '🎬 Video clip'
              : text,
          isUser: true,
          imageBase64: imageBase64,
          imageMimeType: imageBase64 != null ? 'image/jpeg' : null,
        ),
      );
      _isThinking = true;
      _isGenerating = true;
    });
    _syncOverlayState();
    _scrollToBottom();
    _saveChatHistory(); // Save user message
    _addDiagnosticLog('Sending message: $text');

    // Add empty placeholder for the assistant reply
    setState(() {
      _messages.add(ChatMessage(text: '', isUser: false));
    });

    String fullResponse = '';
    final sendStopwatch = Stopwatch()..start();
    var loggedFirstAssistantChunk = false;
    final List<ChatToolEvent> toolEvents = [];
    // <think> block parser state — strips Qwen/DeepSeek reasoning tokens from the
    // main response and accumulates them separately for the collapsible Reasoning UI.
    // Uses a raw-buffer approach so tags split across chunks are handled correctly.
    String rawBuffer = ''; // all tokens accumulated, including <think> tags
    String thinkBuffer = ''; // text inside <think>…</think>

    /// Process one new chunk: appends to [rawBuffer], re-parses the full raw text,
    /// and returns only the visible (non-think) portion. Updates [thinkBuffer].
    String parseThinkChunk(String chunk) {
      rawBuffer += chunk;
      final out = StringBuffer();
      final think = StringBuffer();
      bool inThink = false;
      int i = 0;
      while (i < rawBuffer.length) {
        if (!inThink && rawBuffer.startsWith('<think>', i)) {
          inThink = true;
          i += 7;
        } else if (inThink && rawBuffer.startsWith('</think>', i)) {
          inThink = false;
          i += 8;
        } else if (inThink) {
          think.write(rawBuffer[i]);
          i++;
        } else {
          out.write(rawBuffer[i]);
          i++;
        }
      }
      thinkBuffer = think.toString();
      return _stripAssistantControlMarkers(out.toString());
    }

    try {
      final gatewayProvider = Provider.of<GatewayProvider>(
        context,
        listen: false,
      );
      final localLlm = LocalLlmService();

      // Route based on attachment type & model
      final Stream<String> stream;
      final isLocalModelSelected = ModelProviderCatalog.isLocalModelId(
        _selectedModel,
      );
      String? streamSessionKey = _isUnsafeGatewaySessionKey(_gatewaySessionKey)
          ? null
          : _gatewaySessionKey;
      final bindGatewaySession = _shouldUseGatewaySessionBindingForMessage(
        text: text,
        isLocalModelSelected: isLocalModelSelected,
        hasMediaAttachment: imageBase64 != null || videoBase64 != null,
      );
      if (!bindGatewaySession) {
        streamSessionKey = null;
      }
      _addDiagnosticLog(
        bindGatewaySession
            ? 'Gateway session preflight required for $_selectedModel'
            : 'Gateway session preflight skipped for $_selectedModel',
      );

      if (bindGatewaySession) {
        final localSessionId = _persistence.activeSessionId;
        if (localSessionId != null && localSessionId.isNotEmpty) {
          final resolvedSessionKey = await gatewayProvider
              .resolveOrCreateGatewaySessionKey(
                localSessionId: localSessionId,
                existingSessionKey:
                    _isUnsafeGatewaySessionKey(_gatewaySessionKey)
                    ? null
                    : _gatewaySessionKey,
              );
          if (resolvedSessionKey.isNotEmpty &&
              resolvedSessionKey != _gatewaySessionKey) {
            _gatewaySessionKey = resolvedSessionKey;
            await _persistence.setActiveGatewaySessionKey(resolvedSessionKey);
            _addDiagnosticLog(
              'Bound chat to gateway session: $resolvedSessionKey',
            );
          }
          streamSessionKey = resolvedSessionKey;
        }
      }

      if (isLocalModelSelected) {
        // --- PATH A: Native Local LLM (fllama bypass) ---
        if (videoBase64 != null) {
          if (localLlm.isVisionReady) {
            _addDiagnosticLog('Local Video path: offline frame analysis');
            stream = () async* {
              yield 'Extracting video frames…';
              final mp4Bytes = base64Decode(videoBase64);
              final frames = await VideoFrameExtractor.extractFrames(
                mp4Bytes,
                fps: 1,
                maxFrames: 8,
              );
              if (frames.isEmpty) {
                yield '⚠️ Could not extract frames. Provision android-vision-media-runtime so Native ffmpeg is available.';
                return;
              }
              yield* localLlm.analyseVideoFrames(
                frames,
                text.trim().isEmpty ? 'Describe what is happening.' : text,
              );
            }().cast<String>();
          } else {
            stream = Stream.value(
              '🎥 Video captured, but no local vision model is active. Please start a multimodal model like Qwen2-VL.',
            );
          }
        } else if (imageBase64 != null) {
          if (localLlm.isVisionReady) {
            _addDiagnosticLog(
              'Local Vision path: local multimodal model active',
            );
            stream = gatewayProvider.sendVisionMessage(text, imageBase64);
          } else {
            stream = Stream.value(
              '📷 Image captured, but no local vision model is active.\n\n'
              'To analyse images locally, go to **Local LLM** and start either:\n'
              '• **Qwen2-VL 2B** (compact, ~3 GB RAM)\n'
              '• **LLaVA 1.5 7B** (flagship phones, ~6 GB RAM)',
            );
          }
        } else {
          // Local Text
          final conversationHistory = _conversationHistoryBeforePendingReply();
          stream = gatewayProvider.sendMessage(
            text,
            model: _selectedModel,
            conversationHistory: conversationHistory,
            sessionKey: streamSessionKey,
          );
        }
      } else {
        // --- PATH B: Cloud / Integrated Node Gateway ---
        if (videoBase64 != null) {
          _addDiagnosticLog('Cloud Video path: sending MP4 via gateway');
          stream = gatewayProvider.sendCloudVideoMessage(
            text.trim().isEmpty
                ? 'Describe what is happening in this video.'
                : text,
            videoBase64,
          );
        } else if (imageBase64 != null) {
          _addDiagnosticLog('Cloud Vision path: sending Image via gateway');
          stream = gatewayProvider.sendCloudImageMessage(
            text.trim().isEmpty ? 'Describe what you see in this image.' : text,
            imageBase64,
          );
        } else {
          final conversationHistory = _conversationHistoryBeforePendingReply();
          stream = gatewayProvider.sendMessage(
            text,
            model: _selectedModel,
            conversationHistory: conversationHistory,
            sessionKey: streamSessionKey,
          );
        }
      }
      void applyChatUpdate(
        VoidCallback update, {
        bool syncOverlay = false,
        bool scroll = false,
      }) {
        if (mounted) {
          setState(update);
          if (syncOverlay) _syncOverlayState();
          if (scroll) _scrollToBottom();
        } else {
          update();
        }
      }

      await for (final chunk in stream) {
        // Keep consuming the backend stream even if the user navigates away.
        // The widget may be unmounted, but this async turn can still update
        // in-memory history and persist the final assistant message.

        if (!loggedFirstAssistantChunk &&
            chunk.trim().isNotEmpty &&
            !chunk.startsWith('\x00TOOL_')) {
          loggedFirstAssistantChunk = true;
          _addDiagnosticLog(
            'First assistant chunk after ${sendStopwatch.elapsedMilliseconds}ms',
          );
        }
        _addDiagnosticLog('Chunk received: "$chunk"');

        // Tool call/result markers injected by gateway_service as \x00TOOL_USE:name:json\x00
        if (chunk.startsWith('\x00TOOL_USE:') && chunk.endsWith('\x00')) {
          final inner = chunk.substring(10, chunk.length - 1);
          final colonIdx = inner.indexOf(':');
          if (colonIdx != -1) {
            final name = inner.substring(0, colonIdx);
            final inputJson = inner.substring(colonIdx + 1);
            try {
              final input = jsonDecode(inputJson) as Map<String, dynamic>?;
              toolEvents.add(
                ChatToolEvent(type: 'tool_use', name: name, input: input),
              );
            } catch (_) {
              toolEvents.add(ChatToolEvent(type: 'tool_use', name: name));
            }
            // Reset streaming buffers after a tool call. The gateway resets its
            // assistantSnapshot on tool_use, so the next stream=assistant event
            // will send a fresh cumulative snapshot. Without resetting rawBuffer
            // here, the old text from before the tool call gets concatenated with
            // the new text after the tool call, producing duplicated output.
            rawBuffer = '';
            thinkBuffer = '';
            applyChatUpdate(() {
              _messages.last = ChatMessage(
                text: fullResponse,
                isUser: false,
                thinkContent: thinkBuffer.isNotEmpty ? thinkBuffer : null,
                toolEvents: List.unmodifiable(toolEvents),
              );
            });
          }
          continue;
        }
        if (chunk.startsWith('\x00TOOL_RESULT:') && chunk.endsWith('\x00')) {
          final inner = chunk.substring(13, chunk.length - 1);
          final colonIdx = inner.indexOf(':');
          if (colonIdx != -1) {
            final name = inner.substring(0, colonIdx);
            final resultJson = inner.substring(colonIdx + 1);
            toolEvents.add(
              ChatToolEvent(
                type: 'tool_result',
                name: name,
                result: resultJson,
              ),
            );
            // Reset streaming buffers on tool_result as well — the gateway
            // resets assistantSnapshot here too.
            rawBuffer = '';
            thinkBuffer = '';
            applyChatUpdate(() {
              _messages.last = ChatMessage(
                text: fullResponse,
                isUser: false,
                thinkContent: thinkBuffer.isNotEmpty ? thinkBuffer : null,
                toolEvents: List.unmodifiable(toolEvents),
              );
            });
          }
          continue;
        }

        // Handle common API error patterns and OpenClaw error frames
        if (chunk.contains('[Error]') ||
            chunk.contains('rate limit reached') ||
            chunk.contains('API error')) {
          _addDiagnosticLog('Caught API Error in stream: $chunk');
          var errorMsg = chunk.replaceAll('[Error]', '').trim();
          if (_isRecoverableGatewaySessionFailure(errorMsg)) {
            _gatewaySessionKey = null;
            await _persistence.setActiveGatewaySessionKey(null);
            errorMsg =
                'Gateway session became stale and was reset. Please resend this message.';
            _addDiagnosticLog(
              'Cleared stale gateway session binding after gateway error.',
            );
          }
          applyChatUpdate(() {
            _isThinking = false;
            _isGenerating = false;
            if (fullResponse.isEmpty) {
              fullResponse = '⚠️ $errorMsg';
            } else {
              fullResponse += '\n\n⚠️ $errorMsg';
            }
            _messages.last = ChatMessage(text: fullResponse, isUser: false);
          });
          break; // Stop listening to this stream
        }

        // Strip <think> blocks from visible text; thinkBuffer gets the reasoning.
        // parseThinkChunk re-parses rawBuffer each call so split-tag chunks work.
        final oldLen = fullResponse.length;
        fullResponse = parseThinkChunk(chunk);

        if (fullResponse.length > oldLen) {
          _enqueueTtsFromStream(fullResponse.substring(oldLen));
        }

        applyChatUpdate(
          () {
            _isThinking = false; // Stopped thinking, started talking
            // _speechIntensity is driven ONLY by _tts.onStart/onComplete — not chunk arrival

            // Check for (gesture: name) in bot response. This is a fallback for
            // providers that can follow instructions but do not emit structured
            // tool calls on the current route.
            if (chunk.contains('(gesture:')) {
              final match = RegExp(r'\(gesture:\s*([^)]+)\)').firstMatch(chunk);
              if (match != null) {
                final requestedGesture = (match.group(1) ?? '')
                    .split(',')
                    .first
                    .trim();
                if (requestedGesture.isNotEmpty) {
                  _currentGesture = requestedGesture;
                  unawaited(
                    _handleAvatarGestureRequest({
                      'gesture': requestedGesture,
                      'source': 'assistant-inline-marker',
                    }),
                  );
                }
              }
            }

            _messages.last = ChatMessage(
              text: fullResponse,
              isUser: false,
              thinkContent: thinkBuffer.isNotEmpty ? thinkBuffer : null,
              toolEvents: toolEvents.isNotEmpty
                  ? List.unmodifiable(toolEvents)
                  : null,
            );
          },
          syncOverlay: true,
          scroll: true,
        );
      }
      // Speak any remaining buffered text
      await _flushTtsQueue();
    } catch (e) {
      _addDiagnosticLog('Exception during Chat: $e');
      if (mounted) {
        setState(() {
          _isThinking = false;
          fullResponse += '\n\n[Error: $e]';
          _messages.last = ChatMessage(text: fullResponse, isUser: false);
        });
      } else if (_messages.isNotEmpty) {
        _isThinking = false;
        fullResponse += '\n\n[Error: $e]';
        _messages.last = ChatMessage(text: fullResponse, isUser: false);
      }
    }

    void finishTurnState() {
      _isThinking = false;
      _isGenerating = false;
      // Do NOT reset _speechIntensity here — TTS queue may still be draining.
      // onComplete fires when the last sentence finishes and will close the mouth.

      // Empty stream: model may still be loading, gateway unavailable, or provider error.
      if (fullResponse.trim().isEmpty) {
        fullResponse =
            '⚠️ No response received. The model may still be loading — please try again in a moment.';
        _messages.last = ChatMessage(text: fullResponse, isUser: false);
      }

      // If the AI called camera.snap during this turn, attach the image to the bot reply
      final snapImage = _pendingAiSnapBase64;
      final snapMime = _pendingAiSnapMimeType ?? 'image/jpeg';
      if (snapImage != null && _messages.isNotEmpty) {
        _messages.last = ChatMessage(
          text: _messages.last.text,
          isUser: false,
          thinkContent: _messages.last.thinkContent,
          toolEvents: _messages.last.toolEvents,
          imageBase64: snapImage,
          imageMimeType: snapMime,
        );
        _pendingAiSnapBase64 = null;
        _pendingAiSnapMimeType = null;
      }
    }

    if (mounted) {
      setState(finishTurnState);
      _syncOverlayState();
      _addDiagnosticLog(
        'Generation completed. Total length: ${fullResponse.length}',
      );
    } else {
      finishTurnState();
    }
    // Persist the completed assistant turn (including error fallback messages).
    // The earlier _saveChatHistory() at send-time only captures the user message;
    // the assistant placeholder is added after that point and never gets saved
    // without this call — causing the last assistant turn to vanish on navigation.
    _saveChatHistory();

    // Continuous mode: if there is no TTS audio queued or playing, restart
    // listening now. When TTS IS active the onComplete / onPlayerComplete
    // callbacks handle the restart once the last audio chunk finishes.
    if (mounted &&
        _continuousModeEnabled &&
        _continuousSessionArmed &&
        !_tts.isSpeaking &&
        _ttsQueue.isEmpty) {
      _scheduleContinuousListening();
    }
  }

  void _toggleListening() {
    unawaited(_toggleListeningAsync());
  }

  Future<void> _toggleListeningAsync() async {
    final voiceState = _voiceSession.state;
    if (_isListening || voiceState.captureActive) {
      await _stopListening();
      return;
    }

    // A PiP action can arrive while the previous turn is still transcribing
    // or while its reply/TTS is being delivered. Do not turn that action into
    // a second capture owner; the current turn must reach a terminal state
    // first.
    if (voiceState.phase == VoiceSessionPhase.transcribing ||
        voiceState.phase == VoiceSessionPhase.thinking ||
        voiceState.phase == VoiceSessionPhase.speaking ||
        voiceState.phase == VoiceSessionPhase.reconnecting) {
      _addDiagnosticLog(
        'Voice toggle ignored while phase=${voiceState.phase.name}.',
      );
      return;
    }

    await _startListening();
  }

  void _scheduleContinuousListening() {
    if (!mounted || !_continuousModeEnabled || !_continuousSessionArmed) return;
    if (!_voiceSurfaceCanCapture) return;

    _continuousListeningTimer?.cancel();
    final generation = _voiceSession.state.generation;
    _continuousListeningTimer = Timer(const Duration(milliseconds: 500), () {
      _continuousListeningTimer = null;
      if (!mounted ||
          !_continuousModeEnabled ||
          !_continuousSessionArmed ||
          !_voiceSurfaceCanCapture ||
          !_voiceSession.isCurrent(generation) ||
          _isGenerating ||
          _chatRuntime.isGenerating ||
          _isTtsSpeaking ||
          _tts.isSpeaking ||
          _isListening ||
          _voiceSession.state.captureStartBlocked) {
        return;
      }
      unawaited(_startListening());
    });
  }

  Future<bool> _probeTalkRelaySupport(GatewayProvider gatewayProvider) async {
    final now = DateTime.now();
    final lastChecked = _talkRelaySupportCheckedAt;
    if (lastChecked != null && now.difference(lastChecked).inSeconds < 45) {
      return _talkRelaySupported;
    }
    _talkRelaySupportCheckedAt = now;

    if (ModelProviderCatalog.isLocalModelId(_selectedModel)) {
      _talkRelaySupported = false;
      return false;
    }

    final methods = gatewayProvider.supportedMethods;
    final requiredMethods = <String>{
      'talk.session.create',
      'talk.session.appendAudio',
      'talk.session.close',
    };
    final supportsTalkMethods = requiredMethods.every(methods.contains);
    if (!supportsTalkMethods) {
      _talkRelaySupported = false;
      return false;
    }

    try {
      final catalog = await gatewayProvider.getTalkCatalog();
      final realtime = catalog['realtime'];
      String activeProvider = '';
      bool anyConfigured = false;
      if (realtime is Map) {
        activeProvider = (realtime['activeProvider'] ?? '').toString().trim();
        final providers = realtime['providers'];
        if (providers is List) {
          anyConfigured = providers.any(
            (p) =>
                p is Map &&
                (p['configured'] == true || p['configured'] == 'true'),
          );
        }
      }
      _talkRelaySupported = activeProvider.isNotEmpty || anyConfigured;
      if (_talkRelaySupported) {
        _addDiagnosticLog(
          'Talk relay available (provider=${activeProvider.isEmpty ? 'auto' : activeProvider}).',
        );
      } else {
        _addDiagnosticLog(
          'Talk relay unsupported: no configured realtime provider; using native talk fallback.',
        );
      }
      return _talkRelaySupported;
    } catch (e) {
      _talkRelaySupported = false;
      _addDiagnosticLog('Talk relay probe failed: $e');
      return false;
    }
  }

  Future<bool> _ensureTalkRelaySession(GatewayProvider gatewayProvider) async {
    if (_talkRelaySessionId != null &&
        _talkRelaySessionId!.isNotEmpty &&
        _talkEventSub != null) {
      return true;
    }
    _talkRelaySessionId = null;
    try {
      final locale = Platform.localeName.replaceAll('-', '_');
      final language = locale.split('_').first.trim();
      final session = await gatewayProvider.createTalkRealtimeRelaySession(
        language: language.isEmpty ? null : language,
      );
      final sessionId =
          (session['sessionId'] ??
                  session['relaySessionId'] ??
                  session['transcriptionSessionId'])
              ?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        _addDiagnosticLog('Talk relay create returned no session id.');
        return false;
      }
      _talkRelaySessionId = sessionId;
      _talkRelayReady = false;
      _talkEventSub?.cancel();
      _talkEventSub = gatewayProvider.gatewayEventStream.listen(
        _handleTalkRelayEventFrame,
        onError: (e) => _addDiagnosticLog('Talk relay event stream error: $e'),
      );
      _addDiagnosticLog('Talk relay session created: $sessionId');
      return true;
    } catch (e) {
      _addDiagnosticLog('Talk relay create failed: $e');
      return false;
    }
  }

  void _handleTalkRelayEventFrame(Map<String, dynamic> frame) {
    if (!mounted) return;
    if (frame['type'] != 'event' || frame['event'] != 'talk.event') return;

    final payloadRaw = frame['payload'];
    if (payloadRaw is! Map) return;
    final payload = Map<String, dynamic>.from(payloadRaw);
    final relayId =
        (payload['relaySessionId'] ??
                payload['sessionId'] ??
                payload['transcriptionSessionId'])
            ?.toString();
    if (_talkRelaySessionId == null || relayId != _talkRelaySessionId) return;

    final eventType = payload['type']?.toString() ?? '';
    if (eventType == 'ready') {
      _talkRelayReady = true;
      _addDiagnosticLog('Talk relay ready.');
      return;
    }
    if (eventType == 'error') {
      final message = payload['message']?.toString() ?? 'unknown';
      _talkRelayFinalizationTimer?.cancel();
      _talkRelayFinalizationTimer = null;
      _talkRelayTurnAwaitingTranscript = false;
      _talkRelayReady = false;
      _voiceSession.invalidate(
        phase: VoiceSessionPhase.error,
        reason: 'Talk relay error: $message',
      );
      if (mounted) {
        setState(() {});
        _syncOverlayState();
        _updatePipMicIcon();
      }
      _addDiagnosticLog('Talk relay error: $message');
      _recordVoiceTelemetryFailure(
        source: 'gateway_talk_relay',
        errorCode: 'relay_error',
      );
      unawaited(
        _recoverVoiceInputToWakeWord(
          reason: 'Wake word recovery after Talk relay error.',
        ),
      );
      return;
    }
    if (eventType == 'close') {
      final reason = payload['reason']?.toString() ?? 'unknown';
      _talkRelayFinalizationTimer?.cancel();
      _talkRelayFinalizationTimer = null;
      _talkRelayTurnAwaitingTranscript = false;
      _talkRelayReady = false;
      _voiceSession.invalidate(
        phase: VoiceSessionPhase.paused,
        reason: 'Talk relay closed: $reason',
      );
      if (mounted) {
        setState(() {});
        _syncOverlayState();
        _updatePipMicIcon();
      }
      _talkRelaySessionId = null;
      _talkAssistantMessageIndex = null;
      _talkAssistantTextBuffer = '';
      _addDiagnosticLog('Talk relay closed ($reason).');
      unawaited(
        _recoverVoiceInputToWakeWord(
          reason: 'Wake word recovery after Talk relay close.',
        ),
      );
      return;
    }
    if (eventType != 'transcript') return;

    final role = payload['role']?.toString() ?? '';
    final text = payload['text']?.toString() ?? '';
    final isFinal = payload['final'] == true;

    if (role == 'user') {
      if (isFinal && text.trim().isNotEmpty) {
        _recordVoiceTelemetrySuccess(source: 'gateway_talk_relay');
        // A new Talk turn gets a fresh duplicate window. Keep any currently
        // playing prior audio intact, but allow the same words in a later
        // user turn to be spoken legitimately.
        _queuedTtsKeys.clear();
        // A final user transcript is the relay's VAD boundary. Release the
        // microphone before the assistant speaks so Continuous Mode can
        // safely schedule the next turn and cannot capture TTS echo.
        if (_isTalkRelayCaptureActive) {
          unawaited(
            _stopTalkRelayCapture().then((_) {
              if (!mounted) return;
              _publishListeningState(false);
            }),
          );
        }
        _voiceSession.setPhase(VoiceSessionPhase.thinking);
        setState(() {
          _messages.add(ChatMessage(text: text.trim(), isUser: true));
          _messages.add(ChatMessage(text: '', isUser: false));
          _talkAssistantMessageIndex = _messages.length - 1;
          _talkAssistantTextBuffer = '';
          _isGenerating = true;
          _isThinking = true;
        });
        _updatePipMicIcon();
        _saveChatHistory();
        _scrollToBottom();
      }
      return;
    }

    if (role == 'assistant') {
      if (text.isNotEmpty) {
        _talkAssistantTextBuffer += text;
        _enqueueTtsFromStream(text);
      }

      setState(() {
        _isThinking = false;
        _isGenerating = true;
        final idx = _talkAssistantMessageIndex;
        if (idx != null && idx >= 0 && idx < _messages.length) {
          _messages[idx] = ChatMessage(
            text: _talkAssistantTextBuffer,
            isUser: false,
          );
        } else if (_talkAssistantTextBuffer.isNotEmpty) {
          _messages.add(
            ChatMessage(text: _talkAssistantTextBuffer, isUser: false),
          );
          _talkAssistantMessageIndex = _messages.length - 1;
        }
      });
      _scrollToBottom();

      if (isFinal) {
        _talkRelayFinalizationTimer?.cancel();
        _talkRelayFinalizationTimer = null;
        _talkRelayTurnAwaitingTranscript = false;
        _flushTtsQueue();
        setState(() {
          _isGenerating = false;
          _isThinking = false;
        });
        if (!_tts.isSpeaking && _ttsQueue.isEmpty) {
          _voiceSession.setPhase(VoiceSessionPhase.idle);
          setState(() {});
          _updatePipMicIcon();
          if (_continuousModeEnabled && _continuousSessionArmed) {
            _scheduleContinuousListening();
          } else {
            unawaited(_resumeWakeWordIfNeeded());
          }
        }
        _saveChatHistory();
      }
    }
  }

  Future<void> _forwardTalkAudioChunk(Uint8List chunk) async {
    final sessionId = _talkRelaySessionId;
    if (sessionId == null ||
        sessionId.isEmpty ||
        chunk.isEmpty ||
        !_talkRelayReady ||
        !mounted) {
      return;
    }
    final gatewayProvider = Provider.of<GatewayProvider>(
      context,
      listen: false,
    );
    final audioBase64 = base64Encode(chunk);
    _talkAudioSendChain = _talkAudioSendChain
        .then((_) async {
          await gatewayProvider.appendTalkSessionAudio(
            sessionId: sessionId,
            audioBase64: audioBase64,
            timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
          );
        })
        .catchError((e) {
          _addDiagnosticLog('Talk relay appendAudio failed: $e');
        });
    await _talkAudioSendChain;
  }

  Future<void> _startTalkRelayCapture(GatewayProvider gatewayProvider) async {
    final talkSupported = await _probeTalkRelaySupport(gatewayProvider);
    if (!talkSupported) {
      throw StateError('Talk relay unavailable on this gateway/runtime');
    }
    final hasSession = await _ensureTalkRelaySession(gatewayProvider);
    if (!hasSession) {
      throw StateError('Failed to create talk relay session');
    }
    final stream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ),
    );
    _talkAudioStreamSub?.cancel();
    _talkAudioStreamSub = stream.listen(
      (chunk) => unawaited(_forwardTalkAudioChunk(chunk)),
      onError: (e) => _addDiagnosticLog('Talk relay mic stream error: $e'),
    );
    _isTalkRelayCaptureActive = true;
  }

  Future<void> _stopTalkRelayCapture() async {
    await _audioRecorder.stop();
    await _talkAudioStreamSub?.cancel();
    _talkAudioStreamSub = null;
    _isTalkRelayCaptureActive = false;
  }

  void _armTalkRelayFinalizationTimeout(String? sessionId) {
    _talkRelayFinalizationTimer?.cancel();
    _talkRelayTurnAwaitingTranscript =
        sessionId != null && sessionId.isNotEmpty;
    if (!_talkRelayTurnAwaitingTranscript) return;
    _talkRelayFinalizationTimer = Timer(const Duration(seconds: 15), () {
      unawaited(_expireTalkRelayTurn(sessionId!));
    });
  }

  Future<void> _expireTalkRelayTurn(String sessionId) async {
    if (!mounted ||
        !_talkRelayTurnAwaitingTranscript ||
        _talkRelaySessionId != sessionId) {
      return;
    }
    _talkRelayTurnAwaitingTranscript = false;
    _talkRelayFinalizationTimer = null;
    _talkRelayReady = false;
    _addDiagnosticLog(
      'Talk relay transcript timed out; closing session $sessionId.',
    );
    final gatewayProvider = Provider.of<GatewayProvider>(
      context,
      listen: false,
    );
    try {
      await gatewayProvider.cancelTalkSessionTurn(
        sessionId,
        reason: 'transcript-finalization-timeout',
      );
    } catch (error) {
      _addDiagnosticLog('Talk relay cancel after timeout failed: $error');
    }
    try {
      await gatewayProvider.closeTalkSession(sessionId);
    } catch (error) {
      _addDiagnosticLog('Talk relay close after timeout failed: $error');
    }
    if (_talkRelaySessionId == sessionId) {
      _talkRelaySessionId = null;
      _talkAssistantMessageIndex = null;
      _talkAssistantTextBuffer = '';
    }
    if (mounted) {
      _voiceSession.invalidate(
        phase: VoiceSessionPhase.error,
        reason: 'Talk relay transcript timed out.',
      );
      setState(() {});
      _syncOverlayState();
      _updatePipMicIcon();
      _addDiagnosticLog('Talk relay session closed after transcript timeout.');
      unawaited(
        _recoverVoiceInputToWakeWord(
          reason: 'Wake word recovery after Talk relay timeout.',
        ),
      );
    }
  }

  /// Start recording — called when user begins holding the mic orb (hold-to-record UX).
  Future<void> _startListening({VoiceCaptureOwner? owner}) async {
    if (_isListening || _voiceSession.state.captureStartBlocked) return;

    if (!await _audioRecorder.hasPermission()) {
      _voiceSession.setPhase(
        VoiceSessionPhase.error,
        reason: 'Microphone permission is required for voice input.',
      );
      if (mounted) {
        setState(() {});
        _updatePipMicIcon();
      }
      _addDiagnosticLog('Microphone permission denied.');
      return;
    }
    if (!mounted) return;

    await _pauseWakeWordForVoice();
    if (!mounted) return;

    final captureOwner =
        owner ?? (_isPipMode ? VoiceCaptureOwner.pip : VoiceCaptureOwner.chat);
    final generation = _voiceSession.beginCapture(
      owner: captureOwner,
      surface: _isPipMode
          ? VoiceSessionSurface.pip
          : VoiceSessionSurface.fullScreen,
    );
    if (generation == null) {
      _addDiagnosticLog('Voice capture request ignored: session is busy.');
      if (captureOwner == VoiceCaptureOwner.wakeWord) {
        unawaited(
          _recoverVoiceInputToWakeWord(
            reason: 'Wake word recovery after a busy voice handoff.',
          ),
        );
      }
      return;
    }
    if (_continuousModeEnabled) _continuousSessionArmed = true;
    if (mounted) {
      setState(() {});
      _syncOverlayState();
    }
    _updatePipMicIcon();

    final gatewayProvider = Provider.of<GatewayProvider>(
      context,
      listen: false,
    );
    try {
      await _startTalkRelayCapture(gatewayProvider);
      if (!mounted || !_voiceSession.isCurrent(generation)) {
        if (_isTalkRelayCaptureActive) await _stopTalkRelayCapture();
        return;
      }
      _voiceSession.markListening(generation);
      _publishListeningState(true);
      _addDiagnosticLog(
        'Voice relay recording started (talk.session realtime).',
      );
      return;
    } catch (e) {
      if (_isTalkRelayCaptureActive) await _stopTalkRelayCapture();
      _addDiagnosticLog(
        'Talk relay capture unavailable, using fallback STT: $e',
      );
    }

    // Match the official Android client's fallback contract: when realtime
    // Talk is not configured, use the platform SpeechRecognizer and send its
    // text through the existing chat pipeline. The file upload route below is
    // retained only for runtimes that have neither native recognition nor
    // realtime Talk available.
    _nativeSpeechStopRequested = false;
    _nativeSpeechFinishedBeforeUiState = false;
    _nativeSpeechPendingText = null;
    try {
      final nativeStarted = await _nativeSpeechInput.start(
        onStatus: (status) =>
            _addDiagnosticLog('Native speech status: $status'),
        onError: (message) =>
            _addDiagnosticLog('Native speech error: $message'),
        onFinished: (text) => _handleNativeSpeechFinished(text, generation),
      );
      if (nativeStarted) {
        if (!mounted || !_voiceSession.isCurrent(generation)) {
          await _nativeSpeechInput.cancel();
          return;
        }
        if (_nativeSpeechFinishedBeforeUiState) {
          _finalizeNativeSpeechSession(
            _nativeSpeechPendingText,
            reason: 'Native speech ended during startup.',
          );
          return;
        }
        _usingNativeSpeechFallback = true;
        _voiceSession.markListening(generation);
        _publishListeningState(true);
        _addDiagnosticLog(
          'Voice recording started (native SpeechRecognizer fallback).',
        );
        return;
      }
      _nativeSpeechStopRequested = false;
      _nativeSpeechFinishedBeforeUiState = false;
      _nativeSpeechPendingText = null;
      _addDiagnosticLog('Native SpeechRecognizer is unavailable.');
    } catch (e) {
      _nativeSpeechStopRequested = false;
      _nativeSpeechFinishedBeforeUiState = false;
      _nativeSpeechPendingText = null;
      _addDiagnosticLog('Native SpeechRecognizer fallback failed: $e');
    }

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/stt_recording.m4a';
    const config = RecordConfig(); // default 44.1kHz, AAC
    try {
      await _audioRecorder.start(config, path: path);
      if (!mounted || !_voiceSession.isCurrent(generation)) {
        await _audioRecorder.stop();
        return;
      }
    } catch (e) {
      _voiceSession.invalidate(
        phase: VoiceSessionPhase.error,
        reason: 'Microphone start failed: $e',
      );
      if (mounted) {
        setState(() {});
        _syncOverlayState();
        _updatePipMicIcon();
      }
      _addDiagnosticLog('Voice recording failed to start: $e');
      unawaited(
        _recoverVoiceInputToWakeWord(
          reason: 'Wake word recovery after microphone start failure.',
        ),
      );
      return;
    }
    _voiceSession.markListening(generation);
    _publishListeningState(true);
    _addDiagnosticLog('Voice recording started (fallback STT mode).');
  }

  /// Stop recording and transcribe — called when user releases the mic orb.
  Future<void> _stopListening() async {
    if (!_isListening && !_voiceSession.state.captureActive) return;
    _continuousListeningTimer?.cancel();
    _continuousListeningTimer = null;
    final stopGeneration = _voiceSession.invalidate(
      phase: VoiceSessionPhase.transcribing,
      reason: 'Voice capture stopped by user.',
    );
    if (mounted) {
      setState(() {});
      _syncOverlayState();
    }
    _updatePipMicIcon();

    if (_isTalkRelayCaptureActive) {
      final sessionId = _talkRelaySessionId;
      await _stopTalkRelayCapture();
      if (!mounted || !_voiceSession.isCurrent(stopGeneration)) return;
      _publishListeningState(false);
      _armTalkRelayFinalizationTimeout(sessionId);
      _addDiagnosticLog(
        sessionId == null
            ? 'Voice relay recording stopped without a session id.'
            : 'Voice relay recording stopped; waiting for transcript...',
      );
      return;
    }

    if (_usingNativeSpeechFallback) {
      _nativeSpeechStopRequested = true;
      final text = await _nativeSpeechInput.stop();
      if (!mounted || !_voiceSession.isCurrent(stopGeneration)) return;
      _finalizeNativeSpeechSession(
        text,
        reason: 'Native speech recording stopped by user.',
        expectedGeneration: stopGeneration,
      );
      return;
    }

    final path = await _audioRecorder.stop();
    if (!mounted || !_voiceSession.isCurrent(stopGeneration)) return;
    _publishListeningState(false);
    _addDiagnosticLog('Voice recording stopped.');

    if (path != null) {
      _addDiagnosticLog('Transcribing audio at $path...');
      final text = await GatewayService().transcribeAudio(File(path));
      if (!mounted || !_voiceSession.isCurrent(stopGeneration)) return;
      _submitVoiceTranscript(
        text,
        source: 'Gateway STT',
        expectedGeneration: stopGeneration,
      );
    } else if (mounted && _voiceSession.isCurrent(stopGeneration)) {
      _voiceSession.setPhase(
        VoiceSessionPhase.noTranscript,
        reason: 'Audio recording returned no file.',
      );
      setState(() {});
      _updatePipMicIcon();
      unawaited(
        _recoverVoiceInputToWakeWord(
          reason: 'Wake word recovery after an empty audio recording.',
        ),
      );
    }
  }

  void _submitVoiceTranscript(
    String? rawText, {
    required String source,
    int? expectedGeneration,
  }) {
    if (!mounted) return;
    if (expectedGeneration != null &&
        !_voiceSession.isCurrent(expectedGeneration)) {
      _addDiagnosticLog('$source result ignored from stale voice generation.');
      return;
    }
    final text = rawText?.trim() ?? '';
    if (text.isNotEmpty) {
      _voiceSession.setPhase(VoiceSessionPhase.sent);
      _textController.text = text;
      _addDiagnosticLog('$source recognized: $text');
      setState(() {});
      _updatePipMicIcon();
      _recordVoiceTelemetrySuccess(source: source);
      _handleSubmit(text);
      return;
    }

    final expectedSilence = source == 'Native SpeechRecognizer';
    _voiceSession.setPhase(
      expectedSilence ? VoiceSessionPhase.idle : VoiceSessionPhase.noTranscript,
      reason: expectedSilence
          ? 'No speech detected; voice returned to standby.'
          : '$source returned no text.',
    );
    _addDiagnosticLog('$source returned no text.');
    setState(() {});
    _updatePipMicIcon();
    if (!expectedSilence) {
      _recordVoiceTelemetryFailure(
        source: source,
        errorCode: 'empty_transcript',
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input was not transcribed. Check Gateway STT/Talk setup and try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    unawaited(
      _recoverVoiceInputToWakeWord(
        reason: expectedSilence
            ? 'Voice ended in silence; returned to wake-word standby.'
            : 'Wake word recovery after no transcript.',
      ),
    );
  }

  void _recordVoiceTelemetrySuccess({required String source}) {
    unawaited(
      ProductTelemetryService.instance.record(
        ProductTelemetryEventName.voiceTurnCompleted,
        properties: <String, Object?>{
          'source': _voiceTelemetrySource(source),
          'mode': _continuousModeEnabled ? 'continuous' : 'manual',
          'surface': _isPipMode ? 'pip' : 'chat',
          'outcome': 'transcribed',
        },
      ),
    );
  }

  void _recordVoiceTelemetryFailure({
    required String source,
    required String errorCode,
  }) {
    unawaited(
      ProductTelemetryService.instance.record(
        ProductTelemetryEventName.voiceTranscriptionFailed,
        properties: <String, Object?>{
          'source': _voiceTelemetrySource(source),
          'mode': _continuousModeEnabled ? 'continuous' : 'manual',
          'surface': _isPipMode ? 'pip' : 'chat',
          'errorCode': errorCode,
        },
      ),
    );
  }

  String _voiceTelemetrySource(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('native')) return 'android_speech_recognizer';
    if (normalized.contains('relay')) return 'gateway_talk_relay';
    if (normalized.contains('gateway')) return 'gateway_stt';
    return 'voice_input';
  }

  void _handleNativeSpeechFinished(String? text, int generation) {
    if (!mounted || !_voiceSession.isCurrent(generation)) return;
    if (_nativeSpeechStopRequested) return;
    if (!_usingNativeSpeechFallback) {
      _nativeSpeechFinishedBeforeUiState = true;
      _nativeSpeechPendingText = text;
      return;
    }
    _finalizeNativeSpeechSession(
      text,
      reason: 'Native speech session ended by the platform.',
      expectedGeneration: generation,
    );
  }

  void _finalizeNativeSpeechSession(
    String? text, {
    required String reason,
    int? expectedGeneration,
  }) {
    if (!mounted || _nativeSpeechStopRequested && !_usingNativeSpeechFallback) {
      return;
    }
    if (expectedGeneration != null &&
        !_voiceSession.isCurrent(expectedGeneration)) {
      _addDiagnosticLog('Native speech result ignored from stale generation.');
      return;
    }
    _nativeSpeechStopRequested = true;
    _usingNativeSpeechFallback = false;
    _nativeSpeechFinishedBeforeUiState = false;
    _nativeSpeechPendingText = null;
    final finalizationGeneration =
        _voiceSession.state.phase == VoiceSessionPhase.transcribing
        ? _voiceSession.state.generation
        : _voiceSession.invalidate(
            phase: VoiceSessionPhase.transcribing,
            reason: reason,
          );
    _publishListeningState(false);
    _addDiagnosticLog(reason);
    _submitVoiceTranscript(
      text,
      source: 'Native SpeechRecognizer',
      expectedGeneration: finalizationGeneration,
    );
  }

  void _publishListeningState(bool listening) {
    if (!mounted) return;
    setState(() => _isListening = listening);
    _syncOverlayState();
    _updatePipMicIcon();
  }

  /// Tell native Android to update the PiP RemoteAction icon based on listening state.
  void _updatePipMicIcon() {
    final state = _voiceSession.state;
    final phase = state.phase.name;
    final label = state.phase.userLabel;
    unawaited(
      _pipChannel
          .invokeMethod('updatePipVoiceState', {
            'phase': phase,
            'listening': state.captureActive,
            'label': label,
          })
          .catchError((_) {
            // The native bridge keeps the legacy boolean method for older builds;
            // no UI state depends on a PiP action refresh succeeding.
          }),
    );
  }

  String get _voiceStatusLabel => _voiceSession.state.phase.userLabel;

  bool get _hasVisibleVoiceStatus =>
      _voiceSession.state.phase != VoiceSessionPhase.idle;

  String get _voiceActionLabel => _voiceSession.state.captureActive
      ? 'Stop listening'
      : 'Start voice input';

  IconData get _voiceStatusIcon {
    switch (_voiceSession.state.phase) {
      case VoiceSessionPhase.starting:
      case VoiceSessionPhase.listening:
        return Icons.mic;
      case VoiceSessionPhase.transcribing:
        return Icons.graphic_eq;
      case VoiceSessionPhase.thinking:
        return Icons.psychology_outlined;
      case VoiceSessionPhase.speaking:
        return Icons.volume_up_outlined;
      case VoiceSessionPhase.sent:
        return Icons.check_circle_outline;
      case VoiceSessionPhase.noTranscript:
        return Icons.mic_off_outlined;
      case VoiceSessionPhase.paused:
        return Icons.pause_circle_outline;
      case VoiceSessionPhase.reconnecting:
        return Icons.sync;
      case VoiceSessionPhase.stopped:
        return Icons.stop_circle_outlined;
      case VoiceSessionPhase.error:
        return Icons.error_outline;
      case VoiceSessionPhase.idle:
        return Icons.mic_none;
    }
  }

  Widget _buildVoiceStatusIndicator() {
    if (!_hasVisibleVoiceStatus) return const SizedBox.shrink();
    final active = _voiceSession.state.captureActive;
    final color = active
        ? AppColors.statusGreen
        : _voiceSession.state.phase == VoiceSessionPhase.error ||
              _voiceSession.state.phase == VoiceSessionPhase.noTranscript
        ? AppColors.statusRed
        : Colors.white70;
    return Semantics(
      liveRegion: true,
      label: 'Voice status: $_voiceStatusLabel',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.statusRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.statusRed.withValues(alpha: 0.55),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            Icon(_voiceStatusIcon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              _voiceStatusLabel,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIX: Decoupled cinematic effect from typing to prevent zoom jumps
  bool get _isCinematic => _isGenerating || _isListening;

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _agentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rename Agent',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.statusGreen),
            ),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() => _agentName = newName);
                PreferencesService().agentName = newName;
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDynamicModelPicker() async {
    const toolTestSelectionPrefix = 'plawie-tool-test::';
    var latestSnapshot = await DynamicModelCatalogRepository().loadOrBundled();
    var latestReadiness = await WalletFundedProviderReadinessService().inspect(
      latestSnapshot,
    );
    if (!mounted) return;

    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.82,
            decoration: BoxDecoration(
              color: const Color(0xFF101216),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'CLOUD MODEL CATALOG',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: DynamicModelPickerPanel(
                    snapshot: latestSnapshot,
                    currentModelId: _selectedModel,
                    walletReadiness: latestReadiness,
                    autoRefreshWalletBalances: true,
                    onRefreshProviderBalance: (providerId) async {
                      await ProviderBalanceService.instance.refresh(providerId);
                      latestReadiness =
                          await WalletFundedProviderReadinessService().inspect(
                            latestSnapshot,
                          );
                      return latestReadiness;
                    },
                    onRefreshModels: (providerId) async {
                      final refreshed = await GatewayService()
                          .refreshProviderModelCatalog(providerId);
                      latestSnapshot = await DynamicModelCatalogRepository()
                          .assess(refreshed.withEffectiveState(DateTime.now()));
                      latestReadiness =
                          await WalletFundedProviderReadinessService().inspect(
                            latestSnapshot,
                          );
                      if (mounted) {
                        setState(() {
                          _availableDynamicCatalog = latestSnapshot;
                          _availableDynamicModels = _quickModelsForMenu(
                            latestSnapshot,
                          );
                        });
                      }
                      return latestSnapshot;
                    },
                    onSelected: (model) =>
                        Navigator.pop(sheetContext, model.id),
                    onTestTools: (model) {
                      Navigator.pop(
                        sheetContext,
                        '$toolTestSelectionPrefix${model.id}',
                      );
                    },
                    onProviderAction: (providerId, action) {
                      Navigator.pop(sheetContext);
                      unawaited(
                        runWalletFundedProviderAction(
                          context,
                          providerId: providerId,
                          action: action,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selection == null || !mounted) return;
    final testTools = selection.startsWith(toolTestSelectionPrefix);
    final selectedId = testTools
        ? selection.substring(toolTestSelectionPrefix.length)
        : selection;
    final dynamicModel = <DynamicModelRecord>[
      for (final provider in latestSnapshot.providers) ...provider.models,
    ].firstWhere((model) => model.id == selectedId);
    if (testTools) {
      await _runModelToolCompatibilityTest(dynamicModel);
    } else {
      await _selectDynamicModel(dynamicModel);
    }
  }

  Future<void> _selectDynamicModel(DynamicModelRecord model) async {
    if (!model.liveAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            model.unavailableReason ??
                'This model is not available from a live catalog.',
          ),
        ),
      );
      return;
    }
    final provider = model.providerId;
    final providerOption = ModelProviderCatalog.providerById(provider);
    if (providerOption?.requiresApiKey == true &&
        !await GatewayService().hasProviderCredential(provider)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add a ${providerOption?.label ?? provider} API key in Settings first.',
          ),
        ),
      );
      return;
    }
    try {
      await GatewayService().persistDynamicModel(model);
      if (!mounted) return;
      final prefs = PreferencesService();
      await prefs.init();
      final selection = CanonicalModelSelection.fromDynamic(model);
      setState(() {
        _selectedModelSelection = selection;
        _cloudFallbackModel = model.id;
      });
      prefs.setConfiguredModelSelection(selection);
      prefs.lastCloudModel = model.id;
      if (providerOption?.requiresApiKey == false) {
        prefs.aiPaymentProvider = provider;
      }
      GatewayService().disconnectWebSocket();
      _addDiagnosticLog('Selected dynamic provider model: ${model.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Model selection failed: $error')));
    }
  }

  Future<void> _runModelToolCompatibilityTest(DynamicModelRecord model) async {
    final paid = model.providerId == 'venice' || model.providerId == 'blockrun';
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Test tools with ${model.label}?'),
            content: Text(
              'Plawie will select this exact model and run one short, '
              'read-only OpenClaw session-status turn. It cannot access '
              'files, device controls, apps, notifications, camera, or your '
              'wallet.${paid ? ' This provider may charge its normal model usage.' : ''}\n\n'
              'The model must call the tool once, accept its result, and '
              'finish the response before it is marked Agent-ready.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.science_outlined),
                label: const Text('Run test'),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved || !mounted) return;

    await _selectDynamicModel(model);
    if (!mounted || _selectedModel != model.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The exact model could not be selected, so no test was sent.',
            ),
          ),
        );
      }
      return;
    }
    await _handleSubmit(
      ModelToolCompatibilityProbe.prompt,
      explicitToolCompatibilityProbe: true,
    );
  }

  void _showUnifiedMenu(BuildContext context) {
    HapticFeedback.selectionClick();
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final position = button?.localToGlobal(Offset.zero) ?? Offset.zero;

    showMenu<dynamic>(
      context: context,
      color: Colors.black.withValues(alpha: 0.7), // Deeper frosted alpha
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      position: RelativeRect.fromLTRB(position.dx, 80, position.dx + 300, 0),
      items: [
        // Premium Header
        PopupMenuItem<void>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AGENT SETTINGS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showEditNameDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.edit_note,
                            color: Colors.white70,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'EDIT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/app_icon_official.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _agentName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ModelProviderCatalog.isLocalModelId(_selectedModel)
                              ? 'LOCAL · ON-DEVICE'
                              : ModelProviderCatalog.labelForModel(
                                  _selectedModel,
                                ).toUpperCase(),
                          style: TextStyle(
                            color:
                                ModelProviderCatalog.isLocalModelId(
                                  _selectedModel,
                                )
                                ? const Color(0xFF00E5AA)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white10),
            ],
          ),
        ),

        // Avatars Section
        PopupMenuItem<void>(
          enabled: false,
          height: 20,
          child: Text(
            'ACTIVE AVATAR',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ..._availableAvatars.map(
          (avatar) => PopupMenuItem<String>(
            value: 'avatar:$avatar',
            height: 36,
            child: Row(
              children: [
                Icon(
                  avatar == _selectedAvatar
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: avatar == _selectedAvatar
                      ? AppColors.statusGreen
                      : Colors.white38,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  avatar.split('.').first,
                  style: TextStyle(
                    color: avatar == _selectedAvatar
                        ? Colors.white
                        : Colors.white70,
                    fontWeight: avatar == _selectedAvatar
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),

        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'avatar_forge',
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Colors.purpleAccent.shade100,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Avatar Forge',
                style: TextStyle(
                  color: Colors.purpleAccent.shade100,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white38,
                size: 12,
              ),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // Models Section
        PopupMenuItem<void>(
          enabled: false,
          height: 20,
          child: Text(
            'ACTIVE MODEL',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        // --- INTELLIGENT LOCAL LLM ENTRY ---
        PopupMenuItem<String>(
          value:
              _localLlmState.status == LocalLlmStatus.idle ||
                  !_localChatModeEnabled
              ? 'setup_local_llm'
              : 'model:local-llm/${_localLlmState.activeModelId ?? 'llama-server'}',
          height: 48,
          child: Row(
            children: [
              Icon(
                _localLlmState.status == LocalLlmStatus.idle
                    ? Icons.install_mobile
                    : (!_localChatModeEnabled
                          ? Icons.lock_outline_rounded
                          : (ModelProviderCatalog.isLocalModelId(_selectedModel)
                                ? Icons.memory_rounded
                                : Icons.phone_android)),
                color: ModelProviderCatalog.isLocalModelId(_selectedModel)
                    ? const Color(0xFF00E5AA)
                    : (!_localChatModeEnabled
                          ? AppColors.statusAmber
                          : (_localLlmState.status == LocalLlmStatus.starting
                                ? Colors.amber
                                : (_localLlmState.status == LocalLlmStatus.idle
                                      ? AppColors.statusAmber
                                      : Colors.white38))),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _localLlmState.status == LocalLlmStatus.idle
                          ? 'Setup Local LLM'
                          : (_localLlmState.activeModelId ?? 'Local LLM'),
                      style: TextStyle(
                        color:
                            ModelProviderCatalog.isLocalModelId(_selectedModel)
                            ? Colors.white
                            : (_localLlmState.status == LocalLlmStatus.idle
                                  ? AppColors.statusAmber
                                  : Colors.white70),
                        fontSize: 13,
                        fontWeight:
                            ModelProviderCatalog.isLocalModelId(_selectedModel)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      _localLlmState.status == LocalLlmStatus.starting
                          ? 'WAKING UP...'
                          : (_localLlmState.status == LocalLlmStatus.error
                                ? 'ERROR: CHECK SETUP'
                                : (!_localChatModeEnabled
                                      ? 'NDK READY · CHAT MODE OFF'
                                      : (_localLlmState.status ==
                                                LocalLlmStatus.idle
                                            ? 'Download free model'
                                            : (ModelProviderCatalog.isLocalModelId(
                                                    _selectedModel,
                                                  )
                                                  ? 'ACTIVE · ON-DEVICE'
                                                  : 'ON-DEVICE (READY)')))),
                      style: TextStyle(
                        color: _localLlmState.status == LocalLlmStatus.starting
                            ? Colors.amber
                            : (!_localChatModeEnabled
                                  ? AppColors.statusAmber
                                  : (ModelProviderCatalog.isLocalModelId(
                                          _selectedModel,
                                        )
                                        ? const Color(0xFF00E5AA)
                                        : (_localLlmState.status ==
                                                  LocalLlmStatus.idle
                                              ? AppColors.statusAmber
                                                    .withValues(alpha: 0.6)
                                              : Colors.white38))),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_localLlmState.status == LocalLlmStatus.starting)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.amber,
                  ),
                )
              else if (ModelProviderCatalog.isLocalModelId(_selectedModel))
                const Icon(Icons.check, color: Color(0xFF00E5AA), size: 18),
            ],
          ),
        ),
        // ── Dynamic agents from gateway (empty until gateway connects) ──────
        if (_dynamicAgents.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem<void>(
            enabled: false,
            height: 20,
            child: const Text(
              'AGENTS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ..._dynamicAgents.map(
            (agent) => PopupMenuItem<String>(
              value: 'model:${agent.modelKey}',
              height: 36,
              child: Row(
                children: [
                  Icon(
                    agent.modelKey == _selectedModel
                        ? Icons.check_circle
                        : Icons.smart_toy_outlined,
                    color: agent.modelKey == _selectedModel
                        ? Colors.tealAccent
                        : Colors.white38,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      agent.isDefault ? '${agent.name} (default)' : agent.name,
                      style: TextStyle(
                        color: agent.modelKey == _selectedModel
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 13,
                        fontWeight: agent.modelKey == _selectedModel
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        // ── CLOUD section (gateway cloud providers) ────────────────────────
        const PopupMenuDivider(),
        PopupMenuItem<dynamic>(
          enabled: false,
          height: 20,
          child: Row(
            children: [
              const Icon(Icons.cloud_outlined, color: Colors.white38, size: 12),
              const SizedBox(width: 6),
              const Text(
                'CLOUD',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'browse_models',
          height: 38,
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: Colors.purpleAccent, size: 18),
              SizedBox(width: 10),
              Text(
                'Browse provider models',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        ..._availableDynamicModels.map(
          (model) => PopupMenuItem<String>(
            value: 'dynamic:${model.id}',
            height: 44,
            child: Row(
              children: [
                Icon(
                  model.id == _selectedModel
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: model.id == _selectedModel
                      ? Colors.purpleAccent
                      : Colors.white38,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        model.label,
                        style: TextStyle(
                          color: model.id == _selectedModel
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 13,
                          fontWeight: model.id == _selectedModel
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${model.providerId} · ${model.readinessLabel}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const PopupMenuDivider(),
        PopupMenuItem<void>(
          enabled: false,
          height: 20,
          child: Text(
            'VOICE MODULE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'setup_local_llm',
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Row(
              children: [
                Icon(Icons.memory, color: Colors.cyanAccent, size: 20),
                SizedBox(width: 12),
                Text(
                  'Agent Intelligence',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    ).then((value) async {
      if (value == null) return;
      if (!context.mounted) return;

      if (value == 'browse_models') {
        await _showDynamicModelPicker();
      } else if (value == 'setup_local_llm') {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LocalLlmScreen()));
        _loadPreferences();
      } else if (value == 'avatar_forge') {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AvatarForgePage()));
      } else if (value.toString().startsWith('dynamic:')) {
        final dynamicId = value.toString().substring('dynamic:'.length);
        DynamicModelRecord? dynamicModel;
        for (final candidate in _availableDynamicModels) {
          if (candidate.id == dynamicId) {
            dynamicModel = candidate;
            break;
          }
        }
        if (dynamicModel == null) {
          await _showDynamicModelPicker();
          return;
        }
        final catalog = _availableDynamicCatalog;
        if (catalog != null) {
          final readiness = await WalletFundedProviderReadinessService()
              .inspect(catalog);
          final providerReadiness = readiness[dynamicModel.providerId];
          if (providerReadiness != null && !providerReadiness.canSelectModels) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(providerReadiness.detail)));
            return;
          }
        }
        await _selectDynamicModel(dynamicModel);
      } else if (value.toString().startsWith('model:')) {
        final prefs = PreferencesService();
        await prefs.init();
        final model = ModelProviderCatalog.canonicalizeModelId(
          value.toString().substring(6),
        );
        if (ModelProviderCatalog.isDirectLocalModelId(model) &&
            !prefs.localChatModeEnabled) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Local NDK chat is OFF. Enable it in Local LLM page first.',
              ),
            ),
          );
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LocalLlmScreen()));
          _loadPreferences();
          return;
        }
        final isNowCloud = !ModelProviderCatalog.isDirectLocalModelId(model);
        final catalogModel = ModelProviderCatalog.modelById(model);
        final catalogProvider = catalogModel == null
            ? null
            : ModelProviderCatalog.providerById(catalogModel.providerId);
        if (isNowCloud &&
            catalogModel != null &&
            catalogProvider?.requiresApiKey == true) {
          final hasCredential = await GatewayService().hasProviderCredential(
            catalogModel.providerId,
          );
          if (!context.mounted) return;
          if (!hasCredential) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Add a ${catalogProvider?.label ?? catalogModel.providerId} API key in Settings before using ${catalogModel.label}.',
                ),
              ),
            );
            return;
          }
        }
        setState(() {
          _selectedModel = model;
          if (!ModelProviderCatalog.isDirectLocalModelId(model)) {
            _cloudFallbackModel = model;
          }
        });
        prefs.setConfiguredModelSelection(
          CanonicalModelSelection.fromModelId(model),
        );
        if (!ModelProviderCatalog.isDirectLocalModelId(model)) {
          prefs.lastCloudModel = model;
        }

        final needsReload = ModelProviderCatalog.isDirectLocalModelId(model);
        if (needsReload) {
          final modelId = model.split('/').last;
          final localModel = LocalLlmService().catalog.firstWhere(
            (m) => m.id == modelId,
          );
          LocalLlmService().activateModel(localModel);
        } else {
          await GatewayService().persistModel(model);
          GatewayService().disconnectWebSocket();
        }
        _addDiagnosticLog('Swapped and persisted AI model: $model');
      } else if (value.toString().startsWith('avatar:')) {
        final avatar = value.toString().substring(7);
        setState(() {
          _selectedAvatar = avatar;
          _isReady = false;
        });
        PreferencesService().selectedAvatar = avatar;
        _addDiagnosticLog('Swapped and persisted avatar: $avatar');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _backgroundVoiceStopTimer?.cancel();
      _backgroundVoiceStopTimer = null;
      _scrollToBottom(instant: true);
      if (_continuousModeEnabled &&
          _continuousSessionArmed &&
          !_isGenerating &&
          !_isListening &&
          !_voiceSession.state.captureActive &&
          !_voiceSession.state.captureStartBlocked) {
        _scheduleContinuousListening();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _continuousListeningTimer?.cancel();
      _continuousListeningTimer = null;
      // Android can report paused/inactive just before the PiP mode callback.
      // Defer the stop briefly so an active PiP voice surface keeps ownership,
      // while ordinary backgrounding still releases the microphone promptly.
      if (!_isPipMode && (_isListening || _voiceSession.state.captureActive)) {
        _backgroundVoiceStopTimer?.cancel();
        _backgroundVoiceStopTimer = Timer(const Duration(milliseconds: 350), () {
          _backgroundVoiceStopTimer = null;
          if (!mounted || _isPipMode) return;
          if (_isListening || _voiceSession.state.captureActive) {
            _addDiagnosticLog(
              'Voice capture stopped because the Activity entered background.',
            );
            unawaited(_stopListening());
          }
        });
      }
    }

    final mode = _wakeWordMode;
    if (mode == 'off') return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mode == 'foreground') NativeBridge.stopHotword();
    } else if (state == AppLifecycleState.resumed &&
        !_wakeWordSuspendedForVoice &&
        !_isListening &&
        !_voiceSession.state.captureActive &&
        !_isGenerating) {
      NativeBridge.setHotwordMode(mode);
    }
  }

  @override
  void dispose() {
    _voiceSession.invalidate(
      phase: VoiceSessionPhase.stopped,
      reason: 'Voice surface disposed.',
    );
    final wakeMode = PreferencesService().wakeWordMode;
    // An always-on wake policy belongs to the Android foreground service, not
    // to this particular Flutter route. Stopping it during route disposal
    // creates a silent gap when ChatScreen is recreated or replaced.
    if (wakeMode == 'foreground') NativeBridge.stopHotword();
    WidgetsBinding.instance.removeObserver(this);
    AgentSkillServer.instance.onAvatarChanged = null;
    AgentSkillServer.instance.onAvatarGestureRequested = null;
    AgentSkillServer.instance.onGesturePlayed = null;
    AgentSkillServer.instance.onEmotionSet = null;
    CanvasCapability.onVisibilityChanged = null;
    HologramService.instance.dismiss();
    CanvasCapability().clearController();
    CanvasCapability.onCaptureScreenshot = null;
    CanvasCapability.onActivationRequested = null;
    _hotwordSub?.cancel();
    _localLlmSub?.cancel();
    _gatewaySub?.cancel();
    _gatewayActivitySub?.cancel();
    _skillsSub?.cancel();
    _toolMediaSub?.cancel();
    _talkAudioStreamSub?.cancel();
    _talkEventSub?.cancel();
    _talkRelayFinalizationTimer?.cancel();
    _talkRelayFinalizationTimer = null;
    _backgroundVoiceStopTimer?.cancel();
    _backgroundVoiceStopTimer = null;
    _continuousListeningTimer?.cancel();
    _continuousListeningTimer = null;
    _configurationRequestSub?.cancel();
    _chatRuntime.removeListener(_syncChatRuntimeState);
    _scrollController.removeListener(_handleChatScroll);
    final talkSessionId = _talkRelaySessionId;
    if (talkSessionId != null && talkSessionId.isNotEmpty) {
      unawaited(
        GatewayService().closeTalkSession(talkSessionId).catchError((_) {}),
      );
    }
    _glowController.dispose();
    unawaited(_nativeSpeechInput.dispose());
    _audioRecorder.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  Widget _buildSessionDrawer() {
    final sessions = _persistence.sessions;
    final activeId = _persistence.activeSessionId;

    return Drawer(
      backgroundColor: const Color(0xE0101828),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CHAT SESSIONS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white70),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _persistence.createSession();
                      _loadChatHistory();
                    },
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (ctx, i) {
                  final session = sessions[i];
                  final isActive = session.id == activeId;
                  return ListTile(
                    leading: Icon(
                      isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
                      color: isActive ? AppColors.statusGreen : Colors.white38,
                      size: 20,
                    ),
                    title: Text(
                      session.title,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatDate(session.updatedAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white38,
                        size: 18,
                      ),
                      onSelected: (action) async {
                        if (action == 'delete') {
                          await _persistence.deleteSession(session.id);
                          _loadChatHistory();
                        } else if (action == 'rename') {
                          _renameSession(session);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                    selected: isActive,
                    selectedTileColor: Colors.white.withValues(alpha: 0.05),
                    onTap: () async {
                      Navigator.pop(context);
                      await _persistence.switchSession(session.id);
                      _loadChatHistory();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _renameSession(ChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Chat name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await _persistence.renameSession(session.id, name);
                if (mounted) setState(() {});
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  String? _firstSupportedMethod(
    Set<String> supported,
    List<String> candidates,
  ) {
    for (final method in candidates) {
      if (supported.contains(method)) return method;
    }
    return null;
  }

  Future<void> _invokeGatewayControl(
    BuildContext context, {
    required String label,
    required List<String> candidates,
    Map<String, dynamic> params = const <String, dynamic>{},
  }) async {
    final gateway = context.read<GatewayProvider>();
    final supported = gateway.supportedMethods.toSet();
    final method = _firstSupportedMethod(supported, candidates);
    if (method == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label is not advertised by this Gateway build.'),
          backgroundColor: AppColors.statusAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final result = await gateway.invoke(method, params);
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(label),
          content: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(result),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label failed: $e'),
          backgroundColor: AppColors.statusRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openGatewayDashboard(BuildContext context) async {
    final gateway = context.read<GatewayProvider>();
    final url = await gateway.refreshDashboardUrl();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WebDashboardScreen(url: url)));
  }

  Widget _agentControlCard({
    required IconData icon,
    required String title,
    required String body,
    required bool available,
    required List<Widget> actions,
  }) {
    final accent = available ? AppColors.statusGreen : AppColors.statusAmber;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                available ? 'READY' : 'CHECK',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }

  void _showAgentRuntimeControls(BuildContext context) {
    HapticFeedback.selectionClick();
    final gateway = context.read<GatewayProvider>();
    final supported = gateway.supportedMethods.toSet();
    final cronReady = supported.any((method) => method.startsWith('cron.'));
    final dreamingReady = supported.any(
      (method) =>
          method.startsWith('dream') ||
          method.startsWith('memory.') ||
          method == 'doctor.memory',
    );
    final instancesReady = supported.any(
      (method) =>
          method == 'system-presence' ||
          method.startsWith('instances.') ||
          method.startsWith('presence.') ||
          method.startsWith('clients.'),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.88;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: AppColors.statusGreen,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Agent Controls',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _agentControlCard(
                    icon: Icons.schedule_rounded,
                    title: 'Cron',
                    body:
                        'Scheduled Gateway jobs and delayed agent actions. Use for reminders, follow-ups, and timed checks.',
                    available: cronReady,
                    actions: [
                      OutlinedButton(
                        onPressed: () => _invokeGatewayControl(
                          ctx,
                          label: 'Cron status',
                          candidates: const ['cron.status', 'cron.list'],
                        ),
                        child: const Text('Status'),
                      ),
                      OutlinedButton(
                        onPressed: () => _invokeGatewayControl(
                          ctx,
                          label: 'Cron jobs',
                          candidates: const ['cron.list', 'cron.status'],
                        ),
                        child: const Text('Jobs'),
                      ),
                      TextButton(
                        onPressed: () => _openGatewayDashboard(ctx),
                        child: const Text('Dashboard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _agentControlCard(
                    icon: Icons.nightlight_round,
                    title: 'Dreaming',
                    body:
                        'Memory consolidation and background reflection. Keep it opt-in until release policy is final.',
                    available: dreamingReady,
                    actions: [
                      OutlinedButton(
                        onPressed: () => _invokeGatewayControl(
                          ctx,
                          label: 'Dreaming status',
                          candidates: const [
                            'dreaming.status',
                            'memory.status',
                            'doctor.memory',
                          ],
                        ),
                        child: const Text('Status'),
                      ),
                      TextButton(
                        onPressed: () => _openGatewayDashboard(ctx),
                        child: const Text('Dashboard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _agentControlCard(
                    icon: Icons.hub_rounded,
                    title: 'Instances',
                    body:
                        'Connected Gateway clients and presence. Useful for confirming chat, dashboard, and mobile node ownership.',
                    available: instancesReady,
                    actions: [
                      OutlinedButton(
                        onPressed: () => _invokeGatewayControl(
                          ctx,
                          label: 'Instances',
                          candidates: const [
                            'system-presence',
                            'instances.list',
                            'presence.list',
                            'clients.list',
                          ],
                        ),
                        child: const Text('List'),
                      ),
                      TextButton(
                        onPressed: () => _openGatewayDashboard(ctx),
                        child: const Text('Dashboard'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final viewportWidth = math.max(1.0, size.width);
    final viewportHeight = math.max(1.0, size.height);
    double orderedClamp(double value, double lower, double upper) {
      final lo = math.min(lower, upper);
      final hi = math.max(lower, upper);
      return value.clamp(lo, hi).toDouble();
    }

    // --- Dynamic Sizing for Floating Mic ---
    const double collapsedSize = 96.0;
    // Adaptive height: Capped to avoid keyboard overflow on small screens
    final keyboardHeight = MediaQuery.of(
      context,
    ).viewInsets.bottom.clamp(0.0, viewportHeight * 0.7).toDouble();
    final keyboardVisible = keyboardHeight > 0;
    final rawMaxExpandedHeight =
        viewportHeight - keyboardHeight - (keyboardVisible ? 78.0 : 190.0);
    final isTinyViewport =
        _isPipMode || viewportWidth < 320.0 || viewportHeight < 420.0;
    final maxExpandedHeight = math.max(
      isTinyViewport ? 96.0 : 260.0,
      rawMaxExpandedHeight,
    );
    final minExpandedHeight = math.min(
      isTinyViewport ? 96.0 : 260.0,
      maxExpandedHeight,
    );
    final targetExpandedHeight =
        viewportHeight * (keyboardVisible ? 0.52 : 0.46);
    final expandedHorizontalMargin = viewportWidth < 340.0 ? 0.0 : 10.0;
    final expandedWidth = math.min(
      620.0,
      math.max(1.0, viewportWidth - expandedHorizontalMargin * 2),
    );
    final double barWidth = _isChatCollapsed
        ? math.min(collapsedSize, viewportWidth)
        : expandedWidth;
    final double barHeight = _isChatCollapsed
        ? collapsedSize
        : orderedClamp(
            targetExpandedHeight,
            minExpandedHeight,
            maxExpandedHeight,
          );
    final chatTrayBottomMargin = _isChatCollapsed ? 40.0 : 10.0;
    final chatTrayTopY =
        viewportHeight - keyboardHeight - chatTrayBottomMargin - barHeight;
    final voiceOrbY = _isChatCollapsed
        ? orderedClamp(
            viewportHeight - keyboardHeight - chatTrayBottomMargin - 132.0,
            viewportHeight * 0.46,
            viewportHeight - keyboardHeight - 118.0,
          )
        : orderedClamp(chatTrayTopY - 18.0, 112.0, viewportHeight - 96.0);
    final canvasBottom = barHeight + (_isChatCollapsed ? 40.0 : 0.0) + 16.0;
    final canvasMaxHeight = math.max(
      180.0,
      viewportHeight -
          MediaQuery.paddingOf(context).top -
          MediaQuery.paddingOf(context).bottom -
          canvasBottom -
          16.0,
    );
    // Keep the presentation window comfortably below the status/app bar even
    // on a tall phone. The old 45% height was especially problematic while
    // the IME was visible because the Scaffold does not resize for the VRM.
    final canvasHeight = math.min(
      canvasMaxHeight,
      math.max(220.0, math.min(300.0, viewportHeight * 0.34)),
    );

    Widget avatarSafeBackdrop({
      required Widget child,
      required double sigmaX,
      required double sigmaY,
    }) {
      // Android WebView + WebGL behind a large BackdropFilter can allocate
      // enormous offscreen graphics buffers. Keep the translucent glass look,
      // but skip live backdrop blur where it would starve the gateway/runtime.
      if (Platform.isAndroid) return child;
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: child,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isPipMode ? Colors.transparent : null,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset:
          false, // Prevents VRM aspect-ratio scaling bounds from squishing
      endDrawer: _buildSessionDrawer(),
      appBar: _isPipMode
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: ClipRect(
                child: avatarSafeBackdrop(
                  sigmaX: 12.0,
                  sigmaY: 12.0,
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: 0.05,
                    ), // Reduced alpha for more transparency
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: AnimatedOpacity(
                opacity: _isCinematic ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 400),
                child: GestureDetector(
                  onTap: () => _showUnifiedMenu(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ), // Reduced padding
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/app_icon_official.svg',
                          width: 14,
                          height: 14,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _agentName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight
                                      .w600, // Thinner, cleaner font weight
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                ModelProviderCatalog.isLocalModelId(
                                      _selectedModel,
                                    )
                                    ? '${_selectedAvatar.split('.').first.toUpperCase()} · ${_localLlmState.status == LocalLlmStatus.starting ? 'STARTING...' : 'LOCAL ON-DEVICE'}'
                                    : '${_selectedAvatar.split('.').first.toUpperCase()} · ${_selectedModelSelection.displayLabel.toUpperCase()}',
                                style: TextStyle(
                                  color:
                                      ModelProviderCatalog.isLocalModelId(
                                        _selectedModel,
                                      )
                                      ? (_localLlmState.status ==
                                                LocalLlmStatus.starting
                                            ? Colors.amber
                                            : const Color(0xFF00E5AA))
                                      : Colors.white.withValues(alpha: 0.5),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.expand_more_rounded,
                          color: Colors.white38,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.add_comment_outlined,
                    color: Colors.white70,
                  ),
                  onPressed: () async {
                    await _persistence.createSession();
                    _loadChatHistory();
                  },
                  tooltip: 'New Chat',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white70,
                  ),
                  tooltip: 'More',
                  color: Colors.black.withValues(
                    alpha: 0.7,
                  ), // Deeper frosted alpha
                  constraints: const BoxConstraints(maxWidth: 210),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  onSelected: (value) async {
                    if (value == 'pip') {
                      try {
                        await const MethodChannel(
                          'vrm/pip_mode',
                        ).invokeMethod('enterPictureInPictureMode');
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('PiP not supported: $e')),
                        );
                      }
                    } else if (value == 'agent_controls') {
                      _showAgentRuntimeControls(context);
                    } else if (value == 'ai_payments') {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BaseScreen()),
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<String>(
                      value: 'agent_controls',
                      child: Row(
                        children: const [
                          Icon(
                            Icons.tune_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Agent Controls',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'ai_payments',
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'AI Payments & Wallet',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      enabled: false,
                      height: 40,
                      child: Builder(
                        builder: (ctx2) => ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                          leading: Icon(
                            Icons.picture_in_picture_alt,
                            color: Colors.white70,
                            size: 20,
                          ),
                          title: const Text(
                            'Picture in Picture',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx2);
                            try {
                              await const MethodChannel(
                                'vrm/pip_mode',
                              ).invokeMethod('enterPictureInPictureMode');
                            } catch (_) {}
                          },
                        ),
                      ),
                    ),
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Builder(
                        builder: (ctx2) => ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                          leading: const Icon(
                            Icons.history,
                            color: Colors.white70,
                            size: 20,
                          ),
                          title: const Text(
                            'Chat Sessions',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx2);
                            // Use scaffoldKey to avoid Scaffold.of() resolving against
                            // the PopupMenu overlay context instead of our Scaffold.
                            _scaffoldKey.currentState?.openEndDrawer();
                          },
                        ),
                      ),
                    ),
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Builder(
                        builder: (ctx2) => ListTile(
                          dense: true,
                          leading: Icon(
                            _showDiagnostics
                                ? Icons.bug_report
                                : Icons.bug_report_outlined,
                            color: _showDiagnostics
                                ? AppColors.statusGreen
                                : Colors.white54,
                            size: 20,
                          ),
                          title: Text(
                            _showDiagnostics
                                ? 'Hide Diagnostics'
                                : 'Show Diagnostics',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx2);
                            setState(
                              () => _showDiagnostics = !_showDiagnostics,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: Stack(
        children: [
          // 1. Deep space background
          if (!_isPipMode)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [const Color(0xFF0D1B2A), Colors.black],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),

          // 2. Subtle animated nebula particles
          if (!_isPipMode && !Platform.isAndroid)
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: CustomPaint(
                  painter: NebulaPainter(_isThinking ? 1.0 : 0.0),
                ),
              ),
            ),

          // 3. 3D VRM Avatar
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter, // Ensure centering
              transform: Matrix4.identity()
                ..scaleByDouble(
                  MediaQuery.of(context).viewInsets.bottom > 0 ? 1.04 : 1.0,
                  MediaQuery.of(context).viewInsets.bottom > 0 ? 1.04 : 1.0,
                  1.0,
                  1.0,
                ),
              transformAlignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width.clamp(0.0, 600.0),
                  maxHeight: size.height,
                ),
                child: Builder(
                  builder: (context) {
                    final avatar = VrmAvatarWidget(
                      key: ValueKey(_selectedAvatar),
                      isThinking: _isThinking,
                      speechIntensity: _speechIntensity,
                      glowIntensity: _speechIntensity,
                      avatarFileName: _selectedAvatar,
                      isCinematic: _isCinematic,
                      isPip: _isPipMode,
                      gesture: _currentGesture,
                      gestureMode: _currentGestureMode,
                      controller: _avatarController,
                      onGestureResult: (result) {
                        _addDiagnosticLog(
                          'Avatar gesture result: ${jsonEncode(result)}',
                        );
                      },
                      onLog: (log) {
                        if (log == 'READY') {
                          setState(() => _isReady = true);
                        }
                        _addDiagnosticLog(log);
                      },
                    );

                    // Android PlatformViews/WebView do not like being faded or
                    // scaled under Flutter overlays. Keep avatar switches direct
                    // so Chromium/WebGL owns one stable surface.
                    if (Platform.isAndroid) return avatar;

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: avatar,
                    );
                  },
                ),
              ),
            ),
          ),

          // 4. Glassmorphic Chat Area
          if (!_isPipMode)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 5. Epic Floating Chat/Mic Bar
                    if (!_isChatCollapsed) const Spacer(flex: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      // Elastic curves overshoot and can briefly interpolate
                      // EdgeInsets below zero during voice/full-chat toggles.
                      curve: Curves.easeOutCubic,
                      width: barWidth,
                      height: barHeight,
                      margin: EdgeInsets.only(
                        bottom: chatTrayBottomMargin,
                        left: _isChatCollapsed ? 0 : expandedHorizontalMargin,
                        right: _isChatCollapsed ? 0 : expandedHorizontalMargin,
                      ),
                      decoration: BoxDecoration(
                        gradient: _isChatCollapsed
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.10),
                                  Colors.black.withValues(alpha: 0.20),
                                  Colors.black.withValues(alpha: 0.34),
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                        color: _isChatCollapsed
                            ? Colors.white.withValues(alpha: 0.08)
                            : null,
                        borderRadius: BorderRadius.circular(
                          _isChatCollapsed ? collapsedSize / 2 : 30,
                        ),
                        border: Border.all(
                          color: _isChatCollapsed
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.10),
                          width: _isChatCollapsed ? 2 : 1.2,
                        ),
                        boxShadow: [
                          if (!_isChatCollapsed)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 18,
                              spreadRadius: -8,
                              offset: const Offset(0, -6),
                            ),
                          BoxShadow(
                            color: _isListening
                                ? AppColors.statusGreen.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.3),
                            blurRadius: _isChatCollapsed ? 30 : 20,
                            spreadRadius: _isChatCollapsed ? 5 : -2,
                          ),
                          if (_isListening && _isChatCollapsed)
                            BoxShadow(
                              color: AppColors.statusGreen.withValues(
                                alpha: 0.1 * _glowController.value,
                              ),
                              blurRadius: 20 * _glowController.value,
                              spreadRadius: 10 * _glowController.value,
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          _isChatCollapsed ? collapsedSize / 2 : 30,
                        ),
                        child: avatarSafeBackdrop(
                          sigmaX: 15,
                          sigmaY: 15,
                          child: Column(
                            children: [
                              // ── Drag handle ──────────────────────────────────
                              if (!_isChatCollapsed)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onVerticalDragEnd: (details) {
                                    // Swipe down (positive velocity) → voice-only
                                    // Swipe up (negative velocity)   → expand
                                    if (details.primaryVelocity == null) return;
                                    if (details.primaryVelocity! > 400) {
                                      setState(() => _isChatCollapsed = true);
                                    } else if (details.primaryVelocity! <
                                        -400) {
                                      setState(() => _isChatCollapsed = false);
                                      _scrollToBottom(instant: true);
                                    }
                                  },
                                  child: Container(
                                    height: 28,
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 58,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                            AppColors.statusGreen.withValues(
                                              alpha: 0.46,
                                            ),
                                            Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.statusGreen
                                                .withValues(alpha: 0.14),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (!_isChatCollapsed)
                                Expanded(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.white,
                                            Colors.white,
                                            Colors.transparent,
                                          ],
                                          stops: [0.0, 0.05, 0.95, 1.0],
                                        ).createShader(bounds),
                                    blendMode: BlendMode.dstIn,
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        4,
                                        16,
                                        12,
                                      ),
                                      itemCount: _messages.length,
                                      itemBuilder: (context, i) {
                                        final msg = _messages[i];
                                        return ChatBubble(
                                          message: msg,
                                          isThinking:
                                              i == _messages.length - 1 &&
                                              _isThinking,
                                        );
                                      },
                                    ),
                                  ),
                                ),

                              // Voice persona chips removed — accessible via the AuraDot orb above the avatar.
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _isChatCollapsed ? 0 : 12,
                                  vertical: _isChatCollapsed ? 0 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _isChatCollapsed
                                      ? Colors.transparent
                                      : Colors.black.withValues(alpha: 0.22),
                                  border: _isChatCollapsed
                                      ? null
                                      : Border(
                                          top: BorderSide(
                                            color: AppColors.statusGreen
                                                .withValues(alpha: 0.10),
                                          ),
                                        ),
                                ),
                                child: SafeArea(
                                  top: false,
                                  bottom:
                                      false, // Ensure container is flush against the bottom edge
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!_isChatCollapsed)
                                        _buildVoiceStatusIndicator(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // ──────────────────────────────────────────
                                          // 2026 UX: hold-to-record orb
                                          //   onLongPressStart  → start listening
                                          //   onLongPressEnd    → stop  listening
                                          //   onVerticalDragEnd(up) → expand chat
                                          //   onTap → no-op (reserved for hold)
                                          // ──────────────────────────────────────────
                                          if (_isChatCollapsed)
                                            Semantics(
                                              button: true,
                                              label: _voiceActionLabel,
                                              hint:
                                                  'Hold to talk. Swipe up to expand the chat.',
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () {
                                                  // Tap on collapsed orb = show hint
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).clearSnackBars();
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons.info_outline,
                                                            color:
                                                                Colors.white70,
                                                            size: 16,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            'Hold to talk  ·  Swipe ↑ to expand',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      backgroundColor:
                                                          const Color(
                                                            0xFF1A1A2E,
                                                          ),
                                                      duration: const Duration(
                                                        seconds: 2,
                                                      ),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                onLongPressStart: (_) {
                                                  HapticFeedback.mediumImpact();
                                                  _startListening();
                                                },
                                                onLongPressEnd: (_) {
                                                  HapticFeedback.lightImpact();
                                                  _stopListening();
                                                },
                                                onVerticalDragEnd: (details) {
                                                  if ((details.primaryVelocity ??
                                                          0) <
                                                      -400) {
                                                    setState(
                                                      () => _isChatCollapsed =
                                                          false,
                                                    );
                                                    _scrollToBottom(
                                                      instant: true,
                                                    );
                                                  }
                                                },
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    AnimatedBuilder(
                                                      animation:
                                                          _glowController,
                                                      builder: (_, __) =>
                                                          Transform.translate(
                                                            offset: Offset(
                                                              0,
                                                              -3 *
                                                                  _glowController
                                                                      .value,
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .keyboard_arrow_up_rounded,
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha:
                                                                        0.25 +
                                                                        0.2 *
                                                                            _glowController.value,
                                                                  ),
                                                              size: 14,
                                                            ),
                                                          ),
                                                    ),
                                                    AnimatedBuilder(
                                                      animation:
                                                          _glowController,
                                                      builder: (context, child) {
                                                        return AnimatedContainer(
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    300,
                                                              ),
                                                          width: 64,
                                                          height: 64,
                                                          decoration: BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            color: _isListening
                                                                ? AppColors
                                                                      .statusGreen
                                                                      .withValues(
                                                                        alpha:
                                                                            0.1 *
                                                                            _glowController.value,
                                                                      )
                                                                : Colors
                                                                      .transparent,
                                                          ),
                                                          alignment:
                                                              Alignment.center,
                                                          child: Icon(
                                                            _isListening
                                                                ? Icons.mic
                                                                : Icons
                                                                      .mic_none,
                                                            color: _isListening
                                                                ? AppColors
                                                                      .statusGreen
                                                                : Colors
                                                                      .white70,
                                                            size: 36,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (!_isChatCollapsed) ...[
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Image preview strip — shown when a photo is pending
                                                  if (_pendingImageBase64 !=
                                                      null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 6,
                                                          ),
                                                      child: Stack(
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            child: Image.memory(
                                                              base64Decode(
                                                                _pendingImageBase64!,
                                                              ),
                                                              height: 80,
                                                              width: 80,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                          Positioned(
                                                            top: 2,
                                                            right: 2,
                                                            child: GestureDetector(
                                                              onTap: () => setState(
                                                                () =>
                                                                    _pendingImageBase64 =
                                                                        null,
                                                              ),
                                                              child: Container(
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child: const Icon(
                                                                  Icons.close,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  Row(
                                                    children: [
                                                      // 3-Dots Utility Menu (Camera / Video)
                                                      PopupMenuButton<String>(
                                                        icon: Icon(
                                                          Icons
                                                              .more_horiz_rounded,
                                                          color:
                                                              (_pendingImageBase64 !=
                                                                      null ||
                                                                  _pendingVideoBase64 !=
                                                                      null)
                                                              ? AppColors
                                                                    .statusGreen
                                                              : Colors.white54,
                                                          size: 22,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(
                                                              minWidth: 36,
                                                              minHeight: 36,
                                                            ),
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.9,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                          side: BorderSide(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                            width: 0.8,
                                                          ),
                                                        ),
                                                        onSelected: (value) {
                                                          if (value ==
                                                              'camera') {
                                                            _takePicture();
                                                          }
                                                          if (value ==
                                                              'video') {
                                                            _showVideoDurationPicker();
                                                          }
                                                          if (value ==
                                                              'voice') {
                                                            _toggleListening();
                                                          }
                                                          if (value == 'gif') {
                                                            _importGif();
                                                          }
                                                          if (value ==
                                                              'clear') {
                                                            setState(() {
                                                              _pendingImageBase64 =
                                                                  null;
                                                              _pendingVideoBase64 =
                                                                  null;
                                                            });
                                                          }
                                                        },
                                                        itemBuilder: (ctx) => [
                                                          PopupMenuItem(
                                                            value: 'voice',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  _isListening
                                                                      ? Icons
                                                                            .mic
                                                                      : Icons
                                                                            .mic_none,
                                                                  color:
                                                                      _isListening
                                                                      ? AppColors
                                                                            .statusGreen
                                                                      : Colors
                                                                            .white70,
                                                                  size: 20,
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                Text(
                                                                  _isListening
                                                                      ? 'Stop Listening'
                                                                      : 'Voice Input',
                                                                  style: TextStyle(
                                                                    color:
                                                                        _isListening
                                                                        ? AppColors
                                                                              .statusGreen
                                                                        : Colors
                                                                              .white,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          PopupMenuItem(
                                                            value: 'camera',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  _isTakingPhoto
                                                                      ? Icons
                                                                            .hourglass_empty
                                                                      : Icons
                                                                            .camera_alt_outlined,
                                                                  color: Colors
                                                                      .white70,
                                                                  size: 20,
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                const Text(
                                                                  'Take Photo',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          PopupMenuItem(
                                                            value: 'video',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  _isRecordingVideo
                                                                      ? Icons
                                                                            .hourglass_empty
                                                                      : Icons
                                                                            .videocam_outlined,
                                                                  color: Colors
                                                                      .white70,
                                                                  size: 20,
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                const Text(
                                                                  'Record Clip',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const PopupMenuItem(
                                                            value: 'gif',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .gif_box_outlined,
                                                                  color: Colors
                                                                      .white70,
                                                                  size: 20,
                                                                ),
                                                                SizedBox(
                                                                  width: 12,
                                                                ),
                                                                Text(
                                                                  'Import GIF for gifgrep',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          if (_pendingImageBase64 !=
                                                                  null ||
                                                              _pendingVideoBase64 !=
                                                                  null)
                                                            const PopupMenuItem(
                                                              value: 'clear',
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .delete_outline,
                                                                    color: Colors
                                                                        .redAccent,
                                                                    size: 20,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Text(
                                                                    'Clear Attachment',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .redAccent,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: TextField(
                                                          controller:
                                                              _textController,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 15,
                                                              ),
                                                          onChanged: (_) =>
                                                              setState(() {}),
                                                          decoration: InputDecoration(
                                                            hintText:
                                                                _pendingVideoBase64 !=
                                                                    null
                                                                ? "Ask about the video..."
                                                                : _pendingImageBase64 !=
                                                                      null
                                                                ? "Ask about the image..."
                                                                : "Message your companion...",
                                                            hintStyle: TextStyle(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.40,
                                                                  ),
                                                              fontSize: 14,
                                                            ),
                                                            border: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    30,
                                                                  ),
                                                              borderSide: BorderSide(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    ),
                                                                width: 0.8,
                                                              ),
                                                            ),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    30,
                                                                  ),
                                                              borderSide: BorderSide(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    ),
                                                                width: 0.8,
                                                              ),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    30,
                                                                  ),
                                                              borderSide: const BorderSide(
                                                                color: AppColors
                                                                    .statusGreen,
                                                                width: 1.0,
                                                              ),
                                                            ),
                                                            filled: true,
                                                            fillColor: Colors
                                                                .black
                                                                .withValues(
                                                                  alpha: 0.20,
                                                                ),
                                                            contentPadding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 12,
                                                                ),
                                                          ),
                                                          onSubmitted:
                                                              _handleSubmit,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            AnimatedBuilder(
                                              animation: _glowController,
                                              builder: (context, _) {
                                                final theme = Theme.of(context);
                                                final signalColor =
                                                    _chatNobTtsColor();
                                                final pulse =
                                                    _isGatewayTtsUnavailable
                                                    ? _glowController.value
                                                    : 0.0;
                                                return AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                      colors:
                                                          _chatNobGradientColors(
                                                            theme,
                                                          ),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: signalColor
                                                            .withValues(
                                                              alpha:
                                                                  0.22 +
                                                                  pulse * 0.32,
                                                            ),
                                                        blurRadius:
                                                            18 + pulse * 10,
                                                        spreadRadius:
                                                            -2 + pulse * 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.send_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _handleSubmit(
                                                          _textController.text,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 5. Canvas Overlay (WebView AI Browser)
          if (_canvasVisible && _canvasController != null && !_isPipMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: canvasBottom,
              height: canvasHeight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        key: _canvasRepaintKey,
                        child: WebViewWidget(controller: _canvasController!),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Semantics(
                          button: true,
                          label: 'Close canvas',
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.72),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                final controller = _canvasController;
                                setState(() {
                                  _canvasVisible = false;
                                  _canvasController = null;
                                });
                                CanvasCapability().clearController();
                                unawaited(
                                  controller
                                          ?.loadRequest(
                                            Uri.parse('about:blank'),
                                          )
                                          .catchError((_) {}) ??
                                      Future<void>.value(),
                                );
                              },
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Hologram Overlay (image / canvas snapshot presenter)
          if (!_isPipMode) const HologramOverlay(),

          // 7. Diagnostics (slide-up panel)
          if (_showDiagnostics && !_isPipMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: size.height * 0.4,
              child: _buildDiagnosticsPanel(theme),
            ),

          // PiP mic is handled by native Android RemoteAction (see MainActivity.kt).
          // Flutter UI touch events are blocked in PiP mode by the OS.

          // --- AURA DOT (Holographic Interface) ---
          if (!_isPipMode && _isReady)
            AuraDot(
              position: Offset(size.width / 2, voiceOrbY),
              anchorOffset: Offset.zero,
              isSpeaking:
                  TtsService().isSpeaking ||
                  _isTtsSpeaking ||
                  _ttsQueue.isNotEmpty,
              statusColor: _gatewayTtsAuraColor(),
              alertPulse: _isGatewayTtsUnavailable,
              onTap: () => _showHolographicTtsMenu(context),
            ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsPanel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SYSTEM DIAGNOSTICS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _diagnosticLogs.join('\n')),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Logs copied to clipboard'),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      onPressed: () => setState(() => _showDiagnostics = false),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _logScrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _diagnosticLogs.length,
              itemBuilder: (context, index) {
                final logLine = _diagnosticLogs[index];
                Color lineColor;
                if (logLine.contains('ERROR:')) {
                  lineColor = AppColors.statusRed;
                } else if (logLine.contains('LOG:')) {
                  lineColor = Colors.cyanAccent;
                } else if (logLine.contains('PROGRESS:')) {
                  lineColor = AppColors.statusAmber;
                } else if (logLine.contains('JS:')) {
                  lineColor = Colors.lightBlueAccent;
                } else {
                  lineColor = Colors.white70;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    logLine,
                    style: TextStyle(
                      color: lineColor,
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Holographic TTS Menu ───────────────────────────────────────────────────

  String _voiceCatalogString(Map<String, dynamic> entry, List<String> keys) {
    for (final key in keys) {
      final value = entry[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  String _voiceIdFromCatalogEntry(Object? voice) {
    if (voice is Map) {
      final entry = Map<String, dynamic>.from(voice);
      final id = _voiceCatalogString(entry, const [
        'id',
        'voiceId',
        'voice_id',
        'voice',
        'name',
        'value',
      ]);
      if (id.isNotEmpty) return id;
    }
    return voice?.toString().trim() ?? '';
  }

  String _voiceLabelFromCatalogEntry(Object? voice, String fallback) {
    if (voice is Map) {
      final entry = Map<String, dynamic>.from(voice);
      final label = _voiceCatalogString(entry, const [
        'label',
        'displayName',
        'display_name',
        'name',
        'title',
      ]);
      if (label.isNotEmpty && label.toLowerCase() != fallback.toLowerCase()) {
        return '$label ($fallback)';
      }
    }
    return fallback;
  }

  String? _voiceGenderFromCatalogEntry(
    Object? voice,
    String voiceId,
    String providerId,
  ) {
    String? normalize(String? raw) {
      final lower = raw?.trim().toLowerCase() ?? '';
      if (lower.isEmpty) return null;
      if (lower.contains('female') ||
          lower == 'f' ||
          lower.contains('feminine')) {
        return 'Female';
      }
      if (lower.contains('male') ||
          lower == 'm' ||
          lower.contains('masculine')) {
        return 'Male';
      }
      if (lower.contains('neutral') || lower.contains('androgynous')) {
        return 'Neutral';
      }
      return null;
    }

    if (voice is Map) {
      final entry = Map<String, dynamic>.from(voice);
      for (final key in const [
        'gender',
        'ssmlGender',
        'voiceGender',
        'speakerGender',
        'sex',
        'category',
      ]) {
        final found = normalize(entry[key]?.toString());
        if (found != null) return found;
      }
    }

    final id = voiceId.trim().toLowerCase();
    final provider = providerId.trim().toLowerCase();

    if (id.startsWith('af_') || id.startsWith('bf_')) return 'Female';
    if (id.startsWith('am_') || id.startsWith('bm_')) return 'Male';

    const curated = <String, String>{
      'amy': 'Female',
      'en_us-amy-medium': 'Female',
      'lessac': 'Female',
      'en_us-lessac-high': 'Female',
      'ryan': 'Male',
      'en_us-ryan-high': 'Male',
      'alloy': 'Neutral',
      'echo': 'Male',
      'onyx': 'Male',
      'ash': 'Male',
      'ballad': 'Male',
      'verse': 'Male',
      'coral': 'Female',
      'nova': 'Female',
      'sage': 'Female',
      'shimmer': 'Female',
      'kore': 'Female',
      'leda': 'Female',
      'aoede': 'Female',
      'callirrhoe': 'Female',
      'autonoe': 'Female',
      'achernar': 'Female',
      'despina': 'Female',
      'erinome': 'Female',
      'laomedeia': 'Female',
      'pulcherrima': 'Female',
      'vindemiatrix': 'Female',
      'sadachbia': 'Female',
      'sadaltager': 'Female',
      'sulafat': 'Female',
      'puck': 'Male',
      'charon': 'Male',
      'fenrir': 'Male',
      'orus': 'Male',
      'enceladus': 'Male',
      'iapetus': 'Male',
      'umbriel': 'Male',
      'algieba': 'Male',
      'algenib': 'Male',
      'rasalgethi': 'Male',
      'alnilam': 'Male',
      'schedar': 'Male',
      'gacrux': 'Male',
      'achird': 'Male',
      'zubenelgenubi': 'Male',
    };
    final direct = curated[id];
    if (direct != null) return direct;
    for (final entry in curated.entries) {
      if (id.contains(entry.key)) return entry.value;
    }
    if (provider.contains('google') && id.contains('neural')) {
      if (id.contains('jenny') ||
          id.contains('michelle') ||
          id.contains('aria')) {
        return 'Female';
      }
      if (id.contains('guy') || id.contains('davis') || id.contains('tony')) {
        return 'Male';
      }
    }
    return null;
  }

  Color _voiceGenderColor(String gender) {
    switch (gender.toLowerCase()) {
      case 'female':
        return const Color(0xFFFF79B8);
      case 'male':
        return const Color(0xFF7DB5FF);
      case 'neutral':
        return Colors.cyanAccent;
      default:
        return Colors.white38;
    }
  }

  Future<Map<String, dynamic>> _loadGatewayVoiceControlData() async {
    final gatewayProvider = Provider.of<GatewayProvider>(
      context,
      listen: false,
    );
    final prefs = PreferencesService();
    await prefs.init();

    var activeProvider = '';
    final providers = <Map<String, dynamic>>[];
    final personas = <Map<String, dynamic>>[];
    var activePersona = prefs.currentTtsPersona.trim().toLowerCase();
    final selectedVoiceId = prefs.gatewayVoiceId.trim();
    final voices = <String>[];
    final voiceProviders = <String, String>{};
    final voiceLabels = <String, String>{};
    final voiceGenders = <String, String>{};
    var talkConfigured = false;

    void collectProviderVoices(
      Map<String, dynamic> provider, {
      bool requireConfigured = false,
    }) {
      final id = (provider['id'] ?? '').toString().trim();
      if (id.isEmpty) return;
      if (requireConfigured && provider['configured'] != true) return;
      final rawVoices = provider['voices'];
      if (rawVoices is! List) return;
      for (final voice in rawVoices) {
        final v = _voiceIdFromCatalogEntry(voice);
        if (v.isEmpty) continue;
        voices.add(v);
        final key = v.toLowerCase();
        voiceProviders.putIfAbsent(key, () => id);
        voiceLabels.putIfAbsent(
          key,
          () => _voiceLabelFromCatalogEntry(voice, v),
        );
        final gender = _voiceGenderFromCatalogEntry(voice, v, id);
        if (gender != null) {
          voiceGenders.putIfAbsent(key, () => gender);
        }
      }
    }

    try {
      final providersFrame = await gatewayProvider.getTtsProviders();
      final rawProviders = providersFrame['providers'];
      if (rawProviders is List) {
        for (final item in rawProviders) {
          if (item is Map) {
            final mapped = Map<String, dynamic>.from(item);
            providers.add(mapped);
            collectProviderVoices(mapped);
          }
        }
      }
      activeProvider = (providersFrame['active'] ?? '').toString().trim();
    } catch (e) {
      _addDiagnosticLog('Voice provider lookup failed: $e');
    }

    try {
      final personasFrame = await gatewayProvider.getTtsPersonas();
      final rawPersonas = personasFrame['personas'];
      if (rawPersonas is List) {
        for (final item in rawPersonas) {
          if (item is Map) {
            personas.add(Map<String, dynamic>.from(item));
          }
        }
      }
      final active = personasFrame['active']?.toString().trim().toLowerCase();
      if (active != null && active.isNotEmpty) activePersona = active;
    } catch (e) {
      _addDiagnosticLog('Voice persona lookup failed: $e');
    }

    try {
      final talkCatalog = await gatewayProvider.getTalkCatalog();
      final speech = talkCatalog['speech'];
      if (speech is Map) {
        final speechActive =
            (speech['activeProvider'] ??
                    speech['active'] ??
                    speech['provider'] ??
                    '')
                .toString()
                .trim();
        if (speechActive.isNotEmpty) activeProvider = speechActive;

        final speechProviders = speech['providers'];
        if (speechProviders is List) {
          final speechProviderEntries = <Map<String, dynamic>>[];
          Map<String, dynamic>? activeEntry;
          for (final item in speechProviders) {
            if (item is! Map) continue;
            final mapped = Map<String, dynamic>.from(item);
            speechProviderEntries.add(mapped);
            final id = mapped['id']?.toString() ?? '';
            if (id == activeProvider) {
              activeEntry = mapped;
            }
            collectProviderVoices(mapped);
          }
          if (speechProviderEntries.isNotEmpty) {
            // talk.catalog is authoritative for speech. tts.providers can reflect
            // text/model providers, which made OpenRouter appear as a voice engine.
            providers
              ..clear()
              ..addAll(speechProviderEntries);
          }
          if (activeEntry == null && speechProviders.isNotEmpty) {
            final fallback = speechProviders.first;
            if (fallback is Map) {
              activeEntry = Map<String, dynamic>.from(fallback);
              activeProvider = activeEntry['id']?.toString() ?? activeProvider;
            }
          }

          if (activeEntry?['configured'] == true) {
            talkConfigured = true;
          } else if (activeEntry != null) {
            talkConfigured = false;
          }
        }
      }
    } catch (e) {
      _addDiagnosticLog('Talk catalog lookup failed: $e');
    }

    if (voices.isEmpty && activeProvider.isNotEmpty) {
      final providerEntry = providers.cast<Map<String, dynamic>?>().firstWhere(
        (entry) => entry?['id']?.toString() == activeProvider,
        orElse: () => null,
      );
      final rawVoices = providerEntry?['voices'];
      if (rawVoices is List) {
        for (final voice in rawVoices) {
          final v = _voiceIdFromCatalogEntry(voice);
          if (v.isNotEmpty) {
            voices.add(v);
            final key = v.toLowerCase();
            voiceProviders.putIfAbsent(key, () => activeProvider);
            voiceLabels.putIfAbsent(
              key,
              () => _voiceLabelFromCatalogEntry(voice, v),
            );
            final gender = _voiceGenderFromCatalogEntry(
              voice,
              v,
              activeProvider,
            );
            if (gender != null) {
              voiceGenders.putIfAbsent(key, () => gender);
            }
          }
        }
      }
    }

    final dedupedVoices = <String>[];
    final seen = <String>{};
    for (final voice in voices) {
      if (seen.add(voice.toLowerCase())) {
        dedupedVoices.add(voice);
      }
    }

    return <String, dynamic>{
      'activeProvider': activeProvider,
      'providers': providers,
      'personas': personas,
      'activePersona': activePersona,
      'selectedVoiceId': selectedVoiceId,
      'voices': dedupedVoices,
      'voiceProviders': voiceProviders,
      'voiceLabels': voiceLabels,
      'voiceGenders': voiceGenders,
      'talkConfigured': talkConfigured,
    };
  }

  Future<void> _applyGatewayPersona(String personaId) async {
    final gatewayProvider = Provider.of<GatewayProvider>(
      context,
      listen: false,
    );
    await gatewayProvider.setTtsPersona(personaId);
    final prefs = PreferencesService();
    await prefs.init();
    prefs.currentTtsPersona = personaId.trim().toLowerCase().isEmpty
        ? 'default'
        : personaId.trim().toLowerCase();
  }

  Future<void> _applyGatewayProvider(String providerId) async {
    final gatewayProvider = Provider.of<GatewayProvider>(
      context,
      listen: false,
    );
    await gatewayProvider.setTtsProvider(providerId);
  }

  void _showHolographicTtsMenu(BuildContext context) {
    final dataFuture = _loadGatewayVoiceControlData();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TTS Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return FutureBuilder<Map<String, dynamic>>(
                  future: dataFuture,
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? const <String, dynamic>{};
                    final providers =
                        (data['providers'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        const <Map<String, dynamic>>[];
                    final personas =
                        (data['personas'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        const <Map<String, dynamic>>[];
                    final voices =
                        (data['voices'] as List?)?.cast<String>() ??
                        const <String>[];
                    final voiceProvidersRaw = data['voiceProviders'];
                    final voiceProviders = voiceProvidersRaw is Map
                        ? voiceProvidersRaw.map(
                            (key, value) =>
                                MapEntry(key.toString(), value.toString()),
                          )
                        : const <String, String>{};
                    final voiceLabelsRaw = data['voiceLabels'];
                    final voiceLabels = voiceLabelsRaw is Map
                        ? voiceLabelsRaw.map(
                            (key, value) =>
                                MapEntry(key.toString(), value.toString()),
                          )
                        : const <String, String>{};
                    final voiceGendersRaw = data['voiceGenders'];
                    final voiceGenders = voiceGendersRaw is Map
                        ? voiceGendersRaw.map(
                            (key, value) =>
                                MapEntry(key.toString(), value.toString()),
                          )
                        : const <String, String>{};

                    String activeProvider = (data['activeProvider'] ?? '')
                        .toString();
                    String activePersona = (data['activePersona'] ?? 'default')
                        .toString();
                    String selectedVoiceId = (data['selectedVoiceId'] ?? '')
                        .toString();
                    final talkConfigured = data['talkConfigured'] == true;
                    final speed = PreferencesService().ttsSpeed;

                    if (activeProvider.isEmpty && providers.isNotEmpty) {
                      activeProvider = providers.first['id']?.toString() ?? '';
                    }
                    if (selectedVoiceId.isNotEmpty &&
                        !voices.any(
                          (voice) =>
                              voice.toLowerCase() ==
                              selectedVoiceId.toLowerCase(),
                        )) {
                      selectedVoiceId = '';
                    }

                    return BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.88,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.1),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.record_voice_over_rounded,
                                    color: Colors.cyanAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'GATEWAY VOICE',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 24),
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.cyanAccent,
                                    ),
                                  ),
                                )
                              else ...[
                                if (_isGatewayTtsUnavailable) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _chatNobTtsColor().withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _chatNobTtsColor().withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: _chatNobTtsColor(),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _gatewayTtsHealthMessage ??
                                                'Gateway voice is unavailable right now.',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white.withValues(
                                                alpha: 0.82,
                                              ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                if (providers.isNotEmpty) ...[
                                  Text(
                                    'PROVIDER',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      border: Border.all(
                                        color: Colors.white12,
                                        width: 1,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: activeProvider.isEmpty
                                            ? null
                                            : activeProvider,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF17181F),
                                        items: providers.map((provider) {
                                          final id =
                                              provider['id']?.toString() ?? '';
                                          final label =
                                              provider['name']?.toString() ??
                                              provider['label']?.toString() ??
                                              id;
                                          final configured =
                                              provider['configured'] == true;
                                          return DropdownMenuItem<String>(
                                            value: id,
                                            child: Text(
                                              configured
                                                  ? label
                                                  : '$label (not configured)',
                                              style: TextStyle(
                                                color: configured
                                                    ? Colors.white
                                                    : Colors.white54,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) async {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return;
                                          }
                                          await _applyGatewayProvider(value);
                                          if (!mounted) return;
                                          final refreshed =
                                              await _loadGatewayVoiceControlData();
                                          setModalState(() {
                                            data
                                              ..clear()
                                              ..addAll(refreshed);
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                if (voices.isNotEmpty) ...[
                                  Text(
                                    'VOICE ID',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      border: Border.all(
                                        color: Colors.white12,
                                        width: 1,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedVoiceId.isEmpty
                                            ? null
                                            : selectedVoiceId,
                                        hint: const Text(
                                          'Provider default',
                                          style: TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF17181F),
                                        items: voices.map((voice) {
                                          final key = voice.toLowerCase();
                                          final owner =
                                              voiceProviders[key] ?? '';
                                          final display =
                                              voiceLabels[key] ?? voice;
                                          final gender =
                                              voiceGenders[key] ?? 'Unknown';
                                          final label =
                                              owner.isNotEmpty &&
                                                  owner != activeProvider
                                              ? '$display · $owner'
                                              : display;
                                          return DropdownMenuItem(
                                            value: voice,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    label,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _voiceGenderColor(
                                                      gender,
                                                    ).withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color: _voiceGenderColor(
                                                        gender,
                                                      ).withValues(alpha: 0.55),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    gender,
                                                    style: GoogleFonts.outfit(
                                                      color: _voiceGenderColor(
                                                        gender,
                                                      ),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) async {
                                          if (value == null) return;
                                          final owner =
                                              voiceProviders[value
                                                  .toLowerCase()] ??
                                              '';
                                          if (owner.isNotEmpty &&
                                              owner != activeProvider) {
                                            await _applyGatewayProvider(owner);
                                          }
                                          final prefs = PreferencesService();
                                          await prefs.init();
                                          prefs.gatewayVoiceId = value;
                                          setModalState(() {
                                            data['selectedVoiceId'] = value;
                                            if (owner.isNotEmpty) {
                                              data['activeProvider'] = owner;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                if (personas.isNotEmpty) ...[
                                  Text(
                                    'PERSONA',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: personas.map((entry) {
                                      final id = (entry['id'] ?? '')
                                          .toString()
                                          .trim()
                                          .toLowerCase();
                                      if (id.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      final isSelected = id == activePersona;
                                      return GestureDetector(
                                        onTap: () async {
                                          await _applyGatewayPersona(id);
                                          if (!mounted) return;
                                          setModalState(() {
                                            data['activePersona'] = id;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.cyanAccent.withValues(
                                                    alpha: 0.2,
                                                  )
                                                : Colors.white.withValues(
                                                    alpha: 0.05,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.cyanAccent
                                                  : Colors.white10,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            id.toUpperCase(),
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: isSelected
                                                  ? Colors.cyanAccent
                                                  : Colors.white70,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.speed,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'SPEECH SPEED',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white54,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${speed.toStringAsFixed(1)}X',
                                      style: GoogleFonts.outfit(
                                        color: Colors.cyanAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.cyanAccent,
                                    inactiveTrackColor: Colors.white10,
                                    thumbColor: Colors.white,
                                    trackHeight: 2,
                                  ),
                                  child: Slider(
                                    value: speed,
                                    min: 0.5,
                                    max: 2.0,
                                    onChanged: (v) {
                                      setModalState(() {
                                        PreferencesService().ttsSpeed = v;
                                      });
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: !talkConfigured
                                        ? null
                                        : () async {
                                            final gatewayProvider =
                                                Provider.of<GatewayProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            final result = await gatewayProvider
                                                .speakTextViaTalk(
                                                  'Voice check complete.',
                                                );
                                            if (!context.mounted) return;
                                            _setGatewayTtsHealth(
                                              result.played
                                                  ? _GatewayTtsHealth.normal
                                                  : result.allowNativeFallback ||
                                                        result.status.contains(
                                                          'backoff',
                                                        )
                                                  ? _GatewayTtsHealth.degraded
                                                  : _GatewayTtsHealth.failed,
                                              message: result.displayMessage,
                                            );
                                            if (!result.played &&
                                                result.displayMessage != null) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    result.displayMessage!,
                                                  ),
                                                  backgroundColor:
                                                      Colors.orangeAccent,
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.graphic_eq_rounded),
                                    label: const Text('Test Gateway Voice'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Voice output is streamed from OpenClaw Talk. '
                                  'Local system TTS is used only when talk.speak is unavailable.',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
