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
    expect(find.text('Enable voice-call skill'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'android-skill-config-field-plugins.entries.voice-call.enabled',
        ),
      ),
      findsOneWidget,
    );

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

  testWidgets('successful save shows sanitized Gateway refresh status',
      (tester) async {
    await _pumpSheet(
      tester,
      _slackModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async =>
          _satisfiedReport(
        skillId,
        changed: true,
        reloadRecommended: true,
      ),
    );

    await tester.enterText(_textFieldByLabel('Bot token'), 'xoxb-test-secret');
    await tester.enterText(_textFieldByLabel('Default Slack channel'), 'C123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(
      find.text('Config saved. Gateway refresh requested.'),
      findsOneWidget,
    );
  });

  testWidgets('editing saved values clears provisioning status',
      (tester) async {
    await _pumpSheet(
      tester,
      _slackModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async =>
          _satisfiedReport(
        skillId,
        changed: true,
        reloadRecommended: true,
      ),
    );

    await tester.enterText(_textFieldByLabel('Bot token'), 'xoxb-test-secret');
    await tester.enterText(_textFieldByLabel('Default Slack channel'), 'C123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.textContaining('Gateway refresh requested'), findsOneWidget);

    await tester.enterText(_textFieldByLabel('Default Slack channel'), 'C456');
    await tester.pump();

    expect(find.textContaining('Gateway refresh requested'), findsNothing);
    expect(find.text('Test Connection'), findsNothing);
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

  testWidgets('eightctl save-only gate explains account validation boundary',
      (tester) async {
    await _pumpSheet(
      tester,
      _eightctlModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async =>
          _satisfiedReport(skillId),
    );

    await tester.enterText(
      _textFieldByLabel('Eight Sleep password'),
      'eight-password',
    );
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.text('Test Connection'), findsNothing);
    expect(
      find.textContaining('live Eight Sleep account/device validation'),
      findsOneWidget,
    );
  });

  testWidgets('full save-only gates explain missing Android adapter boundary',
      (tester) async {
    await _pumpSheet(
      tester,
      _onePasswordModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async =>
          _satisfiedReport(skillId),
    );

    await tester.enterText(
      _textFieldByLabel('Service account token'),
      'op-secret-token',
    );
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.text('Test Connection'), findsNothing);
    expect(find.textContaining('1Password config saved'), findsOneWidget);
    expect(
      find.textContaining('Gateway/AgentSkillServer adapter'),
      findsOneWidget,
    );
  });

  testWidgets('Twilio voice-call save reveals setup status check',
      (tester) async {
    AndroidSkillConfigTestPlan? capturedPlan;
    Map<String, String>? capturedEnv;
    Map<String, dynamic>? capturedConfig;

    await _pumpSheet(
      tester,
      _voiceCallModel(),
      applyConfig: ({
        required skillId,
        envValues = const <String, String>{},
        configValues = const <String, dynamic>{},
      }) async {
        capturedEnv = Map<String, String>.from(envValues);
        capturedConfig = Map<String, dynamic>.from(configValues);
        return _satisfiedReport(skillId);
      },
      testConnection: (plan) async {
        capturedPlan = plan;
        return const AndroidSkillConfigTestResult(
          ok: false,
          message: 'Twilio Voice setup status check failed.',
          safeSummary: '{"status":"CONFIG_REQUIRED"}',
        );
      },
    );

    await tester.enterText(_textFieldByLabel('Account identifier'), 'acct_123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(capturedEnv, {
      'VOICE_CALL_PROVIDER': 'twilio',
      'VOICE_CALL_ACCOUNT': 'acct_123',
    });
    expect(capturedConfig, {
      'plugins.entries.voice-call.enabled': 'true',
    });
    expect(find.text('Check Setup Status'), findsOneWidget);
    expect(find.text('Safe read'), findsOneWidget);
    expect(
      find.textContaining('Provider: Twilio, method: get_status'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
        .clearSnackBars();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Check Setup Status'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Check Setup Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check Setup Status'));
    await tester.pumpAndSettle();

    expect(capturedPlan?.toolName, 'twilio-voice');
    expect(capturedPlan?.input, {
      'source': 'android-skill-config-test',
      'method': 'get_status',
    });
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
        .clearSnackBars();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Twilio Voice setup status check failed.'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Twilio Voice setup status check failed.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('CONFIG_REQUIRED'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('CONFIG_REQUIRED'), findsOneWidget);
  });

  testWidgets('non-Twilio voice-call providers stay save-only', (tester) async {
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

    await tester.tap(find.text('twilio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('telnyx').last);
    await tester.pumpAndSettle();

    await tester.enterText(_textFieldByLabel('Account identifier'), 'acct_123');
    await tester.tap(find.text('Save & Check'));
    await tester.pump();

    expect(find.text('Check Setup Status'), findsNothing);
    expect(find.text('Test Connection'), findsNothing);
    expect(
      find.textContaining(
          'setup checks are currently available only for Twilio'),
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

AndroidSkillConfigFormModel _onePasswordModel() {
  return AndroidSkillConfigFormModel.fromSkill({
    'skillId': '1password',
    'androidSupport': 'needs_config',
    'requiredConfig': ['OP_SERVICE_ACCOUNT_TOKEN'],
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
    'requiredConfig': [
      'VOICE_CALL_PROVIDER',
      'VOICE_CALL_ACCOUNT',
      'plugins.entries.voice-call.enabled',
    ],
    'primaryGate': 'missing_native_config',
  });
}

AndroidSkillConfigFormModel _eightctlModel() {
  return AndroidSkillConfigFormModel.fromSkill({
    'skillId': 'eightctl',
    'androidSupport': 'needs_pack',
    'runtimeStatus': 'needs_config',
    'provisioningStatus': 'needs_user_config',
    'requiredEnv': ['EIGHTCTL_PASSWORD'],
    'ready': false,
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

SkillProvisioningReport _satisfiedReport(
  String skillId, {
  bool changed = true,
  bool reloadRecommended = false,
  SkillProvisioningStatus status = SkillProvisioningStatus.satisfied,
  String? primaryGate,
}) {
  return SkillProvisioningReport(
    filesDir: '',
    skillId: skillId,
    auditedAt: DateTime(2026, 6, 7),
    generatedAt: DateTime(2026, 6, 7),
    results: [
      SkillProvisioningSkillResult(
        skillId: skillId,
        readiness: 'needs_config',
        status: status,
        primaryGate: primaryGate,
        actions: const <SkillProvisioningAction>[],
        changed: changed,
        reloadRecommended: reloadRecommended,
      ),
    ],
    changed: changed,
    reloadRecommended: reloadRecommended,
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
