import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clawa/services/dynamic_model_catalog.dart';
import 'package:clawa/services/preferences_service.dart';
import 'package:clawa/services/provider_model_discovery_service.dart';

void main() {
  late PreferencesService preferences;
  late DynamicModelCatalogRepository repository;
  final now = DateTime.utc(2026, 8, 5, 12);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = PreferencesService();
    await preferences.init();
  });

  setUp(() async {
    repository = DynamicModelCatalogRepository(preferences: preferences);
    await repository.clear();
  });

  test('parses OpenRouter metadata and keeps model IDs namespaced', () async {
    final client = _FakeClient((request) async {
      expect(request.url.path, '/api/v1/models');
      expect(request.headers['authorization'], 'Bearer test-key');
      return _jsonResponse(<String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{
            'id': 'openai/gpt-5.4',
            'name': 'GPT 5.4',
            'description': 'Reasoning model',
            'context_length': 128000,
            'top_provider': <String, dynamic>{
              'max_completion_tokens': 16384,
            },
            'architecture': <String, dynamic>{
              'input_modalities': <String>['text', 'image'],
              'output_modalities': <String>['text'],
            },
            'supported_parameters': <String>['tools', 'temperature'],
          },
          <String, dynamic>{'id': 'text-embedding-3-small'},
        ],
      }, headers: <String, String>{
        'etag': 'router-v1'
      });
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
    );

    final snapshot = await service.refreshProvider(
      'openrouter',
      apiKey: 'test-key',
    );
    final provider = snapshot.providers
        .firstWhere((provider) => provider.id == 'openrouter');
    final model = provider.models.single;

    expect(model.id, 'openrouter/openai/gpt-5.4');
    expect(model.providerModelId, 'openai/gpt-5.4');
    expect(model.supportsToolCalls, isTrue);
    expect(model.supportsVision, isTrue);
    expect(model.advertisedContextWindow, 128000);
    expect(model.advertisedMaxOutputTokens, 16384);
    expect(provider.connectionState, DynamicProviderConnectionState.connected);
    expect(provider.etag, 'router-v1');
    expect(snapshot.encode(), isNot(contains('test-key')));
  });

  test('uses the Google query-key contract without putting the key in headers',
      () async {
    final client = _FakeClient((request) async {
      expect(request.url.path, '/v1beta/models');
      expect(request.url.queryParameters['key'], 'google-test-key');
      expect(request.headers.containsKey('authorization'), isFalse);
      return _jsonResponse(<String, dynamic>{
        'models': <dynamic>[
          <String, dynamic>{
            'name': 'models/gemini-2.5-pro',
            'displayName': 'Gemini 2.5 Pro',
            'inputTokenLimit': 1048576,
            'outputTokenLimit': 65536,
            'supportedGenerationMethods': <String>['generateContent'],
          },
        ],
      });
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
    );

    final snapshot = await service.refreshProvider(
      'google',
      apiKey: 'google-test-key',
    );
    final model = snapshot.providers
        .firstWhere((provider) => provider.id == 'google')
        .models
        .single;

    expect(model.id, 'google/gemini-2.5-pro');
    expect(model.providerModelId, 'gemini-2.5-pro');
    expect(model.advertisedContextWindow, 1048576);
    expect(model.advertisedMaxOutputTokens, 65536);
    expect(snapshot.encode(), isNot(contains('google-test-key')));
  });

  test('uses ETag and preserves cached models on a 304 response', () async {
    var call = 0;
    final client = _FakeClient((request) async {
      call++;
      if (call == 2) {
        expect(request.headers['if-none-match'], 'router-v1');
        return http.Response('', 304,
            headers: <String, String>{'etag': 'router-v1'});
      }
      return _jsonResponse(<String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{'id': 'openai/gpt-5'}
        ],
      }, headers: <String, String>{
        'etag': 'router-v1'
      });
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
    );

    final first = await service.refreshProvider('openrouter', apiKey: 'key');
    final second = await service.refreshProvider('openrouter', apiKey: 'key');

    expect(call, 2);
    expect(
      second.providers
          .firstWhere((provider) => provider.id == 'openrouter')
          .models
          .single
          .id,
      first.providers
          .firstWhere((provider) => provider.id == 'openrouter')
          .models
          .single
          .id,
    );
  });

  test('persists a safe provider error without deleting the static fallback',
      () async {
    final client = _FakeClient((request) async => http.Response('', 401));
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
    );

    await expectLater(
      service.refreshProvider('openrouter', apiKey: 'test-key'),
      throwsA(
        isA<ProviderDiscoveryException>().having(
          (error) => error.code,
          'code',
          'authentication_required',
        ),
      ),
    );
    final snapshot = await repository.load(now: now);
    final provider = snapshot!.providers
        .firstWhere((provider) => provider.id == 'openrouter');

    expect(provider.connectionState, DynamicProviderConnectionState.error);
    expect(provider.models, isNotEmpty);
    expect(snapshot.encode(), isNot(contains('test-key')));
  });

  test('marks a provider as needing configuration without making a request',
      () async {
    final client = _FakeClient((request) async {
      fail('A missing key must not make a network request.');
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
    );

    await expectLater(
      service.refreshProvider('openrouter'),
      throwsA(
        isA<ProviderDiscoveryException>().having(
          (error) => error.code,
          'code',
          'configuration_required',
        ),
      ),
    );
    final snapshot = await repository.load(now: now);
    expect(
      snapshot!.providers
          .firstWhere((provider) => provider.id == 'openrouter')
          .connectionState,
      DynamicProviderConnectionState.needsConfiguration,
    );
    expect(client.calls, 0);
  });

  test('converts a timed-out endpoint into a safe cached error', () async {
    final client = _FakeClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return _jsonResponse(<String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{'id': 'gpt-5'}
        ],
      });
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
      timeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      service.refreshProvider('openai', apiKey: 'key'),
      throwsA(
        isA<ProviderDiscoveryException>().having(
          (error) => error.code,
          'code',
          'timed_out',
        ),
      ),
    );
    final snapshot = await repository.load(now: now);
    expect(
      snapshot!.providers
          .firstWhere((provider) => provider.id == 'openai')
          .connectionState,
      DynamicProviderConnectionState.error,
    );
  });

  test('deduplicates concurrent refreshes per provider', () async {
    final gate = Completer<void>();
    final client = _FakeClient((request) async {
      await gate.future;
      return _jsonResponse(<String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{'id': 'gpt-5'}
        ],
      });
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
    );

    final first = service.refreshProvider('openai', apiKey: 'first');
    final second = service.refreshProvider('openai', apiKey: 'second');
    gate.complete();
    await Future.wait(<Future<DynamicCatalogSnapshot>>[first, second]);

    expect(client.calls, 1);
  });
}

http.Response _jsonResponse(
  Map<String, dynamic> body, {
  Map<String, String> headers = const <String, String>{},
}) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: <String, String>{'content-type': 'application/json', ...headers},
  );
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.Response> Function(http.Request request) handler;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
