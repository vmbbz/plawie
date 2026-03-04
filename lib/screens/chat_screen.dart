import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../app.dart';
import '../services/preferences_service.dart';
import '../providers/gateway_provider.dart';
import '../widgets/vrm_avatar_widget.dart';

import '../models/chat_message.dart';
import '../services/chat_persistence_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _logScrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ChatPersistenceService _persistence = ChatPersistenceService();
  
  bool _isThinking = false;
  double _speechIntensity = 0.0;
  bool _isGenerating = false;
  
  // Diagnostics
  final List<String> _diagnosticLogs = [];
  bool _showDiagnostics = false;
  
  // Voice
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  
  String _selectedAvatar = 'gemini.vrm';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _initVoiceParams();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final history = await _persistence.loadMessages();
    final prefs = PreferencesService();
    await prefs.init();
    final agentName = prefs.agentName;

    if (mounted) {
      setState(() {
        if (history.isNotEmpty) {
          _messages.clear();
          _messages.addAll(history);
        } else {
          _messages.add(ChatMessage(text: "Hello! I'm $agentName, your fully local AI companion. How can I help you today?", isUser: false));
        }
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveChatHistory() async {
    await _persistence.saveMessages(_messages);
  }

  Future<void> _loadPreferences() async {
    final prefs = PreferencesService();
    await prefs.init();
    if (mounted) {
      setState(() {
        _selectedAvatar = prefs.selectedAvatar;
      });
    }
  }

  void _addDiagnosticLog(String log) {
    if (!mounted) return;
    setState(() {
      _diagnosticLogs.add('[${DateTime.now().toLocal().toString().split(' ')[1]}] $log');
      if (_diagnosticLogs.length > 100) _diagnosticLogs.removeAt(0);
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

  Future<void> _initVoiceParams() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    await _speechToText.initialize();

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _speechIntensity = 0.8);
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _speechIntensity = 0.0);
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _speechIntensity = 0.0);
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _speechIntensity = 0.0);
    });
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
    _scrollToBottom();
    _saveChatHistory(); // Save user message
    _addDiagnosticLog('Sending message: $text');

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
        
        if (chunk.startsWith('[Error]')) {
          _addDiagnosticLog('API Error: $chunk');
        } else {
           _addDiagnosticLog('Stream Delta: $chunk');
        }
        
        setState(() {
          _isThinking = false; // Stopped thinking, started talking
          _speechIntensity = chunk.length > 2 ? 0.8 : 0.3; // Simulate mouth movement
          fullResponse += chunk;
          _messages.last = ChatMessage(text: fullResponse, isUser: false);
        });
        _scrollToBottom();
      }
      _saveChatHistory(); // Save full assistant response
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
      });
      _addDiagnosticLog('Generation completed. Total length: ${fullResponse.length}');
    }
    
    // Speak the final response
    if (fullResponse.isNotEmpty && !fullResponse.startsWith('[Error')) {
       await _flutterTts.stop();
       await _flutterTts.speak(fullResponse);
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
      _addDiagnosticLog('Voice listening stopped.');
    } else {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
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

  @override
  final List<String> _availableAvatars = [
    'gemini.vrm',
    'boruto.vrm',
    'default_avatar.vrm',
  ];

  final List<String> _availableModels = [
    'clawa',
    'claude-3-5-sonnet',
    'gpt-4o',
    'gemini-1.5-pro',
  ];

  String _selectedModel = 'clawa';
  
  // FIX: Decouple from _messages.isNotEmpty
  bool get _isCinematic => _isGenerating || _isListening || _textController.text.isNotEmpty;

  void _nextAvatar() {
    int currentIndex = _availableAvatars.indexOf(_selectedAvatar);
    if (currentIndex == -1) currentIndex = 0;
    int nextIndex = (currentIndex + 1) % _availableAvatars.length;
    setState(() => _selectedAvatar = _availableAvatars[nextIndex]);
    _addDiagnosticLog('Swapped to avatar: $_selectedAvatar');
  }

  void _prevAvatar() {
    int currentIndex = _availableAvatars.indexOf(_selectedAvatar);
    if (currentIndex == -1) currentIndex = 0;
    int prevIndex = (currentIndex - 1 + _availableAvatars.length) % _availableAvatars.length;
    setState(() => _selectedAvatar = _availableAvatars[prevIndex]);
    _addDiagnosticLog('Swapped to avatar: $_selectedAvatar');
  }

  void _nextModel() {
    int currentIndex = _availableModels.indexOf(_selectedModel);
    int nextIndex = (currentIndex + 1) % _availableModels.length;
    setState(() => _selectedModel = _availableModels[nextIndex]);
    _addDiagnosticLog('Swapped to AI model: $_selectedModel');
  }

  void _prevModel() {
    int currentIndex = _availableModels.indexOf(_selectedModel);
    int prevIndex = (currentIndex - 1 + _availableModels.length) % _availableModels.length;
    setState(() => _selectedModel = _availableModels[prevIndex]);
    _addDiagnosticLog('Swapped to AI model: $_selectedModel');
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    _textController.dispose();
    _scrollController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: AnimatedOpacity(
          opacity: _isCinematic ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _prevAvatar,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedAvatar.split('.').first.toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_right, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _nextAvatar,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'ACTIVE AVATAR',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showDiagnostics ? Icons.bug_report : Icons.bug_report_outlined, 
                       color: _showDiagnostics ? AppColors.statusGreen : Colors.white54),
            onPressed: () => setState(() => _showDiagnostics = !_showDiagnostics),
            tooltip: 'Toggle WebGL/Gateway Diagnostics',
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. Deep Sci-Fi Background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.0,
                colors: [
                  theme.colorScheme.surface,
                  Colors.black,
                ],
                stops: const [0.2, 1.0],
              ),
            ),
          ),

          // 2. Base Spotlight Ellipse
          Positioned(
            bottom: size.height * 0.15,
            left: size.width * 0.1,
            right: size.width * 0.1,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 3. The 3D VRM Avatar (Full Screen Transparent WebGL)
          Positioned.fill(
            child: VrmAvatarWidget(
              isThinking: _isThinking,
              speechIntensity: _speechIntensity,
              avatarFileName: _selectedAvatar,
              isCinematic: _isCinematic,
              onLog: _addDiagnosticLog, // Wire WebView errors to Flutter
            ),
          ),

          // Area indicators removed as per request to use the top rotator for clarity

          // 5. Holographic Chat Overlay
          Positioned.fill(
            child: Column(
              children: [
                const Spacer(flex: 2), // Push messages to the bottom half
                Expanded(
                  flex: 5,
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                        stops: [0.0, 0.1, 0.9, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _buildMessageBubble(msg, theme);
                      },
                    ),
                  ),
                ),
                
                // Diagnostic Overlay
                if (_showDiagnostics)
                  Container(
                    height: 120,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      border: Border.all(color: AppColors.statusRed.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          color: AppColors.statusRed.withOpacity(0.2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('SYSTEM DIAGNOSTICS', style: TextStyle(color: AppColors.statusRed, fontSize: 10, fontWeight: FontWeight.bold)),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.copy, size: 14, color: AppColors.statusRed),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _diagnosticLogs.join('\n')));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs copied!')));
                                }
                              )
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _logScrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: _diagnosticLogs.length,
                            itemBuilder: (context, index) {
                              final logLine = _diagnosticLogs[index];
                              // Color-code by prefix for easier VRM / gateway triage
                              Color lineColor;
                              if (logLine.contains('] ERROR:') || logLine.contains('] API Error')) {
                                lineColor = Colors.redAccent;
                              } else if (logLine.contains('] LOG:')) {
                                lineColor = Colors.cyanAccent;
                              } else if (logLine.contains('] PROGRESS:')) {
                                lineColor = Colors.yellowAccent;
                              } else {
                                lineColor = Colors.greenAccent;
                              }
                              return Text(
                                logLine,
                                style: TextStyle(
                                  color: lineColor,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Input Area (Glassmorphism)
                ClipRRect(
                  child: BackdropFilter(
                    filter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                              color: _isListening ? AppColors.statusRed : theme.colorScheme.primary,
                              onPressed: _toggleListening,
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                                ),
                                child: TextField(
                                  controller: _textController,
                                  style: const TextStyle(color: Colors.white),
                                  onChanged: (_) => setState(() {}), // Trigger cinematic mode on type
                                  decoration: const InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(color: Colors.white54),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                  onSubmitted: _handleSubmit,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withOpacity(0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                onPressed: () => _handleSubmit(_textController.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, ThemeData theme) {
    // Holographic Glassmorphism Bubble
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: msg.isUser ? theme.colorScheme.primary.withOpacity(0.2) : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(20),
            bottomLeft: msg.isUser ? const Radius.circular(20) : const Radius.circular(4),
          ),
          border: Border.all(
            color: msg.isUser ? theme.colorScheme.primary.withOpacity(0.5) : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: msg.isUser ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ] : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(20),
            bottomLeft: msg.isUser ? const Radius.circular(20) : const Radius.circular(4),
          ),
          child: BackdropFilter(
            filter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.dstATop),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                msg.text.isEmpty && _isGenerating && !msg.isUser ? '...' : msg.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  height: 1.4,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
