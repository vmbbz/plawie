import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../native_skill_adapter.dart';
import '../skill_execution_descriptor.dart';

class HttpEndpointAdapter implements NativeSkillAdapter {
  final http.Client? client;

  const HttpEndpointAdapter({this.client});

  @override
  bool canExecute(SkillExecutionDescriptor descriptor) {
    return descriptor.runtime == SkillExecutionRuntime.http &&
        descriptor.mode == SkillExecutionMode.httpEndpoint &&
        Uri.tryParse(descriptor.entrypoint)?.hasAbsolutePath == true;
  }

  @override
  Future<NativeSkillAdapterResult> execute(
    NativeSkillExecutionRequest request,
  ) async {
    final descriptor = request.descriptor;
    if (!canExecute(descriptor)) {
      return NativeSkillAdapterResult(
        ok: false,
        raw: const <String, dynamic>{},
        durationMs: 0,
        error:
            'Unsupported skill descriptor: ${descriptor.runtime.name}/${descriptor.mode.name}',
      );
    }

    final startedAt = DateTime.now();
    final ownedClient = client == null ? http.Client() : null;
    final activeClient = client ?? ownedClient!;
    final responses = <Map<String, dynamic>>[];
    final output = <String, dynamic>{};
    var ok = true;
    String? error;

    try {
      for (final action in request.actions) {
        final method = _methodForAction(descriptor, action);
        final response = await _send(
          activeClient,
          descriptor.entrypoint,
          method,
          action.args,
        ).timeout(request.timeout);
        final decoded = _decodeBody(response.body);
        final responseOk =
            response.statusCode >= 200 && response.statusCode < 300;
        if (!responseOk) {
          ok = false;
          error ??=
              'HTTP $method ${response.statusCode} for ${descriptor.entrypoint}';
        }
        responses.add({
          'label': action.label,
          'method': method,
          'statusCode': response.statusCode,
          'body': decoded,
        });
        output[action.label] = decoded;
      }
    } on TimeoutException {
      ok = false;
      error =
          '${descriptor.skillId} timed out after ${request.timeout.inSeconds} seconds.';
    } catch (err) {
      ok = false;
      error = err.toString();
    } finally {
      ownedClient?.close();
    }

    final completedAt = DateTime.now();
    return NativeSkillAdapterResult(
      ok: ok,
      data: ok ? output : (output.isEmpty ? null : output),
      raw: {'responses': responses},
      error: error,
      durationMs: completedAt.difference(startedAt).inMilliseconds,
    );
  }

  static Future<http.Response> _send(
    http.Client client,
    String entrypoint,
    String method,
    Map<String, dynamic> args,
  ) {
    final uri = Uri.parse(entrypoint);
    if (method == 'POST') {
      return client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(args),
      );
    }
    if (method == 'PUT') {
      return client.put(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(args),
      );
    }
    if (method == 'DELETE') {
      return client.delete(_uriWithQuery(uri, args));
    }
    return client.get(_uriWithQuery(uri, args));
  }

  static Uri _uriWithQuery(Uri uri, Map<String, dynamic> args) {
    if (args.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      for (final entry in args.entries) entry.key: entry.value.toString(),
    });
  }

  static String _methodForAction(
    SkillExecutionDescriptor descriptor,
    SkillExecutionAction action,
  ) {
    for (final method in descriptor.methods) {
      if (method.name == action.method) {
        final description = method.description.trim().toUpperCase();
        if (description.startsWith('POST ')) return 'POST';
        if (description.startsWith('PUT ')) return 'PUT';
        if (description.startsWith('DELETE ')) return 'DELETE';
        return 'GET';
      }
    }
    final fallback = descriptor.methods.isEmpty
        ? ''
        : descriptor.methods.first.description.trim().toUpperCase();
    return fallback.startsWith('POST ') ? 'POST' : 'GET';
  }

  static dynamic _decodeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return trimmed;
    }
  }
}
