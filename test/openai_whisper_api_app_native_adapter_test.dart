import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/capabilities/openai_whisper_api_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('openai whisper api rejects missing API key without HTTP', () async {
    final capability = OpenAiWhisperApiCapability(
      apiKeyProvider: () async => null,
      client: MockClient((request) async {
        fail('missing OpenAI API key must not perform HTTP');
      }),
    );

    final frame = await capability.handle('openai-whisper-api.transcribe', {
      'audioBase64': base64Encode([1, 2, 3]),
      'filename': 'clip.wav',
    });

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_OPENAI_API_KEY');
  });

  test('openai whisper api rejects missing audio without HTTP', () async {
    final capability = OpenAiWhisperApiCapability(
      apiKeyProvider: () async => 'sk-secret',
      client: MockClient((request) async {
        fail('missing audio must not perform HTTP');
      }),
    );

    final frame = await capability.handle(
      'openai-whisper-api.transcribe',
      const {},
    );

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_AUDIO');
  });

  test('openai whisper api sends bounded multipart transcription request',
      () async {
    const apiKey = 'sk-secret-openai';
    final capability = OpenAiWhisperApiCapability(
      apiKeyProvider: () async => apiKey,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/audio/transcriptions');
        expect(request.headers['Authorization'], 'Bearer $apiKey');
        expect(
            request.headers['Content-Type'], contains('multipart/form-data'));
        expect(request.body, contains('name="model"'));
        expect(request.body, contains('gpt-4o-mini-transcribe'));
        expect(request.body, contains('name="response_format"'));
        expect(request.body, contains('json'));
        expect(request.body, contains('filename="clip.wav"'));
        expect(request.body, contains('hello-audio'));
        return http.Response(
          jsonEncode({
            'text': 'Hello from the launch audio.',
            'token': 'must-not-leak',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('openai-whisper-api.transcribe', {
      'audioBase64': base64Encode(utf8.encode('hello-audio')),
      'filename': 'clip.wav',
    });

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-openai-transcription-rest');
    expect(frame.payload?['action'], 'transcribe');
    expect(frame.payload?['model'], 'gpt-4o-mini-transcribe');
    expect(frame.payload?['filename'], 'clip.wav');
    expect(frame.payload?['audioBytes'], utf8.encode('hello-audio').length);
    expect(frame.payload?['text'], 'Hello from the launch audio.');
    expect(jsonEncode(frame.payload), isNot(contains(apiKey)));
    expect(jsonEncode(frame.payload), isNot(contains('must-not-leak')));
  });

  test('openai whisper api stays a config-gated app-native skill', () {
    final entry =
        AndroidSkillSupportManifest.instance.entryFor('openai-whisper-api')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['OPENAI_API_KEY']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('openai whisper api is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool =
        catalog.singleWhere((tool) => tool['name'] == 'openai-whisper-api');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('OpenAI'));
    expect(schema['required'], contains('audioBase64'));
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.keys, containsAll(['audioBase64', 'filename', 'model']));
  });

  test('AgentSkillServer and node allowlist route openai whisper api',
      () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'openai-whisper-api':"));
    expect(
      source,
      contains("'openai-whisper-api': 'openai-whisper-api.transcribe'"),
    );
    expect(source, contains('_openAiWhisperApiCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('openai-whisper-api.transcribe'),
    );
  });
}
