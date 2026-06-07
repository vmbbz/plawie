import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/notion_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notion capability rejects missing token without HTTP', () async {
    final capability = NotionCapability(
      tokenProvider: () async => null,
      client: MockClient((request) async {
        fail('missing Notion token must not perform HTTP');
      }),
    );

    final frame = await capability.handle('notion.search', {
      'query': 'launch plan',
    });

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_NOTION_TOKEN');
  });

  test('notion search uses bounded API request and metadata response',
      () async {
    const token = 'secret_notion_token';
    final capability = NotionCapability(
      tokenProvider: () async => token,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/search');
        expect(request.headers['Authorization'], 'Bearer $token');
        expect(request.headers['Notion-Version'], '2026-03-11');
        expect(request.headers['Content-Type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['query'], 'launch plan');
        expect(body['page_size'], 2);
        expect(body['filter'], {
          'property': 'object',
          'value': 'page',
        });
        expect(body['sort'], {
          'direction': 'descending',
          'timestamp': 'last_edited_time',
        });
        return http.Response(
          jsonEncode({
            'object': 'list',
            'has_more': false,
            'next_cursor': null,
            'results': [
              {
                'object': 'page',
                'id': '11111111-1111-1111-1111-111111111111',
                'created_time': '2026-06-07T01:02:03Z',
                'last_edited_time': '2026-06-07T04:05:06Z',
                'url': 'https://notion.so/launch-plan',
                'public_url': null,
                'in_trash': false,
                'is_archived': false,
                'properties': {
                  'Name': {
                    'title': [
                      {
                        'plain_text': 'Launch Plan',
                      },
                    ],
                  },
                  'Private': {
                    'rich_text': [
                      {
                        'plain_text': 'must not leak',
                      },
                    ],
                  },
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('notion.search', {
      'query': 'launch plan',
      'object': 'page',
      'limit': 2,
    });

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-notion-rest');
    expect(frame.payload?['query'], 'launch plan');
    expect(frame.payload?['count'], 1);
    expect(frame.payload?['hasMore'], false);
    final results = frame.payload?['results'] as List;
    expect(results.single['title'], 'Launch Plan');
    expect(results.single['url'], 'https://notion.so/launch-plan');
    expect(jsonEncode(frame.payload), isNot(contains(token)));
    expect(jsonEncode(frame.payload), isNot(contains('must not leak')));
  });

  test('notion stays a config-gated app-native skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('notion')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['NOTION_TOKEN']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('notion is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == 'notion');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('Notion'));
    expect(schema['required'], contains('query'));
    expect(
      (schema['properties'] as Map<String, dynamic>)['object'],
      isNotNull,
    );
  });

  test('explicit notion prompt routes through Gateway-visible tool chunks',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      notion: NotionCapability(
        tokenProvider: () async => 'secret_notion_token',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'object': 'list',
              'has_more': false,
              'results': [
                {
                  'object': 'page',
                  'id': '11111111-1111-1111-1111-111111111111',
                  'url': 'https://notion.so/launch-plan',
                  'properties': {
                    'Name': {
                      'title': [
                        {'plain_text': 'Launch Plan'},
                      ],
                    },
                  },
                },
              ],
            }),
            200,
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'notion launch plan limit 2',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'notion');
    expect(execution.input, isNot(contains('token')));
    expect(execution.ok, isTrue);
    expect(execution.result['count'], 1);
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:notion:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:notion:'));
  });

  test('AgentSkillServer and node allowlist route notion', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'notion':"));
    expect(source, contains("'notion': 'notion.search'"));
    expect(source, contains('_notionCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('notion.search'),
    );
  });
}
