import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fllama/fllama.dart';
import 'local_llm_service.dart';
import 'model_execution_policy.dart';
import 'model_provider_catalog.dart';

enum NdkGatewayBridgeStatus {
  stopped,
  starting,
  running,
  error,
}

class NdkGatewayBridgeState {
  final NdkGatewayBridgeStatus status;
  final String url;
  final String? errorMessage;
  final int requestCount;

  const NdkGatewayBridgeState({
    this.status = NdkGatewayBridgeStatus.stopped,
    this.url = ModelProviderCatalog.plawieNdkBaseUrl,
    this.errorMessage,
    this.requestCount = 0,
  });

  NdkGatewayBridgeState copyWith({
    NdkGatewayBridgeStatus? status,
    String? url,
    String? errorMessage,
    bool clearError = false,
    int? requestCount,
  }) {
    return NdkGatewayBridgeState(
      status: status ?? this.status,
      url: url ?? this.url,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      requestCount: requestCount ?? this.requestCount,
    );
  }

  bool get isRunning => status == NdkGatewayBridgeStatus.running;
}

class _BridgeChatTurn {
  final List<Map<String, dynamic>> history;
  final String userMessage;

  const _BridgeChatTurn({
    required this.history,
    required this.userMessage,
  });
}

/// Experimental OpenAI-compatible loopback bridge for routing Gateway traffic
/// into the active fllama/NDK model without a PRoot daemon.
///
/// Context trimming: the OpenClaw gateway sends a large system prompt (~6k
/// tokens) plus tool definitions that would overflow a small model like
/// Qwen 1.5B. The bridge trims aggressively before forwarding to fllama.
class NdkGatewayBridgeService {
  static final NdkGatewayBridgeService _instance =
      NdkGatewayBridgeService._internal();

  factory NdkGatewayBridgeService() => _instance;
  NdkGatewayBridgeService._internal();

  static const int port = 11435;

  /// Maximum characters kept from the gateway system prompt before we replace
  /// it with a compact fallback. 0 = always replace with compact prompt.
  static const int _maxSystemPromptChars = 0;

  /// Maximum number of recent conversation turns (user+assistant pairs) to
  /// forward to fllama. Older turns are dropped to stay within context budget.
  static const int _maxHistoryTurns =
      ModelExecutionPolicy.ndkBridgeMaxHistoryTurns;

  final _stateController = StreamController<NdkGatewayBridgeState>.broadcast();
  NdkGatewayBridgeState _state = const NdkGatewayBridgeState();
  HttpServer? _server;

  Stream<NdkGatewayBridgeState> get stateStream => _stateController.stream;
  NdkGatewayBridgeState get state => _state;

