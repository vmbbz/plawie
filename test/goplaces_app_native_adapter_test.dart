import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/goplaces_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('goplaces capability rejects missing API key without HTTP', () async {
    final capability = GoPlacesCapability(
      apiKeyProvider: () async => null,
      client: MockClient((request) async {
        fail('missing Google Places key must not perform HTTP');
      }),
    );

    final frame = await capability.handle('goplaces.search', {
      'query': 'coffee in Cape Town',
    });

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_GOOGLE_PLACES_API_KEY');
  });

  test('goplaces search uses Places Text Search with bounded fields', () async {
    const apiKey = 'AIza_secret_key';
    final capability = GoPlacesCapability(
      apiKeyProvider: () async => apiKey,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/places:searchText');
        expect(request.headers['X-Goog-Api-Key'], apiKey);
        expect(request.headers['X-Goog-FieldMask'], isNot(contains('*')));
        expect(
          request.headers['X-Goog-FieldMask'],
          contains('places.displayName'),
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['textQuery'], 'coffee in Cape Town');
        expect(body['pageSize'], 2);
        return http.Response(
          jsonEncode({
            'places': [
              {
                'id': 'place-1',
                'displayName': {'text': 'Truth Coffee'},
                'formattedAddress': '36 Buitenkant St, Cape Town',
                'location': {'latitude': -33.927, 'longitude': 18.423},
                'googleMapsUri': 'https://maps.google.com/?cid=1',
                'primaryType': 'cafe',
                'reviews': ['must not leak'],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final frame = await capability.handle('goplaces.search', {
      'query': 'coffee in Cape Town',
      'limit': 2,
    });

    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-google-places-rest');
    expect(frame.payload?['query'], 'coffee in Cape Town');
    expect(frame.payload?['count'], 1);
    final places = frame.payload?['places'] as List;
    expect(places.single['displayName'], 'Truth Coffee');
    expect(places.single['formattedAddress'], contains('Cape Town'));
    expect(jsonEncode(frame.payload), isNot(contains(apiKey)));
    expect(jsonEncode(frame.payload), isNot(contains('must not leak')));
  });

  test('goplaces stays a config-gated app-native skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('goplaces')!;

    expect(entry.status, AndroidSkillSupportStatus.needsConfig);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredConfig, ['GOOGLE_PLACES_API_KEY']);
    expect(entry.requiredPacks, isEmpty);
  });

  test('goplaces is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == 'goplaces');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('Google Places'));
    expect(schema['required'], contains('query'));
  });

  test('explicit goplaces prompt routes through Gateway-visible tool chunks',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      goplaces: GoPlacesCapability(
        apiKeyProvider: () async => 'AIza_secret_key',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'place-1',
                  'displayName': {'text': 'Truth Coffee'},
                  'formattedAddress': 'Cape Town',
                },
              ],
            }),
            200,
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'goplaces coffee in Cape Town limit 2',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'goplaces');
    expect(execution.input, isNot(contains('apiKey')));
    expect(execution.ok, isTrue);
    expect(execution.result['count'], 1);
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:goplaces:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:goplaces:'));
  });

  test('AgentSkillServer and node allowlist route goplaces', () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'goplaces':"));
    expect(source, contains("'goplaces': 'goplaces.search'"));
    expect(source, contains('_goPlacesCapability.handle('));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('goplaces.search'),
    );
  });
}
