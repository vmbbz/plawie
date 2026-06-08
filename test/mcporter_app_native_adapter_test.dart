import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/mcporter_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mcporter capability rejects missing config without HTTP', () async {
    final capability = McPorterCapability(
      configProvider: () async => null,
      client: MockClient((request) async {
        fail('missing MCPorter config must not perform HTTP');
      }),
    );

    final frame = await capability.handle('mcporter.health', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_MCPORTER_CONFIG');
  });

  test('mcporter health uses configured endpoint and bounded metadata',
      () async {
    const token = 'mcporter_secret_token';
    final capability = McPorterCapability(
      configProvider: () async => const McPorterConfig(
        endpoint: 'https://mcporter.example.com',
        token: token,
      ),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://mcporter.example.com/health');
        expect(request.headers['Authorization'], 'Bearer $token');
        expect(request.headers['User-Agent'], contains('OpenClaw'));
        return http.Response(
          jsonEncode({
            'ok': true,
            'status': 'ok',
            'version': '1.2.3',
            'servers': [
              {'name': 'alpha'},
              {'name': 'beta'},
            ],
            'token': 'must-not-leak',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('mcporter.health', const {});

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-mcporter-rest');
    expect(frame.payload?['action'], 'health');
    expect(frame.payload?['endpointHost'], 'mcporter.example.com');
    expect(frame.payload?['status'], 'ok');
    expect(frame.payload?['version'], '1.2.3');
    expect(frame.payload?['serverCount'], 2);
    expect(jsonEncode(frame.payload), isNot(contains(token)));
    expect(jsonEncode(frame.payload), isNot(contains('must-not-leak')));
  });

  test('mcporter stays a config-gated app-native skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('mcporter')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['MCPORTER_ENDPOINT', 'MCPORTER_TOKEN']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('mcporter is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == 'mcporter');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('MCPorter'));
    expect(schema['required'], contains('action'));
  });

  test('explicit mcporter prompt routes through Gateway-visible tool chunks',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      mcporter: McPorterCapability(
        configProvider: () async => const McPorterConfig(
          endpoint: 'https://mcporter.example.com',
          token: 'mcporter_secret_token',
        ),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'ok': true,
              'status': 'ok',
              'version': '1.2.3',
            }),
            200,
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'mcporter status',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'mcporter');
    expect(execution.input, isNot(contains('token')));
    expect(execution.ok, isTrue);
    expect(execution.result['status'], 'ok');
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:mcporter:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:mcporter:'));
  });

  test('AgentSkillServer and node allowlist route mcporter', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'mcporter':"));
    expect(source, contains("'mcporter': 'mcporter.health'"));
    expect(source, contains('_mcPorterCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('mcporter.health'),
    );
  });
}
