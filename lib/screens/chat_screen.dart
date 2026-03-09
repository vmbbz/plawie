import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/piper_tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../app.dart';
import '../services/preferences_service.dart';
import '../providers/gateway_provider.dart';
import '../widgets/vrm_avatar_widget.dart';

import '../models/chat_message.dart';
import '../services/chat_persistence_service.dart';
import '../widgets/chat_bubble.dart';
import 'avatar_forge_page.dart';

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
  bool _isReady = false;
  
  // Diagnostics
  final List<String> _diagnosticLogs = [];
  bool _showDiagnostics = false;
  
  // Voice Pipeline (Piper TTS / Local VITS)
  final PiperTtsService _piperTts = PiperTtsService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  
  String _selectedAvatar = 'default_avatar.vrm';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _initVoiceParams();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    await _persistence.init();
    final history = await _persistence.loadMessages();
    final prefs = PreferencesService();
    await prefs.init();
    final agentName = prefs.agentName;

    if (mounted) {
      setState(() {
        _messages.clear();
        if (history.isNotEmpty) {
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

  Future<void> _initVoiceParams() async {
    await _piperTts.init();

    await _speechToText.initialize();

    _piperTts.onStart = () {
      if (mounted) setState(() => _speechIntensity = 0.8);
    };

    _piperTts.onComplete = () {
      if (mounted) setState(() => _speechIntensity = 0.0);
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
      });
      _addDiagnosticLog('Generation completed. Total length: ${fullResponse.length}');
    }
    
    // Speak the final response
    if (fullResponse.isNotEmpty && !fullResponse.startsWith('[Error')) {
       await _piperTts.stop();
       final cleanTextForSpeech = fullResponse.replaceAll(RegExp(r'[\*\`\#]'), '');
       await _piperTts.speak(cleanTextForSpeech);
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
    'google/gemini-3.1-pro-preview',
    'anthropic/claude-opus-4.6',
    'openai/gpt-4o',
    'groq/llama-3.1-405b',
  ];

  String _selectedModel = 'google/gemini-3.1-pro-preview';
  
  // FIX: Decouple from _messages.isNotEmpty
  bool get _isCinematic => _isGenerating || _isListening || _textController.text.isNotEmpty;

  void _nextAvatar() {
    int currentIndex = _availableAvatars.indexOf(_selectedAvatar);
    if (currentIndex == -1) currentIndex = 0;
    int nextIndex = (currentIndex + 1) % _availableAvatars.length;
    setState(() {
      _selectedAvatar = _availableAvatars[nextIndex];
      _isReady = false;
    });
    _addDiagnosticLog('Swapped to avatar: $_selectedAvatar');
  }

  void _prevAvatar() {
    int currentIndex = _availableAvatars.indexOf(_selectedAvatar);
    if (currentIndex == -1) currentIndex = 0;
    int prevIndex = (currentIndex - 1 + _availableAvatars.length) % _availableAvatars.length;
    setState(() {
      _selectedAvatar = _availableAvatars[prevIndex];
      _isReady = false;
    });
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

  void _showAvatarMenu(BuildContext context) {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final position = button?.localToGlobal(Offset.zero) ?? Offset.zero;
    
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, 80, position.dx + 200, 0),
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        ..._availableAvatars.map((avatar) => PopupMenuItem<String>(
          value: avatar,
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
              Icon(Icons.auto_fix_high, color: Colors.purpleAccent.shade100, size: 18),
              const SizedBox(width: 10),
              const Text('Avatar Forge', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == 'avatar_forge') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const AvatarForgePage(),
        ));
        return;
      }
      setState(() {
        _selectedAvatar = value;
        _isReady = false;
      });
      _addDiagnosticLog('Swapped to avatar: $_selectedAvatar');
    });
  }

  void _showModelMenu(BuildContext context) {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final position = button?.localToGlobal(Offset.zero) ?? Offset.zero;
    
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, 80, position.dx + 300, 0),
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: _availableModels.map((model) => PopupMenuItem<String>(
        value: model,
        child: Row(
          children: [
            Icon(
              model == _selectedModel ? Icons.check_circle : Icons.circle_outlined,
              color: model == _selectedModel ? Colors.purpleAccent : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              model,
              style: TextStyle(
                color: model == _selectedModel ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: model == _selectedModel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      )).toList(),
    ).then((value) {
      if (value == null) return;
      setState(() => _selectedModel = value);
      _addDiagnosticLog('Swapped to AI model: $_selectedModel');
    });
  }

  @override
  void dispose() {
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
                    selectedTileColor: Colors.white.withOpacity(0.05),
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      endDrawer: _buildSessionDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: AnimatedOpacity(
          opacity: _isCinematic ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 400),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar dropdown
              GestureDetector(
                onTap: () => _showAvatarMenu(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.face, color: AppColors.statusGreen, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _selectedAvatar.split('.').first,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Model dropdown
              GestureDetector(
                onTap: () => _showModelMenu(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purpleAccent.shade100, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _selectedModel.split('/').last,
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16),
                    ],
                  ),
                ),
              ),
            ],
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
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.history, color: Colors.white70),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              tooltip: 'Chat Sessions',
            ),
          ),
          IconButton(
            icon: Icon(_showDiagnostics ? Icons.bug_report : Icons.bug_report_outlined, 
                       color: _showDiagnostics ? AppColors.statusGreen : Colors.white54),
            onPressed: () => setState(() => _showDiagnostics = !_showDiagnostics),
            tooltip: 'Toggle Diagnostics',
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. Deep space background
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
                onLog: (log) {
                  if (log == 'READY') {
                    setState(() => _isReady = true);
                  }
                  _addDiagnosticLog(log);
                },
              ),
            ),
          ),

          // 4. Glassmorphic Chat Area
          Positioned.fill(
            child: Column(
              children: [
                const Spacer(flex: 3),
                Expanded(
                  flex: 4,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Column(
                          children: [
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
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                              ),
                              child: SafeArea(
                                top: false,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: _toggleListening,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _isListening 
                                                ? AppColors.statusGreen.withOpacity(0.8) 
                                                : Colors.white54,
                                              width: _isListening ? 3 : 1,
                                            ),
                                            boxShadow: _isListening ? [
                                              BoxShadow(
                                                color: AppColors.statusGreen.withOpacity(0.3),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              )
                                            ] : [],
                                          ),
                                          child: Icon(
                                            _isListening ? Icons.mic : Icons.mic_none,
                                            color: _isListening ? AppColors.statusGreen : Colors.white70,
                                            size: 20,
                                          ),
                                        ),
                                      ),
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
                                            fillColor: Colors.white.withOpacity(0.08),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                          ),
                                          onSubmitted: _handleSubmit,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: theme.colorScheme.primary.withOpacity(0.8),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                          onPressed: () => _handleSubmit(_textController.text),
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
                  ),
                ),
              ],
            ),
          ),



          // 6. Diagnostics (slide-up panel)
          if (_showDiagnostics)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: size.height * 0.4,
              child: _buildDiagnosticsPanel(theme),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingChip(String label, VoidCallback onNext, VoidCallback onPrev) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
        color: Colors.black.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
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
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
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
