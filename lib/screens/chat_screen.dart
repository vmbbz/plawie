import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
import '../widgets/aura_dot.dart';
import '../services/gateway_service.dart';
import '../services/agent_skill_server.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/capabilities/camera_capability.dart';
import '../services/capabilities/canvas_capability.dart';
import '../services/hologram_service.dart';
import '../widgets/hologram_overlay.dart';
import 'management/local_llm_screen.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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
  bool _isListening = false;
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
  int? _talkAssistantMessageIndex;
  String _talkAssistantTextBuffer = '';

  // Streaming TTS state
  String _ttsSentenceBuffer = '';
  bool _isTtsSpeaking = false;
  final List<String> _ttsQueue = [];
  String? _gatewaySessionKey;

  String _selectedAvatar = 'gemini.vrm';
  String _agentName = 'Plawie';
  String _selectedModel = ModelProviderCatalog.defaultCloudFallbackModel;
  // Cloud model to fall back to when a local NDK model stops.
  // Set at load time from onboarding provider; updated when user picks a cloud model.
  String _cloudFallbackModel = ModelProviderCatalog.defaultCloudFallbackModel;

  // Vision / image attachment state
  String? _pendingImageBase64; // base64 of photo waiting to be sent
  bool _isTakingPhoto = false; // true while camera shutter is in flight

  // Video attachment state
  String? _pendingVideoBase64; // base64 of recorded clip waiting to be sent
  bool _isRecordingVideo = false;

  // Static cloud model list — augmented at runtime with gateway agents
  final List<String> _availableModels =
      ModelProviderCatalog.cloudModelIds.toList();

  // Dynamic agents fetched from the gateway
  List<AgentInfo> _dynamicAgents = [];

  final List<String> _availableAvatars = [
    'gemini.vrm',
    'boruto.vrm',
  ];

  // Wake word subscription
  StreamSubscription<String>? _hotwordSub;
  // Auto-sync model when local LLM starts/stops
  StreamSubscription<LocalLlmState>? _localLlmSub;
  LocalLlmState _localLlmState = const LocalLlmState();
  bool _localChatModeEnabled = false;
  // Gateway state sync — keeps stale prefs from leaking into the model picker.
  StreamSubscription<GatewayState>? _gatewaySub;
  // Skills event bus — tracks executing/executed/error states
  StreamSubscription? _skillsSub;

  // Latest camera.snap base64 captured by AI tool call — attached to bot message after stream ends
  String? _pendingAiSnapBase64;
  String? _pendingAiSnapMimeType;

  // Canvas overlay state
  WebViewController? _canvasController;
  bool _canvasVisible = false;

  static const MethodChannel _pipChannel = MethodChannel('vrm/pip_mode');
  bool _isPipMode = false;
  bool _isChatCollapsed = false; // Expanded by default
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Wire AgentSkillServer callbacks so agent-controlled avatar changes
    // reflect immediately in the live chat UI (singleton shares state with main()).
    AgentSkillServer.instance.onAvatarChanged = (file) {
      if (mounted) setState(() => _selectedAvatar = file);
    };
    AgentSkillServer.instance.onGesturePlayed = (gesture) {
      if (!mounted) return;
      setState(() => _currentGesture = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentGesture = gesture);
      });
    };
    AgentSkillServer.instance.onGestureModeChanged = (mode) {
      if (mounted) setState(() => _currentGestureMode = mode);
    };
    AgentSkillServer.instance.onEmotionSet =
        (_) {}; // handled by avatar_scene.html
    // When the AI calls camera.snap, store the result so we can show it inline in chat
    CameraCapability.onSnapTaken = (b64, mime) {
      _pendingAiSnapBase64 = b64;
      _pendingAiSnapMimeType = mime;
    };

    // Canvas WebView is created lazily on first tool use. Keeping it out of
    // idle chat avoids holding a second Android WebView/GL context all day.
    CanvasCapability.onActivationRequested = _ensureCanvasController;
    CanvasCapability.onVisibilityChanged = (visible) async {
      if (visible) {
        await _ensureCanvasController();
      }
      if (mounted) setState(() => _canvasVisible = visible);
    };
    CanvasCapability.onSnapshotTaken = (b64, mime) {
      _pendingAiSnapBase64 = b64;
      _pendingAiSnapMimeType = mime;
    };
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
          ModelProviderCatalog.isLocalModelId(_selectedModel)) {
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
        if (ModelProviderCatalog.isLocalModelId(canonical) &&
            !localModeEnabled) {
          setState(() => _selectedModel = _cloudFallbackModel);
          PreferencesService().configuredModel = _cloudFallbackModel;
          return;
        }
        if (_availableModels.contains(canonical) ||
            (ModelProviderCatalog.isLocalModelId(canonical) &&
                LocalLlmService().state.status == LocalLlmStatus.ready)) {
          setState(() => _selectedModel = canonical);
        }
      }
    });
    _initVoiceParams();
    _loadChatHistory();
    // Fetch gateway agents after first frame — gateway may not be ready yet
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDynamicAgents());

    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPModeChanged') {
        final bool isPip = call.arguments as bool;
        if (mounted) {
          // When LEAVING PIP, stop microphone if it was listening
          if (!isPip && _isListening) {
            _addDiagnosticLog('Exiting PIP — stopping mic to reset state');
            await _audioRecorder.stop();
            setState(() {
              _isListening = false;
              _isPipMode = false;
            });
            _syncOverlayState();
          } else {
            setState(() {
              _isPipMode = isPip;
            });
          }
        }
      } else if (call.method == 'toggleMicFromPip') {
        // Native PIP mic button was tapped — toggle voice listening
        _addDiagnosticLog('PIP Mic button tapped (native RemoteAction)');
        _toggleListening();
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
            'Skill toggled: ${event.skillId} — pushing updated catalog to gateway');
        GatewayService().reregisterSkills();
      }
    });
  }

  Future<void> _loadChatHistory() async {
    await _persistence.init();
    final history = await _persistence.loadMessages();
    _gatewaySessionKey = _persistence.activeGatewaySessionKey;
    final prefs = PreferencesService();
    await prefs.init();
    _agentName = prefs.agentName;

    if (mounted) {
      setState(() {
        _messages.clear();
        if (history.isNotEmpty) {
          _messages.addAll(history);
        } else {
          _messages.add(ChatMessage(
              text:
                  "Hello! I'm $_agentName, your fully local AI companion. How can I help you today?",
              isUser: false));
        }
      });
      _scrollToBottom(instant: true);
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
    await _persistence.saveMessages(_messages);
  }

  void _loadPreferences() async {
    final prefs = PreferencesService();
    await prefs.init();
    final storedConfigured = prefs.configuredModel;
    final localModeEnabled = prefs.localChatModeEnabled;
    final canonicalConfigured = storedConfigured == null
        ? null
        : ModelProviderCatalog.canonicalizeModelId(storedConfigured);
    if (storedConfigured != null &&
        canonicalConfigured != null &&
        canonicalConfigured != storedConfigured) {
      prefs.configuredModel = canonicalConfigured;
    }
    if (mounted) {
      setState(() {
        _agentName = prefs.agentName;
        _selectedAvatar = prefs.selectedAvatar;
        _localChatModeEnabled = localModeEnabled;

        final savedCloud = prefs.lastCloudModel;
        if (savedCloud != null &&
            savedCloud.isNotEmpty &&
            !ModelProviderCatalog.isLocalModelId(savedCloud)) {
          _cloudFallbackModel = ModelProviderCatalog.canonicalizeModelId(
            savedCloud,
          );
        }

        // Derive the cloud fallback from the onboarding-chosen provider.
        final provider = prefs.apiProvider;
        if (provider != null &&
            provider.isNotEmpty &&
            !provider.startsWith('local')) {
          _cloudFallbackModel = GatewayService().getModelForProvider(provider);
        }

        // Load the user's configured model (from setup or settings).
        final configured = canonicalConfigured;
        if (configured != null && configured.isNotEmpty) {
          final isLocal = ModelProviderCatalog.isLocalModelId(configured);
          final localReady =
              isLocal && LocalLlmService().state.status == LocalLlmStatus.ready;
          if (isLocal && !localModeEnabled) {
            _selectedModel = _cloudFallbackModel;
            prefs.configuredModel = _cloudFallbackModel;
          } else if (_availableModels.contains(configured) || localReady) {
            _selectedModel = configured;
            if (!isLocal) {
              prefs.lastCloudModel = configured;
            }
          } else if (isLocal) {
            _selectedModel = _cloudFallbackModel;
            prefs.configuredModel = _cloudFallbackModel;
          }
        }
      });
    }
  }

  void _addDiagnosticLog(String log) {
    if (!mounted) return;
    setState(() {
      _diagnosticLogs
          .add('[${DateTime.now().toLocal().toString().split(' ')[1]}] $log');
      if (_diagnosticLogs.length > 100) _diagnosticLogs.removeAt(0);

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
    await controller.loadRequest(Uri.parse('about:blank'));
    if (mounted) setState(() {});
    return controller;
  }

  Future<void> _initVoiceParams() async {
    // Permission check for recorder is handled at start-time
    _tts.init();
    // Subscribe to wake word events from HotwordService (no-op if service not running)
    _hotwordSub = NativeBridge.hotwordEvents.listen((event) {
      if (event == 'wake_word_detected' &&
          mounted &&
          !_isGenerating &&
          !_isListening) {
        _addDiagnosticLog('Wake word "Plawie" detected — activating mic');
        _startListening();
      }
    }, onError: (_) {/* service not running — ignore */});

    final wakeMode = PreferencesService().wakeWordMode;
    if (wakeMode != 'off') {
      NativeBridge.startHotword();
      _addDiagnosticLog('Wake word service started (mode: $wakeMode)');
    }

    _tts.onStart = () {
      if (mounted) {
        setState(() {
          _speechIntensity = 0.8;
          _currentGesture = 'talk';
        });
        _syncOverlayState();
      }
    };

    _tts.onComplete = () {
      if (mounted) {
        _isTtsSpeaking = false;
        _processNextTtsInQueue();

        // Only close mouth and reset gesture when the entire queue is drained
        if (_ttsQueue.isEmpty && _ttsSentenceBuffer.isEmpty) {
          setState(() {
            _speechIntensity = 0.0;
            _currentGesture = 'ready'; // Reset to idle pose
          });
          _syncOverlayState();

          // Continuous mode: wait 500ms then restart listening automatically
          if (PreferencesService().continuousMode && !_isGenerating) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && !_isGenerating && !_isListening) {
                _startListening();
              }
            });
          }
        }
      }
    };
  }

  /// Strips markdown, symbols, URLs, emojis, and other non-speech content so
  /// the TTS engine reads clean natural prose without pronouncing formatting.
  String _sanitizeForTts(String text) {
    var t = text;
    // Think blocks (internal reasoning — never read aloud)
    t = t.replaceAll(
        RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
    // Gesture/action tags
    t = t.replaceAll(RegExp(r'\(gesture:\s*\w+\)\s*'), '');
    // Code blocks → label only (don't read source code verbatim)
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), 'code block. ');
    // Inline code → content only (strip backticks)
    t = t.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // Images → strip entirely
    t = t.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
    // Links → anchor text only
    t = t.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1');
    // Headings → text only (strip leading # symbols)
    t = t.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Bold/italic — triple then double then single (order matters)
    t = t.replaceAll(RegExp(r'\*{3}([^*\n]+)\*{3}'), r'$1');
    t = t.replaceAll(RegExp(r'\*{2}([^*\n]+)\*{2}'), r'$1');
    t = t.replaceAll(RegExp(r'\*([^*\n]+)\*'), r'$1');
    t = t.replaceAll(RegExp(r'_{2}([^_\n]+)_{2}'), r'$1');
    t = t.replaceAll(RegExp(r'_([^_\n]+)_'), r'$1');
    // Strikethrough
    t = t.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');
    // Horizontal rules
    t = t.replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '');
    // Table rows (lines bounded by |) and stray pipes
    t = t.replaceAll(RegExp(r'^\|.*\|$', multiLine: true), '');
    t = t.replaceAll('|', ' ');
    // URLs — unreadable when spoken
    t = t.replaceAll(RegExp(r'https?://\S+'), 'link');
    // Bracket labels used in error messages
    t = t.replaceAll('[Error]', 'Error:');
    t = t.replaceAll('[Warning]', 'Warning:');
    // HTML tags
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    // Common emoji → spoken equivalent or strip
    t = t.replaceAll('⚠️', 'Warning:');
    t = t.replaceAll('✅', '');
    t = t.replaceAll('❌', '');
    t = t.replaceAll('💡', '');
    t = t.replaceAll('🔑', '');
    t = t.replaceAll('📝', '');
    // Strip remaining emoji (Miscellaneous + Supplemental)
    t = t.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '');
    t = t.replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '');
    // Symbol → spoken equivalent
    t = t.replaceAll('→', ' to ');
    t = t.replaceAll('←', '');
    t = t.replaceAll('↑', '');
    t = t.replaceAll('↓', '');
    t = t.replaceAll('—', ', ');
    t = t.replaceAll('–', ', ');
    t = t.replaceAll('•', '');
    t = t.replaceAll('·', '');
    t = t.replaceAll('©', '');
    t = t.replaceAll('®', '');
    t = t.replaceAll('™', '');
    // Normalise whitespace
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    t = t.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return t.trim();
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
      if (clean.isNotEmpty) {
        _ttsQueue.add(clean);
        _processNextTtsInQueue();
      }
    }
  }

  Future<void> _processNextTtsInQueue() async {
    if (_isTtsSpeaking || _ttsQueue.isEmpty || _tts.isSpeaking) return;
    _isTtsSpeaking = true;
    final sentence = _ttsQueue.removeAt(0);
    try {
      if (!mounted) {
        _isTtsSpeaking = false;
        return;
      }
      if (ModelProviderCatalog.isLocalModelId(_selectedModel)) {
        await _tts.speak(sentence);
        return;
      }
      final gatewayProvider =
          Provider.of<GatewayProvider>(context, listen: false);
      final playback = await gatewayProvider.speakTextViaTalk(sentence);
      if (!playback.played && playback.allowNativeFallback) {
        // Official fallback path: only when talk.speak is unavailable on this gateway.
        await _tts.speak(sentence);
        if (!_tts.isSpeaking) {
          _isTtsSpeaking = false;
          _processNextTtsInQueue();
        }
      } else if (!playback.played && playback.errorMessage != null) {
        _addDiagnosticLog('Gateway Talk voice error: ${playback.errorMessage}');
        _isTtsSpeaking = false;
        _processNextTtsInQueue();
      }
    } catch (_) {
      // Guarantee _isTtsSpeaking is cleared on error so queue isn't permanently jammed
      _isTtsSpeaking = false;
      _processNextTtsInQueue();
    }
  }

  Future<void> _flushTtsQueue() async {
    final clean = _sanitizeForTts(_ttsSentenceBuffer);
    if (clean.isNotEmpty) {
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
    final endExclusive =
        _messages.length >= 2 ? _messages.length - 2 : _messages.length;
    return _messages
        .take(endExclusive)
        .where((m) => m.text.trim().isNotEmpty)
        .map((m) => <String, dynamic>{
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
  }

  void _scrollToBottom({bool instant = false}) {
    // Use two nested post-frame callbacks: the first waits for setState to rebuild
    // the list, the second waits for the new layout to be measured. This guarantees
    // maxScrollExtent reflects the real list height and the scroll lands at the bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        if (instant) {
          _scrollController.jumpTo(max);
        } else {
          _scrollController.animateTo(
            max,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
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
                content: Text('No camera available on this device.')),
          );
        }
        return;
      }
      final controller =
          CameraController(cameras.first, ResolutionPreset.medium);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
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
      final bytes =
          await VideoCaptureService.recordClip(durationMs: durationMs);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Video capture failed. Check camera permissions.')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _pendingVideoBase64 = base64Encode(bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video error: $e')),
        );
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
            const Text('Video Duration',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...options.entries.map((e) => ListTile(
                  title:
                      Text(e.key, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, e.value),
                )),
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
    // Cloud text is always the Gateway lane. Binding every text turn to a
    // mobile-owned session keeps Flutter chat away from agent:main:main, which
    // is also used by the dashboard and can carry stale locks/history.
    if (isLocalModelSelected || hasMediaAttachment) return false;
    return text.trim().isNotEmpty;
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

  Future<void> _handleSubmit(String text) async {
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
    _ttsSentenceBuffer = '';
    _isTtsSpeaking = false;
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
      _messages.add(ChatMessage(
        text:
            text.trim().isEmpty && videoBase64 != null ? '🎬 Video clip' : text,
        isUser: true,
        imageBase64: imageBase64,
        imageMimeType: imageBase64 != null ? 'image/jpeg' : null,
      ));
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
      return out.toString();
    }

    try {
      final gatewayProvider =
          Provider.of<GatewayProvider>(context, listen: false);
      final localLlm = LocalLlmService();

      // Route based on attachment type & model
      final Stream<String> stream;
      final isLocalModelSelected =
          ModelProviderCatalog.isLocalModelId(_selectedModel);
      String? streamSessionKey = _isUnsafeGatewaySessionKey(_gatewaySessionKey)
          ? null
          : _gatewaySessionKey;
      final bindGatewaySession = _shouldUseGatewaySessionBindingForMessage(
        text: text,
        isLocalModelSelected: isLocalModelSelected,
        hasMediaAttachment: imageBase64 != null || videoBase64 != null,
      );
      _addDiagnosticLog(
        bindGatewaySession
            ? 'Gateway session preflight required for $_selectedModel'
            : 'Gateway session preflight skipped for $_selectedModel',
      );

      if (bindGatewaySession) {
        final localSessionId = _persistence.activeSessionId;
        if (localSessionId != null && localSessionId.isNotEmpty) {
          final resolvedSessionKey =
              await gatewayProvider.resolveOrCreateGatewaySessionKey(
            localSessionId: localSessionId,
            existingSessionKey: _isUnsafeGatewaySessionKey(_gatewaySessionKey)
                ? null
                : _gatewaySessionKey,
          );
          if (resolvedSessionKey.isNotEmpty &&
              resolvedSessionKey != _gatewaySessionKey) {
            _gatewaySessionKey = resolvedSessionKey;
            await _persistence.setActiveGatewaySessionKey(resolvedSessionKey);
            _addDiagnosticLog(
                'Bound chat to gateway session: $resolvedSessionKey');
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
              final frames = await VideoFrameExtractor.extractFrames(mp4Bytes,
                  fps: 1, maxFrames: 8);
              if (frames.isEmpty) {
                yield '⚠️ Could not extract frames. Make sure ffmpeg is installed in PRoot '
                    '(`apt-get install -y ffmpeg` in a terminal session).';
                return;
              }
              yield* localLlm.analyseVideoFrames(frames,
                  text.trim().isEmpty ? 'Describe what is happening.' : text);
            }()
                .cast<String>();
          } else {
            stream = Stream.value(
                '🎥 Video captured, but no local vision model is active. Please start a multimodal model like Qwen2-VL.');
          }
        } else if (imageBase64 != null) {
          if (localLlm.isVisionReady) {
            _addDiagnosticLog(
                'Local Vision path: local multimodal model active');
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
          stream = gatewayProvider.sendMessage(text,
              model: _selectedModel,
              conversationHistory: conversationHistory,
              sessionKey: streamSessionKey);
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
          stream = gatewayProvider.sendMessage(text,
              model: _selectedModel,
              conversationHistory: conversationHistory,
              sessionKey: streamSessionKey);
        }
      }
      await for (final chunk in stream) {
        if (!mounted) break;

        if (!loggedFirstAssistantChunk &&
            chunk.trim().isNotEmpty &&
            !chunk.startsWith('\x00TOOL_')) {
          loggedFirstAssistantChunk = true;
          _addDiagnosticLog(
              'First assistant chunk after ${sendStopwatch.elapsedMilliseconds}ms');
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
                  ChatToolEvent(type: 'tool_use', name: name, input: input));
            } catch (_) {
              toolEvents.add(ChatToolEvent(type: 'tool_use', name: name));
            }
            setState(() {
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
            toolEvents.add(ChatToolEvent(
                type: 'tool_result', name: name, result: resultJson));
            setState(() {
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
                'Cleared stale gateway session binding after gateway error.');
          }
          setState(() {
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

        setState(() {
          _isThinking = false; // Stopped thinking, started talking
          // _speechIntensity is driven ONLY by _tts.onStart/onComplete — not chunk arrival

          // Check for (gesture: name) in bot response
          if (chunk.contains('(gesture:')) {
            final match = RegExp(r'\(gesture:\s*(\w+)\)').firstMatch(chunk);
            if (match != null) {
              _currentGesture = match.group(1);
            }
          }

          _messages.last = ChatMessage(
            text: fullResponse,
            isUser: false,
            thinkContent: thinkBuffer.isNotEmpty ? thinkBuffer : null,
            toolEvents:
                toolEvents.isNotEmpty ? List.unmodifiable(toolEvents) : null,
          );
        });
        _syncOverlayState();
        _scrollToBottom();
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
      }
    }

    if (mounted) {
      setState(() {
        _isThinking = false;
        _isGenerating = false;
        // Do NOT reset _speechIntensity here — TTS queue may still be draining.
        // onComplete fires when the last sentence finishes and will close the mouth.
        _syncOverlayState();

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
      });
      _addDiagnosticLog(
          'Generation completed. Total length: ${fullResponse.length}');
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
        PreferencesService().continuousMode &&
        !_tts.isSpeaking &&
        _ttsQueue.isEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isGenerating && !_isListening) _startListening();
      });
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
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
          anyConfigured = providers.any((p) =>
              p is Map &&
              (p['configured'] == true || p['configured'] == 'true'));
        }
      }
      _talkRelaySupported = activeProvider.isNotEmpty || anyConfigured;
      if (_talkRelaySupported) {
        _addDiagnosticLog(
            'Talk relay available (provider=${activeProvider.isEmpty ? 'auto' : activeProvider}).');
      } else {
        _addDiagnosticLog(
            'Talk relay unsupported: no configured realtime provider; using native talk fallback.');
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
      final session = await gatewayProvider.createTalkRealtimeRelaySession();
      final sessionId = (session['sessionId'] ??
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
    final relayId = (payload['relaySessionId'] ??
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
      _talkRelayReady = false;
      if (_isTalkRelayCaptureActive) {
        unawaited(_stopTalkRelayCapture().then((_) {
          if (!mounted) return;
          setState(() => _isListening = false);
          _syncOverlayState();
        }));
      }
      _addDiagnosticLog('Talk relay error: $message');
      return;
    }
    if (eventType == 'close') {
      final reason = payload['reason']?.toString() ?? 'unknown';
      _talkRelayReady = false;
      if (_isTalkRelayCaptureActive) {
        unawaited(_stopTalkRelayCapture().then((_) {
          if (!mounted) return;
          setState(() => _isListening = false);
          _syncOverlayState();
        }));
      }
      _talkRelaySessionId = null;
      _talkAssistantMessageIndex = null;
      _talkAssistantTextBuffer = '';
      _addDiagnosticLog('Talk relay closed ($reason).');
      return;
    }
    if (eventType != 'transcript') return;

    final role = payload['role']?.toString() ?? '';
    final text = payload['text']?.toString() ?? '';
    final isFinal = payload['final'] == true;

    if (role == 'user') {
      if (isFinal && text.trim().isNotEmpty) {
        setState(() {
          _messages.add(ChatMessage(text: text.trim(), isUser: true));
          _messages.add(ChatMessage(text: '', isUser: false));
          _talkAssistantMessageIndex = _messages.length - 1;
          _talkAssistantTextBuffer = '';
          _isGenerating = true;
          _isThinking = true;
        });
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
          _messages
              .add(ChatMessage(text: _talkAssistantTextBuffer, isUser: false));
          _talkAssistantMessageIndex = _messages.length - 1;
        }
      });
      _scrollToBottom();

      if (isFinal) {
        _flushTtsQueue();
        setState(() {
          _isGenerating = false;
          _isThinking = false;
        });
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
    final gatewayProvider =
        Provider.of<GatewayProvider>(context, listen: false);
    final audioBase64 = base64Encode(chunk);
    _talkAudioSendChain = _talkAudioSendChain.then((_) async {
      await gatewayProvider.appendTalkSessionAudio(
        sessionId: sessionId,
        audioBase64: audioBase64,
      );
    }).catchError((e) {
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

  /// Start recording — called when user begins holding the mic orb (hold-to-record UX).
  Future<void> _startListening() async {
    if (_isListening) return;

    if (!await _audioRecorder.hasPermission()) {
      _addDiagnosticLog('Microphone permission denied.');
      return;
    }
    if (!mounted) return;

    final gatewayProvider =
        Provider.of<GatewayProvider>(context, listen: false);
    try {
      await _startTalkRelayCapture(gatewayProvider);
      setState(() => _isListening = true);
      _syncOverlayState();
      _addDiagnosticLog(
          'Voice relay recording started (talk.session realtime).');
      return;
    } catch (e) {
      _isTalkRelayCaptureActive = false;
      _addDiagnosticLog(
          'Talk relay capture unavailable, using fallback STT: $e');
    }

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/stt_recording.m4a';
    const config = RecordConfig(); // default 44.1kHz, AAC
    await _audioRecorder.start(config, path: path);
    setState(() => _isListening = true);
    _syncOverlayState();
    _addDiagnosticLog('Voice recording started (fallback STT mode).');
  }

  /// Stop recording and transcribe — called when user releases the mic orb.
  Future<void> _stopListening() async {
    if (!_isListening) return;

    if (_isTalkRelayCaptureActive) {
      await _stopTalkRelayCapture();
      setState(() => _isListening = false);
      _syncOverlayState();
      _addDiagnosticLog(
          'Voice relay recording stopped; waiting for transcript...');
      return;
    }

    final path = await _audioRecorder.stop();
    setState(() => _isListening = false);
    _syncOverlayState();
    _addDiagnosticLog('Voice recording stopped.');

    if (path != null) {
      _addDiagnosticLog('Transcribing audio at $path...');
      final text = await GatewayService().transcribeAudio(File(path));
      if (text != null && text.isNotEmpty) {
        _textController.text = text;
        _addDiagnosticLog('Gateway STT recognized: $text');
        _handleSubmit(text);
      } else {
        _addDiagnosticLog('Gateway STT failed or returned empty text.');
      }
    }
  }

  /// Tell native Android to update the PiP RemoteAction icon based on listening state.
  void _updatePipMicIcon() {
    if (_isPipMode) {
      _pipChannel.invokeMethod('updatePipMicState', _isListening);
    }
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
        title:
            const Text('Rename Agent', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.2))),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.statusGreen)),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
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
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.white.withValues(alpha: 0.05)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_note,
                              color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text('EDIT',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
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
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/app_icon_official.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                            Colors.white, BlendMode.srcIn),
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
                                      _selectedModel)
                                  .toUpperCase(),
                          style: TextStyle(
                            color: ModelProviderCatalog.isLocalModelId(
                                    _selectedModel)
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
        ..._availableAvatars.map((avatar) => PopupMenuItem<String>(
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
            )),

        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'avatar_forge',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: Colors.purpleAccent.shade100, size: 18),
              const SizedBox(width: 10),
              Text('Avatar Forge',
                  style: TextStyle(
                      color: Colors.purpleAccent.shade100,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white38, size: 12),
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
          value: _localLlmState.status == LocalLlmStatus.idle ||
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
                                              _selectedModel)
                                          ? 'ACTIVE · ON-DEVICE'
                                          : 'ON-DEVICE (READY)')))),
                      style: TextStyle(
                        color: _localLlmState.status == LocalLlmStatus.starting
                            ? Colors.amber
                            : (!_localChatModeEnabled
                                ? AppColors.statusAmber
                                : (ModelProviderCatalog.isLocalModelId(
                                        _selectedModel)
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
                        strokeWidth: 2, color: Colors.amber))
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
            child: const Text('AGENTS',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
          ),
          ..._dynamicAgents.map((agent) => PopupMenuItem<String>(
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
                        agent.isDefault
                            ? '${agent.name} (default)'
                            : agent.name,
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
              )),
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
              const Text('CLOUD',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
            ],
          ),
        ),
        ..._availableModels.map((model) => PopupMenuItem<String>(
              value: 'model:$model',
              height: 44,
              child: Row(
                children: [
                  Icon(
                    model == _selectedModel
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: model == _selectedModel
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
                          ModelProviderCatalog.labelForModel(model),
                          style: TextStyle(
                            color: model == _selectedModel
                                ? Colors.white
                                : Colors.white70,
                            fontSize: 13,
                            fontWeight: model == _selectedModel
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          ModelProviderCatalog.routeLabelForModel(model),
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
            )),

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
                Text('Agent Intelligence',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    ).then((value) async {
      if (value == null) return;
      if (!context.mounted) return;

      if (value == 'setup_local_llm') {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const LocalLlmScreen(),
        ));
        _loadPreferences();
      } else if (value == 'avatar_forge') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const AvatarForgePage(),
        ));
      } else if (value.toString().startsWith('model:')) {
        final prefs = PreferencesService();
        await prefs.init();
        final model = ModelProviderCatalog.canonicalizeModelId(
            value.toString().substring(6));
        if (ModelProviderCatalog.isLocalModelId(model) &&
            !prefs.localChatModeEnabled) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Local NDK chat is OFF. Enable it in Local LLM page first.',
              ),
            ),
          );
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const LocalLlmScreen(),
          ));
          _loadPreferences();
          return;
        }
        final isNowCloud = !ModelProviderCatalog.isLocalModelId(model);
        final catalogModel = ModelProviderCatalog.modelById(model);
        if (isNowCloud && catalogModel != null) {
          final hasCredential = await GatewayService()
              .hasProviderCredential(catalogModel.providerId);
          if (!context.mounted) return;
          if (!hasCredential) {
            final provider =
                ModelProviderCatalog.providerById(catalogModel.providerId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Add a ${provider?.label ?? catalogModel.providerId} API key in Settings before using ${catalogModel.label}.',
                ),
              ),
            );
            return;
          }
        }
        setState(() {
          _selectedModel = model;
          if (!ModelProviderCatalog.isLocalModelId(model)) {
            _cloudFallbackModel = model;
          }
        });
        prefs.configuredModel = model;
        if (!ModelProviderCatalog.isLocalModelId(model)) {
          prefs.lastCloudModel = model;
        }

        final needsReload = ModelProviderCatalog.isLocalModelId(model);
        if (needsReload) {
          final modelId = model.split('/').last;
          final localModel =
              LocalLlmService().catalog.firstWhere((m) => m.id == modelId);
          LocalLlmService().activateModel(localModel);
        } else {
          unawaited(GatewayService().persistModel(model));
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
    final mode = PreferencesService().wakeWordMode;
    if (mode == 'off') return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mode == 'foreground') NativeBridge.stopHotword();
    } else if (state == AppLifecycleState.resumed) {
      NativeBridge.startHotword();
    }
  }

  @override
  void dispose() {
    final wakeMode = PreferencesService().wakeWordMode;
    if (wakeMode != 'off') NativeBridge.stopHotword();
    WidgetsBinding.instance.removeObserver(this);
    AgentSkillServer.instance.onAvatarChanged = null;
    AgentSkillServer.instance.onGesturePlayed = null;
    AgentSkillServer.instance.onEmotionSet = null;
    // Clear static callbacks set during initState so they don't reference this
    // widget after it's been disposed — prevents stale closure crashes.
    CameraCapability.onSnapTaken = null;
    CanvasCapability.onVisibilityChanged = null;
    CanvasCapability.onSnapshotTaken = null;
    HologramService.instance.dismiss();
    CanvasCapability().clearController();
    CanvasCapability.onActivationRequested = null;
    _hotwordSub?.cancel();
    _localLlmSub?.cancel();
    _gatewaySub?.cancel();
    _skillsSub?.cancel();
    _talkAudioStreamSub?.cancel();
    _talkEventSub?.cancel();
    final talkSessionId = _talkRelaySessionId;
    if (talkSessionId != null && talkSessionId.isNotEmpty) {
      unawaited(
          GatewayService().closeTalkSession(talkSessionId).catchError((_) {}));
    }
    _glowController.dispose();
    _tts.stop();
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
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatDate(session.updatedAt),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white38, size: 18),
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
                            value: 'rename', child: Text('Rename')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // --- Dynamic Sizing for Floating Mic ---
    const double collapsedSize = 96.0;
    // Adaptive height: Capped to avoid keyboard overflow on small screens
    final keyboardHeight =
        MediaQuery.of(context).viewInsets.bottom.clamp(0.0, size.height * 0.7);
    final keyboardVisible = keyboardHeight > 0;
    final rawMaxExpandedHeight =
        size.height - keyboardHeight - (keyboardVisible ? 78.0 : 190.0);
    final maxExpandedHeight =
        rawMaxExpandedHeight < 260.0 ? 260.0 : rawMaxExpandedHeight;
    final targetExpandedHeight = size.height * (keyboardVisible ? 0.52 : 0.46);
    final double barWidth = _isChatCollapsed
        ? collapsedSize
        : (size.width - 20).clamp(320.0, 620.0);
    final double barHeight = _isChatCollapsed
        ? collapsedSize
        : targetExpandedHeight.clamp(260.0, maxExpandedHeight);
    final chatTrayBottomMargin = _isChatCollapsed ? 40.0 : 10.0;
    final chatTrayTopY =
        size.height - keyboardHeight - chatTrayBottomMargin - barHeight;
    final voiceOrbY = _isChatCollapsed
        ? (size.height - keyboardHeight - chatTrayBottomMargin - 132.0)
            .clamp(size.height * 0.46, size.height - keyboardHeight - 118.0)
            .toDouble()
        : (chatTrayTopY - 18.0).clamp(112.0, size.height - 96.0).toDouble();

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
                        alpha: 0.05), // Reduced alpha for more transparency
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
                        horizontal: 10, vertical: 6), // Reduced padding
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/app_icon_official.svg',
                          width: 14,
                          height: 14,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
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
                                        _selectedModel)
                                    ? '${_selectedAvatar.split('.').first.toUpperCase()} · ${_localLlmState.status == LocalLlmStatus.starting ? 'STARTING...' : 'LOCAL ON-DEVICE'}'
                                    : '${_selectedAvatar.split('.').first.toUpperCase()} · ${ModelProviderCatalog.labelForModel(_selectedModel).toUpperCase()}',
                                style: TextStyle(
                                  color: ModelProviderCatalog.isLocalModelId(
                                          _selectedModel)
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
                        const Icon(Icons.expand_more_rounded,
                            color: Colors.white38, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined,
                      color: Colors.white70),
                  onPressed: () async {
                    await _persistence.createSession();
                    _loadChatHistory();
                  },
                  tooltip: 'New Chat',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Colors.white70),
                  tooltip: 'More',
                  color: Colors.black
                      .withValues(alpha: 0.7), // Deeper frosted alpha
                  constraints: const BoxConstraints(maxWidth: 210),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  onSelected: (value) async {
                    if (value == 'pip') {
                      try {
                        await const MethodChannel('vrm/pip_mode')
                            .invokeMethod('enterPictureInPictureMode');
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('PiP not supported: $e')),
                        );
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      height: 40,
                      child: Builder(
                        builder: (ctx2) => ListTile(
                          dense: true,
                          visualDensity:
                              const VisualDensity(horizontal: -4, vertical: -4),
                          leading: Icon(
                            Icons.picture_in_picture_alt,
                            color: Colors.white70,
                            size: 20,
                          ),
                          title: const Text('Picture in Picture',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          onTap: () async {
                            Navigator.pop(ctx2);
                            try {
                              await const MethodChannel('vrm/pip_mode')
                                  .invokeMethod('enterPictureInPictureMode');
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
                          visualDensity:
                              const VisualDensity(horizontal: -4, vertical: -4),
                          leading: const Icon(Icons.history,
                              color: Colors.white70, size: 20),
                          title: const Text('Chat Sessions',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
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
                                color: Colors.white70, fontSize: 13),
                          ),
                          onTap: () {
                            Navigator.pop(ctx2);
                            setState(
                                () => _showDiagnostics = !_showDiagnostics);
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
                  colors: [
                    const Color(0xFF0D1B2A),
                    Colors.black,
                  ],
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
                  minWidth: size.width,
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
                    bottom: MediaQuery.of(context).viewInsets.bottom),
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
                        left: _isChatCollapsed ? 0 : 10,
                        right: _isChatCollapsed ? 0 : 10,
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
                            _isChatCollapsed ? collapsedSize / 2 : 30),
                        border: Border.all(
                          color: _isChatCollapsed
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.statusGreen.withValues(alpha: 0.18),
                          width: _isChatCollapsed ? 2 : 1.2,
                        ),
                        boxShadow: [
                          if (!_isChatCollapsed)
                            BoxShadow(
                              color:
                                  AppColors.statusGreen.withValues(alpha: 0.08),
                              blurRadius: 28,
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
                                  alpha: 0.1 * _glowController.value),
                              blurRadius: 20 * _glowController.value,
                              spreadRadius: 10 * _glowController.value,
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            _isChatCollapsed ? collapsedSize / 2 : 30),
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
                                            Colors.white
                                                .withValues(alpha: 0.18),
                                            AppColors.statusGreen
                                                .withValues(alpha: 0.46),
                                            Colors.white
                                                .withValues(alpha: 0.18),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(999),
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
                                        Colors.transparent
                                      ],
                                      stops: [0.0, 0.05, 0.95, 1.0],
                                    ).createShader(bounds),
                                    blendMode: BlendMode.dstIn,
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 4, 16, 12),
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
                                    vertical: _isChatCollapsed ? 0 : 10),
                                decoration: BoxDecoration(
                                  color: _isChatCollapsed
                                      ? Colors.transparent
                                      : Colors.black.withValues(alpha: 0.22),
                                  border: _isChatCollapsed
                                      ? null
                                      : Border(
                                          top: BorderSide(
                                              color: AppColors.statusGreen
                                                  .withValues(alpha: 0.10))),
                                ),
                                child: SafeArea(
                                  top: false,
                                  bottom:
                                      false, // Ensure container is flush against the bottom edge
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // ──────────────────────────────────────────
                                      // 2026 UX: hold-to-record orb
                                      //   onLongPressStart  → start listening
                                      //   onLongPressEnd    → stop  listening
                                      //   onVerticalDragEnd(up) → expand chat
                                      //   onTap → no-op (reserved for hold)
                                      // ──────────────────────────────────────────
                                      if (_isChatCollapsed)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            // Tap on collapsed orb = show hint
                                            ScaffoldMessenger.of(context)
                                                .clearSnackBars();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: const Row(
                                                  children: [
                                                    Icon(Icons.info_outline,
                                                        color: Colors.white70,
                                                        size: 16),
                                                    SizedBox(width: 8),
                                                    Text(
                                                        'Hold to talk  ·  Swipe ↑ to expand',
                                                        style: TextStyle(
                                                            fontSize: 13)),
                                                  ],
                                                ),
                                                backgroundColor:
                                                    const Color(0xFF1A1A2E),
                                                duration:
                                                    const Duration(seconds: 2),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
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
                                            if ((details.primaryVelocity ?? 0) <
                                                -400) {
                                              setState(() =>
                                                  _isChatCollapsed = false);
                                            }
                                          },
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AnimatedBuilder(
                                                animation: _glowController,
                                                builder: (_, __) =>
                                                    Transform.translate(
                                                  offset: Offset(
                                                      0,
                                                      -3 *
                                                          _glowController
                                                              .value),
                                                  child: Icon(
                                                    Icons
                                                        .keyboard_arrow_up_rounded,
                                                    color: Colors.white.withValues(
                                                        alpha: 0.25 +
                                                            0.2 *
                                                                _glowController
                                                                    .value),
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                              AnimatedBuilder(
                                                animation: _glowController,
                                                builder: (context, child) {
                                                  return AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 300),
                                                    width: 64,
                                                    height: 64,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: _isListening
                                                          ? AppColors
                                                              .statusGreen
                                                              .withValues(
                                                                  alpha: 0.1 *
                                                                      _glowController
                                                                          .value)
                                                          : Colors.transparent,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Icon(
                                                      _isListening
                                                          ? Icons.mic
                                                          : Icons.mic_none,
                                                      color: _isListening
                                                          ? AppColors
                                                              .statusGreen
                                                          : Colors.white70,
                                                      size: 36,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (!_isChatCollapsed) ...[
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Image preview strip — shown when a photo is pending
                                              if (_pendingImageBase64 != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 6),
                                                  child: Stack(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        child: Image.memory(
                                                          base64Decode(
                                                              _pendingImageBase64!),
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
                                                                      null),
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                      alpha:
                                                                          0.6),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: const Icon(
                                                                Icons.close,
                                                                color: Colors
                                                                    .white,
                                                                size: 16),
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
                                                      Icons.more_horiz_rounded,
                                                      color: (_pendingImageBase64 !=
                                                                  null ||
                                                              _pendingVideoBase64 !=
                                                                  null)
                                                          ? AppColors
                                                              .statusGreen
                                                          : Colors.white54,
                                                      size: 22,
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                            minWidth: 36,
                                                            minHeight: 36),
                                                    color: Colors.black
                                                        .withValues(alpha: 0.9),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      side: BorderSide(
                                                          color: Colors.white
                                                              .withValues(
                                                                  alpha: 0.1),
                                                          width: 0.8),
                                                    ),
                                                    onSelected: (value) {
                                                      if (value == 'camera') {
                                                        _takePicture();
                                                      }
                                                      if (value == 'video') {
                                                        _showVideoDurationPicker();
                                                      }
                                                      if (value == 'voice') {
                                                        _toggleListening();
                                                      }
                                                      if (value == 'clear') {
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
                                                                    ? Icons.mic
                                                                    : Icons
                                                                        .mic_none,
                                                                color: _isListening
                                                                    ? AppColors
                                                                        .statusGreen
                                                                    : Colors
                                                                        .white70,
                                                                size: 20),
                                                            const SizedBox(
                                                                width: 12),
                                                            Text(
                                                                _isListening
                                                                    ? 'Stop Listening'
                                                                    : 'Voice Input',
                                                                style: TextStyle(
                                                                    color: _isListening
                                                                        ? AppColors
                                                                            .statusGreen
                                                                        : Colors
                                                                            .white,
                                                                    fontSize:
                                                                        13)),
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
                                                                size: 20),
                                                            const SizedBox(
                                                                width: 12),
                                                            const Text(
                                                                'Take Photo',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        13)),
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
                                                                size: 20),
                                                            const SizedBox(
                                                                width: 12),
                                                            const Text(
                                                                'Record Clip',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        13)),
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
                                                                  size: 20),
                                                              SizedBox(
                                                                  width: 12),
                                                              Text(
                                                                  'Clear Attachment',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .redAccent,
                                                                      fontSize:
                                                                          13)),
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
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 15),
                                                      onChanged: (_) =>
                                                          setState(() {}),
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: _pendingVideoBase64 !=
                                                                null
                                                            ? "Ask about the video..."
                                                            : _pendingImageBase64 !=
                                                                    null
                                                                ? "Ask about the image..."
                                                                : "Message your companion...",
                                                        hintStyle: TextStyle(
                                                            color: Colors.white
                                                                .withValues(
                                                                    alpha:
                                                                        0.40),
                                                            fontSize: 14),
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(30),
                                                          borderSide: BorderSide(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.1),
                                                              width: 0.8),
                                                        ),
                                                        enabledBorder:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(30),
                                                          borderSide: BorderSide(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.1),
                                                              width: 0.8),
                                                        ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(30),
                                                          borderSide:
                                                              const BorderSide(
                                                                  color: AppColors
                                                                      .statusGreen,
                                                                  width: 1.0),
                                                        ),
                                                        filled: true,
                                                        fillColor: Colors.black
                                                            .withValues(
                                                                alpha: 0.20),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 16,
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
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                AppColors.statusGreen
                                                    .withValues(alpha: 0.95),
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.82),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.statusGreen
                                                    .withValues(alpha: 0.22),
                                                blurRadius: 18,
                                                spreadRadius: -2,
                                              ),
                                            ],
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.send_rounded,
                                                color: Colors.white, size: 20),
                                            onPressed: () => _handleSubmit(
                                                _textController.text),
                                          ),
                                        ),
                                      ],
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
              bottom: barHeight + (_isChatCollapsed ? 40 : 0) + 16,
              height: size.height * 0.45,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5),
                  ],
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _canvasController!),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            final controller = _canvasController;
                            setState(() {
                              _canvasVisible = false;
                              _canvasController = null;
                            });
                            CanvasCapability().clearController();
                            unawaited(controller
                                    ?.loadRequest(Uri.parse('about:blank'))
                                    .catchError((_) {}) ??
                                Future<void>.value());
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
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
              isSpeaking: TtsService().isSpeaking,
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
                  bottom:
                      BorderSide(color: Colors.white.withValues(alpha: 0.1))),
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
                      icon: const Icon(Icons.copy_rounded,
                          size: 18, color: Colors.white70),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _diagnosticLogs.join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Logs copied to clipboard')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.white70),
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

  Future<Map<String, dynamic>> _loadGatewayVoiceControlData() async {
    final gatewayProvider =
        Provider.of<GatewayProvider>(context, listen: false);
    final prefs = PreferencesService();
    await prefs.init();

    var activeProvider = '';
    final providers = <Map<String, dynamic>>[];
    final personas = <Map<String, dynamic>>[];
    var activePersona = prefs.currentTtsPersona.trim().toLowerCase();
    final selectedVoiceId = prefs.gatewayVoiceId.trim();
    final voices = <String>[];
    var talkConfigured = false;
    var talkStatusMessage =
        'Gateway Talk provider is not configured for speech output yet.';

    try {
      final providersFrame = await gatewayProvider.getTtsProviders();
      final rawProviders = providersFrame['providers'];
      if (rawProviders is List) {
        for (final item in rawProviders) {
          if (item is Map) {
            providers.add(Map<String, dynamic>.from(item));
          }
        }
      }
      activeProvider = (providersFrame['active'] ?? '').toString().trim();
      for (final provider in providers) {
        final id = provider['id']?.toString().trim() ?? '';
        if (id == activeProvider && provider['configured'] == true) {
          talkConfigured = true;
          talkStatusMessage = 'Gateway Talk is configured.';
          break;
        }
      }
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
        final speechProviders = speech['providers'];
        if (speechProviders is List) {
          Map<String, dynamic>? activeEntry;
          for (final item in speechProviders) {
            if (item is! Map) continue;
            final mapped = Map<String, dynamic>.from(item);
            final id = mapped['id']?.toString() ?? '';
            if (id == activeProvider) {
              activeEntry = mapped;
              break;
            }
          }
          if (activeEntry == null && speechProviders.isNotEmpty) {
            final fallback = speechProviders.first;
            if (fallback is Map) {
              activeEntry = Map<String, dynamic>.from(fallback);
              activeProvider = activeEntry['id']?.toString() ?? activeProvider;
            }
          }

          final rawVoices = activeEntry?['voices'];
          if (activeEntry?['configured'] == true) {
            talkConfigured = true;
            talkStatusMessage = 'Gateway Talk is configured.';
          } else if (activeEntry != null) {
            talkConfigured = false;
            talkStatusMessage =
                'Selected Gateway Talk provider is not configured.';
          }
          if (rawVoices is List) {
            for (final voice in rawVoices) {
              final v = voice.toString().trim();
              if (v.isNotEmpty) voices.add(v);
            }
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
          final v = voice.toString().trim();
          if (v.isNotEmpty) voices.add(v);
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
      'talkConfigured': talkConfigured,
      'talkStatusMessage': talkStatusMessage,
    };
  }

  Future<void> _applyGatewayPersona(String personaId) async {
    final gatewayProvider =
        Provider.of<GatewayProvider>(context, listen: false);
    await gatewayProvider.setTtsPersona(personaId);
    final prefs = PreferencesService();
    await prefs.init();
    prefs.currentTtsPersona = personaId.trim().toLowerCase().isEmpty
        ? 'default'
        : personaId.trim().toLowerCase();
  }

  Future<void> _applyGatewayProvider(String providerId) async {
    final gatewayProvider =
        Provider.of<GatewayProvider>(context, listen: false);
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
                    final providers = (data['providers'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        const <Map<String, dynamic>>[];
                    final personas = (data['personas'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        const <Map<String, dynamic>>[];
                    final voices = (data['voices'] as List?)?.cast<String>() ??
                        const <String>[];

                    String activeProvider =
                        (data['activeProvider'] ?? '').toString();
                    String activePersona =
                        (data['activePersona'] ?? 'default').toString();
                    String selectedVoiceId =
                        (data['selectedVoiceId'] ?? '').toString();
                    final talkConfigured = data['talkConfigured'] == true;
                    final talkStatusMessage = (data['talkStatusMessage'] ??
                            'Gateway Talk provider is not configured.')
                        .toString();
                    final speed = PreferencesService().ttsSpeed;

                    if (activeProvider.isEmpty && providers.isNotEmpty) {
                      activeProvider = providers.first['id']?.toString() ?? '';
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
                              color: Colors.white.withValues(alpha: 0.2)),
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
                                  const Icon(Icons.record_voice_over_rounded,
                                      color: Colors.cyanAccent, size: 20),
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
                                    icon: const Icon(Icons.close,
                                        color: Colors.white54, size: 20),
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
                                  )),
                                )
                              else ...[
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
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color:
                                          Colors.white.withValues(alpha: 0.05),
                                      border: Border.all(
                                          color: Colors.white12, width: 1),
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
                                          final label = provider['name']
                                                  ?.toString() ??
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
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color:
                                          Colors.white.withValues(alpha: 0.05),
                                      border: Border.all(
                                          color: Colors.white12, width: 1),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedVoiceId.isEmpty
                                            ? null
                                            : selectedVoiceId,
                                        hint: const Text('Provider default',
                                            style: TextStyle(
                                                color: Colors.white54)),
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF17181F),
                                        items: voices
                                            .map((voice) => DropdownMenuItem(
                                                  value: voice,
                                                  child: Text(voice),
                                                ))
                                            .toList(),
                                        onChanged: (value) async {
                                          if (value == null) return;
                                          final prefs = PreferencesService();
                                          await prefs.init();
                                          prefs.gatewayVoiceId = value;
                                          setModalState(() {
                                            data['selectedVoiceId'] = value;
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
                                          duration:
                                              const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.cyanAccent
                                                    .withValues(alpha: 0.2)
                                                : Colors.white
                                                    .withValues(alpha: 0.05),
                                            borderRadius:
                                                BorderRadius.circular(14),
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
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (talkConfigured
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent)
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: (talkConfigured
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent)
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    talkStatusMessage,
                                    style: TextStyle(
                                      color: talkConfigured
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    const Icon(Icons.speed,
                                        color: Colors.white54, size: 16),
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
                                                    listen: false);
                                            final result = await gatewayProvider
                                                .speakTextViaTalk(
                                              'Voice check complete.',
                                            );
                                            if (!context.mounted) return;
                                            if (!result.played &&
                                                result.errorMessage != null) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      result.errorMessage!),
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
                CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
  }
}
