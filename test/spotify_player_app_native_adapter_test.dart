import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/capabilities/spotify_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('spotify capability rejects missing access token without HTTP',
      () async {
    final capability = SpotifyCapability(
      tokenProvider: () async => null,
      client: MockClient((request) async {
        fail('missing Spotify access token must not perform HTTP');
      }),
    );

    final frame = await capability.handle('spotify-player.profile', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_SPOTIFY_ACCESS_TOKEN');
  });

  test('spotify reads current user profile without leaking token or email',
      () async {
    const token = 'spotify-secret';
    final capability = SpotifyCapability(
      tokenProvider: () async => token,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/me');
        expect(request.headers['Authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'display_name': 'Launch Listener',
            'product': 'premium',
            'email': 'private@example.test',
            'external_urls': {
              'spotify': 'https://open.spotify.com/user/user-1'
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('spotify-player.profile', const {});

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-spotify-rest');
    expect(frame.payload?['action'], 'profile');
    expect(frame.payload?['id'], 'user-1');
    expect(frame.payload?['displayName'], 'Launch Listener');
    expect(frame.payload?['product'], 'premium');
    expect(jsonEncode(frame.payload), isNot(contains(token)));
    expect(jsonEncode(frame.payload), isNot(contains('private@example.test')));
  });

  test('spotify-player is a config-gated app-native skill', () {
    final entry =
        AndroidSkillSupportManifest.instance.entryFor('spotify-player')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['SPOTIFY_ACCESS_TOKEN']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('spotify-player is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool =
        catalog.singleWhere((tool) => tool['name'] == 'spotify-player');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('Spotify'));
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.keys, contains('action'));
  });

  test('AgentSkillServer and node allowlist route spotify-player', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'spotify-player':"));
    expect(source, contains("'spotify-player': 'spotify-player.profile'"));
    expect(source, contains('_spotifyCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('spotify-player.profile'),
    );
  });
}
