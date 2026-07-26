import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/xurl_capability.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('explicit xurl prompt routes through Gateway-visible tool chunks',
      () async {
    final target = 'https://example.test/fixture';
    final router = AppNativeChatToolRouter.forTesting(
      xurl: XurlCapability(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), target);
          return http.Response(
            jsonEncode({'ok': true, 'skill': 'xurl'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'xurl GET $target',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'xurl');
    expect(execution.input['url'], target);
    expect(execution.input['method'], 'GET');
    expect(
      execution.input['routingSource'],
      'gateway-required-tool-intent',
    );
    expect(execution.ok, isTrue);
    expect(execution.result['statusCode'], 200);
    expect(execution.result['bodyPreview'], contains('"skill":"xurl"'));
    expect(execution.result['bytes'], greaterThan(0));
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:xurl:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:xurl:'));
    expect(execution.visibleText, contains('HTTP 200'));
  });

  test('xurl POST includes request body and returns response metadata',
      () async {
    final target = 'https://example.test/post';
    final router = AppNativeChatToolRouter.forTesting(
      xurl: XurlCapability(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), target);
          return http.Response(
            'accepted',
            202,
            headers: {'content-type': 'text/plain'},
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'xurl POST $target body={"hello":"world"}',
    );

    expect(execution, isNotNull);
    expect(execution!.input['body'], '{"hello":"world"}');
    expect(execution.input['method'], 'POST');
    expect(execution.result['statusCode'], 202);
    expect(execution.result['bodyPreview'], 'accepted');
  });

  test('xurl HEAD omits body preview but keeps status metadata', () async {
    final target = 'https://example.test/headers';
    final router = AppNativeChatToolRouter.forTesting(
      xurl: XurlCapability(
        client: MockClient((request) async {
          expect(request.method, 'HEAD');
          expect(request.url.toString(), target);
          return http.Response(
            '',
            204,
            headers: {'content-type': 'text/plain'},
          );
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'xurl HEAD $target',
    );

    expect(execution, isNotNull);
    expect(execution!.input['method'], 'HEAD');
    expect(execution.result['statusCode'], 204);
    expect(execution.result['bodyPreview'], '');
  });

  test('xurl rejects non-HTTP URLs instead of reading local files', () async {
    final router = AppNativeChatToolRouter.forTesting(
      xurl: XurlCapability(
        client: MockClient((request) async {
          fail('invalid xurl URL must not perform HTTP');
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'xurl file:///etc/passwd',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'xurl');
    expect(execution.input['url'], 'file:///etc/passwd');
    expect(execution.ok, isFalse);
    expect(execution.result['error'], isA<Map>());
    expect((execution.result['error'] as Map)['code'], 'INVALID_URL');
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:xurl:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:xurl:'));
  });

  test('xurl blocks loopback POSTs to protect app control endpoints', () async {
    final router = AppNativeChatToolRouter.forTesting(
      xurl: XurlCapability(
        client: MockClient((request) async {
          fail('loopback POST must not perform HTTP');
        }),
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'xurl POST http://127.0.0.1:8765/api/tools/execute body={}',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'xurl');
    expect(execution.input['method'], 'POST');
    expect(execution.ok, isFalse);
    expect((execution.result['error'] as Map)['code'], 'LOCAL_POST_BLOCKED');
  });

  test('xurl loopback POST block covers alternate loopback aliases', () async {
    final capability = XurlCapability(
      client: MockClient((request) async {
        fail('loopback POST alias must not perform HTTP');
      }),
    );

    for (final url in const [
      'http://127.1:8765/api/tools/execute',
      'http://127.0.1:8765/api/tools/execute',
      'http://127.255.255.255:8765/api/tools/execute',
      'http://[::1]:8765/api/tools/execute',
      'http://[::ffff:127.0.0.1]:8765/api/tools/execute',
      'http://[0:0:0:0:0:ffff:127.0.0.1]:8765/api/tools/execute',
      'http://2130706433:8765/api/tools/execute',
      'http://0177.0.0.1:8765/api/tools/execute',
      'http://0x7f000001:8765/api/tools/execute',
    ]) {
      final frame = await capability.handle('xurl.request', {
        'method': 'POST',
        'url': url,
        'body': '{}',
      });

      expect(frame.isError, isTrue, reason: url);
      expect(frame.error?['code'], 'LOCAL_POST_BLOCKED', reason: url);
    }
  });

  test('xurl loopback policy does not classify non-loopback hosts', () {
    expect(XurlCapability.isLoopbackHostForPolicy('localhost'), isTrue);
    expect(XurlCapability.isLoopbackHostForPolicy('127.1'), isTrue);
    expect(XurlCapability.isLoopbackHostForPolicy('2130706433'), isTrue);
    expect(XurlCapability.isLoopbackHostForPolicy('0177.0.0.1'), isTrue);
    expect(XurlCapability.isLoopbackHostForPolicy('0x7f000001'), isTrue);
    expect(
      XurlCapability.isLoopbackHostForPolicy('::ffff:127.0.0.1'),
      isTrue,
    );
    expect(XurlCapability.isLoopbackHostForPolicy('192.168.1.4'), isFalse);
    expect(XurlCapability.isLoopbackHostForPolicy('0300.0250.1.4'), isFalse);
    expect(XurlCapability.isLoopbackHostForPolicy('example.com'), isFalse);
  });

  test('AgentSkillServer dry-run validation shares xurl loopback policy',
      () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(
      source,
      contains('XurlCapability.isLoopbackHostForPolicy(uri.host)'),
    );
    expect(source, isNot(contains('_isLoopbackHostForXurl')));
  });

  test('xurl is advertised in native tools catalog with URL schema', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog = SkillsService().getToolsCatalog();
    final xurl = catalog
        .cast<Map<String, dynamic>>()
        .singleWhere((tool) => tool['name'] == 'xurl');
    final schema = xurl['input_schema'] as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;
    final method = properties['method'] as Map<String, dynamic>;
    final url = properties['url'] as Map<String, dynamic>;

    expect(xurl['description'], contains('HTTP'));
    expect(url['format'], 'uri');
    expect(method['enum'], containsAll(['GET', 'HEAD', 'POST']));
    expect(schema['required'], contains('url'));
  });
}
