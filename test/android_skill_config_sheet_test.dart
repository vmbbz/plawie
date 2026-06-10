import 'package:clawa/screens/management/skills/android_skill_config_sheet.dart';
import 'package:clawa/services/android_skill_config_form_model.dart';
import 'package:clawa/services/android_skill_config_test_plan.dart';
import 'package:clawa/services/android_skill_config_test_service.dart';
import 'package:clawa/services/skill_provisioning_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders service-aware Slack fields and masks secrets',
      (tester) async {
    await _pumpSheet(tester, _slackModel());

    expect(find.text('Slack'), findsOneWidget);
    expect(find.text('Bot token'), findsOneWidget);
    expect(find.text('Default Slack channel'), findsOneWidget);
    expect(find.text('CREDENTIALS'), findsOneWidget);
    expect(find.text('WORKSPACE'), findsOneWidget);
    expect(find.byTooltip('Show value'), findsOneWidget);
    expect(find.text('SLACK_BOT_TOKEN'), findsNothing);
  });

  testWidgets('missing required values show user-facing field labels',
      (tester) async {
    await _pumpSheet(tester, _slackModel());

    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(
      find.text('Missing values: Bot token, Default Slack channel'),
      findsOneWidget,
    );
    expect(find.text('Bot token'), findsOneWidget);
    expect(find.text('Default Slack channel'), findsOneWidget);
    expect(find.textContaining('xoxb-test-secret'), findsNothing);
  });

  testWidgets('URL fields reject non-URL values before save', (tester) async {
    await _pumpSheet(tester, _mcporterModel());

    await tester.enterText(_textFieldByLabel('MCPorter endpoint'), 'localhost');
    await tester.enterText(_textFieldByLabel('MCPorter token'), 'token-value');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.text('Invalid URL: MCPorter endpoint'), findsOneWidget);
    expect(find.text('MCPorter endpoint'), findsOneWidget);
    expect(find.textContaining('Invalid URL: localhost'), findsNothing);
  });

  testWidgets('provider fields render as dropdown choices', (tester) async {
    await _pumpSheet(tester, _voiceCallModel());

    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('twilio'), findsOneWidget);

    await tester.tap(find.text('twilio'));
    await tester.pumpAndSettle();
    expect(find.text('telnyx'), findsOneWidget);
    expect(find.text('custom'), findsOneWidget);
  });

  testWidgets('save splits env and config values for provisioning',
      (tester) async {
    Map<String, String>? capturedEnv;
    Map<String, dynamic>? capturedConfig;

    await _pumpSheet(
      tester,
      _slackModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async {
        capturedEnv = Map<String, String>.from(envValues);
        capturedConfig = Map<String, dynamic>.from(configValues);
        return _satisfiedReport(skillId);
      },
    );

    await tester.enterText(_textFieldByLabel('Bot token'), 'xoxb-test-secret');
    await tester.enterText(_textFieldByLabel('Default Slack channel'), 'C123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(capturedEnv, {'SLACK_BOT_TOKEN': 'xoxb-test-secret'});
    expect(capturedConfig, {'channels.slack': 'C123'});
  });

  testWidgets(
      'successful save reveals test connection action for supported skill',
      (tester) async {
    AndroidSkillConfigTestPlan? capturedPlan;

    await _pumpSheet(
      tester,
      _slackModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async =>
          _satisfiedReport(skillId),
      testConnection: (plan) async {
        capturedPlan = plan;
        return const AndroidSkillConfigTestResult(
          ok: true,
          message: 'Slack auth check passed.',
          safeSummary: '{"team":"OpenClaw"}',
        );
      },
    );

    expect(find.text('Test Connection'), findsNothing);

    await tester.enterText(_textFieldByLabel('Bot token'), 'xoxb-test-secret');
    await tester.enterText(_textFieldByLabel('Default Slack channel'), 'C123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.text('Test Connection'), findsOneWidget);
    await tester.tap(find.text('Test Connection'));
    await tester.pump();

    expect(capturedPlan?.toolName, 'slack');
    expect(find.text('Slack auth check passed.'), findsOneWidget);
    expect(find.textContaining('OpenClaw'), findsOneWidget);
    expect(find.textContaining('must-not-leak'), findsNothing);
  });

  testWidgets('connection test failures stay sanitized', (tester) async {
    await _pumpSheet(
      tester,
      _slackModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async =>
          _satisfiedReport(skillId),
      testConnection: (_) async => const AndroidSkillConfigTestResult(
        ok: false,
        message: 'Slack auth check failed.',
        safeSummary: 'Bad token [secret]',
      ),
    );

    await tester.enterText(_textFieldByLabel('Bot token'), 'xoxb-test-secret');
    await tester.enterText(_textFieldByLabel('Default Slack channel'), 'C123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();
    await tester.tap(find.text('Test Connection'));
    await tester.pump();

    expect(find.text('Slack auth check failed.'), findsOneWidget);
    expect(find.textContaining('Bad token [secret]'), findsOneWidget);
    expect(find.textContaining('xoxb-secret'), findsNothing);
  });

  testWidgets('query checks show bounded input before testing', (tester) async {
    AndroidSkillConfigTestPlan? capturedPlan;

    await _pumpSheet(
      tester,
      _notionModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async =>
          _satisfiedReport(skillId),
      testConnection: (plan) async {
        capturedPlan = plan;
        return const AndroidSkillConfigTestResult(
          ok: true,
          message: 'Notion search check passed.',
          safeSummary: '{"count":"1"}',
        );
      },
    );

    await tester.enterText(
      _textFieldByLabel('Integration token'),
      'secret_notion_token',
    );
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.text('Bounded query'), findsOneWidget);
    expect(find.textContaining('Query: OpenClaw, limit: 1'), findsOneWidget);

    await tester.tap(find.text('Test Connection'));
    await tester.pump();

    expect(capturedPlan?.skillId, 'notion');
    expect(find.text('Notion search check passed.'), findsOneWidget);
  });

  testWidgets('billable checks require explicit confirmation', (tester) async {
    AndroidSkillConfigTestPlan? capturedPlan;

    await _pumpSheet(
      tester,
      _openAiWhisperModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async =>
          _satisfiedReport(skillId),
      testConnection: (plan) async {
        capturedPlan = plan;
        return const AndroidSkillConfigTestResult(
          ok: true,
          message: 'OpenAI transcription check passed.',
          safeSummary: '{"text":""}',
        );
      },
    );

    await tester.enterText(
      _textFieldByLabel('OpenAI API key'),
      'sk-secret-openai',
    );
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.text('Billable API call'), findsOneWidget);
    expect(find.textContaining('openclaw-config-test.wav'), findsOneWidget);

    await tester.tap(find.text('Test Connection'));
    await tester.pumpAndSettle();

    expect(capturedPlan, isNull);
    expect(find.text('Run billable connection test?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('sk-secret-openai'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Run Test'));
    await tester.pump();

    expect(capturedPlan?.skillId, 'openai-whisper-api');
    expect(find.text('OpenAI transcription check passed.'), findsOneWidget);
  });

  testWidgets('save-only config gates show no live test message',
      (tester) async {
    await _pumpSheet(
      tester,
      _voiceCallModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async =>
          _satisfiedReport(skillId),
    );

    await tester.enterText(_textFieldByLabel('Account identifier'), 'acct_123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.text('Test Connection'), findsNothing);
    expect(
      find.textContaining('No live connection test is available yet'),
      findsOneWidget,
    );
  });

  testWidgets('empty provisioning result is shown as an explicit failure',
      (tester) async {
    await _pumpSheet(
      tester,
      _slackModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async {
        return _emptyReport(skillId);
      },
    );

    await tester.enterText(_textFieldByLabel('Bot token'), 'xoxb-test-secret');
    await tester.enterText(_textFieldByLabel('Default Slack channel'), 'C123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.textContaining('No provisioning result'), findsOneWidget);
    expect(find.textContaining('config saved'), findsNothing);
  });

  testWidgets('provider save failures do not leak typed secret values',
      (tester) async {
    await _pumpSheet(
      tester,
      _slackModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async {
        throw Exception('xoxb-test-secret should not surface');
      },
    );

    await tester.enterText(_textFieldByLabel('Bot token'), 'xoxb-test-secret');
    await tester.enterText(_textFieldByLabel('Default Slack channel'), 'C123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(
      find.text('Save failed. Check skill configuration and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('should not surface'), findsNothing);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester,
  AndroidSkillConfigFormModel model, {
  AndroidSkillConfigApply? applyConfig,
  AndroidSkillConfigTestApply? testConnection,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AndroidSkillConfigSheet(
          model: model,
          applyConfig: applyConfig,
          testConnection: testConnection,
        ),
      ),
    ),
  );
}

AndroidSkillConfigFormModel _slackModel() {
  return AndroidSkillConfigFormModel.fromSkill({
    'skillId': 'slack',
    'androidSupport': 'needs_config',
    'requiredConfig': ['SLACK_BOT_TOKEN', 'channels.slack'],
    'primaryGate': 'missing_native_config',
  });
}

AndroidSkillConfigFormModel _mcporterModel() {
  return AndroidSkillConfigFormModel.fromSkill({
    'skillId': 'mcporter',
    'androidSupport': 'needs_config',
    'requiredConfig': ['MCPORTER_ENDPOINT', 'MCPORTER_TOKEN'],
    'primaryGate': 'missing_native_config',
  });
}

AndroidSkillConfigFormModel _voiceCallModel() {
  return AndroidSkillConfigFormModel.fromSkill({
    'skillId': 'voice-call',
    'androidSupport': 'needs_config',
    'requiredConfig': ['VOICE_CALL_PROVIDER', 'VOICE_CALL_ACCOUNT'],
    'primaryGate': 'missing_native_config',
  });
}

AndroidSkillConfigFormModel _notionModel() {
  return AndroidSkillConfigFormModel.fromSkill({
    'skillId': 'notion',
    'androidSupport': 'needs_config',
    'requiredConfig': ['NOTION_TOKEN'],
    'primaryGate': 'missing_native_config',
  });
}

AndroidSkillConfigFormModel _openAiWhisperModel() {
  return AndroidSkillConfigFormModel.fromSkill({
    'skillId': 'openai-whisper-api',
    'androidSupport': 'needs_config',
    'requiredConfig': ['OPENAI_API_KEY'],
    'primaryGate': 'missing_native_config',
  });
}

SkillProvisioningReport _emptyReport(String skillId) {
  return SkillProvisioningReport(
    filesDir: '',
    skillId: skillId,
    auditedAt: DateTime(2026, 6, 7),
    generatedAt: DateTime(2026, 6, 7),
    results: const <SkillProvisioningSkillResult>[],
    changed: true,
    reloadRecommended: false,
  );
}

SkillProvisioningReport _satisfiedReport(String skillId) {
  return SkillProvisioningReport(
    filesDir: '',
    skillId: skillId,
    auditedAt: DateTime(2026, 6, 7),
    generatedAt: DateTime(2026, 6, 7),
    results: [
      SkillProvisioningSkillResult(
        skillId: skillId,
        readiness: 'needs_config',
        status: SkillProvisioningStatus.satisfied,
        primaryGate: null,
        actions: const <SkillProvisioningAction>[],
        changed: true,
        reloadRecommended: false,
      ),
    ],
    changed: true,
    reloadRecommended: false,
  );
}

Finder _textFieldByLabel(String label) {
  return find
      .ancestor(
        of: find.text(label),
        matching: find.byType(TextField),
      )
      .first;
}
