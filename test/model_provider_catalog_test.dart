import 'package:flutter_test/flutter_test.dart';
import 'package:clawa/services/model_execution_policy.dart';
import 'package:clawa/services/model_provider_catalog.dart';

void main() {
  test('wallet-funded providers require no API key and use loopback defaults',
      () {
    final venice = ModelProviderCatalog.providerById('VENICE');
    final blockRun = ModelProviderCatalog.providerById('blockrun');

    expect(venice, isNotNull);
    expect(blockRun, isNotNull);
    expect(
        venice!.authenticationMode, ProviderAuthenticationMode.walletIdentity);
    expect(blockRun!.authenticationMode,
        ProviderAuthenticationMode.walletIdentity);
    expect(venice.requiresApiKey, isFalse);
    expect(blockRun.requiresApiKey, isFalse);
    expect(venice.envKey, isEmpty);
    expect(blockRun.envKey, isEmpty);

    expect(ModelProviderCatalog.providerConfigDefaults('venice'), {
      'api': 'openai-completions',
      'baseUrl': 'http://127.0.0.1:11436/venice/v1',
      'models': <Map<String, dynamic>>[],
    });
    expect(ModelProviderCatalog.providerConfigDefaults('blockrun'), {
      'api': 'openai-completions',
      'baseUrl': 'http://127.0.0.1:11436/blockrun/v1',
      'models': <Map<String, dynamic>>[],
    });
    expect(
      ModelProviderCatalog.mergeProviderConfig('venice', const {}),
      isNot(contains('apiKey')),
    );
    expect(
      ModelProviderCatalog.isProviderSupportedByNativeGateway('venice'),
      isTrue,
    );
    expect(
      ModelProviderCatalog.isProviderSupportedByNativeGateway('blockrun'),
      isTrue,
    );
  });

  test('OpenRouter Auto keeps the upstream router model id', () {
    final auto = ModelProviderCatalog.modelById('openrouter/auto');

    expect(auto, isNotNull);
    expect(auto!.providerModelId, 'openrouter/auto');
    expect(auto.providerConfig['contextWindow'],
        ModelExecutionPolicy.openRouterAutoContextWindow);
    expect(auto.providerConfig['maxTokens'],
        ModelExecutionPolicy.standardOutputTokens);
  });

  test('OpenRouter legacy auto config is canonicalized and healed', () {
    final merged = ModelProviderCatalog.mergeProviderConfig('openrouter', {
      'models': [
        {'id': 'openrouter/auto', 'name': 'OpenRouter Auto'},
        {'id': 'auto', 'name': 'Legacy Auto'},
      ],
    });

    final models = (merged['models'] as List).cast<Map<String, dynamic>>();
    final autoModels =
        models.where((model) => model['id'] == 'openrouter/auto').toList();

    expect(autoModels, hasLength(1));
    expect(autoModels.single['contextWindow'],
        ModelExecutionPolicy.openRouterAutoContextWindow);
    expect(autoModels.single['maxTokens'],
        ModelExecutionPolicy.standardOutputTokens);
  });

  test('OpenRouter free router remains the user-selected gateway model', () {
    expect(
      ModelProviderCatalog.canonicalizeModelId(
        'openrouter/openrouter/free',
      ),
      'openrouter/openrouter/free',
    );
    expect(
      ModelProviderCatalog.modelById('openrouter/openrouter/free')
          ?.providerModelId,
      'openrouter/free',
    );
  });

  test('Groq routes are marked variable and compact by default', () {
    final groq70b =
        ModelProviderCatalog.modelById('groq/llama-3.3-70b-versatile');
    final groq8b = ModelProviderCatalog.modelById('groq/llama-3.1-8b-instant');

    expect(groq70b, isNotNull);
    expect(groq8b, isNotNull);
    expect(groq70b!.toolPolicy, ModelToolPolicy.variable);
    expect(groq8b!.toolPolicy, ModelToolPolicy.variable);
    expect(groq70b.maxTokens, ModelExecutionPolicy.compactOutputTokens);
    expect(groq8b.maxTokens, ModelExecutionPolicy.compactOutputTokens);
  });
}
