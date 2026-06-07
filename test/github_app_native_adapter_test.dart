import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/github_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('github capability rejects missing token without making HTTP calls',
      () async {
    final capability = GitHubCapability(
      tokenProvider: () async => null,
      client: MockClient((request) async {
        fail('missing GitHub token must not perform HTTP');
      }),
    );

    final frame = await capability.handle('github.user', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_GITHUB_TOKEN');
  });

  test('github user request uses token and returns bounded profile metadata',
      () async {
    const token = 'ghp_secret_token';
    final capability = GitHubCapability(
      tokenProvider: () async => token,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/user');
        expect(request.headers['Authorization'], 'Bearer $token');
        expect(request.headers['User-Agent'], contains('OpenClaw'));
        return http.Response(
          jsonEncode({
            'login': 'octocat',
            'id': 1,
            'name': 'The Octocat',
            'html_url': 'https://github.com/octocat',
            'private': 'must not leak',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('github.user', const {});

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-github-rest');
    expect(frame.payload?['login'], 'octocat');
    expect(frame.payload?['name'], 'The Octocat');
    expect(frame.payload?['profileUrl'], 'https://github.com/octocat');
    expect(jsonEncode(frame.payload), isNot(contains(token)));
    expect(jsonEncode(frame.payload), isNot(contains('must not leak')));
  });

  test('gh-issues list request returns bounded issue metadata', () async {
    final capability = GitHubCapability(
      tokenProvider: () async => 'ghp_secret_token',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/repos/openai/codex/issues');
        expect(request.url.queryParameters['state'], 'open');
        expect(request.url.queryParameters['per_page'], '2');
        return http.Response(
          jsonEncode([
            {
              'number': 42,
              'title': 'Android smoke failure',
              'state': 'open',
              'html_url': 'https://github.com/openai/codex/issues/42',
              'updated_at': '2026-06-07T01:02:03Z',
              'pull_request': {'url': 'https://api.github.com/pr/42'},
              'body': 'long issue body must not be returned',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('gh-issues.list', {
      'owner': 'openai',
      'repo': 'codex',
      'state': 'open',
      'limit': 2,
    });

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-github-rest');
    expect(frame.payload?['repository'], 'openai/codex');
    expect(frame.payload?['count'], 1);
    final issues = frame.payload?['issues'] as List;
    expect(issues.single['number'], 42);
    expect(issues.single['isPullRequest'], isTrue);
    expect(jsonEncode(issues), isNot(contains('long issue body')));
  });

  test('github and gh-issues stay config-gated app-native skills', () {
    final github = AndroidSkillSupportManifest.instance.entryFor('github')!;
    final issues = AndroidSkillSupportManifest.instance.entryFor('gh-issues')!;

    for (final entry in [github, issues]) {
      expect(entry.status, AndroidSkillSupportStatus.needsConfig);
      expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
      expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
      expect(entry.requiredConfig, ['GITHUB_TOKEN']);
      expect(entry.requiredPacks, isEmpty);
    }
  });

  test('github and gh-issues are advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final github = catalog.singleWhere((tool) => tool['name'] == 'github');
    final issues = catalog.singleWhere((tool) => tool['name'] == 'gh-issues');
    final githubSchema = github['input_schema'] as Map<String, dynamic>;
    final issueSchema = issues['input_schema'] as Map<String, dynamic>;

    expect(github['description'], contains('GitHub'));
    expect(githubSchema['required'], contains('action'));
    expect(issues['description'], contains('issues'));
    expect(issueSchema['required'], containsAll(['owner', 'repo']));
  });

  test('explicit github prompt routes through Gateway-visible tool chunks',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      github: GitHubCapability(
        tokenProvider: () async => 'ghp_secret_token',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'login': 'octocat',
              'html_url': 'https://github.com/octocat',
            }),
            200,
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent('github user');

    expect(execution, isNotNull);
    expect(execution!.toolName, 'github');
    expect(execution.input, isNot(contains('token')));
    expect(execution.ok, isTrue);
    expect(execution.result['login'], 'octocat');
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:github:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:github:'));
  });

  test('AgentSkillServer and node allowlist route github tools', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'github':"));
    expect(source, contains("case 'gh-issues':"));
    expect(source, contains("'github': 'github.user'"));
    expect(source, contains("'gh-issues': 'gh-issues.list'"));
    expect(source, contains('_githubCapability.handle('));
    expect(GatewayToolCatalog.mobileNodeAllowCommands, contains('github.user'));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('gh-issues.list'),
    );
  });
}
