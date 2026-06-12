import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/capabilities/gemini_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gemini capability rejects missing API key without HTTP', () async {
    final capability = GeminiCapability(
      apiKeyProvider: () async => null,
      client: MockClient((request) async {
        fail('missing Gemini API key must not perform HTTP');
      }),
    );

    final frame = await capability.handle('gemini.models', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_GEMINI_API_KEY');
  });

  test('gemini lists models through the official REST API', () async {
    const apiKey = 'gemini-secret';
    final capability = GeminiCapability(
      apiKeyProvider: () async => apiKey,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1beta/models');
        expect(request.url.queryParameters['key'], apiKey);
        expect(request.url.queryParameters['pageSize'], '10');
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-2.0-flash',
                'displayName': 'Gemini 2.0 Flash',
                'baseModelId': 'gemini-2.0-flash',
                'supportedGenerationMethods': ['generateContent'],
                'private': 'must-not-leak',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('gemini.models', const {});

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-gemini-rest');
    expect(frame.payload?['action'], 'models');
    expect(frame.payload?['count'], 1);
    final models = frame.payload?['models'] as List;
    expect(models.single['name'], 'models/gemini-2.0-flash');
    expect(models.single['displayName'], 'Gemini 2.0 Flash');
    expect(jsonEncode(frame.payload), isNot(contains(apiKey)));
    expect(jsonEncode(frame.payload), isNot(contains('must-not-leak')));
  });

  test('gemini stays a config-gated app-native skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('gemini')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['GEMINI_API_KEY']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('gemini is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == 'gemini');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('Gemini'));
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.keys, containsAll(['action', 'prompt', 'model']));
  });

  test('AgentSkillServer and node allowlist route gemini', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'gemini':"));
    expect(source, contains("'gemini': 'gemini.models'"));
    expect(source, contains('_geminiCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('gemini.models'),
    );
  });
}
