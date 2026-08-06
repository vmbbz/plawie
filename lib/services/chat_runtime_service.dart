import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../utils/video_frame_extractor.dart';
import 'capabilities/avatar_capability.dart';
import 'chat_persistence_service.dart';
import 'gateway_service.dart';
import 'local_llm_service.dart';
import 'model_provider_catalog.dart';
import 'paid_provider_turn_authorization_service.dart';
import 'preferences_service.dart';
import 'tool_media_event_bus.dart';
import 'tts_service.dart';

enum ChatRuntimeTtsHealth {
  normal,
  processing,
  degraded,
  failed,
}

class ChatConfigurationRequest {
  final String skillId;
  final String title;
  final String message;

  const ChatConfigurationRequest({
    required this.skillId,
    required this.title,
    required this.message,
  });
}

class ChatRuntimeService extends ChangeNotifier {
  static const Duration _chatTurnSilenceNotice = Duration(minutes: 6);

  static final ChatRuntimeService _instance = ChatRuntimeService._internal();
  factory ChatRuntimeService() => _instance;
  ChatRuntimeService._internal() {
    _tts.addCompleteListener(_handleTtsComplete);
    _mediaSubscription = ToolMediaEventBus.instance.stream.listen((event) {
      _pendingAiSnapBase64 = event.base64;
      _pendingAiSnapMimeType = event.mimeType;
      _pendingAiSnapMetadata = event.toMetadata();
    });
  }

  final ChatPersistenceService _persistence = ChatPersistenceService();
  final TtsService _tts = TtsService();
  final List<ChatMessage> _messages = [];
  final List<String> _diagnostics = [];
  final List<String> _ttsQueue = [];
  final StreamController<ChatConfigurationRequest>
      _configurationRequestController =
      StreamController<ChatConfigurationRequest>.broadcast();

  bool _initialized = false;
  Future<void>? _initFuture;
  bool _isThinking = false;
  bool _isGenerating = false;
  bool _isTtsSpeaking = false;
  ChatRuntimeTtsHealth _ttsHealth = ChatRuntimeTtsHealth.normal;
  String? _ttsHealthMessage;
  String _ttsSentenceBuffer = '';
  String _ttsModel = ModelProviderCatalog.defaultCloudFallbackModel;
  String _agentName = 'Plawie';
  String? _gatewaySessionKey;
  String? _pendingAiSnapBase64;
  String? _pendingAiSnapMimeType;
  Map<String, dynamic>? _pendingAiSnapMetadata;
  Timer? _persistDebounce;
  late final StreamSubscription<ToolMediaEvent> _mediaSubscription;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get diagnostics => List.unmodifiable(_diagnostics);
  bool get isThinking => _isThinking;
  bool get isGenerating => _isGenerating;
  bool get isTtsSpeaking => _isTtsSpeaking || _tts.isSpeaking;
  ChatRuntimeTtsHealth get ttsHealth => _ttsHealth;
  String? get ttsHealthMessage => _ttsHealthMessage;
  Stream<ChatConfigurationRequest> get configurationRequests =>
      _configurationRequestController.stream;

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

  void _setTtsHealth(
    ChatRuntimeTtsHealth health, {
    String? message,
    bool notify = true,
  }) {
    if (_ttsHealth == health && _ttsHealthMessage == message) return;
    _ttsHealth = health;
    _ttsHealthMessage = message;
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
        lower.contains('agent cleanup timed out') ||
        lower.contains('unknown session') ||
        lower.contains('unknown sessionkey') ||
        lower.contains('unknown session key') ||
        lower.contains('unknown chatid') ||
        lower.contains('unknown chat id');
  }

  Future<void> sendMessage({
    required String text,
    required String model,
    String? imageBase64,
    String? videoBase64,
    PaidProviderTurnLease? paidProviderTurnLease,
  }) async {
    try {
      await _sendMessageAuthorized(
        text: text,
        model: model,
        imageBase64: imageBase64,
        videoBase64: videoBase64,
      );
    } finally {
      final lease = paidProviderTurnLease;
      if (lease != null) {
        PaidProviderTurnAuthorizationService.instance.closeLease(lease.leaseId);
      }
    }
  }

