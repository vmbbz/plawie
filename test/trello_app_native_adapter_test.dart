import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/trello_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('trello capability rejects missing config without HTTP', () async {
    final capability = TrelloCapability(
      credentialsProvider: () async => null,
      client: MockClient((request) async {
        fail('missing Trello config must not perform HTTP');
      }),
    );

    final frame = await capability.handle('trello.boards', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_TRELLO_CONFIG');
  });

  test('trello boards request uses key token and returns bounded summaries',
      () async {
    const apiKey = 'trello_key';
    const token = 'trello_token';
    final capability = TrelloCapability(
      credentialsProvider: () async =>
          const TrelloCredentials(apiKey: apiKey, token: token),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/1/members/me/boards');
        expect(request.url.queryParameters['key'], apiKey);
        expect(request.url.queryParameters['token'], token);
        expect(request.url.queryParameters['fields'],
            'name,url,closed,dateLastActivity');
        expect(request.url.queryParameters['filter'], 'open');
        return http.Response(
          jsonEncode([
            {
              'id': 'board-1',
              'name': 'Launch',
              'url': 'https://trello.com/b/launch',
              'closed': false,
              'dateLastActivity': '2026-06-07T01:02:03.000Z',
              'prefs': {'must': 'not leak'},
            },
            {
              'id': 'board-2',
              'name': 'Roadmap',
              'url': 'https://trello.com/b/roadmap',
              'closed': false,
            },
            {
              'id': 'board-3',
              'name': 'Overflow',
              'url': 'https://trello.com/b/overflow',
              'closed': false,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('trello.boards', {'limit': 2});

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-trello-rest');
    expect(frame.payload?['count'], 2);
    final boards = frame.payload?['boards'] as List;
    expect(boards.length, 2);
    expect(boards.first['name'], 'Launch');
    expect(jsonEncode(frame.payload), isNot(contains(apiKey)));
    expect(jsonEncode(frame.payload), isNot(contains(token)));
    expect(jsonEncode(frame.payload), isNot(contains('must')));
  });

  test('trello stays a config-gated app-native skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('trello')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['TRELLO_API_KEY', 'TRELLO_TOKEN']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('trello is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == 'trello');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('Trello'));
    expect(schema['required'], contains('action'));
  });

  test('explicit trello prompt routes through Gateway-visible tool chunks',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      trello: TrelloCapability(
        credentialsProvider: () async =>
            const TrelloCredentials(apiKey: 'trello_key', token: 'token'),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode([
              {
                'id': 'board-1',
                'name': 'Launch',
                'url': 'https://trello.com/b/launch',
              },
            ]),
            200,
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'trello boards limit 2',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'trello');
    expect(execution.input, isNot(contains('token')));
    expect(execution.ok, isTrue);
    expect(execution.result['count'], 1);
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:trello:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:trello:'));
  });

  test('AgentSkillServer and node allowlist route trello', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'trello':"));
    expect(source, contains("'trello': 'trello.boards'"));
    expect(source, contains('_trelloCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('trello.boards'),
    );
  });
}
