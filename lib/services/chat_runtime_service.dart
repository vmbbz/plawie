import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../utils/video_frame_extractor.dart';
import 'capabilities/camera_capability.dart';
import 'chat_persistence_service.dart';
import 'gateway_service.dart';
import 'local_llm_service.dart';
import 'model_provider_catalog.dart';
import 'preferences_service.dart';
import 'tts_service.dart';

class ChatRuntimeService extends ChangeNotifier {
  static const Duration _chatTurnHardTimeout = Duration(minutes: 6);

  static final ChatRuntimeService _instance = ChatRuntimeService._internal();
  factory ChatRuntimeService() => _instance;
  ChatRuntimeService._internal() {
    _tts.addCompleteListener(_handleTtsComplete);
    CameraCapability.onSnapTaken = (b64, mime) {
      _pendingAiSnapBase64 = b64;
      _pendingAiSnapMimeType = mime;
    };
  }

  final ChatPersistenceService _persistence = ChatPersistenceService();
  final TtsService _tts = TtsService();
  final List<ChatMessage> _messages = [];
  final List<String> _diagnostics = [];
  final List<String> _ttsQueue = [];

  bool _initialized = false;
  Future<void>? _initFuture;
  bool _isThinking = false;
  bool _isGenerating = false;
  bool _isTtsSpeaking = false;
  String _ttsSentenceBuffer = '';
  String _ttsModel = ModelProviderCatalog.defaultCloudFallbackModel;
  String _agentName = 'Plawie';
  String? _gatewaySessionKey;
  String? _pendingAiSnapBase64;
  String? _pendingAiSnapMimeType;
  Timer? _persistDebounce;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get diagnostics => List.unmodifiable(_diagnostics);
  bool get isThinking => _isThinking;
  bool get isGenerating => _isGenerating;
  bool get isTtsSpeaking => _isTtsSpeaking || _tts.isSpeaking;

  Future<void> init() {
    if (_initialized) return Future<void>.value();
    _initFuture ??= _init();
    return _initFuture!;
  }

  Future<void> _init() async {
    await _persistence.init();
    final prefs = PreferencesService();
    await prefs.init();
    _agentName = prefs.agentName;
    _gatewaySessionKey = _persistence.activeGatewaySessionKey;
    await _loadMessagesForActiveSession();
    _initialized = true;
  }

  Future<void> reloadActiveSession() async {
    await init();
    if (_isGenerating) return;
    _gatewaySessionKey = _persistence.activeGatewaySessionKey;
    await _loadMessagesForActiveSession();
    notifyListeners();
  }

  Future<void> _loadMessagesForActiveSession() async {
    final history = await _persistence.loadMessages();
    _messages
      ..clear()
      ..addAll(history);
    if (_messages.isNotEmpty &&
        !_messages.last.isUser &&
        _messages.last.text.trim().isEmpty) {
      _messages[_messages.length - 1] = ChatMessage(
        text:
            'Warning: Previous response was interrupted before the Gateway returned a final result. Please resend the last message.',
        isUser: false,
      );
      unawaited(_persistence.saveMessages(_messages));
    }
    if (_messages.isEmpty) {
      _messages.add(ChatMessage(
        text:
            "Hello! I'm $_agentName, your fully local AI companion. How can I help you today?",
        isUser: false,
      ));
    }
  }

  Future<void> persistNow() async {
    _persistDebounce?.cancel();
    await _persistence.saveMessages(_messages);
  }

