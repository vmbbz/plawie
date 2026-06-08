import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/slack_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('slack capability rejects missing config without HTTP', () async {
    final capability = SlackCapability(
      configProvider: () async => null,
      client: MockClient((request) async {
        fail('missing Slack config must not perform HTTP');
      }),
    );

    final frame = await capability.handle('slack.me', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_SLACK_CONFIG');
  });

  test('slack auth test uses token and returns bounded workspace metadata',
      () async {
    const token = 'xoxb-secret-token';
    final capability = SlackCapability(
      configProvider: () async => const SlackConfig(
        botToken: token,
        defaultChannel: 'C123',
      ),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth.test');
        expect(request.headers['Authorization'], 'Bearer $token');
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(request.headers['User-Agent'], contains('OpenClaw'));
        return http.Response(
          jsonEncode({
            'ok': true,
            'url': 'https://openclaw.slack.com/',
            'team': 'OpenClaw',
            'user': 'openclaw-bot',
            'team_id': 'T123',
            'user_id': 'U123',
            'bot_id': 'B123',
            'token': 'must-not-leak',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('slack.me', const {});

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-slack-rest');
    expect(frame.payload?['action'], 'me');
    expect(frame.payload?['team'], 'OpenClaw');
    expect(frame.payload?['teamId'], 'T123');
    expect(frame.payload?['user'], 'openclaw-bot');
    expect(frame.payload?['userId'], 'U123');
    expect(frame.payload?['botId'], 'B123');
    expect(frame.payload?['defaultChannel'], 'C123');
    expect(jsonEncode(frame.payload), isNot(contains(token)));
    expect(jsonEncode(frame.payload), isNot(contains('must-not-leak')));
  });

  test('slack post uses configured channel fallback and bounded metadata',
      () async {
    const token = 'xoxb-secret-token';
    final capability = SlackCapability(
      configProvider: () async => const SlackConfig(
        botToken: token,
        defaultChannel: 'C123',
      ),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/chat.postMessage');
        expect(request.headers['Authorization'], 'Bearer $token');
        expect(request.headers['Content-Type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['channel'], 'C123');
        expect(body['text'], 'Launch update');
        return http.Response(
          jsonEncode({
            'ok': true,
            'channel': 'C123',
            'ts': '123.456',
            'message': {
              'text': 'Launch update',
              'user': 'U123',
              'token': 'must-not-leak',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('slack.post', {
      'text': 'Launch update',
    });

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-slack-rest');
    expect(frame.payload?['action'], 'post');
    expect(frame.payload?['channel'], 'C123');
    expect(frame.payload?['ts'], '123.456');
    expect(frame.payload?['textPreview'], 'Launch update');
    expect(jsonEncode(frame.payload), isNot(contains(token)));
    expect(jsonEncode(frame.payload), isNot(contains('must-not-leak')));
  });

  test('slack stays a config-gated app-native skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('slack')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['SLACK_BOT_TOKEN', 'channels.slack']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('slack is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == 'slack');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('Slack'));
    expect(schema['required'], contains('action'));
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.keys, containsAll(['action', 'channel', 'text']));
  });

  test(
      'explicit slack status prompt routes through Gateway-visible tool chunks',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      slack: SlackCapability(
        configProvider: () async => const SlackConfig(
          botToken: 'xoxb-secret-token',
          defaultChannel: 'C123',
        ),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'ok': true,
              'team': 'OpenClaw',
              'user': 'openclaw-bot',
              'team_id': 'T123',
              'user_id': 'U123',
            }),
            200,
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'slack status',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'slack');
    expect(execution.input, isNot(contains('token')));
    expect(execution.ok, isTrue);
    expect(execution.result['team'], 'OpenClaw');
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:slack:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:slack:'));
  });

  test('explicit slack post prompt routes through configured default channel',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      slack: SlackCapability(
        configProvider: () async => const SlackConfig(
          botToken: 'xoxb-secret-token',
          defaultChannel: 'C123',
        ),
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['channel'], 'C123');
          expect(body['text'], 'Launch update');
          return http.Response(
            jsonEncode({
              'ok': true,
              'channel': 'C123',
              'ts': '123.456',
              'message': {'text': 'Launch update'},
            }),
            200,
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'slack post Launch update',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'slack');
    expect(execution.input['text'], 'Launch update');
    expect(execution.input, isNot(contains('token')));
    expect(execution.ok, isTrue);
    expect(execution.result['channel'], 'C123');
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:slack:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:slack:'));
  });

  test('AgentSkillServer and node allowlist route slack', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'slack':"));
    expect(source, contains("'slack': 'slack.me'"));
    expect(source, contains("'slack_post': 'slack.post'"));
    expect(source, contains('_slackCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('slack.me'),
    );
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('slack.post'),
    );
  });
}
