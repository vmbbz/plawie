import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../services/tts_service.dart';
import '../services/native_bridge.dart';
import '../services/video_capture_service.dart';
import '../utils/video_frame_extractor.dart';
import '../models/agent_info.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
import '../main.dart';
import 'avatar_forge_page.dart';
import '../services/skills_service.dart';
import '../services/local_llm_service.dart';
import '../services/gateway_service.dart';
import '../services/agent_skill_server.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/capabilities/camera_capability.dart';
import '../services/capabilities/canvas_capability.dart';
import 'management/local_llm_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
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
  
  // Voice Pipeline (Piper TTS / Local VITS)
  final TtsService _tts = TtsService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String? _currentGesture;
  String? _lastUserMessage;
  
  // Streaming TTS state
  String _ttsSentenceBuffer = '';
  bool _isTtsSpeaking = false;
  final List<String> _ttsQueue = [];
  
  String _selectedAvatar = 'default_avatar.vrm';
  String _agentName = 'Plawie';
  String _selectedModel = 'google/gemini-3.1-pro-preview';
  // Cloud model to fall back to when a local model (NDK or Ollama) stops.
  // Set at load time from onboarding provider; updated when user picks a cloud model.
  String _cloudFallbackModel = 'google/gemini-3.1-pro-preview';

  // Vision / image attachment state
  String? _pendingImageBase64;   // base64 of photo waiting to be sent
  bool _isTakingPhoto = false;   // true while camera shutter is in flight

  // Video attachment state
  String? _pendingVideoBase64;   // base64 of recorded clip waiting to be sent
  bool _isRecordingVideo = false;

  // Static cloud model list — augmented at runtime with gateway agents
  List<String> _availableModels = [
    'google/gemini-3.1-pro-preview',
    'anthropic/claude-opus-4.6',
    'openai/gpt-4o',
    'groq/llama-3.1-405b',
  ];

  // Ollama cloud models — available whenever Ollama Hub is running.
  // Route identically to local Ollama models (same `ollama/` prefix); the
  // Ollama daemon proxies inference to ollama.com when it sees a :cloud tag.
  static const _kCloudOllamaModels = [
    'ollama/qwen3-coder:480b-cloud',
    'ollama/gpt-oss:120b-cloud',
    'ollama/gpt-oss:20b-cloud',
    'ollama/deepseek-v3.1:671b-cloud',
    'ollama/kimi-k2.5:cloud',
    'ollama/minimax-m2.7:cloud',
    'ollama/glm-5:cloud',
  ];

  // Dynamic agents fetched from the gateway
  List<AgentInfo> _dynamicAgents = [];

  final List<String> _availableAvatars = [
    'gemini.vrm',
    'boruto.vrm',
    'default_avatar.vrm',
  ];
  
  bool _isTtsDownloaded = false;
  double _downloadProgress = 0.0;
  bool _isDownloadingTts = false;
  bool _hasShownTtsFallbackPrompt = false; // Track if we've alerted about the fallback

  // Wake word subscription
  StreamSubscription<String>? _hotwordSub;
  // Auto-sync model when local LLM starts/stops
  StreamSubscription<LocalLlmState>? _localLlmSub;
  LocalLlmState _localLlmState = const LocalLlmState();
  // Ollama Hub model sync — surfaces 'ollama/*' models in the dropdown
  StreamSubscription<GatewayState>? _gatewaySub;
  // Transitional model-switching states
  bool _isOllamaAutoStarting = false; // true while hub auto-starts on model selection
  bool _ollamaStopFlash = false;      // true for 1.8 s after switching away from ollama/
  // Skills event bus — tracks executing/executed/error states
  StreamSubscription? _skillsSub;

  // Latest camera.snap base64 captured by AI tool call — attached to bot message after stream ends
  String? _pendingAiSnapBase64;

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
    // Wire AgentSkillServer callbacks so agent-controlled avatar changes
    // reflect immediately in the live chat UI (singleton shares state with main()).
    AgentSkillServer.instance.onAvatarChanged = (file) {
      if (mounted) setState(() => _selectedAvatar = file);
    };
    AgentSkillServer.instance.onGesturePlayed = (gesture) {
      if (mounted) setState(() => _currentGesture = gesture);
    };
    AgentSkillServer.instance.onEmotionSet = (_) {}; // handled by avatar_scene.html
    // When the AI calls camera.snap, store the result so we can show it inline in chat
    CameraCapability.onSnapTaken = (b64, mime) {
      _pendingAiSnapBase64 = b64;
    };

    // Set up canvas WebView controller and wire it to CanvasCapability
    _canvasController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('about:blank'));
    CanvasCapability().setController(_canvasController!);
    CanvasCapability.onVisibilityChanged = (visible) {
      if (mounted) setState(() => _canvasVisible = visible);
    };
    CanvasCapability.onSnapshotTaken = (b64, mime) {
      _pendingAiSnapBase64 = b64;
    };
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadPreferences();
    _localLlmSub = LocalLlmService().stateStream.listen((llmState) {
      if (!mounted) return;
      setState(() => _localLlmState = llmState);
      
      if (llmState.status == LocalLlmStatus.ready && llmState.activeModelId != null) {
        final localModel = 'local-llm/${llmState.activeModelId}';
        if (_selectedModel != localModel) {
          setState(() => _selectedModel = localModel);
          PreferencesService().configuredModel = localModel;
        }
      } else if (llmState.status == LocalLlmStatus.idle &&
                 _selectedModel.startsWith('local-llm/')) {
        setState(() => _selectedModel = _cloudFallbackModel);
        PreferencesService().configuredModel = _cloudFallbackModel;
      }
    });
    // React to Ollama Hub start/stop and agent-arena model changes.
    _gatewaySub = GatewayService().stateStream.listen((gwState) {
      if (!mounted) return;

      // If agent arena (or any other writer) changed prefs.configuredModel,
      // sync it to the UI — but only if Ollama is running for ollama/ models.
      final prefsModel = PreferencesService().configuredModel;
      if (prefsModel != null && prefsModel.isNotEmpty &&
          prefsModel != _selectedModel) {
        final isOllama = prefsModel.startsWith('ollama/');
        if (!isOllama || gwState.isOllamaRunning) {
          setState(() => _selectedModel = prefsModel);
        }
      }

      if (!gwState.isOllamaRunning) {
        // Ollama stopped/crashed — remove local hub models but keep :cloud models always.
        final wasOnLocalHub = _selectedModel.startsWith('ollama/') && !_selectedModel.contains(':cloud');
        setState(() {
          _availableModels.removeWhere((m) => m.startsWith('ollama/') && !m.contains(':cloud'));
          _isOllamaAutoStarting = false;
          if (wasOnLocalHub) {
            _selectedModel = _cloudFallbackModel;
            PreferencesService().configuredModel = _cloudFallbackModel;
          }
          // Re-ensure cloud models stay present
          for (final m in _kCloudOllamaModels) {
            if (!_availableModels.contains(m)) _availableModels.add(m);
          }
        });
        return;
      }

      // Ollama running — clear auto-starting flag, merge local hub + cloud models.
      setState(() {
        _isOllamaAutoStarting = false;
        _availableModels.removeWhere((m) => m.startsWith('ollama/') && !m.contains(':cloud'));
        if (gwState.ollamaHubModels.isNotEmpty) {
          _availableModels.addAll(
            gwState.ollamaHubModels
                .where((m) => !m.endsWith(':cloud'))
                .map((m) => 'ollama/$m'),
          );
        }
        // Always ensure cloud models are present
        for (final m in _kCloudOllamaModels) {
          if (!_availableModels.contains(m)) _availableModels.add(m);
        }
      });
    });
    _initVoiceParams();
    _loadChatHistory();
    _checkTtsModel();
    // Fetch gateway agents after first frame — gateway may not be ready yet
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDynamicAgents());

    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPModeChanged') {
        final bool isPip = call.arguments as bool;
        if (mounted) {
          // When LEAVING PIP, stop microphone if it was listening
          if (!isPip && _isListening) {
            _addDiagnosticLog('Exiting PIP — stopping mic to reset state');
            await _speechToText.stop();
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
        setState(() {
          _isThinking = true;
          _currentGesture = 'pose'; // Elegant pose while calculating
        });
      } else if (event.type == SkillsEventType.executed || event.type == SkillsEventType.error) {
        _addDiagnosticLog('Skill finished: ${event.skillId}');
        setState(() {
          _isThinking = false;
          _currentGesture = 'ready'; // Drop back to ready
        });
      }
    });
    
    // Listen for background download progress
    _tts.onDownloadProgress = (p) {
      if (mounted) {
        setState(() {
          _downloadProgress = p;
          if (p >= 1.0) {
            _isDownloadingTts = false;
            _isTtsDownloaded = true;
            // Persist so future visits skip the download prompt
            final prefs = PreferencesService();
            prefs.ttsPiperDownloaded = true;
            prefs.ttsEngine = 'piper';
          } else if (p > 0) {
            _isDownloadingTts = true;
          }
        });
      }
    };
  }

  Future<void> _checkTtsModel() async {
    final prefs = PreferencesService();
    // Fast path: trust persisted flag so navigation doesn't re-prompt every visit
    if (prefs.ttsPiperDownloaded) {
      if (mounted) setState(() => _isTtsDownloaded = true);
      _initPiperModelInBackground();
      return;
    }
    // Slow path: verify filesystem (first run or after reinstall)
    final downloaded = await _tts.isModelDownloaded();
    if (downloaded) {
      // Persist so we skip filesystem check next time
      prefs.ttsPiperDownloaded = true;
      _initPiperModelInBackground();
    }
    if (mounted) setState(() => _isTtsDownloaded = downloaded);
  }

  void _initPiperModelInBackground() {
    _tts.init(forceDownload: false).then((_) {
      _addDiagnosticLog('Piper TTS model loaded into memory');
      if (mounted && !_tts.isReady) {
        _addDiagnosticLog('WARNING: Piper model files exist but failed to init');
      }
    }).catchError((e) {
      _addDiagnosticLog('Piper model init error: $e');
    });
  }

  void _showTtsDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Download Voice Data'),
        content: const Text('To enable voice, a one-time 67MB high-quality voice model (Piper Amy) needs to be downloaded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startPiperDownload();
            },
            child: const Text('Download Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _startPiperDownload() async {
    if (_isDownloadingTts) return;

    setState(() {
      _isDownloadingTts = true;
      _downloadProgress = 0.0;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      _addDiagnosticLog('Starting Piper TTS background download...');
      await _tts.init(forceDownload: true);

      if (mounted) {
        // Persist download flag — won't re-prompt on next navigation
        final prefs = PreferencesService();
        prefs.ttsPiperDownloaded = true;
        prefs.ttsEngine = 'piper';

        setState(() {
          _isDownloadingTts = false;
          _isTtsDownloaded = true;
          _downloadProgress = 1.0;
        });

        // Verify piper actually loaded (sherpa-onnx may fail silently)
        if (!_tts.isReady) {
          final ok = await _tts.reinitializePiper();
          if (!ok && mounted) {
            messenger.showSnackBar(const SnackBar(
              content: Text('Voice model downloaded but could not start — using device voice.'),
              backgroundColor: Colors.orange,
            ));
            return;
          }
        }

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Natural voice ready! Piper TTS is now active.'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
    } catch (e) {
      _addDiagnosticLog('Download Error: $e');
      if (mounted) {
        setState(() => _isDownloadingTts = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString().split(':').last.trim()}'),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _startPiperDownload(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadChatHistory() async {
    await _persistence.init();
    final history = await _persistence.loadMessages();
    final prefs = PreferencesService();
    await prefs.init();
    _agentName = prefs.agentName;

    if (mounted) {
      setState(() {
        _messages.clear();
        if (history.isNotEmpty) {
          _messages.addAll(history);
        } else {
          _messages.add(ChatMessage(text: "Hello! I'm $_agentName, your fully local AI companion. How can I help you today?", isUser: false));
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
    if (mounted) {
      setState(() {
        _agentName = prefs.agentName;
        _selectedAvatar = prefs.selectedAvatar;

        // Derive the cloud fallback from the onboarding-chosen provider.
        final provider = prefs.apiProvider;
        if (provider != null && provider.isNotEmpty &&
            provider != 'ollama' && !provider.startsWith('local')) {
          _cloudFallbackModel = GatewayService().getModelForProvider(provider);
        }

        // OLLAMA CLOUD models are always visible regardless of hub state.
        for (final m in _kCloudOllamaModels) {
          if (!_availableModels.contains(m)) _availableModels.add(m);
        }

        // Seed any already-synced Ollama Hub models from current gateway state.
        // The stateStream listener only fires on NEW events; at open time we must
        // read the current snapshot so the dropdown is populated immediately.
        final gwState = GatewayService().state;
        if (gwState.ollamaHubModels.isNotEmpty) {
          _availableModels.removeWhere((m) => m.startsWith('ollama/') && !m.contains(':cloud'));
          _availableModels.addAll(
            gwState.ollamaHubModels.where((m) => !m.endsWith(':cloud')).map((m) => 'ollama/$m'),
          );
        } else if (gwState.isOllamaRunning) {
          // Ollama is running but ollamaHubModels is empty — this happens when
          // the gateway was restarted (stop() now preserves isOllamaRunning but
          // sync hasn't re-fired yet). Kick off a background sync so _gatewaySub
          // receives the state event with the model list shortly after.
          GatewayService().syncLocalModelsWithOllama();
        }

        // Load the user's configured model (from setup or settings).
        final configured = prefs.configuredModel;
        if (configured != null && configured.isNotEmpty) {
          final ollamaOk = gwState.isOllamaRunning;
          final isOllama = configured.startsWith('ollama/');
          final isLocal = configured.startsWith('local-llm/');
          final isCloudOllama = isOllama && configured.contains(':cloud');
          if (_availableModels.contains(configured) || isLocal ||
              (isOllama && ollamaOk) || isCloudOllama) {
            _selectedModel = configured;
          } else if (isOllama && !ollamaOk && !isCloudOllama) {
            // Local hub model but Ollama not running — don't restore stale model.
            _selectedModel = _cloudFallbackModel;
          }
        }
      });
    }
  }

  void _addDiagnosticLog(String log) {
    if (!mounted) return;
    setState(() {
      _diagnosticLogs.add('[${DateTime.now().toLocal().toString().split(' ')[1]}] $log');
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

  Future<void> _initVoiceParams() async {
    // Only initialize the shell STT, don't pre-emptively init Piper (it hangs)
    await _speechToText.initialize();

    // Subscribe to wake word events from HotwordService (no-op if service not running)
    _hotwordSub = NativeBridge.hotwordEvents.listen((event) {
      if (event == 'wake_word_detected' && mounted && !_isGenerating && !_isListening) {
        _addDiagnosticLog('Wake word "Plawie" detected — activating mic');
        _startListening();
      }
    }, onError: (_) {/* service not running — ignore */});

    _tts.onStart = () {
      if (mounted) {
        setState(() {
          _speechIntensity = 0.8;
          // No gesture change — visemes drive mouth movement; body stays idle
        });
        
        // If falling back to Native TTS (Piper preferred but not loaded), prompt user
        if (_tts.isUsingFallback && !_hasShownTtsFallbackPrompt) {
          _hasShownTtsFallbackPrompt = true;
          if (PreferencesService().ttsPiperDownloaded) {
            // Model was downloaded but sherpa failed to init — offer re-init
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Using device voice — natural voice engine failed to start.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(label: 'Retry', onPressed: () async {
                final ok = await _tts.reinitializePiper();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Natural voice ready!' : 'Could not start — using device voice.'),
                    backgroundColor: ok ? AppColors.statusGreen : Colors.orange,
                  ));
                }
              }),
            ));
          } else {
            _showTtsDownloadDialog();
          }
        }
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
    t = t.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
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
    if (_isTtsSpeaking || _ttsQueue.isEmpty) return;
    _isTtsSpeaking = true;
    final sentence = _ttsQueue.removeAt(0);
    try {
      await _tts.speak(sentence);
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
            const SnackBar(content: Text('No camera available on this device.')),
          );
        }
        return;
      }
      final controller = CameraController(cameras.first, ResolutionPreset.medium);
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
      final bytes = await VideoCaptureService.recordClip(durationMs: durationMs);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video capture failed. Check camera permissions.')),
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
            const Text('Video Duration', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...options.entries.map((e) => ListTile(
              title: Text(e.key, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, e.value),
            )),
          ],
        ),
      ),
    );
    if (chosen != null) await _recordVideo(durationMs: chosen);
  }

  // ---------------------------------------------------------------------------

  Future<void> _handleSubmit(String text) async {
    if ((text.trim().isEmpty && _pendingImageBase64 == null && _pendingVideoBase64 == null) || _isGenerating) return;

    // Stop any in-progress TTS and clear the queue so the previous response
    // doesn't keep playing while the user has already sent a new message.
    _tts.stop();
    _ttsQueue.clear();
    _ttsSentenceBuffer = '';
    _isTtsSpeaking = false;
    setState(() => _speechIntensity = 0.0);

    // Capture and clear pending attachments before any async gaps
    final imageBase64 = _pendingImageBase64;
    final videoBase64 = _pendingVideoBase64;
    _textController.clear();
    setState(() {
      _pendingImageBase64 = null;
      _pendingVideoBase64 = null;
      _messages.add(ChatMessage(
        text: text.trim().isEmpty && videoBase64 != null ? '🎬 Video clip' : text,
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
    setState(() => _lastUserMessage = text); // Trigger JS keyword listener

    // Add empty placeholder for the assistant reply
    setState(() {
      _messages.add(ChatMessage(text: '', isUser: false));
    });

    String fullResponse = '';
    final List<ChatToolEvent> toolEvents = [];
    // <think> block parser state — strips Qwen/DeepSeek reasoning tokens from the
    // main response and accumulates them separately for the collapsible Reasoning UI.
    // Uses a raw-buffer approach so tags split across chunks are handled correctly.
    String rawBuffer = '';      // all tokens accumulated, including <think> tags
    String thinkBuffer = '';    // text inside <think>…</think>

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
      final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);
      final localLlm = LocalLlmService();

      // Route based on attachment type & model
      final Stream<String> stream;
      final isLocalModelSelected = _selectedModel.startsWith('local-llm/');

      if (isLocalModelSelected) {
        // --- PATH A: Native Local LLM (fllama bypass) ---
        if (videoBase64 != null) {
          if (localLlm.isVisionReady) {
            _addDiagnosticLog('Local Video path: offline frame analysis');
            stream = () async* {
              yield 'Extracting video frames…';
              final mp4Bytes = base64Decode(videoBase64);
              final frames = await VideoFrameExtractor.extractFrames(mp4Bytes, fps: 1, maxFrames: 8);
              if (frames.isEmpty) {
                yield '⚠️ Could not extract frames. Make sure ffmpeg is installed in PRoot '
                    '(`apt-get install -y ffmpeg` in a terminal session).';
                return;
              }
              yield* localLlm.analyseVideoFrames(frames, text.trim().isEmpty ? 'Describe what is happening.' : text);
            }().cast<String>();
          } else {
            stream = Stream.value('🎥 Video captured, but no local vision model is active. Please start a multimodal model like Qwen2-VL.');
          }
        } else if (imageBase64 != null) {
          if (localLlm.isVisionReady) {
            _addDiagnosticLog('Local Vision path: local multimodal model active');
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
          final conversationHistory = _messages
              .take(_messages.length - 1)
              .where((m) => m.text.isNotEmpty)
              .map((m) => <String, dynamic>{
                    'role': m.isUser ? 'user' : 'assistant',
                    'content': m.text,
                  })
              .toList();
          stream = gatewayProvider.sendMessage(text,
              model: _selectedModel, conversationHistory: conversationHistory);
        }
      } else {
        // --- PATH B: Cloud / Integrated Node Gateway ---
        if (videoBase64 != null) {
          _addDiagnosticLog('Cloud Video path: sending MP4 via gateway');
          stream = gatewayProvider.sendCloudVideoMessage(
            text.trim().isEmpty ? 'Describe what is happening in this video.' : text,
            videoBase64,
          );
        } else if (imageBase64 != null) {
          _addDiagnosticLog('Cloud Vision path: sending Image via gateway');
          stream = gatewayProvider.sendCloudImageMessage(
            text.trim().isEmpty ? 'Describe what you see in this image.' : text,
            imageBase64,
          );
        } else {
          final conversationHistory = _messages
              .take(_messages.length - 1)
              .where((m) => m.text.isNotEmpty)
              .map((m) => <String, dynamic>{
                    'role': m.isUser ? 'user' : 'assistant',
                    'content': m.text,
                  })
              .toList();
          stream = gatewayProvider.sendMessage(text,
              model: _selectedModel, conversationHistory: conversationHistory);
        }
      }
      await for (final chunk in stream) {
        if (!mounted) break;

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
              toolEvents.add(ChatToolEvent(type: 'tool_use', name: name, input: input));
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
            toolEvents.add(ChatToolEvent(type: 'tool_result', name: name, result: resultJson));
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
        if (chunk.contains('[Error]') || chunk.contains('rate limit reached') || chunk.contains('API error')) {
          _addDiagnosticLog('Caught API Error in stream: $chunk');
          final errorMsg = chunk.replaceAll('[Error]', '').trim();
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
            toolEvents: toolEvents.isNotEmpty ? List.unmodifiable(toolEvents) : null,
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
          fullResponse = '⚠️ No response received. The model may still be loading — please try again in a moment.';
          _messages.last = ChatMessage(text: fullResponse, isUser: false);
        }

        // If the AI called camera.snap during this turn, attach the image to the bot reply
        final snapImage = _pendingAiSnapBase64;
        if (snapImage != null && _messages.isNotEmpty) {
          _messages.last = ChatMessage(
            text: _messages.last.text,
            isUser: false,
            thinkContent: _messages.last.thinkContent,
            toolEvents: _messages.last.toolEvents,
            imageBase64: snapImage,
            imageMimeType: 'image/jpeg',
          );
          _pendingAiSnapBase64 = null;
        }
      });
      _addDiagnosticLog('Generation completed. Total length: ${fullResponse.length}');
    }
    // Persist the completed assistant turn (including error fallback messages).
    // The earlier _saveChatHistory() at send-time only captures the user message;
    // the assistant placeholder is added after that point and never gets saved
    // without this call — causing the last assistant turn to vanish on navigation.
    _saveChatHistory();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  /// Start STT — called when user begins holding the mic orb (hold-to-record UX).
  Future<void> _startListening() async {
    if (_isListening) return;
    bool available = await _speechToText.initialize();
    if (available) {
      setState(() => _isListening = true);
      _syncOverlayState();
      _addDiagnosticLog('Voice listening started.');
      final silenceSecs = PreferencesService().silenceTimeoutSeconds;
      await _speechToText.listen(
        onResult: (result) {
          _textController.text = result.recognizedWords;
          if (result.hasConfidenceRating &&
              result.confidence > 0 &&
              result.recognizedWords.isNotEmpty &&
              !_speechToText.isListening) {
            _addDiagnosticLog('Voice recognized: ${result.recognizedWords}');
            _handleSubmit(result.recognizedWords);
          }
        },
        pauseFor: Duration(seconds: silenceSecs),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
        ),
      );
    } else {
      _addDiagnosticLog('Voice recognition unavailable on device.');
    }
  }

  /// Stop STT — called when user releases the mic orb (hold-to-record UX).
  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speechToText.stop();
    setState(() => _isListening = false);
    _syncOverlayState();
    _addDiagnosticLog('Voice listening stopped.');
  }

  /// Tell native Android to update the PiP RemoteAction icon based on listening state.
  void _updatePipMicIcon() {
    if (_isPipMode) {
      _pipChannel.invokeMethod('updatePipMicState', _isListening);
    }
  }

  // FIX: Decoupled cinematic effect from typing to prevent zoom jumps 
  bool get _isCinematic => _isGenerating || _isListening;

  void _nextAvatar() {
    int currentIndex = _availableAvatars.indexOf(_selectedAvatar);
    if (currentIndex == -1) currentIndex = 0;
    int nextIndex = (currentIndex + 1) % _availableAvatars.length;
    setState(() {
      _selectedAvatar = _availableAvatars[nextIndex];
      _isReady = false;
    });
    PreferencesService().selectedAvatar = _selectedAvatar;
    _syncOverlayState();
    _addDiagnosticLog('Swapped and persisted avatar: $_selectedAvatar');
  }

  void _prevAvatar() {
    int currentIndex = _availableAvatars.indexOf(_selectedAvatar);
    if (currentIndex == -1) currentIndex = 0;
    int prevIndex = (currentIndex - 1 + _availableAvatars.length) % _availableAvatars.length;
    setState(() {
      _selectedAvatar = _availableAvatars[prevIndex];
      _isReady = false;
    });
    PreferencesService().selectedAvatar = _selectedAvatar;
    _syncOverlayState();
    _addDiagnosticLog('Swapped and persisted avatar: $_selectedAvatar');
  }

  void _nextModel() {
    int currentIndex = _availableModels.indexOf(_selectedModel);
    int nextIndex = (currentIndex + 1) % _availableModels.length;
    final nextModel = _availableModels[nextIndex];
    setState(() => _selectedModel = nextModel);
    PreferencesService().configuredModel = nextModel;
    _addDiagnosticLog('Swapped and persisted AI model: $nextModel');
  }

  void _prevModel() {
    int currentIndex = _availableModels.indexOf(_selectedModel);
    int prevIndex = (currentIndex - 1 + _availableModels.length) % _availableModels.length;
    setState(() => _selectedModel = _availableModels[prevIndex]);
    PreferencesService().configuredModel = _availableModels[prevIndex];
    _addDiagnosticLog('Swapped and persisted AI model: $_availableModels[prevIndex]');
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _agentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Agent', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.statusGreen)),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      color: AppColors.statusGreen.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600, // Thinner
                      letterSpacing: 2.0,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showEditNameDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_note, color: AppColors.statusGreen, size: 14),
                          SizedBox(width: 4),
                          Text('EDIT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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
                      color: AppColors.statusGreen.withValues(alpha: 0.25), // Soft single shade
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/app_icon_official.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                          _selectedModel.startsWith('local-llm/')
                            ? 'LOCAL · ON-DEVICE'
                            : (_selectedModel.startsWith('ollama/') && _selectedModel.contains(':cloud'))
                              ? 'CLOUD · OLLAMA'
                              : _selectedModel.startsWith('ollama/')
                                ? 'LOCAL · HUB'
                                : _selectedModel.split('/').last.toUpperCase(),
                          style: TextStyle(
                            color: _selectedModel.startsWith('local-llm/')
                              ? const Color(0xFF00E5AA)
                              : (_selectedModel.startsWith('ollama/') && _selectedModel.contains(':cloud'))
                                ? const Color(0xFFAB47BC)
                                : _selectedModel.startsWith('ollama/')
                                  ? const Color(0xFF00C8FF)
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
                avatar == _selectedAvatar ? Icons.check_circle : Icons.circle_outlined,
                color: avatar == _selectedAvatar ? AppColors.statusGreen : Colors.white38,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                avatar.split('.').first,
                style: TextStyle(
                  color: avatar == _selectedAvatar ? Colors.white : Colors.white70,
                  fontWeight: avatar == _selectedAvatar ? FontWeight.bold : FontWeight.normal,
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
              Icon(Icons.face, color: AppColors.statusGreen, size: 18),
              const SizedBox(width: 10),
              const Text('Avatar Forge', style: TextStyle(color: AppColors.statusGreen, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
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
          value: _localLlmState.status == LocalLlmStatus.idle 
              ? 'setup_local_llm' 
              : 'model:local-llm/${_localLlmState.activeModelId ?? 'llama-server'}',
          height: 48,
          child: Row(
            children: [
              Icon(
                _localLlmState.status == LocalLlmStatus.idle 
                    ? Icons.install_mobile 
                    : (_selectedModel.startsWith('local-llm/') ? Icons.memory_rounded : Icons.phone_android),
                color: _selectedModel.startsWith('local-llm/') 
                    ? const Color(0xFF00E5AA) 
                    : (_localLlmState.status == LocalLlmStatus.starting ? Colors.amber : (_localLlmState.status == LocalLlmStatus.idle ? AppColors.statusAmber : Colors.white38)),
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
                        color: _selectedModel.startsWith('local-llm/') 
                            ? Colors.white 
                            : (_localLlmState.status == LocalLlmStatus.idle ? AppColors.statusAmber : Colors.white70),
                        fontSize: 13,
                        fontWeight: _selectedModel.startsWith('local-llm/') ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      _localLlmState.status == LocalLlmStatus.starting
                          ? 'WAKING UP...'
                          : (_localLlmState.status == LocalLlmStatus.error
                              ? 'ERROR: CHECK SETUP'
                              : (_localLlmState.status == LocalLlmStatus.idle 
                                ? 'Download free model' 
                                : (_selectedModel.startsWith('local-llm/') ? 'ACTIVE · ON-DEVICE' : 'ON-DEVICE (READY)'))),
                      style: TextStyle(
                        color: _localLlmState.status == LocalLlmStatus.starting
                            ? Colors.amber
                            : (_selectedModel.startsWith('local-llm/') 
                                ? const Color(0xFF00E5AA) 
                                : (_localLlmState.status == LocalLlmStatus.idle ? AppColors.statusAmber.withValues(alpha: 0.6) : Colors.white38)),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_localLlmState.status == LocalLlmStatus.starting)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
              else if (_selectedModel.startsWith('local-llm/'))
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
            child: const Text('AGENTS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          ),
          ..._dynamicAgents.map((agent) => PopupMenuItem<String>(
            value: 'model:${agent.modelKey}',
            height: 36,
            child: Row(
              children: [
                Icon(
                  agent.modelKey == _selectedModel ? Icons.check_circle : Icons.smart_toy_outlined,
                  color: agent.modelKey == _selectedModel ? Colors.tealAccent : Colors.white38,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    agent.isDefault ? '${agent.name} (default)' : agent.name,
                    style: TextStyle(
                      color: agent.modelKey == _selectedModel ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: agent.modelKey == _selectedModel ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
        ],
        // ── LOCAL HUB section (on-device Ollama models) ───────────────────
        ...() {
          final hubModels = _availableModels
              .where((m) => m.startsWith('ollama/') && !m.contains(':cloud'))
              .toList();
          if (hubModels.isEmpty) return <PopupMenuEntry<dynamic>>[];
          return <PopupMenuEntry<dynamic>>[
            const PopupMenuDivider(),
            PopupMenuItem<dynamic>(
              enabled: false,
              height: 20,
              child: Row(
                children: [
                  const Icon(Icons.lan_rounded, color: Color(0xFF00C8FF), size: 12),
                  const SizedBox(width: 6),
                  const Text('LOCAL HUB', style: TextStyle(color: Color(0xFF00C8FF), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                ],
              ),
            ),
            ...hubModels.map((model) {
              final isSelected = model == _selectedModel;
              final displayName = model.replaceFirst('ollama/', '');
              return PopupMenuItem<dynamic>(
                value: 'model:$model',
                height: 44,
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.lan_rounded,
                      color: isSelected ? const Color(0xFF00C8FF) : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'LOCAL · HUB',
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF00C8FF) : Colors.white38,
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
              );
            }),
          ];
        }(),
        // ── OLLAMA CLOUD section (ollama.com server-side models) ───────────
        ...() {
          final cloudHub = _availableModels
              .where((m) => m.startsWith('ollama/') && m.contains(':cloud'))
              .toList();
          if (cloudHub.isEmpty) return <PopupMenuEntry<dynamic>>[];
          final hubInstalled = GatewayService().state.isOllamaRunning ||
              _isOllamaAutoStarting;
          return <PopupMenuEntry<dynamic>>[
            const PopupMenuDivider(),
            PopupMenuItem<dynamic>(
              enabled: false,
              height: 20,
              child: Row(
                children: [
                  const Icon(Icons.cloud_queue_rounded, color: Color(0xFFAB47BC), size: 12),
                  const SizedBox(width: 6),
                  const Text('OLLAMA CLOUD', style: TextStyle(color: Color(0xFFAB47BC), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  if (!hubInstalled) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('AUTO-START', style: TextStyle(color: Colors.amber, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                  ],
                ],
              ),
            ),
            ...cloudHub.map((model) {
              final isSelected = model == _selectedModel;
              final displayName = '☁ ' + model.split('/').last.replaceAll(':cloud', '').toUpperCase();
              return PopupMenuItem<dynamic>(
                value: 'model:$model',
                height: 44,
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.cloud_queue_rounded,
                      color: isSelected ? const Color(0xFFAB47BC) : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'FREE · NO DOWNLOAD',
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFAB47BC) : Colors.white38,
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
              );
            }),
          ];
        }(),
        // ── CLOUD section (gateway cloud providers) ────────────────────────
        const PopupMenuDivider(),
        PopupMenuItem<dynamic>(
          enabled: false,
          height: 20,
          child: Row(
            children: [
              const Icon(Icons.cloud_outlined, color: Colors.white38, size: 12),
              const SizedBox(width: 6),
              const Text('CLOUD', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ],
          ),
        ),
        ..._availableModels
            .where((m) => !m.startsWith('ollama/'))
            .map((model) => PopupMenuItem<String>(
          value: 'model:$model',
          height: 36,
          child: Row(
            children: [
              Icon(
                model == _selectedModel ? Icons.check_circle : Icons.circle_outlined,
                color: model == _selectedModel ? Colors.purpleAccent : Colors.white38,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  model,
                  style: TextStyle(
                    color: model == _selectedModel ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: model == _selectedModel ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
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
          value: 'tts_status',
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (_isTtsDownloaded ? AppColors.statusGreen : (_isDownloadingTts ? Colors.orange : Colors.blue)).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isTtsDownloaded ? Icons.volume_up : (_isDownloadingTts ? Icons.downloading : Icons.cloud_download),
                    color: _isTtsDownloaded ? AppColors.statusGreen : (_isDownloadingTts ? Colors.orange : Colors.blue),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isTtsDownloaded ? 'Piper Voice Engine' : (_isDownloadingTts ? 'Downloading...' : 'Voice Engine'),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _isTtsDownloaded 
                          ? 'Active & Ready' 
                          : (_isDownloadingTts 
                              ? '${(_downloadProgress * 100).toInt()}% complete' 
                              : 'High-quality TTS required'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isTtsDownloaded && !_isDownloadingTts)
                   const Icon(Icons.arrow_circle_right_outlined, color: Colors.blue, size: 20),
              ],
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      
      if (value == 'tts_status' && !_isTtsDownloaded && !_isDownloadingTts) {
        _showTtsDownloadDialog();
      } else if (value == 'setup_local_llm') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const LocalLlmScreen(),
        ));
      } else if (value == 'avatar_forge') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const AvatarForgePage(),
        ));
      } else if (value.toString().startsWith('model:')) {
        final model = value.toString().substring(6);
        final isNowOllama = model.startsWith('ollama/');
        final isNowCloud = !model.startsWith('ollama/') && !model.startsWith('local-llm/');
        setState(() {
          _selectedModel = model;
          if (!model.startsWith('local-llm/') && !model.startsWith('ollama/')) {
            _cloudFallbackModel = model;
          }
        });
        PreferencesService().configuredModel = model;

        // Auto-start Ollama Hub if switching to any ollama/ model while hub is off
        if (isNowOllama && !GatewayService().state.isOllamaRunning) {
          setState(() => _isOllamaAutoStarting = true);
          unawaited(GatewayService().startInternalOllama());
        }

        // Auto-stop Ollama Hub when switching to a pure cloud model (saves memory)
        if (isNowCloud && GatewayService().state.isOllamaRunning) {
          unawaited(GatewayService().stopInternalOllama());
          setState(() => _ollamaStopFlash = true);
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted) setState(() => _ollamaStopFlash = false);
          });
        }

        final needsReload = model.startsWith('local-llm');
        if (needsReload) {
          final modelId = model.split('/').last;
          final localModel = LocalLlmService().catalog.firstWhere((m) => m.id == modelId);
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
  void dispose() {
    AgentSkillServer.instance.onAvatarChanged = null;
    AgentSkillServer.instance.onGesturePlayed = null;
    AgentSkillServer.instance.onEmotionSet = null;
    // Clear static callbacks set during initState so they don't reference this
    // widget after it's been disposed — prevents stale closure crashes.
    CameraCapability.onSnapTaken = null;
    CanvasCapability.onVisibilityChanged = null;
    CanvasCapability.onSnapshotTaken = null;
    CanvasCapability().clearController();
    _hotwordSub?.cancel();
    _localLlmSub?.cancel();
    _gatewaySub?.cancel();
    _skillsSub?.cancel();
    _glowController.dispose();
    _tts.stop();
    _speechToText.stop();
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
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatDate(session.updatedAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
                      onSelected: (action) async {
                        if (action == 'delete') {
                          await _persistence.deleteSession(session.id);
                          _loadChatHistory();
                        } else if (action == 'rename') {
                          _renameSession(session);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'rename', child: Text('Rename')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await _persistence.renameSession(session.id, name);
                setState(() {});
              }
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
    // Removed the -24 margin to make chat container flush with screen edges
    final double barWidth = _isChatCollapsed ? collapsedSize : size.width;
    
    // Adaptive height: Capped to avoid keyboard overflow on small screens
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double barHeight = _isChatCollapsed 
        ? collapsedSize 
        : (size.height * 0.6).clamp(320.0, size.height - keyboardHeight - (keyboardHeight > 0 ? 80 : 160));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isPipMode ? Colors.transparent : null,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false, // Prevents VRM aspect-ratio scaling bounds from squishing
      endDrawer: _buildSessionDrawer(),
      appBar: _isPipMode ? null : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              color: Colors.black.withValues(alpha: 0.05), // Reduced alpha for more transparency
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Reduced padding
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   SvgPicture.asset(
                    'assets/app_icon_official.svg',
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                            fontWeight: FontWeight.w600, // Thinner, cleaner font weight
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _selectedModel.startsWith('local-llm/')
                            ? '${_selectedAvatar.split('.').first.toUpperCase()} · ${_localLlmState.status == LocalLlmStatus.starting ? 'STARTING...' : 'LOCAL ON-DEVICE'}'
                            : _selectedModel.startsWith('ollama/')
                              ? '${_selectedAvatar.split('.').first.toUpperCase()} · ${_isOllamaAutoStarting ? 'STARTING HUB...' : _selectedModel.contains(':cloud') ? 'OLLAMA CLOUD' : 'LOCAL HUB'}'
                              : '${_selectedAvatar.split('.').first.toUpperCase()} · ${_ollamaStopFlash ? 'HUB OFF' : _selectedModel.split('/').last.toUpperCase()}',
                          style: TextStyle(
                            color: _selectedModel.startsWith('local-llm/')
                              ? (_localLlmState.status == LocalLlmStatus.starting ? Colors.amber : const Color(0xFF00E5AA))
                              : _selectedModel.startsWith('ollama/')
                                ? (_isOllamaAutoStarting ? Colors.amber : _selectedModel.contains(':cloud') ? const Color(0xFFAB47BC) : const Color(0xFF00C8FF))
                                : (_ollamaStopFlash ? Colors.white38 : Colors.white.withValues(alpha: 0.5)),
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
                  const Icon(Icons.expand_more_rounded, color: Colors.white38, size: 16),
                ],
              ),
            ),
          ),
        ),
      centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white70),
            onPressed: () async {
              await _persistence.createSession();
              _loadChatHistory();
            },
            tooltip: 'New Chat',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            tooltip: 'More',
            color: Colors.black.withValues(alpha: 0.7), // Deeper frosted alpha
            constraints: const BoxConstraints(maxWidth: 210),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            onSelected: (value) async {
              if (value == 'pip') {
                try {
                  await const MethodChannel('vrm/pip_mode').invokeMethod('enterPictureInPictureMode');
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PiP not supported: $e')),
                    );
                  }
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
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                    leading: Icon(
                      Icons.picture_in_picture_alt,
                      color: Colors.white70,
                      size: 20,
                    ),
                    title: const Text('Picture in Picture',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    onTap: () async {
                      Navigator.pop(ctx2);
                      try {
                        await const MethodChannel('vrm/pip_mode').invokeMethod('enterPictureInPictureMode');
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
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                    leading: const Icon(Icons.history, color: Colors.white70, size: 20),
                    title: const Text('Chat Sessions',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                      _showDiagnostics ? Icons.bug_report : Icons.bug_report_outlined,
                      color: _showDiagnostics ? AppColors.statusGreen : Colors.white54,
                      size: 20,
                    ),
                    title: Text(
                      _showDiagnostics ? 'Hide Diagnostics' : 'Show Diagnostics',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    onTap: () {
                      Navigator.pop(ctx2);
                      setState(() => _showDiagnostics = !_showDiagnostics);
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
          if (!_isPipMode)
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
                ..scale(MediaQuery.of(context).viewInsets.bottom > 0 ? 1.04 : 1.0),
              transformAlignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: size.width, 
                  maxWidth: size.width.clamp(0.0, 600.0),
                  maxHeight: size.height,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300), // Swifter transition
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: VrmAvatarWidget(
                    key: ValueKey(_selectedAvatar),
                    isThinking: _isThinking,
                    speechIntensity: _speechIntensity,
                    glowIntensity: _speechIntensity,
                    avatarFileName: _selectedAvatar,
                    isCinematic: _isCinematic,
                    isPip: _isPipMode,
                    gesture: _currentGesture,
                    userMessage: _lastUserMessage,
                    onLog: (log) {
                      if (log == 'READY') {
                        setState(() => _isReady = true);
                      }
                      _addDiagnosticLog(log);
                    },
                  ),
                ),
              ),
            ),
          ),

          // 4. Glassmorphic Chat Area
          if (!_isPipMode)
            Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // --- PIPER TTS GLOBAL PROGRESS OVERLAY ---
                  if (_isDownloadingTts)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 100, 20, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.downloading, color: Colors.blue, size: 16),
                              const SizedBox(width: 10),
                              Text(
                                _downloadProgress > 0.82 ? 'Extracting Voice...' : 'Downloading Voice Engine',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Text(
                                '${(_downloadProgress * 100).toInt()}%',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              color: Colors.blue,
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 5. Epic Floating Chat/Mic Bar

                  if (!_isChatCollapsed) const Spacer(flex: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    width: barWidth,
                    height: barHeight,
                    margin: EdgeInsets.only(bottom: _isChatCollapsed ? 40 : 0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(_isChatCollapsed ? collapsedSize / 2 : 24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: _isChatCollapsed ? 0.2 : 0.12),
                        width: _isChatCollapsed ? 2 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isListening 
                              ? AppColors.statusGreen.withValues(alpha: 0.2) 
                              : Colors.black.withValues(alpha: 0.3),
                          blurRadius: _isChatCollapsed ? 30 : 20,
                          spreadRadius: _isChatCollapsed ? 5 : -2,
                        ),
                        if (_isListening && _isChatCollapsed)
                          BoxShadow(
                            color: AppColors.statusGreen.withValues(alpha: 0.1 * _glowController.value),
                            blurRadius: 20 * _glowController.value,
                            spreadRadius: 10 * _glowController.value,
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_isChatCollapsed ? collapsedSize / 2 : 32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                                  } else if (details.primaryVelocity! < -400) {
                                    setState(() => _isChatCollapsed = false);
                                  }
                                },
                                child: Container(
                                  height: 32, // Larger vertical hit area
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                                    stops: [0.0, 0.05, 0.95, 1.0],
                                  ).createShader(bounds),
                                  blendMode: BlendMode.dstIn,
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(20),
                                    itemCount: _messages.length,
                                    itemBuilder: (context, i) {
                                      final msg = _messages[i];
                                      return ChatBubble(
                                        message: msg,
                                        isThinking: i == _messages.length - 1 && _isThinking,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: _isChatCollapsed ? 0 : 16, 
                                vertical: _isChatCollapsed ? 0 : 12
                              ),
                              decoration: BoxDecoration(
                                color: _isChatCollapsed ? Colors.transparent : Colors.black.withValues(alpha: 0.4),
                                border: _isChatCollapsed 
                                  ? null 
                                  : Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                              ),
                              child: SafeArea(
                                top: false,
                                bottom: false, // Ensure container is flush against the bottom edge
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
                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.info_outline, color: Colors.white70, size: 16),
                                                  SizedBox(width: 8),
                                                  Text('Hold to talk  ·  Swipe ↑ to expand', style: TextStyle(fontSize: 13)),
                                                ],
                                              ),
                                              backgroundColor: const Color(0xFF1A1A2E),
                                              duration: const Duration(seconds: 2),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                          if ((details.primaryVelocity ?? 0) < -400) {
                                            setState(() => _isChatCollapsed = false);
                                          }
                                        },
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AnimatedBuilder(
                                              animation: _glowController,
                                              builder: (_, __) => Transform.translate(
                                                offset: Offset(0, -3 * _glowController.value),
                                                child: Icon(
                                                  Icons.keyboard_arrow_up_rounded,
                                                  color: Colors.white.withValues(alpha: 0.25 + 0.2 * _glowController.value),
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                            AnimatedBuilder(
                                              animation: _glowController,
                                              builder: (context, child) {
                                                return AnimatedContainer(
                                                  duration: const Duration(milliseconds: 300),
                                                  width: 64,
                                                  height: 64,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _isListening 
                                                        ? AppColors.statusGreen.withValues(alpha: 0.1 * _glowController.value)
                                                        : Colors.transparent,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    _isListening ? Icons.mic : Icons.mic_none,
                                                    color: _isListening ? AppColors.statusGreen : Colors.white70,
                                                    size: 36,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (!_isChatCollapsed) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Image preview strip — shown when a photo is pending
                                            if (_pendingImageBase64 != null)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Stack(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(10),
                                                      child: Image.memory(
                                                        base64Decode(_pendingImageBase64!),
                                                        height: 80,
                                                        width: 80,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 2,
                                                      right: 2,
                                                      child: GestureDetector(
                                                        onTap: () => setState(() => _pendingImageBase64 = null),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withValues(alpha: 0.6),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
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
                                                    color: (_pendingImageBase64 != null || _pendingVideoBase64 != null)
                                                        ? AppColors.statusGreen
                                                        : Colors.white54,
                                                    size: 22,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                  color: Colors.black.withValues(alpha: 0.9),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.8),
                                                  ),
                                                  onSelected: (value) {
                                                    if (value == 'camera') _takePicture();
                                                    if (value == 'video') _showVideoDurationPicker();
                                                    if (value == 'voice') _toggleListening();
                                                    if (value == 'clear') {
                                                      setState(() {
                                                        _pendingImageBase64 = null;
                                                        _pendingVideoBase64 = null;
                                                      });
                                                    }
                                                  },
                                                  itemBuilder: (ctx) => [
                                                    PopupMenuItem(
                                                      value: 'voice',
                                                      child: Row(
                                                        children: [
                                                          Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? AppColors.statusGreen : Colors.white70, size: 20),
                                                          const SizedBox(width: 12),
                                                          Text(_isListening ? 'Stop Listening' : 'Voice Input', style: TextStyle(color: _isListening ? AppColors.statusGreen : Colors.white, fontSize: 13)),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'camera',
                                                      child: Row(
                                                        children: [
                                                          Icon(_isTakingPhoto ? Icons.hourglass_empty : Icons.camera_alt_outlined, color: Colors.white70, size: 20),
                                                          const SizedBox(width: 12),
                                                          const Text('Take Photo', style: TextStyle(color: Colors.white, fontSize: 13)),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'video',
                                                      child: Row(
                                                        children: [
                                                          Icon(_isRecordingVideo ? Icons.hourglass_empty : Icons.videocam_outlined, color: Colors.white70, size: 20),
                                                          const SizedBox(width: 12),
                                                          const Text('Record Clip', style: TextStyle(color: Colors.white, fontSize: 13)),
                                                        ],
                                                      ),
                                                    ),
                                                    if (_pendingImageBase64 != null || _pendingVideoBase64 != null)
                                                      const PopupMenuItem(
                                                        value: 'clear',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                            const SizedBox(width: 12),
                                                            const Text('Clear Attachment', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: TextField(
                                                    controller: _textController,
                                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                                    onChanged: (_) => setState(() {}),
                                                    decoration: InputDecoration(
                                                      hintText: _pendingVideoBase64 != null
                                                          ? "Ask about the video..."
                                                          : _pendingImageBase64 != null
                                                              ? "Ask about the image..."
                                                              : "Message your companion...",
                                                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(30),
                                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.8),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(30),
                                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.8),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(30),
                                                        borderSide: const BorderSide(color: AppColors.statusGreen, width: 1.0),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    ),
                                                    onSubmitted: _handleSubmit,
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
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                          onPressed: () => _handleSubmit(_textController.text),
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
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
                  ],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                            setState(() => _canvasVisible = false);
                            CanvasCapability().clearController();
                            _canvasController = WebViewController()
                              ..setJavaScriptMode(JavaScriptMode.unrestricted)
                              ..loadRequest(Uri.parse('about:blank'));
                            CanvasCapability().setController(_canvasController!);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Diagnostics (slide-up panel)
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
        ],
      ),
    );
  }

  Widget _buildFloatingChip(String label, VoidCallback onNext, VoidCallback onPrev) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onPrev,
            child: const Icon(Icons.chevron_left, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onNext,
            child: const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
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
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
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
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _diagnosticLogs.join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logs copied to clipboard')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
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
}