  void _persistSoon() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_persistence.saveMessages(_messages));
    });
  }

  void _setState({
    bool? isThinking,
    bool? isGenerating,
    bool notify = true,
  }) {
    _isThinking = isThinking ?? _isThinking;
    _isGenerating = isGenerating ?? _isGenerating;
    if (notify) notifyListeners();
  }

  void addDiagnostic(String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _diagnostics.add('[$ts] $message');
    if (_diagnostics.length > 240) {
      _diagnostics.removeRange(0, _diagnostics.length - 240);
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> _conversationHistoryBeforePendingReply() {
    final cutoff =
        _messages.length >= 2 ? _messages.length - 2 : _messages.length;
    return _messages
        .take(cutoff)
        .where((m) => m.text.trim().isNotEmpty)
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
  }

  bool _shouldUseGatewaySessionBindingForMessage({
    required String text,
    required bool isLocalModelSelected,
    required bool hasMediaAttachment,
  }) {
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

  Future<void> sendMessage({
    required String text,
    required String model,
    String? imageBase64,
    String? videoBase64,
  }) async {
    await init();
    if ((text.trim().isEmpty && imageBase64 == null && videoBase64 == null) ||
        _isGenerating) {
      return;
    }

    await _tts.stop();
    _ttsQueue.clear();
    _ttsSentenceBuffer = '';
    _isTtsSpeaking = false;
    _ttsModel = model;

    _messages.add(ChatMessage(
      text: text.trim().isEmpty && videoBase64 != null ? 'Video clip' : text,
      isUser: true,
      imageBase64: imageBase64,
      imageMimeType: imageBase64 != null ? 'image/jpeg' : null,
    ));
    _messages.add(ChatMessage(text: '', isUser: false));
    _setState(isThinking: true, isGenerating: true);
    await persistNow();
    addDiagnostic('Sending message: $text');

    var fullResponse = '';
    final sendStopwatch = Stopwatch()..start();
    var loggedFirstAssistantChunk = false;
    final List<ChatToolEvent> toolEvents = [];
    var rawBuffer = '';
    var thinkBuffer = '';

    String parseThinkChunk(String chunk) {
      rawBuffer += chunk;
      final out = StringBuffer();
      final think = StringBuffer();
      var inThink = false;
      var i = 0;
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

    void updateAssistant({
      String? text,
      String? thinkContent,
      List<ChatToolEvent>? events,
    }) {
      if (_messages.isEmpty) return;
      _messages.last = ChatMessage(
        text: text ?? fullResponse,
        isUser: false,
        thinkContent: thinkContent?.isNotEmpty == true ? thinkContent : null,
        toolEvents:
            events?.isNotEmpty == true ? List.unmodifiable(events!) : null,
      );
      notifyListeners();
      _persistSoon();
    }

    try {
      final gateway = GatewayService();
      final localLlm = LocalLlmService();
      final isLocalModelSelected = ModelProviderCatalog.isLocalModelId(model);
      String? streamSessionKey = _isUnsafeGatewaySessionKey(_gatewaySessionKey)
          ? null
          : _gatewaySessionKey;
      final bindGatewaySession = _shouldUseGatewaySessionBindingForMessage(
        text: text,
        isLocalModelSelected: isLocalModelSelected,
        hasMediaAttachment: imageBase64 != null || videoBase64 != null,
      );
      if (!bindGatewaySession) streamSessionKey = null;

      final Stream<String> stream;
      if (isLocalModelSelected) {
        if (videoBase64 != null) {
          if (localLlm.isVisionReady) {
            stream = () async* {
              yield 'Extracting video frames...';
              final mp4Bytes = base64Decode(videoBase64);
              final frames = await VideoFrameExtractor.extractFrames(
                mp4Bytes,
                fps: 1,
                maxFrames: 8,
              );
              if (frames.isEmpty) {
                yield 'Could not extract frames. Make sure ffmpeg is installed in PRoot.';
                return;
              }
              yield* localLlm.analyseVideoFrames(
                frames,
                text.trim().isEmpty ? 'Describe what is happening.' : text,
              );
            }();
          } else {
            stream = Stream.value(
              'Video captured, but no local vision model is active. Please start a multimodal model like Qwen2-VL.',
            );
          }
        } else if (imageBase64 != null) {
          if (localLlm.isVisionReady) {
            stream = gateway.sendVisionMessage(text, imageBase64);
          } else {
            stream = Stream.value(
              'Image captured, but no local vision model is active. Start Qwen2-VL 2B or LLaVA 1.5 7B in Local LLM.',
            );
          }
        } else {
          stream = gateway.sendMessage(
            text,
            model: model,
            conversationHistory: _conversationHistoryBeforePendingReply(),
            sessionKey: streamSessionKey,
          );
        }
      } else if (videoBase64 != null) {
        stream = gateway.sendCloudVideoMessage(
          text.trim().isEmpty
              ? 'Describe what is happening in this video.'
              : text,
          videoBase64,
        );
      } else if (imageBase64 != null) {
        stream = gateway.sendCloudImageMessage(
          text.trim().isEmpty ? 'Describe what you see in this image.' : text,
          imageBase64,
        );
      } else {
        stream = gateway.sendMessage(
          text,
          model: model,
          conversationHistory: _conversationHistoryBeforePendingReply(),
          sessionKey: streamSessionKey,
        );
      }

      final guardedStream = stream.timeout(
        _chatTurnHardTimeout,
        onTimeout: (sink) {
          sink.add(
            '[Error] Chat timed out after '
            '${_chatTurnHardTimeout.inMinutes} minutes. '
            'Retry after switching provider/model or API key.',
          );
          sink.close();
        },
      );

      await for (final chunk in guardedStream) {
        if (!loggedFirstAssistantChunk &&
            chunk.trim().isNotEmpty &&
            !chunk.startsWith('\x00TOOL_')) {
          loggedFirstAssistantChunk = true;
          addDiagnostic(
              'First assistant chunk after ${sendStopwatch.elapsedMilliseconds}ms');
        }

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
            updateAssistant(thinkContent: thinkBuffer, events: toolEvents);
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
                  type: 'tool_result', name: name, result: resultJson),
            );
            updateAssistant(thinkContent: thinkBuffer, events: toolEvents);
          }
          continue;
        }

        if (chunk.contains('[Error]') ||
            chunk.contains('rate limit reached') ||
            chunk.contains('API error')) {
          var errorMsg = chunk.replaceAll('[Error]', '').trim();
          if (_isRecoverableGatewaySessionFailure(errorMsg)) {
            _gatewaySessionKey = null;
            await _persistence.setActiveGatewaySessionKey(null);
            errorMsg =
                'Gateway session became stale and was reset. Please resend this message.';
          }
          fullResponse = fullResponse.isEmpty
              ? 'Warning: $errorMsg'
              : '$fullResponse\n\nWarning: $errorMsg';
          updateAssistant(text: fullResponse);
          break;
        }

        final oldLen = fullResponse.length;
        fullResponse = parseThinkChunk(chunk);
        if (fullResponse.length > oldLen) {
          _enqueueTtsFromStream(fullResponse.substring(oldLen));
        }
        _setState(isThinking: false, notify: false);
        updateAssistant(thinkContent: thinkBuffer, events: toolEvents);
      }

      _flushTtsQueue();
    } catch (e) {
      addDiagnostic('Exception during chat: $e');
      fullResponse += '\n\n[Error: $e]';
      updateAssistant(text: fullResponse);
    }

    if (fullResponse.trim().isEmpty) {
      fullResponse =
          'Warning: No response received. The model may still be loading. Please try again in a moment.';
      updateAssistant(text: fullResponse);
    }

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

    _setState(isThinking: false, isGenerating: false, notify: false);
    addDiagnostic('Generation completed. Total length: ${fullResponse.length}');
    notifyListeners();
    await persistNow();
  }

  String _sanitizeForTts(String text) {
    var t = text;
    t = t.replaceAll(
        RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\(gesture:\s*\w+\)\s*'), '');
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), 'code block. ');
    t = t.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    t = t.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
    t = t.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1');
    t = t.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    t = t.replaceAll(RegExp(r'\*{3}([^*\n]+)\*{3}'), r'$1');
    t = t.replaceAll(RegExp(r'\*{2}([^*\n]+)\*{2}'), r'$1');
    t = t.replaceAll(RegExp(r'\*([^*\n]+)\*'), r'$1');
    t = t.replaceAll(RegExp(r'_{2}([^_\n]+)_{2}'), r'$1');
    t = t.replaceAll(RegExp(r'_([^_\n]+)_'), r'$1');
    t = t.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');
    t = t.replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '');
    t = t.replaceAll(RegExp(r'^\|.*\|$', multiLine: true), '');
    t = t.replaceAll('|', ' ');
    t = t.replaceAll(RegExp(r'https?://\S+'), 'link');
    t = t.replaceAll('[Error]', 'Error:');
    t = t.replaceAll('[Warning]', 'Warning:');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    t = t.replaceAll('Warning:', 'Warning:');
    t = t.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '');
    t = t.replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '');
    t = t.replaceAll('→', ' to ');
    t = t.replaceAll('←', '');
    t = t.replaceAll('↑', '');
    t = t.replaceAll('↓', '');
    t = t.replaceAll('—', ', ');
    t = t.replaceAll('–', ', ');
    t = t.replaceAll('•', '');
    t = t.replaceAll('·', '');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    t = t.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return t.trim();
  }

  void _enqueueTtsFromStream(String chunk) {
    _ttsSentenceBuffer += chunk;
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

  void _flushTtsQueue() {
    final clean = _sanitizeForTts(_ttsSentenceBuffer);
    if (clean.isNotEmpty) {
      _ttsQueue.add(clean);
      _processNextTtsInQueue();
    }
    _ttsSentenceBuffer = '';
  }

  void _handleTtsComplete() {
    _isTtsSpeaking = false;
    _processNextTtsInQueue();
  }

  Future<void> _processNextTtsInQueue() async {
    if (_isTtsSpeaking || _ttsQueue.isEmpty || _tts.isSpeaking) return;
    _isTtsSpeaking = true;
    final sentence = _ttsQueue.removeAt(0);
    try {
      if (ModelProviderCatalog.isLocalModelId(_ttsModel)) {
        await _tts.speak(sentence);
        return;
      }
      final playback = await GatewayService().speakTextViaTalk(sentence);
      if (!playback.played && playback.allowNativeFallback) {
        await _tts.speak(sentence);
      } else if (!playback.played) {
        _isTtsSpeaking = false;
        _processNextTtsInQueue();
      }
    } catch (e) {
      addDiagnostic('TTS error: $e');
      _isTtsSpeaking = false;
      _processNextTtsInQueue();
    }
  }
}
