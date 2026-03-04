import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../app.dart';
import '../services/preferences_service.dart';
import '../providers/gateway_provider.dart';
import '../widgets/vrm_avatar_widget.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  bool _isThinking = false;
  double _speechIntensity = 0.0;
  bool _isGenerating = false;
  
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
    _messages.add(ChatMessage(text: "Hello! I'm Clawa, your fully local AI companion. How can I help you today?", isUser: false));
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

    // Add empty message for the assistant
    setState(() {
      _messages.add(ChatMessage(text: '', isUser: false));
    });

    String fullResponse = '';
    
    try {
      // Use Consumer<GatewayProvider> to access shared gateway state
      final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);
      final stream = gatewayProvider.sendMessage(text);
      await for (final chunk in stream) {
        if (!mounted) break;
        setState(() {
          _isThinking = false; // Stopped thinking, started talking
          _speechIntensity = chunk.length > 2 ? 0.8 : 0.3; // Simulate mouth movement
          fullResponse += chunk;
          _messages.last = ChatMessage(text: fullResponse, isUser: false);
        });
        _scrollToBottom();
      }
    } catch (e) {
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
    } else {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        await _speechToText.listen(
          onResult: (result) {
            _textController.text = result.recognizedWords;
            if (result.hasConfidenceRating && result.confidence > 0 && result.recognizedWords.isNotEmpty && !_speechToText.isListening) {
                // Done recognizing
                _handleSubmit(result.recognizedWords);
            }
          },
        );
      }
    }
  }

  @override
  final List<String> _availableModels = [
    'gemini.vrm',
    'boruto.vrm',
    'default_avatar.vrm',
  ];
  
  bool get _isCinematic => _messages.isNotEmpty || _isListening || _textController.text.isNotEmpty;

  void _nextModel() {
    int currentIndex = _availableModels.indexOf(_selectedAvatar);
    if (currentIndex == -1) currentIndex = 0;
    int nextIndex = (currentIndex + 1) % _availableModels.length;
    setState(() => _selectedAvatar = _availableModels[nextIndex]);
    
    // Play a tiny haptic or feedback here if desired
  }

  void _prevModel() {
    int currentIndex = _availableModels.indexOf(_selectedAvatar);
    if (currentIndex == -1) currentIndex = 0;
    int prevIndex = (currentIndex - 1 + _availableModels.length) % _availableModels.length;
    setState(() => _selectedAvatar = _availableModels[prevIndex]);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    _textController.dispose();
    _scrollController.dispose();
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
            children: [
              Text(
                _selectedAvatar.split('.').first.toUpperCase(),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  letterSpacing: 4.0,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: theme.colorScheme.primary, blurRadius: 10),
                  ],
                ),
              ),
              Text(
                'AI COMPANION',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
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
              modelFileName: _selectedAvatar,
              isCinematic: _isCinematic,
            ),
          ),

          // 4. Model Selection Carousel (Left/Right Arrows)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutBack,
            left: _isCinematic ? -80 : 16, // Slides out of view when cinematic
            top: size.height * 0.4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
              ),
              child: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                onPressed: _prevModel,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutBack,
            right: _isCinematic ? -80 : 16, // Slides out of view when cinematic
            top: size.height * 0.4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
              ),
              child: IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                onPressed: _nextModel,
              ),
            ),
          ),

          // 5. Holographic Chat Overlay
          Positioned.fill(
            child: Column(
              children: [
                const Spacer(flex: 3), // Push messages to the bottom half
                Expanded(
                  flex: 5,
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white, Colors.white],
                        stops: [0.0, 0.1, 1.0],
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