  Future<void> _sendMessageAuthorized({
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
    _setTtsHealth(ChatRuntimeTtsHealth.normal, notify: false);
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
    final dispatchedInlineGestureMarkers = <String>{};
    Map<String, dynamic>? lastLocationResult;
    String? transientStatusText;
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
      final effectiveEvents =
          events ?? (toolEvents.isNotEmpty ? toolEvents : null);
      final displayText = text ??
          (fullResponse.trim().isNotEmpty
              ? fullResponse
              : transientStatusText ?? '');
      _messages.last = ChatMessage(
        text: displayText,
        isUser: false,
        thinkContent: thinkContent?.isNotEmpty == true ? thinkContent : null,
        toolEvents: effectiveEvents?.isNotEmpty == true
            ? List.unmodifiable(effectiveEvents!)
            : null,
      );
      notifyListeners();
      _persistSoon();
    }

    void dispatchInlineControlMarkers(String visibleText) {
      for (final match in RegExp(
        r'\(gesture\s*:\s*([^)]+)\)',
        caseSensitive: false,
      ).allMatches(visibleText)) {
        final gesture = (match.group(1) ?? '').split(',').first.trim();
        if (gesture.isEmpty) continue;
        final markerKey = '${match.start}:$gesture';
        if (!dispatchedInlineGestureMarkers.add(markerKey)) continue;
        addDiagnostic('Assistant inline gesture marker: $gesture');
        unawaited(_dispatchInlineAvatarGesture(gesture));
      }
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
                yield 'Could not extract frames. Provision android-vision-media-runtime so Native ffmpeg is available.';
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
        _chatTurnSilenceNotice,
        onTimeout: (_) {
          addDiagnostic(
            'No chat chunks for ${_chatTurnSilenceNotice.inMinutes} minutes; '
            'still listening for the Gateway response.',
          );
        },
      );

      await for (final chunk in guardedStream) {
        if (chunk.startsWith('\x00CHAT_STATUS:') && chunk.endsWith('\x00')) {
          final encoded = chunk.substring(13, chunk.length - 1);
          String statusText;
          try {
            statusText = jsonDecode(encoded).toString();
          } catch (_) {
            statusText = encoded;
          }
          addDiagnostic(statusText);
          if (fullResponse.trim().isEmpty) {
            transientStatusText = statusText;
            updateAssistant(events: toolEvents);
          }
          continue;
        }

        if (!loggedFirstAssistantChunk &&
            chunk.trim().isNotEmpty &&
            !chunk.startsWith('\x00TOOL_') &&
            !chunk.startsWith('\x00CHAT_STATUS:')) {
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
            final sanitizedResultJson = _sanitizeToolResultJson(
              name,
              resultJson,
              pendingMediaMetadata: _pendingAiSnapMetadata,
            );
            final decodedResult = _tryDecodeJsonMap(resultJson);
            final configurationRequest =
                _configurationRequestFromToolResult(name, decodedResult);
            if (configurationRequest != null) {
              _configurationRequestController.add(configurationRequest);
            }
            if ((_isLocationToolName(name) ||
                    _looksLikeLocationResult(decodedResult)) &&
                decodedResult != null) {
              lastLocationResult = decodedResult;
            }
            toolEvents.add(
              ChatToolEvent(
                type: 'tool_result',
                name: name,
                result: sanitizedResultJson,
              ),
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
            final rawGatewayError = errorMsg;
            _gatewaySessionKey = null;
            await _persistence.setActiveGatewaySessionKey(null);
            errorMsg =
                'Gateway session became stale and was reset before this turn could finish.\n\n'
                'Raw Gateway error: $rawGatewayError\n\n'
                'Please resend this message.';
          }
          fullResponse =
              fullResponse.isEmpty ? errorMsg : '$fullResponse\n\n$errorMsg';
          updateAssistant(text: fullResponse);
          break;
        }

        final oldLen = fullResponse.length;
        final visibleWithMarkers = parseThinkChunk(chunk);
        dispatchInlineControlMarkers(visibleWithMarkers);
        fullResponse = _stripAssistantControlMarkers(visibleWithMarkers);
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
    final snapMetadata = _pendingAiSnapMetadata;
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
      _pendingAiSnapMetadata = null;
    }

    final locationResult = lastLocationResult;
    if (_shouldExplainLocation(text) && locationResult != null) {
      final locationSummary = _locationSummary(locationResult);
      if (locationSummary != null &&
          !_responseAlreadyIncludesLocation(fullResponse, locationResult)) {
        fullResponse = _appendAssistantSection(fullResponse, locationSummary);
        _messages.last = ChatMessage(
          text: fullResponse,
          isUser: false,
          thinkContent: _messages.last.thinkContent,
          toolEvents: _messages.last.toolEvents,
          imageBase64: snapImage,
          imageMimeType: snapImage != null ? snapMime : null,
        );
        _enqueueTtsFromStream(locationSummary);
        _flushTtsQueue();
      }
    }

    if (snapImage != null &&
        _shouldRunMediaVisionContinuation(text, toolEvents, snapMetadata)) {
      final continuation = await _runImageContinuation(
        originalPrompt: text,
        model: model,
        imageBase64: snapImage,
        mimeType: snapMime,
      );
      if (continuation.trim().isNotEmpty) {
        fullResponse = _appendAssistantSection(fullResponse, continuation);
        _messages.last = ChatMessage(
          text: fullResponse,
          isUser: false,
          thinkContent: _messages.last.thinkContent,
          toolEvents: _messages.last.toolEvents,
          imageBase64: snapImage,
          imageMimeType: snapMime,
        );
        _enqueueTtsFromStream(continuation);
        _flushTtsQueue();
      }
    }

    _setState(isThinking: false, isGenerating: false, notify: false);
    addDiagnostic('Generation completed. Total length: ${fullResponse.length}');
    notifyListeners();
    await persistNow();
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  ChatConfigurationRequest? _configurationRequestFromToolResult(
    String toolName,
    Map<String, dynamic>? result,
  ) {
    if (result == null ||
        (toolName != 'gifgrep' && !toolName.startsWith('gifgrep.'))) {
      return null;
    }
    final error = result['error'];
    final code =
        error is Map ? error['code']?.toString() : result['code']?.toString();
    if (code != 'GIFGREP_PROVIDER_CONFIG_REQUIRED') return null;
    final message = error is Map
        ? error['message']?.toString()
        : result['message']?.toString();
    return ChatConfigurationRequest(
      skillId: 'gifgrep',
      title: 'Configure gifgrep search',
      message: message?.trim().isNotEmpty == true
          ? message!.trim()
          : 'Online GIF search needs a provider key.',
    );
  }

  String _sanitizeToolResultJson(
    String name,
    String resultJson, {
    Map<String, dynamic>? pendingMediaMetadata,
  }) {
    final decoded = _tryDecodeJsonMap(resultJson);
    if (decoded == null) return resultJson;
    final copy = Map<String, dynamic>.from(decoded);
    final base64 = copy.remove('base64')?.toString();
    if (base64 != null && base64.isNotEmpty) {
      copy['base64Omitted'] = true;
      copy['base64Bytes'] = base64.length;
      copy['attachedImage'] = true;
    }
    if ((_isMediaToolName(name) || _looksLikeMediaResult(copy)) &&
        pendingMediaMetadata != null) {
      copy.addAll(pendingMediaMetadata);
    }
    return jsonEncode(copy);
  }

  bool _isMediaToolName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('camera') ||
        lower.contains('photo') ||
        lower.contains('snapshot') ||
        lower.contains('canvas');
  }

