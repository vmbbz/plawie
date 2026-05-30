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
  static const int _maxSelectedGatewayTools = 4;
  static const int _maxGatewayToolDescriptionChars = 220;
  static const int _maxGatewayToolSchemaChars = 900;
  static const int _maxGatewayToolProperties = 12;
  static const int _maxGatewayToolEnumValues = 24;

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
    final selectedTools = _selectToolsForTurn(tools, messages);

    // Context trimming:
    // The gateway sends a ~25K-char system prompt and full tool definitions.
    // Small models (Qwen 1.5B, 3B) overflow immediately. We:
    //   1. Replace or truncate the system prompt to a compact bridge prompt.
    //   2. Preserve recent assistant tool_calls and matching tool results.
    //   3. Keep only the latest bounded conversation slice.
    //   4. Forward only a small packed set of relevant tool schemas.
    final trimmedMessages = _trimForSmallModel(
      messages,
      toolsAvailable: selectedTools.isNotEmpty,
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
        tools: selectedTools,
      );
    } else {
      final buffer = StringBuffer();
      await for (final token in local.chat(
        chatTurn.history,
        chatTurn.userMessage,
        tools: selectedTools,
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

  List<Tool> _selectToolsForTurn(
    List<Tool> tools,
    List<Map<String, dynamic>> messages,
  ) {
    if (tools.isEmpty) return const <Tool>[];

    final query = _lastUserMessage(messages).toLowerCase();
    if (!_hasToolIntent(query)) return const <Tool>[];

    final scored = tools
        .map((tool) => MapEntry(tool, _scoreToolForTurn(tool, query)))
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selected = scored
        .take(_maxSelectedGatewayTools)
        .map((entry) => _compactGatewayTool(entry.key, query))
        .toList(growable: false);

    if (selected.isNotEmpty) return selected;

    final broad = tools.where((tool) {
      final name = tool.name.toLowerCase();
      return name.contains('node') ||
          name.contains('tool') ||
          name.contains('android') ||
          name.contains('device');
    }).take(1);

    return broad
        .map((tool) => _compactGatewayTool(tool, query))
        .toList(growable: false);
  }

  bool _hasToolIntent(String query) {
    if (query.trim().isEmpty) return false;
    return _containsAny(query, const [
      'tool',
      'skill',
      'capabilit',
      'can you do',
      'available',
      'use ',
      'run ',
      'open ',
      'browse',
      'web',
      'search',
      'camera',
      'photo',
      'picture',
      'snapshot',
      'battery',
      'charge',
      'location',
      'gps',
      'weather',
      'screen',
      'record',
      'canvas',
      'avatar',
      'gesture',
      'vibrate',
      'haptic',
      'sensor',
      'flash',
      'torch',
      'terminal',
      'shell',
      'command',
    ]);
  }

  int _scoreToolForTurn(Tool tool, String query) {
    final name = tool.name.toLowerCase();
    final description = tool.description.toLowerCase();
    final schemaProbe = tool.jsonSchema.length > 3000
        ? tool.jsonSchema.substring(0, 3000).toLowerCase()
        : tool.jsonSchema.toLowerCase();
    final haystack = '$name $description $schemaProbe';
    var score = 0;

    void addFor(List<String> queryTerms, List<String> toolTerms, int weight) {
      if (!_containsAny(query, queryTerms)) return;
      if (_containsAny(haystack, toolTerms)) score += weight;
    }

    addFor(const ['tool', 'skill', 'capabilit', 'available', 'can you do'],
        const ['tool', 'skill', 'node', 'android', 'device'], 8);
    addFor(const ['camera', 'photo', 'picture', 'snapshot', 'selfie', 'image'],
        const ['camera', 'photo', 'picture', 'snapshot', 'image'], 14);
    addFor(const ['battery', 'charge'],
        const ['battery', 'charge', 'device', 'android', 'node'], 12);
    addFor(const ['location', 'gps', 'where am i'],
        const ['location', 'gps', 'device', 'android', 'node'], 12);
    addFor(const ['weather', 'forecast'],
        const ['weather', 'forecast', 'location'], 12);
    addFor(const ['screen', 'record', 'screenshot', 'canvas', 'browser'],
        const ['screen', 'record', 'screenshot', 'canvas', 'browser'], 12);
    addFor(const ['avatar', 'gesture', 'wave', 'dance', 'emotion'],
        const ['avatar', 'gesture', 'emotion', 'node'], 12);
    addFor(const ['vibrate', 'haptic'],
        const ['vibrate', 'haptic', 'device', 'android', 'node'], 12);
    addFor(const ['sensor', 'accelerometer', 'gyro', 'gyroscope'],
        const ['sensor', 'accelerometer', 'gyro', 'device', 'node'], 12);
    addFor(const ['flash', 'torch', 'light'],
        const ['flash', 'torch', 'light', 'camera', 'node'], 12);
    addFor(const ['terminal', 'shell', 'command', 'exec'],
        const ['terminal', 'shell', 'command', 'exec'], 12);
    addFor(const ['open ', 'browse', 'url', 'web', 'search'],
        const ['open', 'browse', 'url', 'web', 'search', 'canvas'], 10);

    for (final token in _queryTokens(query)) {
      if (token.length >= 4 && haystack.contains(token)) score += 1;
    }
    if (name.contains('node') || name.contains('android')) score += 2;
    return score;
  }

  Tool _compactGatewayTool(Tool tool, String query) {
    final compactSchema = _compactToolSchema(tool.jsonSchema, query);
    var schemaJson = jsonEncode(compactSchema);
    if (schemaJson.length > _maxGatewayToolSchemaChars) {
      schemaJson = jsonEncode({
        'type': 'object',
        'additionalProperties': true,
      });
    }

    return Tool(
      name: tool.name,
      description: _truncateBridgeContent(
        tool.description,
        _maxGatewayToolDescriptionChars,
      ),
      jsonSchema: schemaJson,
    );
  }

  Map<String, dynamic> _compactToolSchema(String schemaJson, String query) {
    try {
      final decoded = jsonDecode(schemaJson);
      if (decoded is Map) {
        return _compactSchemaMap(decoded, query);
      }
    } catch (_) {}
    return {
      'type': 'object',
      'additionalProperties': true,
    };
  }

  Map<String, dynamic> _compactSchemaMap(Map raw, String query) {
    final result = <String, dynamic>{
      'type': raw['type']?.toString().isNotEmpty == true
          ? raw['type'].toString()
          : 'object',
    };

    final rawProperties = raw['properties'];
    if (rawProperties is Map && rawProperties.isNotEmpty) {
      final selectedKeys = _selectSchemaPropertyKeys(rawProperties, raw, query);
      final compactProperties = <String, dynamic>{};
      for (final key in selectedKeys) {
        final value = rawProperties[key];
        if (value is Map) {
          compactProperties[key] = _compactSchemaProperty(value, query);
        }
      }
      if (compactProperties.isNotEmpty) {
        result['properties'] = compactProperties;
      }

      final required = raw['required'];
      if (required is List) {
        final keptRequired = required
            .map((value) => value.toString())
            .where(compactProperties.containsKey)
            .toList(growable: false);
        if (keptRequired.isNotEmpty) result['required'] = keptRequired;
      }
    }

    if (!result.containsKey('properties')) {
      result['additionalProperties'] = true;
    }
    return result;
  }

  List<String> _selectSchemaPropertyKeys(
    Map properties,
    Map schema,
    String query,
  ) {
    final preferred = const [
      'action',
      'tool',
      'node',
      'name',
      'command',
      'input',
      'text',
      'query',
      'url',
      'location',
      'arguments',
      'args',
      'params',
      'invokeCommand',
      'invokeParamsJson',
      'durationMs',
      'quality',
      'gesture',
      'emotion',
    ];
    final required = schema['required'] is List
        ? (schema['required'] as List).map((value) => value.toString()).toList()
        : const <String>[];
    final keys = properties.keys.map((key) => key.toString()).toList();
    final selected = <String>[];

    void add(String key) {
      if (properties.containsKey(key) &&
          !selected.contains(key) &&
          selected.length < _maxGatewayToolProperties) {
        selected.add(key);
      }
    }

    for (final key in required) {
      add(key);
    }
    for (final key in preferred) {
      add(key);
    }

    final queryTokens = _queryTokens(query).toSet();
    final scored = keys.where((key) => !selected.contains(key)).map((key) {
      var score = 0;
      final lowerKey = key.toLowerCase();
      if (queryTokens.any(lowerKey.contains)) score += 4;
      final value = properties[key];
      if (value is Map) {
        final description = value['description']?.toString().toLowerCase();
        if (description != null &&
            queryTokens.any((token) => description.contains(token))) {
          score += 2;
        }
      }
      return MapEntry(key, score);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in scored) {
      if (selected.length >= _maxGatewayToolProperties) break;
      add(entry.key);
    }
    return selected;
  }

  Map<String, dynamic> _compactSchemaProperty(Map raw, String query) {
    final result = <String, dynamic>{};
    final type = raw['type'];
    if (type is String && type.isNotEmpty) result['type'] = type;

    final description = raw['description'];
    if (description is String && description.trim().isNotEmpty) {
      result['description'] = _truncateBridgeContent(description, 120);
    }

    final enumValues = raw['enum'];
    if (enumValues is List && enumValues.isNotEmpty) {
      final sortedEnumValues = List<Object?>.from(enumValues);
      final queryTokens = _queryTokens(query).toSet();
      sortedEnumValues.sort((a, b) {
        final left = _enumScore(a, queryTokens);
        final right = _enumScore(b, queryTokens);
        return right.compareTo(left);
      });
      result['enum'] = sortedEnumValues
          .take(_maxGatewayToolEnumValues)
          .map((value) =>
              value is num || value is bool ? value : value.toString())
          .toList(growable: false);
    }

    final items = raw['items'];
    if (items is Map) {
      final itemType = items['type'];
      if (itemType is String && itemType.isNotEmpty) {
        result['items'] = {'type': itemType};
      }
    }

    if (result.isEmpty) result['type'] = 'string';
    return result;
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }

  int _enumScore(Object? value, Set<String> queryTokens) {
    final text = value?.toString().toLowerCase() ?? '';
    var score = 0;
    for (final token in queryTokens) {
      if (text.contains(token)) score += 1;
    }
    return score;
  }

  Iterable<String> _queryTokens(String query) sync* {
    for (final token in query.split(RegExp(r'[^a-z0-9_]+'))) {
      if (token.length >= 3) yield token;
    }
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
