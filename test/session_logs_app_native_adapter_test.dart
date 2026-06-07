import 'dart:io';

import 'package:clawa/models/chat_message.dart';
import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/session_logs_capability.dart';
import 'package:clawa/services/chat_persistence_service.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sessions = [
    ChatSession(
      id: 'active-session',
      title: 'Gateway smoke',
      createdAt: DateTime.utc(2026, 6, 7, 9),
      updatedAt: DateTime.utc(2026, 6, 7, 10),
      gatewaySessionKey: 'mobile:chat:secret-key',
    ),
    ChatSession(
      id: 'older-session',
      title: 'Pack planning',
      createdAt: DateTime.utc(2026, 6, 6, 12),
      updatedAt: DateTime.utc(2026, 6, 6, 13),
    ),
  ];

  _FakeSessionLogSource fakeSource() => _FakeSessionLogSource(
        snapshotValue: SessionLogSnapshot(
          sessions: sessions,
          activeSessionId: 'active-session',
        ),
        messagesBySessionId: {
          'active-session': [
            ChatMessage(
              text:
                  'Gateway routing produced tool evidence while preserving the agent continuation loop.',
              isUser: true,
              imageBase64: 'base64-must-not-leak',
            ),
            ChatMessage(
              text: 'The assistant continued after the tool result.',
              isUser: false,
              toolEvents: [
                ChatToolEvent(type: 'tool_use', name: 'xurl'),
                ChatToolEvent(type: 'tool_result', name: 'xurl'),
              ],
            ),
          ],
          'older-session': [
            ChatMessage(
              text: 'Dependency packs stay outside the launch gate.',
              isUser: false,
            ),
          ],
        },
      );

  test('session-logs lists bounded app-owned session metadata', () async {
    final frame = await SessionLogsCapability(source: fakeSource()).handle(
      'session-logs.query',
      {'action': 'list', 'limit': 1},
    );

    expect(frame.isError, isFalse);
    final payload = frame.payload!;
    expect(payload['runtime'], 'app-native-session-logs');
    expect(payload['action'], 'list');
    expect(payload['totalSessionCount'], 2);
    expect(payload['returnedSessionCount'], 1);
    final returned = payload['sessions'] as List<dynamic>;
    expect(returned.single['id'], 'active-session');
    expect(returned.single['active'], isTrue);
    expect(returned.single['hasGatewaySessionKey'], isTrue);
    expect(returned.single.containsKey('gatewaySessionKey'), isFalse);
  });

  test('session-logs reads active messages without raw media payloads',
      () async {
    final frame = await SessionLogsCapability(source: fakeSource()).handle(
      'session_logs_query',
      {'action': 'read', 'limit': 2, 'maxMessageChars': 40},
    );

    expect(frame.isError, isFalse);
    final payload = frame.payload!;
    expect(payload['action'], 'read');
    expect(payload['session']['id'], 'active-session');
    final messages = payload['messages'] as List<dynamic>;
    expect(messages, hasLength(2));
    expect(messages.first['role'], 'user');
    expect(
        messages.first['textPreview'].toString().length, lessThanOrEqualTo(40));
    expect(messages.first['hasImage'], isTrue);
    expect(messages.first.containsKey('imageBase64'), isFalse);
    expect(messages.last['toolEventNames'], ['xurl', 'xurl']);
  });

  test('session-logs searches bounded messages across app sessions', () async {
    final frame = await SessionLogsCapability(source: fakeSource()).handle(
      'query',
      {'action': 'search', 'query': 'gateway', 'limit': 5},
    );

    expect(frame.isError, isFalse);
    final payload = frame.payload!;
    expect(payload['action'], 'search');
    expect(payload['query'], 'gateway');
    expect(payload['matchCount'], 1);
    final matches = payload['matches'] as List<dynamic>;
    expect(matches.single['session']['id'], 'active-session');
    expect(matches.single['message']['textPreview'], contains('Gateway'));
  });

  test('session-logs rejects missing search query and unknown sessions',
      () async {
    final capability = SessionLogsCapability(source: fakeSource());

    final missingQuery = await capability.handle(
      'session-logs.query',
      {'action': 'search'},
    );
    expect(missingQuery.isError, isTrue);
    expect(missingQuery.error?['code'], 'MISSING_QUERY');

    final unknownSession = await capability.handle(
      'session-logs.query',
      {'action': 'read', 'sessionId': 'not-real'},
    );
    expect(unknownSession.isError, isTrue);
    expect(unknownSession.error?['code'], 'SESSION_NOT_FOUND');

    final invalidAction = await capability.handle(
      'session-logs.query',
      {'action': 'export'},
    );
    expect(invalidAction.isError, isTrue);
    expect(invalidAction.error?['code'], 'INVALID_ACTION');
  });

  test('session-logs is classified as app-native ready optional', () {
    final entry =
        AndroidSkillSupportManifest.instance.entryFor('session-logs')!;

    expect(entry.status, AndroidSkillSupportStatus.readyOptional);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.appNativeTool);
    expect(entry.requiredConfig, isEmpty);
    expect(entry.launchCritical, isFalse);
  });

  test('session-logs is advertised in native tools catalog with query schema',
      () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog = SkillsService().getToolsCatalog();
    final sessionLogs = catalog
        .cast<Map<String, dynamic>>()
        .singleWhere((tool) => tool['name'] == 'session-logs');
    final schema = sessionLogs['input_schema'] as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;

    expect(sessionLogs['description'], contains('chat session'));
    expect(properties['action'], isA<Map<String, dynamic>>());
    expect(properties['query'], isA<Map<String, dynamic>>());
    expect(schema['required'], contains('action'));
  });

  test('session-logs is allowed as an intentional mobile node command', () {
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      containsAll([
        'session-logs',
        'session_logs',
        'session-logs.query',
        'session_logs_query',
      ]),
    );
  });

  test('explicit session-logs prompt routes through Gateway-visible chunks',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      sessionLogs: SessionLogsCapability(source: fakeSource()),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'session-logs search gateway limit 5',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'session-logs');
    expect(execution.input['action'], 'search');
    expect(execution.input['query'], 'gateway');
    expect(execution.ok, isTrue);
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:session-logs:'));
    expect(
      execution.toolResultChunk,
      startsWith('\x00TOOL_RESULT:session-logs:'),
    );
  });

  test(
      'AgentSkillServer routes session-logs execution to SessionLogsCapability',
      () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'session-logs':"));
    expect(source, contains("'session-logs': 'session-logs.query'"));
    expect(source, contains("_sessionLogsCapability.handle("));
  });
}

class _FakeSessionLogSource implements SessionLogSource {
  _FakeSessionLogSource({
    required this.snapshotValue,
    required this.messagesBySessionId,
  });

  final SessionLogSnapshot snapshotValue;
  final Map<String, List<ChatMessage>> messagesBySessionId;

  @override
  Future<SessionLogSnapshot> snapshot() async => snapshotValue;

  @override
  Future<List<ChatMessage>> loadMessages(String sessionId) async =>
      messagesBySessionId[sessionId] ?? const [];
}
