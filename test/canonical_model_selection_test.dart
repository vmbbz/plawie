import 'package:clawa/services/canonical_model_selection.dart';
import 'package:clawa/services/dynamic_model_catalog.dart';
import 'package:clawa/services/model_provider_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dynamic identity preserves provider model and visible label', () {
    const model = DynamicModelRecord(
      id: 'venice/gemini-3-6-flash',
      providerId: 'venice',
      providerModelId: 'gemini-3-6-flash',
      label: 'Gemini 3.6 Flash',
      route: ModelRouteKind.cloud,
    );

    final selection = CanonicalModelSelection.fromDynamic(
      model,
      catalogRevision: 'venice-v7',
    );
    final decoded = CanonicalModelSelection.tryDecode(selection.encode());

    expect(decoded, isNotNull);
    expect(decoded!.providerId, 'venice');
    expect(decoded.namespacedModelId, 'venice/gemini-3-6-flash');
    expect(decoded.upstreamModelId, 'gemini-3-6-flash');
    expect(decoded.displayLabel, 'Gemini 3.6 Flash');
    expect(decoded.catalogRevision, 'venice-v7');
  });

  test('static and legacy IDs use one canonical identity', () {
    final selection = CanonicalModelSelection.fromModelId(
      'groq/llama-3.3-70b-versatile',
    );

    expect(selection.namespacedModelId, 'groq/openai/gpt-oss-120b');
    expect(selection.providerId, 'groq');
    expect(selection.upstreamModelId, 'openai/gpt-oss-120b');
    expect(selection.displayLabel, 'GPT-OSS 120B via Groq');
  });

  test('tampered provider and upstream combinations fail closed', () {
    expect(
      CanonicalModelSelection.tryDecode('''{
        "providerId":"venice",
        "namespacedModelId":"venice/gemini-3-6-flash",
        "upstreamModelId":"gemma-4-uncensored",
        "displayLabel":"Claude Sonnet 4.6",
        "routeKind":"cloud"
      }'''),
      isNull,
    );
  });
}
