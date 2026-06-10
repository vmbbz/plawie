import 'dart:convert';

import 'package:clawa/services/android_skill_config_test_plan.dart';
import 'package:clawa/services/android_skill_config_test_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts test plan to local AgentSkillServer tool execution route',
      () async {
    Map<String, dynamic>? capturedBody;
    final service = AndroidSkillConfigTestService(
      baseUri: Uri.parse('http://127.0.0.1:8765'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'http://127.0.0.1:8765/api/tools/execute',
        );
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'runtime': 'app-native-slack-rest',
            'team': 'OpenClaw',
            'token': 'must-not-leak',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.run(
      AndroidSkillConfigTestPlan.forSkill('slack')!,
    );

    expect(capturedBody, {
      'name': 'slack',
      'input': {'source': 'android-skill-config-test', 'action': 'me'},
    });
    expect(result.ok, isTrue);
    expect(result.message, 'Slack auth check passed.');
    expect(result.safeSummary, contains('team'));
    expect(jsonEncode(result.toJson()), isNot(contains('must-not-leak')));
  });

  test('normalizes failed bridge results without leaking request input',
      () async {
    final service = AndroidSkillConfigTestService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': jsonEncode({
              'message': 'Bad token xoxb-secret',
            }),
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.run(
      AndroidSkillConfigTestPlan.forSkill('slack')!,
    );

    expect(result.ok, isFalse);
    expect(result.message, 'Slack auth check failed.');
    expect(result.safeSummary, contains('Bad token'));
    expect(result.safeSummary, isNot(contains('xoxb-secret')));
  });

  test('treats setup-status payloads with missing config as failed', () async {
    final service = AndroidSkillConfigTestService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'provider': 'Twilio Voice',
            'configured': false,
            'connected': false,
            'status': 'CONFIG_REQUIRED',
            'actionRequired':
                'Configure Twilio Account SID and Auth Token AC1234567890abcdef1234567890abcdef',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.run(
      AndroidSkillConfigTestPlan.forSkill(
        'voice-call',
        envValues: const {'VOICE_CALL_PROVIDER': 'twilio'},
      )!,
    );

    expect(result.ok, isFalse);
    expect(result.message, 'Twilio Voice setup status check failed.');
    expect(result.safeSummary, contains('CONFIG_REQUIRED'));
    expect(result.safeSummary, isNot(contains('AC1234567890')));
  });

  test('accepts successful setup-status payloads without success wrapper',
      () async {
    final service = AndroidSkillConfigTestService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'provider': 'Twilio Voice',
            'configured': true,
            'connected': true,
            'status': 'READY',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.run(
      AndroidSkillConfigTestPlan.forSkill(
        'voice-call',
        envValues: const {'VOICE_CALL_PROVIDER': 'twilio'},
      )!,
    );

    expect(result.ok, isTrue);
    expect(result.message, 'Twilio Voice setup status check passed.');
    expect(result.safeSummary, contains('READY'));
  });
}
