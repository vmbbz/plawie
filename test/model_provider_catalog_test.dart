import 'package:flutter_test/flutter_test.dart';
import 'package:clawa/services/model_execution_policy.dart';
import 'package:clawa/services/model_provider_catalog.dart';

void main() {
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
