import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:clawa/services/paid_provider_http_client.dart';
import 'package:clawa/services/paid_provider_loopback_credential_service.dart';
import 'package:clawa/services/paid_provider_proxy_models.dart';
import 'package:clawa/services/paid_provider_proxy_service.dart';

void main() {
  test('preserves ordinary status, body bytes, and safe headers', () async {
    final expectedBody = utf8.encode('{"message":"héllo","ok":true}');
    late http.BaseRequest upstreamRequest;
    late List<int> upstreamRequestBody;
    final upstream = _FakeClient((request) async {
      upstreamRequest = request;
      upstreamRequestBody = await request.finalize().toBytes();
      return http.StreamedResponse(
        Stream<List<int>>.fromIterable([
          expectedBody.sublist(0, 8),
          expectedBody.sublist(8),
        ]),
        HttpStatus.unprocessableEntity,
        headers: {
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          'x-request-id': 'request-123',
          'x-ratelimit-remaining': '7',
          'set-cookie': 'must-not-cross-loopback',
          'connection': 'close',
        },
        contentLength: expectedBody.length,
      );
    });
    final relay = PaidProviderHttpClient(client: upstream);

    final result = await _throughProxy(
      relay,
      path: '/venice/v1/chat/completions',
      body: {
        'model': 'venice/model-a',
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
        'tools': [
          {
            'type': 'function',
            'function': {'name': 'device.status'}
          },
        ],
        'stream': false,
      },
      upstreamHeaders: const {'X-SIGN-IN-WITH-X': 'bounded-siwe'},
    );

    expect(result.statusCode, HttpStatus.unprocessableEntity);
    expect(result.bodyBytes, expectedBody);
    expect(result.headers['content-type'], contains('application/json'));
    expect(result.headers['x-request-id'], 'request-123');
    expect(result.headers['x-ratelimit-remaining'], '7');
    expect(result.headers, isNot(contains('set-cookie')));
    expect(result.headers, isNot(contains('connection')));

    expect(upstreamRequest.method, 'POST');
    expect(upstreamRequest.url,
        Uri.parse('https://api.venice.ai/api/v1/chat/completions'));
    expect(upstreamRequest.followRedirects, isFalse);
    expect(upstreamRequest.maxRedirects, 0);
    expect(upstreamRequest.headers['x-sign-in-with-x'], 'bounded-siwe');
    expect(upstreamRequest.headers, isNot(contains('sign-in-with-x')));
    expect(upstreamRequest.headers, isNot(contains('authorization')));
    final sent = jsonDecode(utf8.decode(upstreamRequestBody));
    expect(sent['model'], 'model-a');
    expect(sent['messages'][0]['content'], 'hello');
    expect(sent['tools'][0]['function']['name'], 'device.status');
  });

  test('preserves fragmented SSE, tool calls, usage, comments, and done bytes',
      () async {
    final payload = utf8.encode(
      ': keepalive\n\n'
      'data: {"choices":[{"delta":{"content":"Hi 👋"}}]}\n\n'
      'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"x\\":"}}]}}]}\n\n'
      'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"1}"}}]}}]}\n\n'
      'data: {"usage":{"prompt_tokens":4,"completion_tokens":2}}\n\n'
      'data: [DONE]\n\n',
    );
    final wave = utf8.encode('👋');
    final waveIndex = _indexOf(payload, wave);
    final upstream = _FakeClient((_) async => http.StreamedResponse(
          Stream<List<int>>.fromIterable([
            payload.sublist(0, waveIndex + 1),
            payload.sublist(waveIndex + 1, waveIndex + wave.length - 1),
            payload.sublist(waveIndex + wave.length - 1),
          ]),
          HttpStatus.ok,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        ));

    final result = await _throughProxy(
      PaidProviderHttpClient(client: upstream),
      path: '/blockrun/v1/chat/completions',
      body: {
        'model': 'blockrun/openai/model-a',
        'messages': [
          {'role': 'user', 'content': 'stream'},
        ],
        'stream': true,
      },
    );

    expect(result.statusCode, HttpStatus.ok);
    expect(result.bodyBytes, payload);
    expect(result.headers['content-type'], contains('text/event-stream'));
  });

  test('rejects upstream redirects without following them', () async {
    var calls = 0;
    final upstream = _FakeClient((request) async {
      calls++;
      expect(request.followRedirects, isFalse);
      return http.StreamedResponse(
        const Stream<List<int>>.empty(),
        HttpStatus.found,
        headers: {'location': 'https://evil.example/steal'},
      );
    });

    final result = await _throughProxy(
      PaidProviderHttpClient(client: upstream),
      path: '/blockrun/v1/models',
    );

    expect(calls, 1);
    expect(result.statusCode, HttpStatus.badGateway);
    expect(
        utf8.decode(result.bodyBytes), contains('upstream_redirect_rejected'));
    expect(utf8.decode(result.bodyBytes), isNot(contains('evil.example')));
  });

  test('rejects oversized response headers and known ordinary bodies',
      () async {
    final oversizedHeaders = _FakeClient((_) async => http.StreamedResponse(
          const Stream<List<int>>.empty(),
          HttpStatus.ok,
          headers: {'x-request-id': 'x' * 128},
        ));
    final headerResult = await _throughProxy(
      PaidProviderHttpClient(
        client: oversizedHeaders,
        maxResponseHeaderBytes: 64,
      ),
      path: '/venice/v1/models',
    );
    expect(headerResult.statusCode, HttpStatus.badGateway);
    expect(utf8.decode(headerResult.bodyBytes),
        contains('upstream_headers_too_large'));

    final oversizedBody = _FakeClient((_) async => http.StreamedResponse(
          Stream<List<int>>.multi((controller) {
            controller.add(List<int>.filled(65, 1));
            controller.close();
          }),
          HttpStatus.ok,
          headers: {'content-type': 'application/json'},
          contentLength: 65,
        ));
    final bodyResult = await _throughProxy(
      PaidProviderHttpClient(
        client: oversizedBody,
        maxOrdinaryResponseBytes: 64,
      ),
      path: '/blockrun/v1/models',
    );
    expect(bodyResult.statusCode, HttpStatus.badGateway);
    expect(utf8.decode(bodyResult.bodyBytes),
        contains('upstream_response_too_large'));
  });

  test('rejects an oversized SSE line before exposing response bytes',
      () async {
    final upstream = _FakeClient((_) async => http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('data: ${'x' * 65}\n\n')),
          HttpStatus.ok,
          headers: {'content-type': 'text/event-stream'},
        ));

    final result = await _throughProxy(
      PaidProviderHttpClient(client: upstream, maxSseLineBytes: 64),
      path: '/venice/v1/chat/completions',
      body: {
        'model': 'venice/model-a',
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
        'stream': true,
      },
    );

    expect(result.statusCode, HttpStatus.badGateway);
    expect(
        utf8.decode(result.bodyBytes), contains('upstream_sse_line_too_large'));
  });

  test('times out waiting for the first upstream byte', () async {
    final controller = StreamController<List<int>>();
    addTearDown(controller.close);
    final upstream = _FakeClient((_) async => http.StreamedResponse(
          controller.stream,
          HttpStatus.ok,
          headers: {'content-type': 'text/event-stream'},
        ));

    final result = await _throughProxy(
      PaidProviderHttpClient(
        client: upstream,
        firstByteTimeout: const Duration(milliseconds: 20),
      ),
      path: '/blockrun/v1/chat/completions',
      body: {
        'model': 'blockrun/model-a',
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
        'stream': true,
      },
    );

    expect(result.statusCode, HttpStatus.gatewayTimeout);
    expect(
        utf8.decode(result.bodyBytes), contains('upstream_first_byte_timeout'));
  });

  test('times out an upstream connection without retrying', () async {
    var calls = 0;
    final never = Completer<http.StreamedResponse>();
    final upstream = _FakeClient((_) {
      calls++;
      return never.future;
    });

    final result = await _throughProxy(
      PaidProviderHttpClient(
        client: upstream,
        connectTimeout: const Duration(milliseconds: 20),
      ),
      path: '/venice/v1/models',
    );

    expect(calls, 1);
    expect(result.statusCode, HttpStatus.gatewayTimeout);
    expect(utf8.decode(result.bodyBytes), contains('upstream_connect_timeout'));
  });

  test('reports an upstream disconnect before any response bytes', () async {
    final upstream = _FakeClient((_) async => http.StreamedResponse(
          Stream<List<int>>.error(StateError('socket closed')),
          HttpStatus.ok,
          headers: {'content-type': 'application/json'},
        ));

    final result = await _throughProxy(
      PaidProviderHttpClient(client: upstream),
      path: '/blockrun/v1/models',
    );

    expect(result.statusCode, HttpStatus.badGateway);
    expect(utf8.decode(result.bodyBytes), contains('upstream_stream_failed'));
    expect(utf8.decode(result.bodyBytes), isNot(contains('socket closed')));
  });

  test('enforces ordinary streaming size and SSE inactivity after first byte',
      () async {
    final ordinaryRelay = PaidProviderHttpClient(
      client: _FakeClient((_) async => http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              [1, 2, 3, 4],
              [5, 6, 7, 8],
            ]),
            HttpStatus.ok,
            headers: {'content-type': 'application/json'},
          )),
      maxOrdinaryResponseBytes: 6,
    );
    final ordinaryResponse = await ordinaryRelay.send(
      const PaidProviderProxyRequest(
        provider: PaidProviderId.blockrun,
        route: PaidProviderProxyRoute.blockrunModels,
      ),
    );
    await expectLater(
      ordinaryResponse.bodyStream,
      emitsInOrder([
        [1, 2, 3, 4],
        emitsError(isA<PaidProviderProxyException>()),
      ]),
    );
    ordinaryRelay.close();

    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () => controller.add(utf8.encode('data: first\n\n')),
    );
    addTearDown(controller.close);
    final sseRelay = PaidProviderHttpClient(
      client: _FakeClient((_) async => http.StreamedResponse(
            controller.stream,
            HttpStatus.ok,
            headers: {'content-type': 'text/event-stream'},
          )),
      streamingInactivityTimeout: const Duration(milliseconds: 20),
    );
    final sseResponse = await sseRelay.send(
      const PaidProviderProxyRequest(
        provider: PaidProviderId.venice,
        route: PaidProviderProxyRoute.veniceModels,
      ),
    );
    await expectLater(
      sseResponse.bodyStream,
      emitsInOrder([
        utf8.encode('data: first\n\n'),
        emitsError(isA<PaidProviderProxyException>()),
      ]),
    );
    sseRelay.close();
  });

  test('cancelling the relayed stream cancels the upstream subscription',
      () async {
    var cancelled = false;
    var aborted = false;
    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () => controller.add(utf8.encode('data: first\n\n')),
      onCancel: () => cancelled = true,
    );
    addTearDown(controller.close);
    final upstream = _FakeClient((request) async {
      final abortable = request as http.AbortableRequest;
      abortable.abortTrigger?.then((_) => aborted = true);
      return http.StreamedResponse(
        controller.stream,
        HttpStatus.ok,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final relay = PaidProviderHttpClient(client: upstream);
    final response = await relay.send(
      const PaidProviderProxyRequest(
        provider: PaidProviderId.blockrun,
        route: PaidProviderProxyRoute.blockrunModels,
      ),
    );
    final subscription = response.bodyStream!.listen((_) {});

    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    await Future<void>.delayed(Duration.zero);

    expect(cancelled, isTrue);
    expect(aborted, isTrue);
  });
}

Future<_HttpResult> _throughProxy(
  PaidProviderHttpClient relay, {
  required String path,
  Map<String, dynamic>? body,
  Map<String, String> upstreamHeaders = const {},
}) async {
  final credentials = PaidProviderLoopbackCredentialService();
  final proxy = PaidProviderProxyService(
    credentialService: credentials,
    port: 0,
    handler: (request) => relay.send(
      request,
      upstreamHeaders: upstreamHeaders,
    ),
  );
  await proxy.start();
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      body == null ? 'GET' : 'POST',
      proxy.uri.resolve(path),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${credentials.credentialForGatewayConfiguration()}',
    );
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close();
    final bytes = await response.fold<List<int>>(<int>[], (all, chunk) {
      all.addAll(chunk);
      return all;
    });
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });
    return _HttpResult(response.statusCode, headers, bytes);
  } finally {
    client.close(force: true);
    await proxy.stop();
    relay.close();
  }
}

int _indexOf(List<int> haystack, List<int> needle) {
  for (var index = 0; index <= haystack.length - needle.length; index++) {
    var matches = true;
    for (var offset = 0; offset < needle.length; offset++) {
      if (haystack[index + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return index;
  }
  return -1;
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._send);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _send;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);
}

class _HttpResult {
  const _HttpResult(this.statusCode, this.headers, this.bodyBytes);

  final int statusCode;
  final Map<String, String> headers;
  final List<int> bodyBytes;
}
