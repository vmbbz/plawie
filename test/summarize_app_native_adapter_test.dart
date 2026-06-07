import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/summarize_capability.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('summarize extracts a bounded local summary from provided text',
      () async {
    final frame = await SummarizeCapability().handle('summarize.text', {
      'text': [
        'Battery tests passed on the Android bridge.',
        'Weather requests now return bounded app-native summaries.',
        'Battery and sensor routing are the most important launch checks.',
        'Pack-gated media tools remain outside the fresh-user promise.',
      ].join(' '),
      'maxSentences': 2,
      'maxChars': 220,
    });

    expect(frame.isError, isFalse);
    final payload = frame.payload!;
    expect(payload['runtime'], 'app-native-extractive-summary');
    expect(payload['mode'], 'extractive');
    expect(payload['summary'], contains('Battery'));
    expect(payload['sentenceCount'], lessThanOrEqualTo(2));
    expect(payload['summaryChars'], lessThanOrEqualTo(220));
  });

  test('summarize rejects empty text instead of calling a provider', () async {
    final frame = await SummarizeCapability().handle('summarize.text', {
      'text': '   ',
    });

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_TEXT');
  });

  test('summarize is classified as app-native ready optional', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('summarize')!;

    expect(entry.status, AndroidSkillSupportStatus.readyOptional);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.appNativeTool);
    expect(entry.requiredConfig, isEmpty);
    expect(entry.launchCritical, isFalse);
  });

  test('summarize is advertised in native tools catalog with text schema',
      () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog = SkillsService().getToolsCatalog();
    final summarize = catalog
        .cast<Map<String, dynamic>>()
        .singleWhere((tool) => tool['name'] == 'summarize');
    final schema = summarize['input_schema'] as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;

    expect(summarize['description'], contains('Summarize'));
    expect(properties['text'], isA<Map<String, dynamic>>());
    expect(schema['required'], contains('text'));
  });

  test('explicit summarize prompt routes through Gateway-visible tool chunks',
      () async {
    final execution =
        await AppNativeChatToolRouter.instance.tryExecuteRequiredToolIntent(
      'summarize: Battery bridge passed. Battery routing passed. Packs remain pending.',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'summarize');
    expect(execution.input['text'], contains('Battery bridge'));
    expect(execution.input['source'], 'gateway-required-tool-intent');
    expect(execution.ok, isTrue);
    expect(execution.result['runtime'], 'app-native-extractive-summary');
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:summarize:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:summarize:'));
    expect(execution.visibleText, startsWith('Summary: '));
  });

  test('AgentSkillServer routes summarize execution to SummarizeCapability',
      () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'summarize':"));
    expect(source, contains("'summarize': 'summarize.text'"));
    expect(source, contains("_summarizeCapability.handle("));
  });
}
