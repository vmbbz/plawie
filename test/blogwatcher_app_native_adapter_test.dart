import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/blog_watcher_capability.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('blogwatcher fetches bounded RSS feed metadata', () async {
    final capability = BlogWatcherCapability(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://example.test/feed.xml');
        return http.Response(
          '''
          <rss><channel>
            <title>OpenClaw Updates</title>
            <item>
              <guid>post-1</guid>
              <title>Native gateway ready</title>
              <link>https://example.test/native</link>
              <pubDate>Sun, 07 Jun 2026 10:00:00 GMT</pubDate>
              <description>Gateway tool routing now emits visible chunks.</description>
            </item>
            <item>
              <guid>post-2</guid>
              <title>Dependency packs next</title>
              <link>https://example.test/packs</link>
              <description>Pack lanes stay policy reviewed.</description>
            </item>
          </channel></rss>
          ''',
          200,
          headers: {'content-type': 'application/rss+xml'},
        );
      }),
    );

    final frame = await capability.handle('blogwatcher.check', {
      'url': 'https://example.test/feed.xml',
      'limit': 1,
    });

    expect(frame.isError, isFalse);
    final payload = frame.payload!;
    expect(payload['runtime'], 'app-native-feed-check');
    expect(payload['feedTitle'], 'OpenClaw Updates');
    expect(payload['itemCount'], 1);
    expect(payload['truncated'], isTrue);
    final items = payload['items'] as List<dynamic>;
    expect(items.single['title'], 'Native gateway ready');
    expect(items.single['summaryPreview'], contains('visible chunks'));
  });

  test('blogwatcher rejects local/private fetch targets', () async {
    final capability = BlogWatcherCapability(
      client: MockClient((request) async {
        fail('blocked blogwatcher URL must not perform HTTP');
      }),
    );

    for (final url in const [
      'file:///sdcard/feed.xml',
      'http://127.0.0.1:8765/feed.xml',
      'http://10.0.2.2/feed.xml',
      'http://192.168.1.2/feed.xml',
    ]) {
      final frame = await capability.handle('blogwatcher.check', {'url': url});
      expect(frame.isError, isTrue, reason: url);
    }
  });

  test('blogwatcher is classified as app-native ready optional', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('blogwatcher')!;

    expect(entry.status, AndroidSkillSupportStatus.readyOptional);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.httpAdapter);
    expect(entry.requiredPacks, isEmpty);
    expect(entry.launchCritical, isFalse);
  });

  test('blogwatcher is advertised in native tools catalog with URL schema',
      () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog = SkillsService().getToolsCatalog();
    final blogwatcher = catalog
        .cast<Map<String, dynamic>>()
        .singleWhere((tool) => tool['name'] == 'blogwatcher');
    final schema = blogwatcher['input_schema'] as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;

    expect(blogwatcher['description'], contains('RSS'));
    expect(properties['url'], isA<Map<String, dynamic>>());
    expect(schema['required'], contains('url'));
  });

  test('explicit blogwatcher prompt routes through Gateway-visible tool chunks',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      blogWatcher: BlogWatcherCapability(
        client: MockClient((request) async {
          return http.Response(
            '<feed><title>Lab Feed</title><entry><id>e1</id><title>Adapter landed</title><link href="https://example.test/e1"/></entry></feed>',
            200,
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'blogwatcher https://example.test/feed.xml limit 1',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'blogwatcher');
    expect(execution.input['url'], 'https://example.test/feed.xml');
    expect(execution.input['limit'], 1);
    expect(execution.ok, isTrue);
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:blogwatcher:'));
    expect(
      execution.toolResultChunk,
      startsWith('\x00TOOL_RESULT:blogwatcher:'),
    );
  });

  test('natural blogwatcher prompt with a URL stays on the native adapter',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      blogWatcher: BlogWatcherCapability(
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://example.test/feed.xml');
          return http.Response(
            '<rss><channel><title>Native Feed</title></channel></rss>',
            200,
            headers: {'content-type': 'application/rss+xml'},
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'Please use the blogwatcher skill to check https://example.test/feed.xml',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'blogwatcher');
    expect(execution.input['url'], 'https://example.test/feed.xml');
    expect(execution.ok, isTrue);
  });

  test('blogwatcher without a URL returns native guidance instead of Go error',
      () async {
    final router = AppNativeChatToolRouter.forTesting();

    final execution =
        await router.tryExecuteRequiredToolIntent('Please test blogwatcher');

    expect(execution, isNotNull);
    expect(execution!.ok, isFalse);
    expect(execution.visibleText, contains('absolute http or https URL'));
  });

  test('AgentSkillServer routes blogwatcher execution to BlogWatcherCapability',
      () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'blogwatcher':"));
    expect(source, contains("'blogwatcher': 'blogwatcher.check'"));
    expect(source, contains("_blogWatcherCapability.handle("));
  });
}