  void _updateState(NdkGatewayBridgeState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  Future<bool> start({bool forceRestart = false}) async {
    if (_server != null && !forceRestart) return true;
    if (_server != null) await stop();

    _updateState(_state.copyWith(
      status: NdkGatewayBridgeStatus.starting,
      clearError: true,
    ));

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server!.listen(
        _handleRequest,
        onError: (Object error, StackTrace stack) {
          _updateState(_state.copyWith(
            status: NdkGatewayBridgeStatus.error,
            errorMessage: error.toString(),
          ));
        },
        cancelOnError: false,
      );
      _updateState(_state.copyWith(
        status: NdkGatewayBridgeStatus.running,
        url: ModelProviderCatalog.plawieNdkBaseUrl,
        clearError: true,
      ));
      return true;
    } catch (e) {
      _server = null;
      _updateState(_state.copyWith(
        status: NdkGatewayBridgeStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    _updateState(const NdkGatewayBridgeState());
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    try {
      final path = request.uri.path;
      if (request.method == 'GET' &&
          (path == '/health' || path == '/v1/health')) {
        await _writeJson(request.response, _healthPayload());
        return;
      }

      if (request.method == 'GET' && path == '/v1/models') {
        await _writeJson(request.response, _modelsPayload());
        return;
      }

      if (request.method == 'POST' && path == '/v1/chat/completions') {
        await _handleChatCompletions(request);
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await _writeJson(request.response, {
        'error': {
          'message': 'Route not found',
          'type': 'not_found',
        },
      });
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await _writeJson(request.response, {
          'error': {
            'message': e.toString(),
            'type': 'bridge_error',
          },
        });
      } catch (_) {
        try {
          await request.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _handleChatCompletions(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      request.response.statusCode = HttpStatus.badRequest;
      await _writeJson(request.response, {
        'error': {
          'message': 'Expected JSON object',
          'type': 'invalid_request',
        },
      });
      return;
    }

    final local = LocalLlmService();
    if (local.state.status != LocalLlmStatus.ready) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await _writeJson(request.response, {
        'error': {
          'message': 'NDK model is not ready',
          'type': 'model_not_ready',
          'status': local.state.status.name,
        },
      });
      return;
    }

    final messages = _parseMessages(decoded['messages']);
    final tools = _parseTools(decoded['tools']);

    // Context trimming:
    // The gateway sends a ~25K-char system prompt and full tool definitions.
    // Small models (Qwen 1.5B, 3B) overflow immediately. We:
    //   1. Replace or truncate the system prompt to a compact bridge prompt.
    //   2. Preserve recent assistant tool_calls and matching tool results.
    //   3. Keep only the latest bounded conversation slice.
    final trimmedMessages = _trimForSmallModel(
      messages,
      toolsAvailable: tools.isNotEmpty,
    );
    final chatTurn = _chatTurnFromTrimmedMessages(trimmedMessages);
    if (chatTurn.userMessage.trim().isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await _writeJson(request.response, {
        'error': {
          'message': 'No user message supplied',
          'type': 'invalid_request',
        },
      });
      return;
    }

    final requestId =
        'chatcmpl-plawie-${DateTime.now().microsecondsSinceEpoch}';
    final model = decoded['model']?.toString().trim().isNotEmpty == true
        ? decoded['model'].toString()
        : 'local-llm';
    final stream = decoded['stream'] == true;

    _updateState(_state.copyWith(requestCount: _state.requestCount + 1));

    if (stream) {
      await _streamChatResponse(
        request.response,
        requestId: requestId,
        model: model,
        history: chatTurn.history,
        userMessage: chatTurn.userMessage,
        tools: tools.isNotEmpty ? tools : null,
      );
    } else {
      final buffer = StringBuffer();
      await for (final token in local.chat(
        chatTurn.history,
        chatTurn.userMessage,
        tools: tools.isNotEmpty ? tools : null,
        yieldToolCalls: true,
      )) {
        if (token.startsWith('\x00TOOL_CALLS:') && token.endsWith('\x00')) {
          final callsJson = token.substring(12, token.length - 1);
          final calls = jsonDecode(callsJson) as List<dynamic>;
          await _writeJson(
            request.response,
            _chatCompletionToolPayload(
              requestId: requestId,
              model: model,
              toolCalls: calls,
            ),
          );
          return;
        }
        buffer.write(token);
      }
      await _writeJson(
        request.response,
        _chatCompletionPayload(
          requestId: requestId,
          model: model,
          content: buffer.toString(),
        ),
      );
    }
  }

  Future<void> _streamChatResponse(
    HttpResponse response, {
    required String requestId,
    required String model,
    required List<Map<String, dynamic>> history,
    required String userMessage,
    List<Tool>? tools,
  }) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType =
        ContentType('text', 'event-stream', charset: 'utf-8');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

    bool handledToolCall = false;
    await for (final token in LocalLlmService()
        .chat(history, userMessage, tools: tools, yieldToolCalls: true)) {
      if (token.startsWith('\x00TOOL_CALLS:') && token.endsWith('\x00')) {
        final callsJson = token.substring(12, token.length - 1);
        final calls = jsonDecode(callsJson) as List<dynamic>;
        response.write('data: ${jsonEncode(_chatToolCallsPayload(
          requestId: requestId,
          model: model,
          toolCalls: calls,
        ))}\n\n');
        await response.flush();
        handledToolCall = true;
        break; // Stream ends after tool call
      }
      response.write('data: ${jsonEncode(_chatDeltaPayload(
        requestId: requestId,
        model: model,
        content: token,
      ))}\n\n');
      await response.flush();
    }

    if (!handledToolCall) {
      response.write('data: ${jsonEncode(_chatDeltaPayload(
        requestId: requestId,
        model: model,
        content: '',
        finishReason: 'stop',
      ))}\n\n');
    }
    response.write('data: [DONE]\n\n');
    await response.close();
  }

  Map<String, dynamic> _healthPayload() {
    final local = LocalLlmService();
    return {
      'ok': local.state.status == LocalLlmStatus.ready,
      'bridge': 'plawie_ndk',
      'runtime': 'fllama',
      'status': local.state.status.name,
      'activeModelId': local.state.activeModelId,
      'baseUrl': ModelProviderCatalog.plawieNdkBaseUrl,
      'requestCount': _state.requestCount,
    };
  }

  Map<String, dynamic> _modelsPayload() {
    final local = LocalLlmService();
    final active = local.state.activeModelId ?? 'local-llm';
    return {
      'object': 'list',
      'data': [
        {
          'id': active,
          'object': 'model',
          'created': 0,
          'owned_by': 'plawie-ndk',
        }
      ],
    };
  }

  Map<String, dynamic> _chatCompletionPayload({
    required String requestId,
    required String model,
    required String content,
  }) {
    return {
      'id': requestId,
      'object': 'chat.completion',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': 'stop',
        }
      ],
    };
  }

  Map<String, dynamic> _chatCompletionToolPayload({
    required String requestId,
    required String model,
    required List<dynamic> toolCalls,
  }) {
    return {
      'id': requestId,
      'object': 'chat.completion',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'tool_calls': toolCalls},
          'finish_reason': 'tool_calls',
        }
      ],
    };
  }

  Map<String, dynamic> _chatToolCallsPayload({
    required String requestId,
    required String model,
    required List<dynamic> toolCalls,
  }) {
    return {
      'id': requestId,
      'object': 'chat.completion.chunk',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': model,
      'choices': [
        {
          'index': 0,
          'delta': {'tool_calls': toolCalls},
          'finish_reason': 'tool_calls',
        }
      ],
    };
  }

  Map<String, dynamic> _chatDeltaPayload({
    required String requestId,
    required String model,
    required String content,
    String? finishReason,
  }) {
    return {
      'id': requestId,
      'object': 'chat.completion.chunk',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': model,
      'choices': [
        {
          'index': 0,
          'delta': content.isEmpty ? <String, dynamic>{} : {'content': content},
          'finish_reason': finishReason,
        }
      ],
    };
  }

  List<Tool> _parseTools(dynamic raw) {
    if (raw is! List) return const <Tool>[];
    return raw
        .whereType<Map>()
        .map((m) {
          final function = m['function'];
          if (function is! Map) return null;
          return Tool(
            name: function['name']?.toString() ?? '',
            description: function['description']?.toString() ?? '',
            jsonSchema: jsonEncode(function['parameters'] ?? {}),
          );
        })
        .whereType<Tool>()
        .toList();
  }

  List<Map<String, dynamic>> _parseMessages(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((m) {
      final role = m['role']?.toString() ?? 'user';
      final parsed = <String, dynamic>{
        'role': role,
        'content': _stringifyContent(m['content']),
      };
      final toolCalls = m['tool_calls'];
      if (toolCalls is List && toolCalls.isNotEmpty) {
        parsed['tool_calls'] = toolCalls;
      }
      final toolCallId = m['tool_call_id'];
      if (toolCallId != null) parsed['tool_call_id'] = toolCallId.toString();
      final name = m['name'];
      if (name != null) parsed['name'] = name.toString();
      return parsed;
    }).where((m) {
      final content = (m['content'] as String).trim();
      final hasToolCalls = m['tool_calls'] is List;
      final hasToolMeta = m['tool_call_id'] != null ||
          (m['name'] as String?)?.isNotEmpty == true;
      return content.isNotEmpty || hasToolCalls || hasToolMeta;
    }).toList(growable: false);
  }

  /// Trim the message list to fit a small-context model:
  ///   - System prompt is replaced with a compact bridge prompt (or truncated
  ///     if _maxSystemPromptChars > 0 and the original is short enough).
  ///   - Recent tool calls and tool results are preserved.
  ///   - Conversation is capped to a small recent window.
  List<Map<String, dynamic>> _trimForSmallModel(
    List<Map<String, dynamic>> messages, {
    required bool toolsAvailable,
  }) {
    // 1. Separate system from conversation.
    String systemContent = ModelExecutionPolicy.ndkBridgeCompactPrompt(
      toolsAvailable: toolsAvailable,
    );
    final convo = <Map<String, dynamic>>[];
    final toolNamesById = <String, String>{};

    for (final msg in messages) {
      final role = msg['role'] as String;
      if (role == 'system') {
        final original = msg['content'] as String;
        if (_maxSystemPromptChars > 0 &&
            original.length <= _maxSystemPromptChars) {
          systemContent = original;
        }
        // else keep compact prompt
        continue;
      }
      final normalized = <String, dynamic>{...msg};

      if (role == 'assistant') {
        final toolCalls = normalized['tool_calls'];
        if (toolCalls is List) {
          for (final call in toolCalls.whereType<Map>()) {
            final id = call['id']?.toString();
            final function = call['function'];
            final name = function is Map ? function['name']?.toString() : null;
            if (id != null &&
                id.isNotEmpty &&
                name != null &&
                name.isNotEmpty) {
              toolNamesById[id] = name;
            }
          }
        }
      }

      if (role == 'tool' || role == 'function') {
        final toolCallId = normalized['tool_call_id']?.toString();
        final name = normalized['name']?.toString();
        if ((name == null || name.isEmpty) &&
            toolCallId != null &&
            toolNamesById.containsKey(toolCallId)) {
          normalized['name'] = toolNamesById[toolCallId];
        }
        normalized['content'] = _truncateBridgeContent(
          normalized['content']?.toString() ?? '',
          ModelExecutionPolicy.ndkBridgeMaxToolResultChars,
        );
      }

      convo.add(normalized);
    }

    // 2. Keep only the last bounded slice from the conversation. A recent tool
    //    turn can include user + assistant tool_calls + tool result.
    final List<Map<String, dynamic>> trimmed;
    final maxConversationMessages = _maxHistoryTurns * 3 + 2;
    if (_maxHistoryTurns > 0 && convo.length > maxConversationMessages) {
      trimmed = convo.sublist(convo.length - maxConversationMessages);
    } else {
      trimmed = List.of(convo);
    }

    // 3. Prepend compact system prompt.
    return [
      {'role': 'system', 'content': systemContent},
      ...trimmed,
    ];
  }

  _BridgeChatTurn _chatTurnFromTrimmedMessages(
    List<Map<String, dynamic>> messages,
  ) {
    if (messages.isEmpty) {
      return const _BridgeChatTurn(
        history: <Map<String, dynamic>>[],
        userMessage: '',
      );
    }
    if (!messages.any((m) => m['role'] != 'system')) {
      return const _BridgeChatTurn(
        history: <Map<String, dynamic>>[],
        userMessage: '',
      );
    }

    final last = messages.last;
    final role = last['role'] as String? ?? 'user';
    if (role == 'user') {
      return _BridgeChatTurn(
        history: messages.length > 1
            ? messages.sublist(0, messages.length - 1)
            : <Map<String, dynamic>>[],
        userMessage: last['content'] as String? ?? '',
      );
    }

    if (role == 'tool' || role == 'function') {
      final toolName = last['name'] as String?;
      final target = toolName != null && toolName.isNotEmpty
          ? 'the $toolName tool result'
          : 'the tool result';
      return _BridgeChatTurn(
        history: messages,
        userMessage:
            'Using $target above, answer the user now. Do not repeat the same tool call unless another real action is required.',
      );
    }

    final lastUser = _lastUserMessage(messages);
    return _BridgeChatTurn(
      history: messages,
      userMessage: lastUser.isNotEmpty ? lastUser : '',
    );
  }

  String _lastUserMessage(List<Map<String, dynamic>> messages) {
    for (final message in messages.reversed) {
      if (message['role'] == 'user') return message['content'] as String;
    }
    return messages.isNotEmpty ? messages.last['content'] as String : '';
  }

  String _stringifyContent(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .map((part) {
            if (part is Map) {
              final text = part['text'];
              if (text is String) return text;
              final type = part['type'];
              if (type is String) return '[unsupported $type content]';
            }
            return part?.toString() ?? '';
          })
          .where((part) => part.trim().isNotEmpty)
          .join('\n');
    }
    return content?.toString() ?? '';
  }

  String _truncateBridgeContent(String input, int maxChars) {
    final clean = input.trim();
    if (clean.length <= maxChars) return clean;
    return '${clean.substring(0, maxChars - 24).trim()} ... [truncated]';
  }

  void _addCorsHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.headers.set(
      HttpHeaders.accessControlAllowMethodsHeader,
      'GET, POST, OPTIONS',
    );
    response.headers.set(
      HttpHeaders.accessControlAllowHeadersHeader,
      'authorization, content-type',
    );
  }

  Future<void> _writeJson(
    HttpResponse response,
    Map<String, dynamic> payload,
  ) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(payload));
    await response.close();
  }
}
