import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/capabilities/one_password_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('1password connect rejects missing config without HTTP', () async {
    final capability = OnePasswordCapability(
      configProvider: () async => null,
      client: MockClient((request) async {
        fail('missing 1Password Connect config must not perform HTTP');
      }),
    );

    final frame = await capability.handle('1password.vaults', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_ONEPASSWORD_CONNECT_CONFIG');
  });

  test('1password connect lists vault metadata without leaking token',
      () async {
    const token = 'op-connect-secret';
    final capability = OnePasswordCapability(
      configProvider: () async => OnePasswordConnectConfig(
        host: Uri.parse('https://connect.example.test'),
        token: token,
      ),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
            request.url.toString(), 'https://connect.example.test/v1/vaults');
        expect(request.headers['Authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode([
            {
              'id': 'vault-1',
              'name': 'Launch',
              'attributeVersion': 1,
              'items': ['must-not-leak'],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('1password.vaults', const {});

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-1password-connect-rest');
    expect(frame.payload?['action'], 'vaults');
    expect(frame.payload?['count'], 1);
    final vaults = frame.payload?['vaults'] as List;
    expect(vaults.single['id'], 'vault-1');
    expect(vaults.single['name'], 'Launch');
    expect(jsonEncode(frame.payload), isNot(contains(token)));
    expect(jsonEncode(frame.payload), isNot(contains('must-not-leak')));
  });

  test('1password is a config-gated app-native Connect skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('1password')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['OP_CONNECT_HOST', 'OP_CONNECT_TOKEN']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('1password is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == '1password');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('1Password'));
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.keys, contains('action'));
  });

  test('AgentSkillServer and node allowlist route 1password', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case '1password':"));
    expect(source, contains("'1password': '1password.vaults'"));
    expect(source, contains('_onePasswordCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('1password.vaults'),
    );
  });
}
