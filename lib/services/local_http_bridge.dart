import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:fllama/fllama.dart';

import 'local_llm_service.dart';

class LocalHttpBridge {
  static final LocalHttpBridge _instance = LocalHttpBridge._internal();
  factory LocalHttpBridge() => _instance;
  LocalHttpBridge._internal();

  HttpServer? _server;
  int? _activeRequestId;

  Future<void> start() async {
    if (_server != null) return;
    
    final app = Router();
    app.post('/v1/chat/completions', _handleChatCompletions);

    // Provide a simple health endpoint
    app.get('/api/tags', _handleTags);

    try {
      _server = await shelf_io.serve(app.call, '127.0.0.1', 11434, shared: true);
      debugPrint('[LocalHttpBridge] fllama HTTP bridge running on localhost:${_server!.port}');
    } catch (e) {
      debugPrint('[LocalHttpBridge] Failed to start HTTP bridge: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    if (_activeRequestId != null) {
      fllamaCancelInference(_activeRequestId!);
      _activeRequestId = null;
    }
  }

  Response _handleTags(Request request) {
    // Mock the Ollama /api/tags endpoint to keep the gateway health checks happy.
    final llmService = LocalLlmService();
    final modelName = llmService.activeModel != null ? '${llmService.activeModel!.id}:local' : 'mocked-model:latest';
    
    return Response.ok(
      jsonEncode({
        "models": [
          {
            "name": modelName,
            "modified_at": DateTime.now().toIso8601String(),
            "size": 1000000000,
          }
        ]
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleChatCompletions(Request request) async {
    final llmService = LocalLlmService();
    if (llmService.state.status != LocalLlmStatus.ready || llmService.activeModelPath == null) {
      return Response.internalServerError(
        body: jsonEncode({"error": "Local LLM is not ready"}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final payloadStr = await request.readAsString();
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;

      // Map messages
      final rawMessages = payload['messages'] as List? ?? [];
      final messages = rawMessages.map((msg) {
        final r = msg['role'] == 'assistant' 
            ? Role.assistant 
            : msg['role'] == 'system' ? Role.system : Role.user;
        final content = msg['content']?.toString() ?? '';
        return Message(r, content);
      }).toList();

      // Cancel any ongoing request before starting a new one
      if (_activeRequestId != null) {
        fllamaCancelInference(_activeRequestId!);
        _activeRequestId = null;
      }

      final isStreaming = payload['stream'] == true;

      // Map to fllama request
      final req = OpenAiRequest(
        modelPath: llmService.activeModelPath!,
        messages: messages,
        // Since we are proxying OpenClaw, we use a 4096 context bound safely 
        // to avoid model memory explosions
        contextSize: 4096, 
        maxTokens: payload['max_tokens'] ?? 1024,
        temperature: (payload['temperature'] as num?)?.toDouble() ?? 0.7,
      );

      final controller = StreamController<List<int>>();

      // Natively the Fllama plugin returns perfectly formatted OpenAI json delta responses.
      fllamaChat(req, (responseAcc, responseJson, done) {
        // SSE formatting mapping explicitly.
        if (isStreaming) {
          if (responseJson.isNotEmpty) {
             controller.add(utf8.encode('data: $responseJson\n\n'));
          }
          if (done) {
             controller.add(utf8.encode('data: [DONE]\n\n'));
             controller.close();
          }
        } else {
          // If not streaming, buffer chunks.
          // Wait, fllamaChat is designed heavily around SSE streaming natively. 
          // Assuming OpenClaw asks mostly in stream mode. If not streaming:
          if (done) {
            // responseAcc has the full accumulated response.
             final fullJson = jsonEncode({
               "choices": [{"message": {"role": "assistant", "content": responseAcc}}],
             });
             controller.add(utf8.encode(fullJson));
             controller.close();
          }
        }
      }).then((id) {
         _activeRequestId = id;
      });

      if (isStreaming) {
        return Response.ok(controller.stream, headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        });
      } else {
        return Response.ok(controller.stream, headers: {
          'Content-Type': 'application/json',
        });
      }

    } catch (e) {
      debugPrint('[LocalHttpBridge] Error processing chat completions: $e');
      return Response.internalServerError(
         body: jsonEncode({"error": e.toString()}),
         headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
