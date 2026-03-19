import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../services/piper_tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../app.dart';
import '../services/preferences_service.dart';
import '../providers/gateway_provider.dart';
import '../widgets/vrm_avatar_widget.dart';

import 'dart:ui';
import '../models/chat_message.dart';
import '../services/chat_persistence_service.dart';
import '../widgets/chat_bubble.dart';
import '../main.dart';
import 'avatar_forge_page.dart';
import '../services/skills_service.dart';

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
  
  bool _isThinking = false;
  double _speechIntensity = 0.0;
  bool _isGenerating = false;
  bool _isReady = false;
  
  // Diagnostics
  final List<String> _diagnosticLogs = [];
  bool _showDiagnostics = false;
  
  // Voice Pipeline (Piper TTS / Local VITS)
  final PiperTtsService _piperTts = PiperTtsService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String? _currentGesture;
  String? _lastUserMessage;
  
  String _selectedAvatar = 'default_avatar.vrm';
  String _agentName = 'Clawa Pocket';
  String _selectedModel = 'google/gemini-3.1-pro-preview';
  
  final List<String> _availableModels = [
    'google/gemini-3.1-pro-preview',
    'anthropic/claude-opus-4.6',
    'openai/gpt-4o',
    'groq/llama-3.1-405b',
  ];

  final List<String> _availableAvatars = [
    'gemini.vrm',
    'boruto.vrm',
    'default_avatar.vrm',
  ];
  
  bool _isTtsDownloaded = false;
  double _downloadProgress = 0.0;
  bool _isDownloadingTts = false;

  static const MethodChannel _pipChannel = MethodChannel('vrm/pip_mode');
  bool _isPipMode = false;
  bool _isChatCollapsed = false; // Expanded by default
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadPreferences();
    _initVoiceParams();
    _loadChatHistory();
    _checkTtsModel();

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
    SkillsService().events.listen((event) {
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
    _piperTts.onDownloadProgress = (p) {
      if (mounted) {
        setState(() {
          _downloadProgress = p;
          if (p >= 1.0) {
            _isDownloadingTts = false;
            _isTtsDownloaded = true;
          } else if (p > 0) {
            _isDownloadingTts = true;
          }
        });
      }
    };
  }

  Future<void> _checkTtsModel() async {
    final downloaded = await _piperTts.isModelDownloaded();
    if (mounted) {
      setState(() => _isTtsDownloaded = downloaded);
    }
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

    try {
      _addDiagnosticLog('Starting Piper TTS background download...');
      await _piperTts.init(forceDownload: true);
      
      if (mounted) {
        setState(() {
          _isDownloadingTts = false;
          _isTtsDownloaded = true;
          _downloadProgress = 1.0;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice engine ready! Tap the mic to start talking.'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
    } catch (e) {
      _addDiagnosticLog('Download Error: $e');
      if (mounted) {
        setState(() => _isDownloadingTts = false);
        ScaffoldMessenger.of(context).showSnackBar(
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
      _scrollToBottom();
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
        // Load the user's configured model (from setup or settings)
        final configured = prefs.configuredModel;
        if (configured != null && configured.isNotEmpty && _availableModels.contains(configured)) {
          _selectedModel = configured;
        }
      });
    }
  }

  void _addDiagnosticLog(String log) {
    if (!mounted) return;
    setState(() {
      _diagnosticLogs.add('[${DateTime.now().toLocal().toString().split(' ')[1]}] $log');
      if (_diagnosticLogs.length > 100) _diagnosticLogs.removeAt(0);

      // Auto-show diagnostics on first error
      if (log.contains('ERROR:') && !_showDiagnostics) {
        _showDiagnostics = true;
      }
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

    _piperTts.onStart = () {
      if (mounted) {
        setState(() => _speechIntensity = 0.8);
      }
    };

    _piperTts.onComplete = () {
      if (mounted) {
        setState(() => _speechIntensity = 0.0);
        _syncOverlayState();
      }
    };
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmit(String text) async {
    if (text.trim().isEmpty || _isGenerating) return;
    
    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isThinking = true;
      _isGenerating = true;
    });
    _syncOverlayState();
    _scrollToBottom();
    _saveChatHistory(); // Save user message
    _addDiagnosticLog('Sending message: $text');
    setState(() => _lastUserMessage = text); // Trigger JS keyword listener

    // Add empty message for the assistant
    setState(() {
      _messages.add(ChatMessage(text: '', isUser: false));
    });

    String fullResponse = '';
    
    try {
      final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);
      final stream = gatewayProvider.sendMessage(text, model: _selectedModel);
      await for (final chunk in stream) {
        if (!mounted) break;
        
        _addDiagnosticLog('Chunk received: "$chunk"');
        
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
        
        setState(() {
          _isThinking = false; // Stopped thinking, started talking
          _speechIntensity = chunk.length > 2 ? 0.8 : 0.3; // Simulate mouth movement
          
          // Check for (gesture: name) in bot response
          if (chunk.contains('(gesture:')) {
            final match = RegExp(r'\(gesture:\s*(\w+)\)').firstMatch(chunk);
            if (match != null) {
              _currentGesture = match.group(1);
            }
          }
          
          fullResponse += chunk;
          _messages.last = ChatMessage(text: fullResponse, isUser: false);
        });
        _syncOverlayState();
        _scrollToBottom();
      }
      _saveChatHistory(); // Save full assistant response

      // Strip markdown symbols before speaking so it doesn't pronounce asterisks
      final cleanTextForSpeech = fullResponse.replaceAll(RegExp(r'[\*\`\#]'), '');
      _piperTts.speak(cleanTextForSpeech);
      
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
        _speechIntensity = 0.0; // Stop mouth
        _syncOverlayState();
        
        // If the upstream AI provider rate-limited silently, the message stream will be empty.
        // Catch this and provide a human-readable fallback instead of a blank bubble.
        if (fullResponse.trim().isEmpty) {
          fullResponse = '⚠️ **API Rate Limit Reached**. Please wait a moment before trying again.';
          _messages.last = ChatMessage(text: fullResponse, isUser: false);
        }
      });
      _addDiagnosticLog('Generation completed. Total length: ${fullResponse.length}');
    }
    
    // Speak the final response (including errors now!)
    if (fullResponse.isNotEmpty) {
       await _piperTts.stop();
       // Clean emojis and markdown for TTS
       final cleanTextForSpeech = fullResponse
         .replaceAll('⚠️', 'Attention, ')
         .replaceAll(RegExp(r'[\*\`\#]'), '')
         .replaceAll(RegExp(r'\(gesture:.*?\)\s*'), ''); // Don't speak the tag
       await _piperTts.speak(cleanTextForSpeech);
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
      _syncOverlayState();
      _addDiagnosticLog('Voice listening stopped.');
    } else {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _syncOverlayState();
        _addDiagnosticLog('Voice listening started.');
        await _speechToText.listen(
          onResult: (result) {
            _textController.text = result.recognizedWords;
            if (result.hasConfidenceRating && result.confidence > 0 && result.recognizedWords.isNotEmpty && !_speechToText.isListening) {
                // Done recognizing
                _addDiagnosticLog('Voice recognized: ${result.recognizedWords}');
                _handleSubmit(result.recognizedWords);
            }
          },
        );
      } else {
        _addDiagnosticLog('Voice recognition unavailable on device.');
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
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final position = button?.localToGlobal(Offset.zero) ?? Offset.zero;
    
    showMenu<dynamic>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, 80, position.dx + 300, 0),
      color: const Color(0xFF1A1A2E),
      elevation: 20,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
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
                      color: AppColors.statusGreen.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.statusGreen, AppColors.statusGreen.withValues(alpha: 0.4)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.statusGreen.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 20),
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
                          _selectedModel.split('/').last.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
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
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
            ],
          ),
        ),

        // Avatars Section
        PopupMenuItem<void>(
          enabled: false,
          child: Text(
            'ACTIVE AVATAR',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ..._availableAvatars.map((avatar) => PopupMenuItem<String>(
          value: 'avatar:$avatar',
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
          child: Text(
            'ACTIVE MODEL',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ..._availableModels.map((model) => PopupMenuItem<String>(
          value: 'model:$model',
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
          child: Text(
            'VOICE MODULE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
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
      } else if (value == 'avatar_forge') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const AvatarForgePage(),
        ));
      } else if (value.toString().startsWith('model:')) {
        final model = value.toString().substring(6);
        setState(() => _selectedModel = model);
        PreferencesService().configuredModel = model;
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
    _glowController.dispose();
    _piperTts.stop();
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
    const double collapsedSize = 80.0;
    final double barWidth = _isChatCollapsed ? collapsedSize : size.width - 24;
    final double barHeight = _isChatCollapsed ? collapsedSize : (size.height * 0.6);

    return Scaffold(
      backgroundColor: _isPipMode ? Colors.transparent : null,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false, // Prevents VRM aspect-ratio scaling bounds from squishing
      endDrawer: _buildSessionDrawer(),
      appBar: _isPipMode ? null : AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: AnimatedOpacity(
          opacity: _isCinematic ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 400),
          child: GestureDetector(
            onTap: () => _showUnifiedMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.face_unlock_rounded, color: AppColors.statusGreen.withValues(alpha: 0.9), size: 16),
                   const SizedBox(width: 10),
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
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_selectedAvatar.split('.').first.toUpperCase()} · ${_selectedModel.split('/').last.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
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
            color: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
                child: Builder(
                  builder: (ctx2) => ListTile(
                    dense: true,
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
                    leading: const Icon(Icons.history, color: Colors.white70, size: 20),
                    title: const Text('Chat Sessions',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    onTap: () {
                      Navigator.pop(ctx2);
                      Scaffold.of(context).openEndDrawer();
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
                      _isChatCollapsed ? Icons.unfold_more : Icons.unfold_less,
                      color: _isChatCollapsed ? AppColors.statusGreen : Colors.white70,
                      size: 20,
                    ),
                    title: Text(
                      _isChatCollapsed ? 'Expand Chat' : 'Voice Only Mode',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    onTap: () {
                      Navigator.pop(ctx2);
                      setState(() => _isChatCollapsed = !_isChatCollapsed);
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
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..scale(MediaQuery.of(context).viewInsets.bottom > 0 ? 1.04 : 1.0),
                transformAlignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: size.width.clamp(0.0, 600.0),
                    maxHeight: size.height,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
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
                    margin: EdgeInsets.only(bottom: _isChatCollapsed ? 40 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(_isChatCollapsed ? collapsedSize / 2 : 32),
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
                            if (!_isChatCollapsed)
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
                                bottom: !_isChatCollapsed,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: _toggleListening,
                                      child: AnimatedBuilder(
                                        animation: _glowController,
                                        builder: (context, child) {
                                          return AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            width: _isChatCollapsed ? collapsedSize : 48,
                                            height: _isChatCollapsed ? collapsedSize : 48,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _isListening && _isChatCollapsed
                                                  ? AppColors.statusGreen.withValues(alpha: 0.1 * _glowController.value)
                                                  : Colors.transparent,
                                            ),
                                            child: Icon(
                                              _isListening ? Icons.mic : Icons.mic_none,
                                              color: _isListening ? AppColors.statusGreen : Colors.white70,
                                              size: _isChatCollapsed ? 36 : 24,
                                            ),
                                          );
                                        }
                                      ),
                                    ),
                                    if (!_isChatCollapsed) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: _textController,
                                          style: const TextStyle(color: Colors.white, fontSize: 15),
                                          onChanged: (_) => setState(() {}),
                                          decoration: InputDecoration(
                                            hintText: "Message your companion...",
                                            hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(30),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.white.withValues(alpha: 0.08),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                          ),
                                          onSubmitted: _handleSubmit,
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
                    color: AppColors.statusGreen,
                    fontSize: 11,
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
