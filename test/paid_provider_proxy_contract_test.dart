import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/paid_provider_loopback_credential_service.dart';
import 'package:clawa/services/paid_provider_http_client.dart';
import 'package:clawa/services/paid_provider_proxy_models.dart';
import 'package:clawa/services/paid_provider_proxy_service.dart';

void main() {
  group('paid-provider request mapping', () {
    test('changes only the bounded provider model prefix', () {
      final original = <String, dynamic>{
        'model': 'venice/llama-3.3-70b',
        'messages': <Map<String, dynamic>>[
          {
            'role': 'system',
            'content': 'Preserve the gateway context and tools.',
          },
          {'role': 'user', 'content': 'hello'},
          {
            'role': 'assistant',
            'content': null,
            'tool_calls': [
              {
                'id': 'call_1',
                'type': 'function',
                'function': {'name': 'canvas.present', 'arguments': '{"x":1}'},
              },
              {
                'id': 'call_2',
                'type': 'function',
                'function': {'name': 'device.status', 'arguments': '{}'},
              },
            ],
          },
          {
            'role': 'tool',
            'tool_call_id': 'call_1',
            'content': '{"ok":true}',
          },
        ],
        'tools': <Map<String, dynamic>>[
          {
            'type': 'function',
            'function': {
              'name': 'canvas.present',
              'parameters': {
                'type': 'object',
                'properties': <String, dynamic>{},
                'required': <String>[],
              },
            },
          },
        ],
        'tool_choice': 'auto',
        'stream': true,
        'temperature': 0.25,
        'max_tokens': 1234,
        'stop': ['END', 'STOP'],
        'response_format': {'type': 'json_object'},
        'stream_options': {'include_usage': true},
        'metadata': {'mobile': true},
        'x-openclaw-extension': {
          'nested': [1, true, null, 'preserve'],
        },
      };
      final snapshot = jsonDecode(jsonEncode(original));

      final mapped = PaidProviderRequestMapper.mapChatRequest(
        original,
        provider: PaidProviderId.venice,
      );

      expect(mapped['model'], 'llama-3.3-70b');
      expect(
        Map<String, dynamic>.from(mapped)..remove('model'),
        Map<String, dynamic>.from(original)..remove('model'),
      );
      expect(original, snapshot,
          reason: 'mapping must not mutate gateway data');

      final blockrun = PaidProviderRequestMapper.mapChatRequest(
        {
          ...original,
          'model': 'blockrun/vendor/model-b',
        },
        provider: PaidProviderId.blockrun,
      );
      expect(blockrun['model'], 'vendor/model-b');
    });

    test('preserves the provider-local model id emitted by OpenClaw', () {
      final original = <String, dynamic>{
        'model': 'openai/gpt-5.5',
        'messages': <Map<String, dynamic>>[
          {'role': 'user', 'content': 'keep the exact Gateway payload'},
        ],
        'stream': true,
      };

      final mapped = PaidProviderRequestMapper.mapChatRequest(
        original,
        provider: PaidProviderId.blockrun,
      );

      expect(mapped, original);
      expect(identical(mapped, original), isFalse);
    });

    test('rejects missing, empty, and cross-provider model identifiers', () {
      for (final body in <Map<String, dynamic>>[
        <String, dynamic>{},
        {'model': 'venice/'},
        {'model': 'blockrun/model-a'},
        {'model': 42},
      ]) {
        expect(
          () => PaidProviderRequestMapper.mapChatRequest(
            body,
            provider: PaidProviderId.venice,
          ),
          throwsA(isA<PaidProviderProxyException>()),
        );
      }
    });
  });

  group('paid-provider proxy contract', () {
    late PaidProviderLoopbackCredentialService credentials;
    late PaidProviderProxyService proxy;
    late String credential;
    var handlerCalls = 0;

    setUp(() async {
      handlerCalls = 0;
      credentials = PaidProviderLoopbackCredentialService();
      credential = credentials.credentialForGatewayConfiguration();
      proxy = PaidProviderProxyService(
        credentialService: credentials,
        port: 0,
        maxRequestBodyBytes: 512,
        readyProviders: () => const {PaidProviderId.venice},
        handler: (request) async {
          handlerCalls++;
          return PaidProviderProxyResponse.json(
            statusCode: HttpStatus.ok,
            body: {
              'provider': request.provider.wireName,
              'path': request.route.path,
              if (request.gatewayModelId != null)
                'gatewayModelId': request.gatewayModelId,
              if (request.jsonBody != null) 'request': request.jsonBody,
            },
          );
        },
      );
      await proxy.start();
    });

    tearDown(() => proxy.stop());

    test('binds only to loopback and exposes authenticated health', () async {
      expect(proxy.uri.host, InternetAddress.loopbackIPv4.address);

      final unauthorized = await _request(proxy.uri.resolve('/health'));
      expect(unauthorized.statusCode, HttpStatus.unauthorized);
      expect(handlerCalls, 0);

      final healthy = await _request(
        proxy.uri.resolve('/health'),
        credential: credential,
      );
      expect(healthy.statusCode, HttpStatus.ok);
      expect(jsonDecode(healthy.body), containsPair('status', 'ok'));
      expect(
        jsonDecode(healthy.body),
        containsPair('readyProviders', ['venice']),
      );
      expect(healthy.body, isNot(contains(credential)));
    });

    test('rejects authentication before dispatching or parsing a body',
        () async {
      final response = await _request(
        proxy.uri.resolve('/venice/v1/chat/completions'),
        method: 'POST',
        credential: 'wrong-capability',
        body: '{ definitely not json',
      );

      expect(response.statusCode, HttpStatus.unauthorized);
      expect(handlerCalls, 0);
    });

    test('uses a fixed route table and disables responses endpoints', () async {
      final missing = await _request(
        proxy.uri.resolve('/venice/v1/unknown'),
        credential: credential,
      );
      expect(missing.statusCode, HttpStatus.notFound);

      final wrongMethod = await _request(
        proxy.uri.resolve('/venice/v1/models'),
        method: 'POST',
        credential: credential,
        body: '{}',
      );
      expect(wrongMethod.statusCode, HttpStatus.methodNotAllowed);
      expect(wrongMethod.headers[HttpHeaders.allowHeader], contains('GET'));

      final disabled = await _request(
        proxy.uri.resolve('/blockrun/v1/responses'),
        method: 'POST',
        credential: credential,
        body: '{}',
      );
      expect(disabled.statusCode, HttpStatus.notImplemented);
      expect(handlerCalls, 0);
    });

    test('forwards models and rewrites only the chat model identifier',
        () async {
      final models = await _request(
        proxy.uri.resolve('/venice/v1/models'),
        credential: credential,
      );
      expect(models.statusCode, HttpStatus.ok);

      final chat = await _request(
        proxy.uri.resolve('/blockrun/v1/chat/completions'),
        method: 'POST',
        credential: credential,
        body: jsonEncode({
          'model': 'model-a',
          'messages': [
            {'role': 'user', 'content': 'keep me'},
          ],
          'tools': [
            {
              'type': 'function',
              'function': {'name': 'keep_me'}
            },
          ],
          'stream': true,
        }),
      );
      final decoded = jsonDecode(chat.body) as Map<String, dynamic>;

      expect(chat.statusCode, HttpStatus.ok);
      expect(decoded['gatewayModelId'], 'blockrun/model-a');
      expect(decoded['request']['model'], 'model-a');
      expect(decoded['request']['messages'][0]['content'], 'keep me');
      expect(decoded['request']['tools'][0]['function']['name'], 'keep_me');
      expect(decoded['request']['stream'], isTrue);
      expect(handlerCalls, 2);
    });

    test('rejects oversized JSON before dispatch', () async {
      final response = await _request(
        proxy.uri.resolve('/venice/v1/chat/completions'),
        method: 'POST',
        credential: credential,
        body: jsonEncode({
          'model': 'venice/model-a',
          'messages': [
            {'role': 'user', 'content': 'x' * 1024},
          ],
        }),
      );

      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
      expect(handlerCalls, 0);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('rejects malformed JSON and non-JSON content before dispatch',
        () async {
      final malformed = await _request(
        proxy.uri.resolve('/venice/v1/chat/completions'),
        method: 'POST',
        credential: credential,
        body: '{broken',
      );
      expect(malformed.statusCode, HttpStatus.badRequest);

      final nonJson = await _request(
        proxy.uri.resolve('/venice/v1/chat/completions'),
        method: 'POST',
        credential: credential,
        body: 'model=venice/model-a',
        contentType: ContentType.text,
      );
      expect(nonJson.statusCode, HttpStatus.unsupportedMediaType);
      expect(handlerCalls, 0);
    });
  });

  test('refuses a non-loopback bind target', () async {
    final proxy = PaidProviderProxyService(
      credentialService: PaidProviderLoopbackCredentialService(),
      bindAddress: InternetAddress.anyIPv4,
      port: 0,
      handler: (_) async => PaidProviderProxyResponse.json(body: const {}),
    );

    await expectLater(proxy.start(), throwsStateError);
  });

  test('port collision attaches only to the authenticated Plawie proxy',
      () async {
    final credentials = PaidProviderLoopbackCredentialService();
    final owner = PaidProviderProxyService(
      credentialService: credentials,
      port: 0,
      handler: (_) async => PaidProviderProxyResponse.json(body: const {}),
    );
    await owner.start();

    final trustedCollision = PaidProviderProxyService(
      credentialService: credentials,
      port: owner.uri.port,
      handler: (_) async => PaidProviderProxyResponse.json(body: const {}),
    );
    final attachedUri = await trustedCollision.start();
    expect(attachedUri, owner.uri);
    expect(trustedCollision.isRunning, isTrue);
    expect(trustedCollision.ownsServer, isFalse);
    expect(trustedCollision.attachedToExisting, isTrue);

    final unknownCollision = PaidProviderProxyService(
      credentialService: PaidProviderLoopbackCredentialService(),
      port: owner.uri.port,
      handler: (_) async => PaidProviderProxyResponse.json(body: const {}),
    );
    await expectLater(unknownCollision.start(), throwsA(anything));
    expect(unknownCollision.isRunning, isFalse);

    await unknownCollision.stop();
    await trustedCollision.stop();
    await owner.stop();
  });

  test('allows only the exact HTTPS upstream origin for each provider', () {
    expect(
      PaidProviderUpstreamPolicy.validate(
        Uri.parse('https://api.venice.ai/api/v1/models'),
        provider: PaidProviderId.venice,
      ).host,
      'api.venice.ai',
    );
    expect(
      PaidProviderUpstreamPolicy.validate(
        Uri.parse('https://blockrun.ai/v1/chat/completions'),
        provider: PaidProviderId.blockrun,
      ).host,
      'blockrun.ai',
    );
    for (final uri in <Uri>[
      Uri.parse('http://api.venice.ai/api/v1/models'),
      Uri.parse('https://api.venice.ai.evil.example/api/v1/models'),
      Uri.parse('https://user@api.venice.ai/api/v1/models'),
      Uri.parse('https://api.venice.ai:444/api/v1/models'),
      Uri.parse('https://blockrun.ai/v1/models'),
    ]) {
      expect(
        () => PaidProviderUpstreamPolicy.validate(
          uri,
          provider: PaidProviderId.venice,
        ),
        throwsA(isA<PaidProviderProxyException>()),
      );
    }
  });
}

Future<_HttpResult> _request(
  Uri uri, {
  String method = 'GET',
  String? credential,
  String? body,
  ContentType? contentType,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    if (credential != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $credential',
      );
    }
    if (body != null) {
      request.headers.contentType = contentType ?? ContentType.json;
      request.headers.contentLength = utf8.encode(body).length;
      request.write(body);
    }
    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });
    return _HttpResult(
      response.statusCode,
      headers,
      responseBody,
    );
  } finally {
    client.close(force: true);
  }
}

class _HttpResult {
  const _HttpResult(this.statusCode, this.headers, this.body);

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}
