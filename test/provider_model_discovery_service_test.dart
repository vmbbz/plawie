import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clawa/services/dynamic_model_catalog.dart';
import 'package:clawa/services/model_execution_policy.dart';
import 'package:clawa/services/model_provider_catalog.dart';
import 'package:clawa/services/native_bridge.dart';
import 'package:clawa/services/preferences_service.dart';
import 'package:clawa/services/provider_model_discovery_service.dart';
import 'package:clawa/services/venice_wallet_auth_service.dart';

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
            'created': DateTime.utc(2026, 8, 1).millisecondsSinceEpoch ~/ 1000,
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
    expect(model.toolPolicy, ModelToolPolicy.variable);
    expect(model.chatReadiness, ModelChatReadiness.providerAdvertised);
    expect(model.toolReadiness, ModelToolReadiness.providerAdvertised);
    expect(model.agentReady, isFalse);
    expect(model.supportsVision, isTrue);
    expect(model.advertisedContextWindow, 128000);
    expect(model.advertisedMaxOutputTokens, 16384);
    expect(model.providerCreatedAt, DateTime.utc(2026, 8, 1));
    expect(provider.connectionState, DynamicProviderConnectionState.connected);
    expect(provider.etag, 'router-v1');
    expect(snapshot.encode(), isNot(contains('test-key')));
  });

  test('preserves upcoming retirement and disables an expired model', () async {
    final client = _FakeClient((request) async => _jsonResponse(
          <String, dynamic>{
            'data': <dynamic>[
              <String, dynamic>{
                'id': 'provider/upcoming',
                'expiration_date': '2026-08-16',
              },
              <String, dynamic>{
                'id': 'provider/expired',
                'expiration_date': '2026-08-01',
              },
            ],
          },
        ));
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
    );

    final snapshot = await service.refreshProvider(
      'openrouter',
      apiKey: 'test-key',
    );
    final models = snapshot.providers
        .firstWhere((provider) => provider.id == 'openrouter')
        .models;
    final upcoming = models
        .firstWhere((model) => model.id == 'openrouter/provider/upcoming');
    final expired =
        models.firstWhere((model) => model.id == 'openrouter/provider/expired');

    expect(upcoming.deprecationDate, DateTime.utc(2026, 8, 16));
    expect(upcoming.liveAvailable, isTrue);
    expect(expired.deprecationDate, DateTime.utc(2026, 8, 1));
    expect(expired.liveAvailable, isFalse);
    expect(expired.unavailableReason, contains('retired'));
  });

  test('discovers Venice with a fresh bounded wallet identity', () async {
    const address = '0x857b06519E91e3A54538791bDbb0E22373e36b66';
    var signedRequests = 0;
    final auth = VeniceWalletAuthService(
      clock: () => now,
      nonceFactory: () => 'AbCdEf123456',
      walletStatus: () async => _healthyWallet(address),
      signer: (request) async {
        signedRequests++;
        return <String, dynamic>{
          'payer': address,
          'signature': '0x${'a' * 130}',
          'message': _veniceMessage(address, request),
        };
      },
    );
    final client = _FakeClient((request) async {
      expect(
        request.url,
        Uri.parse('https://api.venice.ai/api/v1/models?type=text'),
      );
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 0);
      expect(request.headers['x-sign-in-with-x'], isNotEmpty);
      expect(request.headers.containsKey('sign-in-with-x'), isFalse);
      expect(request.headers.containsKey('authorization'), isFalse);
      return _jsonResponse(<String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{
            'id': 'llama-3.3-70b',
            'type': 'text',
            'model_spec': <String, dynamic>{
              'name': 'Llama 3.3 70B',
              'availableContextTokens': 131072,
              'capabilities': <String, dynamic>{
                'supportsFunctionCalling': true,
                'supportsVision': false,
                'supportsReasoning': true,
              },
            },
          },
          <String, dynamic>{'id': 'stable-diffusion-xl', 'type': 'image'},
        ],
      }, headers: <String, String>{
        'etag': 'venice-v1'
      });
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
      veniceWalletAuth: auth,
    );

    final snapshot = await service.refreshProvider('venice');
    final provider =
        snapshot.providers.firstWhere((record) => record.id == 'venice');
    final model = provider.models.single;

    expect(signedRequests, 1);
    expect(
        provider.authenticationMode, ProviderAuthenticationMode.walletIdentity);
    expect(provider.requiresApiKey, isFalse);
    expect(provider.connectionState, DynamicProviderConnectionState.unknown);
    expect(provider.catalogState, DynamicProviderCatalogState.fresh);
    expect(provider.lastRefreshedAt, now);
    expect(provider.etag, 'venice-v1');
    expect(model.id, 'venice/llama-3.3-70b');
    expect(model.providerModelId, 'llama-3.3-70b');
    expect(model.label, 'Llama 3.3 70B');
    expect(model.supportsToolCalls, isTrue);
    expect(model.toolPolicy, ModelToolPolicy.variable);
    expect(model.chatReadiness, ModelChatReadiness.providerAdvertised);
    expect(model.toolReadiness, ModelToolReadiness.providerAdvertised);
    expect(model.agentReady, isFalse);
    expect(model.supportsVision, isFalse);
    expect(model.capabilities, contains('reasoning'));
    expect(model.advertisedContextWindow, 131072);
    expect(model.liveAvailable, isTrue);
  });

  test('rejects Venice redirects without forwarding the wallet identity',
      () async {
    const address = '0x857b06519E91e3A54538791bDbb0E22373e36b66';
    final auth = VeniceWalletAuthService(
      clock: () => now,
      nonceFactory: () => 'AbCdEf123456',
      walletStatus: () async => _healthyWallet(address),
      signer: (request) async => <String, dynamic>{
        'payer': address,
        'signature': '0x${'a' * 130}',
        'message': _veniceMessage(address, request),
      },
    );
    final client = _FakeClient((request) async => http.Response(
          '',
          302,
          headers: const <String, String>{
            'location': 'https://attacker.example/models',
          },
        ));
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
      veniceWalletAuth: auth,
    );

    await expectLater(
      service.refreshProvider('venice'),
      throwsA(isA<ProviderDiscoveryException>().having(
        (error) => error.code,
        'code',
        'redirect_rejected',
      )),
    );
    expect(client.calls, 1);
  });

  test('keeps Venice fallback unavailable when the secure wallet is absent',
      () async {
    final auth = VeniceWalletAuthService(
      walletStatus: () async => SecureWalletStatus.absent(),
      signer: (_) async => fail('An absent wallet must not sign.'),
    );
    final client = _FakeClient((request) async {
      fail('An absent wallet must not reach Venice.');
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
      veniceWalletAuth: auth,
    );

    await expectLater(
      service.refreshProvider('venice'),
      throwsA(isA<ProviderDiscoveryException>().having(
        (error) => error.code,
        'code',
        'wallet_not_ready',
      )),
    );
    final snapshot = await repository.load(now: now);
    final provider =
        snapshot!.providers.firstWhere((record) => record.id == 'venice');
    expect(client.calls, 0);
    expect(
        provider.connectionState, DynamicProviderConnectionState.unavailable);
    expect(provider.catalogState, DynamicProviderCatalogState.offlineFallback);
    expect(provider.errorMessage, contains('wallet'));
    expect(provider.models.single.liveAvailable, isFalse);
  });

  test('discovers public BlockRun models and removes unavailable duplicates',
      () async {
    final client = _FakeClient((request) async {
      expect(request.url, Uri.parse('https://blockrun.ai/api/v1/models'));
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(request.headers.containsKey('payment-signature'), isFalse);
      return _jsonResponse(<String, dynamic>{
        'models': <dynamic>[
          <String, dynamic>{
            'id': 'openai/gpt-5-mini',
            'name': 'GPT-5 Mini',
            'description': 'Fast tool model',
            'context_window': 400000,
            'max_output': 128000,
            'categories': <String>['text', 'tools'],
            'available': true,
          },
          <String, dynamic>{
            'id': 'openai/gpt-5-mini',
            'name': 'Duplicate ignored',
            'available': true,
          },
          <String, dynamic>{
            'id': 'offline-model',
            'available': false,
          },
        ],
      }, headers: <String, String>{
        'etag': 'blockrun-v1'
      });
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
    );

    final snapshot = await service.refreshProvider('blockrun');
    final provider =
        snapshot.providers.firstWhere((record) => record.id == 'blockrun');
    final model = provider.models.single;

    expect(model.id, 'blockrun/openai/gpt-5-mini');
    expect(model.providerModelId, 'openai/gpt-5-mini');
    expect(model.label, 'GPT-5 Mini');
    expect(model.supportsToolCalls, isTrue);
    expect(model.advertisedContextWindow, 400000);
    expect(model.advertisedMaxOutputTokens, 128000);
    expect(provider.catalogState, DynamicProviderCatalogState.fresh);
    expect(provider.connectionState, DynamicProviderConnectionState.unknown);
    expect(provider.etag, 'blockrun-v1');
  });

  test('updates BlockRun cache timestamp after a valid 304', () async {
    var call = 0;
    var clock = now;
    final client = _FakeClient((request) async {
      call++;
      if (call == 2) {
        expect(request.headers['if-none-match'], 'blockrun-v1');
        return http.Response('', 304);
      }
      return _jsonResponse(<String, dynamic>{
        'models': <dynamic>[
          <String, dynamic>{'id': 'model-a', 'available': true},
        ],
      }, headers: <String, String>{
        'etag': 'blockrun-v1'
      });
    });
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => clock,
    );

    await service.refreshProvider('blockrun');
    clock = now.add(const Duration(hours: 2));
    final refreshed = await service.refreshProvider('blockrun');
    final provider =
        refreshed.providers.firstWhere((record) => record.id == 'blockrun');

    expect(provider.lastRefreshedAt, clock);
    expect(provider.models.single.id, 'blockrun/model-a');
    expect(provider.catalogState, DynamicProviderCatalogState.fresh);
  });

  test('records an actionable BlockRun reason for malformed metadata',
      () async {
    final client = _FakeClient((request) async =>
        _jsonResponse(<String, dynamic>{'models': <String, dynamic>{}}));
    final service = ProviderModelDiscoveryService(
      client: client,
      repository: repository,
      clock: () => now,
    );

    await expectLater(
      service.refreshProvider('blockrun'),
      throwsA(isA<ProviderDiscoveryException>().having(
        (error) => error.code,
        'code',
        'invalid_response',
      )),
    );
    final snapshot = await repository.load(now: now);
    final provider =
        snapshot!.providers.firstWhere((record) => record.id == 'blockrun');
    expect(provider.catalogState, DynamicProviderCatalogState.offlineFallback);
    expect(provider.errorMessage, isNotEmpty);
    expect(provider.models.single.liveAvailable, isFalse);
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

SecureWalletStatus _healthyWallet(String address) => SecureWalletStatus(
      state: SecureWalletState.healthy,
      address: address,
      securityLevel: 'Trusted Environment',
      authenticationMode: 'deviceCredential',
      errorCode: '',
      envelopeIntegrity: 'verified',
      authenticationAvailable: true,
      hardwareBacked: true,
      verificationPending: false,
      verificationCode: '',
    );

String _veniceMessage(String address, Map<String, dynamic> request) =>
    'api.venice.ai wants you to sign in with your Ethereum account:\n'
    '$address\n\n'
    'Sign in to Venice AI\n\n'
    'URI: ${request['uri']}\n'
    'Version: 1\n'
    'Chain ID: 8453\n'
    'Nonce: ${request['nonce']}\n'
    'Issued At: ${request['issuedAt']}\n'
    'Expiration Time: ${request['expirationTime']}';
