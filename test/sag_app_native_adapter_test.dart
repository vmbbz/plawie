import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/capabilities/sag_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sag capability rejects missing API key without HTTP', () async {
    final capability = SagCapability(
      apiKeyProvider: () async => null,
      client: MockClient((request) async {
        fail('missing ElevenLabs/SAG API key must not perform HTTP');
      }),
    );

    final frame = await capability.handle('sag.voices', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_SAG_API_KEY');
  });

  test('sag lists ElevenLabs voices through a safe read', () async {
    const apiKey = 'elevenlabs-secret';
    final capability = SagCapability(
      apiKeyProvider: () async => apiKey,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v2/voices');
        expect(request.url.queryParameters['page_size'], '10');
        expect(request.headers['xi-api-key'], apiKey);
        return http.Response(
          jsonEncode({
            'voices': [
              {
                'voice_id': 'voice-1',
                'name': 'Rachel',
                'category': 'premade',
                'labels': {'accent': 'american'},
                'samples': ['must-not-leak'],
              },
            ],
            'total_count': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('sag.voices', const {});

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-elevenlabs-rest');
    expect(frame.payload?['action'], 'voices');
    expect(frame.payload?['count'], 1);
    final voices = frame.payload?['voices'] as List;
    expect(voices.single['voiceId'], 'voice-1');
    expect(voices.single['name'], 'Rachel');
    expect(jsonEncode(frame.payload), isNot(contains(apiKey)));
    expect(jsonEncode(frame.payload), isNot(contains('must-not-leak')));
  });

  test('sag is a config-gated app-native ElevenLabs skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('sag')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['ELEVENLABS_API_KEY']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('sag is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == 'sag');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('ElevenLabs'));
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.keys, containsAll(['action', 'text', 'voiceId']));
  });

  test('AgentSkillServer and node allowlist route sag', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'sag':"));
    expect(source, contains("'sag': 'sag.voices'"));
    expect(source, contains('_sagCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('sag.voices'),
    );
  });
}
