import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/discord_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('discord capability rejects missing bot token without HTTP', () async {
    final capability = DiscordCapability(
      tokenProvider: () async => null,
      client: MockClient((request) async {
        fail('missing Discord bot token must not perform HTTP');
      }),
    );

    final frame = await capability.handle('discord.me', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_DISCORD_BOT_TOKEN');
  });

  test('discord bot status uses token and returns bounded user metadata',
      () async {
    const token = 'discord_secret_token';
    final capability = DiscordCapability(
      tokenProvider: () async => token,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v10/users/@me');
        expect(request.headers['Authorization'], 'Bot $token');
        expect(request.headers['User-Agent'], contains('OpenClaw'));
        return http.Response(
          jsonEncode({
            'id': '1234567890',
            'username': 'openclaw-bot',
            'global_name': 'OpenClaw Bot',
            'discriminator': '0000',
            'bot': true,
            'email': 'must-not-leak@example.com',
            'token': 'must not leak',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('discord.me', const {});

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-discord-rest');
    expect(frame.payload?['id'], '1234567890');
    expect(frame.payload?['username'], 'openclaw-bot');
    expect(frame.payload?['globalName'], 'OpenClaw Bot');
    expect(frame.payload?['bot'], true);
    expect(jsonEncode(frame.payload), isNot(contains(token)));
    expect(jsonEncode(frame.payload), isNot(contains('must-not-leak')));
  });

  test('discord stays a config-gated app-native skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('discord')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['DISCORD_BOT_TOKEN']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('discord is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == 'discord');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('Discord'));
    expect(schema['required'], contains('action'));
  });

  test('explicit discord prompt routes through Gateway-visible tool chunks',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      discord: DiscordCapability(
        tokenProvider: () async => 'discord_secret_token',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': '1234567890',
              'username': 'openclaw-bot',
              'bot': true,
            }),
            200,
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'discord bot status',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'discord');
    expect(execution.input, isNot(contains('token')));
    expect(execution.ok, isTrue);
    expect(execution.result['username'], 'openclaw-bot');
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:discord:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:discord:'));
  });

  test('AgentSkillServer and node allowlist route discord', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'discord':"));
    expect(source, contains("'discord': 'discord.me'"));
    expect(source, contains('_discordCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('discord.me'),
    );
  });
}