  bool _isLocationToolName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('location') || lower.contains('gps');
  }

  bool _looksLikeLocationResult(Map<String, dynamic>? result) {
    if (result == null) return false;
    return (result.containsKey('lat') || result.containsKey('latitude')) &&
        (result.containsKey('lng') || result.containsKey('longitude'));
  }

  bool _looksLikeMediaResult(Map<String, dynamic>? result) {
    if (result == null) return false;
    return result['attachedImage'] == true ||
        result['base64Omitted'] == true ||
        result['mimeType']?.toString().startsWith('image/') == true ||
        result['format']?.toString().toLowerCase() == 'jpg' ||
        result['format']?.toString().toLowerCase() == 'jpeg' ||
        result['format']?.toString().toLowerCase() == 'png';
  }

  bool _toolEventResultLooksLikeMedia(ChatToolEvent event) {
    final result = event.result;
    if (result == null || result.trim().isEmpty) return false;
    return _looksLikeMediaResult(_tryDecodeJsonMap(result));
  }

  bool _shouldRunMediaVisionContinuation(
    String prompt,
    List<ChatToolEvent> events,
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) return false;
    final lower = prompt.toLowerCase();
    final asksVision = RegExp(
      r"\b(describe|see|look|inspect|analy[sz]e|what is|what's|read|discuss|comment|tell me about|use|identify)\b",
    ).hasMatch(lower);
    final toolCaptured = events.any((event) {
      final name = event.name.toLowerCase();
      return event.type == 'tool_result' &&
          (_isMediaToolName(name) || _toolEventResultLooksLikeMedia(event));
    });
    return toolCaptured && asksVision;
  }

  Future<String> _runImageContinuation({
    required String originalPrompt,
    required String model,
    required String imageBase64,
    required String mimeType,
  }) async {
    final gateway = GatewayService();
    final localLlm = LocalLlmService();
    final prompt = originalPrompt.trim().isEmpty
        ? 'Describe the image that was just captured.'
        : 'Use the image that was just captured to answer this request: $originalPrompt';
    try {
      final Stream<String> stream;
      if (ModelProviderCatalog.isLocalModelId(model)) {
        if (!localLlm.isVisionReady) {
          return 'Image captured and attached, but no local vision model is active to analyze it.';
        }
        stream =
            gateway.sendVisionMessage(prompt, imageBase64, mimeType: mimeType);
      } else {
        stream = gateway.sendCloudImageMessage(
          prompt,
          imageBase64,
          mimeType: mimeType,
        );
      }
      return _collectVisibleStream(stream);
    } catch (e) {
      return 'Image captured and attached, but vision analysis failed: $e';
    }
  }

  Future<String> _collectVisibleStream(Stream<String> stream) async {
    final buffer = StringBuffer();
    await for (final chunk in stream.timeout(
      const Duration(minutes: 3),
      onTimeout: (_) {},
    )) {
      if (chunk.startsWith('\x00')) continue;
      if (chunk.contains('[Error]')) {
        buffer.write(chunk.replaceAll('[Error]', '').trim());
        continue;
      }
      buffer.write(chunk);
    }
    return _stripAssistantControlMarkers(buffer.toString()).trim();
  }

  bool _shouldExplainLocation(String prompt) {
    final lower = prompt.toLowerCase();
    return lower.contains('where am i') ||
        lower.contains('where are we') ||
        lower.contains('where we are') ||
        (lower.contains('location') &&
            RegExp(r'\b(tell|say|explain|where|address|place)\b')
                .hasMatch(lower));
  }

  String? _locationSummary(Map<String, dynamic> result) {
    final lat = result['lat'] ?? result['latitude'];
    final lng = result['lng'] ?? result['longitude'];
    if (lat == null || lng == null) return null;
    final address = [
      result['address'],
      result['locality'],
      result['adminArea'],
      result['country'],
    ]
        .whereType<Object>()
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .join(', ');
    final accuracy = result['accuracy'];
    final where = address.isNotEmpty ? address : '$lat, $lng';
    return accuracy == null
        ? 'Location result: you appear to be near $where.'
        : 'Location result: you appear to be near $where (accuracy about ${accuracy}m).';
  }

  bool _responseAlreadyIncludesLocation(
    String response,
    Map<String, dynamic> result,
  ) {
    final lower = response.toLowerCase();
    if (lower.contains('location result') ||
        lower.contains('you appear to be') ||
        lower.contains('latitude') ||
        lower.contains('longitude')) {
      return true;
    }
    final lat = result['lat']?.toString();
    final lng = result['lng']?.toString();
    final latPrefix = lat?.substring(0, lat.length < 5 ? lat.length : 5);
    final lngPrefix = lng?.substring(0, lng.length < 5 ? lng.length : 5);
    return (latPrefix != null && lower.contains(latPrefix)) ||
        (lngPrefix != null && lower.contains(lngPrefix));
  }

  String _appendAssistantSection(String current, String addition) {
    final clean = addition.trim();
    if (clean.isEmpty) return current;
    if (current.trim().isEmpty) return clean;
    return '${current.trimRight()}\n\n$clean';
  }

  String _sanitizeForTts(String text) {
    var t = _stripAssistantControlMarkers(text);
    t = t.replaceAll(
        RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
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

  Future<void> _dispatchInlineAvatarGesture(String gesture) async {
    try {
      final frame = await AvatarCapability().handle('avatar.gesture', {
        'gesture': gesture,
        'source': 'assistant-inline-marker',
      });
      if (frame.error != null) {
        addDiagnostic(
          'Inline avatar gesture failed: '
          '${frame.error?['message'] ?? frame.error}',
        );
        return;
      }
      addDiagnostic(
        'Inline avatar gesture queued: '
        '${frame.payload?['gesture'] ?? gesture}',
      );
    } catch (e) {
      addDiagnostic('Inline avatar gesture error: $e');
    }
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
    if (_ttsHealth == ChatRuntimeTtsHealth.processing) {
      _setTtsHealth(ChatRuntimeTtsHealth.normal, notify: false);
    }
    notifyListeners();
    _processNextTtsInQueue();
  }

  Future<void> _processNextTtsInQueue() async {
    if (_isTtsSpeaking || _ttsQueue.isEmpty || _tts.isSpeaking) return;
    _isTtsSpeaking = true;
    if (_ttsHealth == ChatRuntimeTtsHealth.normal) {
      _setTtsHealth(ChatRuntimeTtsHealth.processing, notify: false);
    }
    notifyListeners();
    final sentence = _ttsQueue.removeAt(0);
    try {
      if (ModelProviderCatalog.isLocalModelId(_ttsModel)) {
        await _tts.speak(sentence);
        return;
      }
      final playback = await GatewayService().speakTextViaTalk(sentence);
      if (playback.played) {
        _setTtsHealth(ChatRuntimeTtsHealth.normal);
      }
      if (!playback.played && playback.allowNativeFallback) {
        _setTtsHealth(
          ChatRuntimeTtsHealth.degraded,
          message: playback.displayMessage ??
              'Gateway voice is unavailable; using local system TTS.',
        );
        await _tts.speak(sentence);
      } else if (!playback.played) {
        final message = playback.displayMessage ??
            'Gateway voice skipped playback (${playback.status}).';
        final degraded = playback.status.contains('backoff');
        addDiagnostic('TTS ${playback.status}: $message');
        _setTtsHealth(
          degraded
              ? ChatRuntimeTtsHealth.degraded
              : ChatRuntimeTtsHealth.failed,
          message: message,
        );
        _isTtsSpeaking = false;
        notifyListeners();
        _processNextTtsInQueue();
      }
    } catch (e) {
      addDiagnostic('TTS error: $e');
      _setTtsHealth(ChatRuntimeTtsHealth.failed, message: 'TTS error: $e');
      _isTtsSpeaking = false;
      notifyListeners();
      _processNextTtsInQueue();
    }
  }

  @override
  void dispose() {
    _mediaSubscription.cancel();
    _configurationRequestController.close();
    super.dispose();
  }
}
