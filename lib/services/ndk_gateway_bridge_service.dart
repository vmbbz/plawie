import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_llm_service.dart';
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

/// Experimental OpenAI-compatible loopback bridge for routing Gateway traffic
/// into the active fllama/NDK model without a PRoot daemon.
class NdkGatewayBridgeService {
  static final NdkGatewayBridgeService _instance =
      NdkGatewayBridgeService._internal();

  factory NdkGatewayBridgeService() => _instance;
  NdkGatewayBridgeService._internal();

  static const int port = 11435;

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
    final userMessage = _lastUserMessage(messages);
    if (userMessage.trim().isEmpty) {
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
    final history = messages.length > 1
        ? messages.sublist(0, messages.length - 1)
        : <Map<String, dynamic>>[];

    _updateState(_state.copyWith(requestCount: _state.requestCount + 1));

    if (stream) {
      await _streamChatResponse(
        request.response,
        requestId: requestId,
        model: model,
        history: history,
        userMessage: userMessage,
      );
    } else {
      final buffer = StringBuffer();
      await for (final token in local.chat(history, userMessage)) {
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
  }) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType =
        ContentType('text', 'event-stream', charset: 'utf-8');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

    await for (final token in LocalLlmService().chat(history, userMessage)) {
      response.write('data: ${jsonEncode(_chatDeltaPayload(
        requestId: requestId,
        model: model,
        content: token,
      ))}\n\n');
      await response.flush();
    }

    response.write('data: ${jsonEncode(_chatDeltaPayload(
      requestId: requestId,
      model: model,
      content: '',
      finishReason: 'stop',
    ))}\n\n');
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

  List<Map<String, dynamic>> _parseMessages(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((m) {
          final role = m['role']?.toString() ?? 'user';
          return {
            'role': role,
            'content': _stringifyContent(m['content']),
          };
        })
        .where((m) => (m['content'] as String).trim().isNotEmpty)
        .toList(growable: false);
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
