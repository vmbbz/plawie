import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../app.dart';
import '../services/gateway_service.dart';
import '../services/preferences_service.dart';
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

  late final GatewayService _gatewayService;
  String _selectedAvatar = 'gemini.vrm';

  @override
  void initState() {
    super.initState();
    _gatewayService = GatewayService();
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
      final stream = _gatewayService.sendMessage(text);
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
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    _textController.dispose();
    _scrollController.dispose();
    _gatewayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Clawa'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // VRM Avatar Header
          SizedBox(
            height: size.height * 0.45,
            child: Stack(
              children: [
                // Background gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                         theme.colorScheme.surface.withOpacity(0.0),
                         theme.colorScheme.surface,
                      ],
                      stops: const [0.7, 1.0],
                    ),
                  ),
                ),
                VrmAvatarWidget(
                  isThinking: _isThinking,
                  speechIntensity: _speechIntensity,
                  modelFileName: _selectedAvatar,
                ),
              ],
            ),
          ),
          
          // Chat Messages
          Expanded(
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
          
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
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
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                      ),
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        onSubmitted: _handleSubmit,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: IconButton(
                      icon: Icon(Icons.send, color: theme.colorScheme.onPrimary, size: 20),
                      onPressed: () => _handleSubmit(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, ThemeData theme) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser ? theme.colorScheme.primary : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(0) : const Radius.circular(20),
            bottomLeft: msg.isUser ? const Radius.circular(20) : const Radius.circular(0),
          ),
          border: msg.isUser ? null : Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Text(
          msg.text.isEmpty && _isGenerating && !msg.isUser ? '...' : msg.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: msg.isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
