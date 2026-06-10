import 'package:clawa/services/android_skill_config_test_plan.dart';
import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps safe config-gated skills to AgentSkillServer tool checks', () {
    final slack = AndroidSkillConfigTestPlan.forSkill('slack')!;
    expect(slack.skillId, 'slack');
    expect(slack.toolName, 'slack');
    expect(slack.input, {
      'source': 'android-skill-config-test',
      'action': 'me',
    });
    expect(slack.buttonLabel, 'Test Connection');
    expect(slack.risk, AndroidSkillConfigTestRisk.safeRead);

    final github = AndroidSkillConfigTestPlan.forSkill('github')!;
    expect(github.toolName, 'github');
    expect(github.input, {
      'source': 'android-skill-config-test',
      'action': 'user',
    });
    expect(github.successActionLabel, 'GitHub user');

    final issues = AndroidSkillConfigTestPlan.forSkill('gh-issues')!;
    expect(issues.toolName, 'gh-issues');
    expect(issues.input, {
      'source': 'android-skill-config-test',
      'owner': 'openai',
      'repo': 'codex',
      'state': 'open',
      'limit': 1,
    });
    expect(issues.successActionLabel, 'GitHub issues');
    expect(
      issues.visibleInputSummary,
      'Repository: openai/codex, state: open, limit: 1',
    );

    final notion = AndroidSkillConfigTestPlan.forSkill('notion')!;
    expect(notion.toolName, 'notion');
    expect(notion.input, {
      'source': 'android-skill-config-test',
      'query': 'OpenClaw',
      'limit': 1,
    });
    expect(notion.risk, AndroidSkillConfigTestRisk.queryRead);
    expect(notion.visibleInputSummary, 'Query: OpenClaw, limit: 1');

    final whisper = AndroidSkillConfigTestPlan.forSkill('openai-whisper-api')!;
    expect(whisper.toolName, 'openai-whisper-api');
    expect(whisper.risk, AndroidSkillConfigTestRisk.billableRead);
    expect(whisper.input.keys, containsAll(['audioBase64', 'filename']));
    expect(whisper.input.values.join(' '), isNot(contains('OPENAI_API_KEY')));
    expect(
      whisper.visibleInputSummary,
      'Fixture: openclaw-config-test.wav, model: gpt-4o-mini-transcribe',
    );

    final discord = AndroidSkillConfigTestPlan.forSkill('discord')!;
    expect(discord.input, {
      'source': 'android-skill-config-test',
      'action': 'me',
    });

    final mcporter = AndroidSkillConfigTestPlan.forSkill('mcporter')!;
    expect(mcporter.input, {
      'source': 'android-skill-config-test',
      'action': 'health',
    });

    final trello = AndroidSkillConfigTestPlan.forSkill('trello')!;
    expect(trello.input, {
      'source': 'android-skill-config-test',
      'action': 'boards',
      'limit': 1,
    });
  });

  test('offers Twilio-only setup status for voice-call config', () {
    expect(AndroidSkillConfigTestPlan.forSkill('voice-call'), isNull);

    final twilio = AndroidSkillConfigTestPlan.forSkill(
      'voice-call',
      envValues: const {'VOICE_CALL_PROVIDER': 'twilio'},
    )!;
    expect(twilio.skillId, 'voice-call');
    expect(twilio.toolName, 'twilio-voice');
    expect(twilio.input, {
      'source': 'android-skill-config-test',
      'method': 'get_status',
    });
    expect(twilio.buttonLabel, 'Check Setup Status');
    expect(twilio.risk, AndroidSkillConfigTestRisk.safeRead);
    expect(twilio.successActionLabel, 'Twilio Voice setup status');
    expect(
      twilio.visibleInputSummary,
      'Provider: Twilio, method: get_status',
    );

    expect(
      AndroidSkillConfigTestPlan.forSkill(
        'voice-call',
        envValues: const {'VOICE_CALL_PROVIDER': 'telnyx'},
      ),
      isNull,
    );
    expect(
      AndroidSkillConfigTestPlan.forSkill(
        'voice-call',
        envValues: const {'VOICE_CALL_PROVIDER': 'custom'},
      ),
      isNull,
    );
  });

  test('does not offer connection checks for config-only placeholders yet', () {
    expect(AndroidSkillConfigTestPlan.forSkill('1password'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('eightctl'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('gog'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('ordercli'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('sag'), isNull);
  });

  test('classifies config support across all Phase 6C gates', () {
    for (final skillId in const [
      'discord',
      'gh-issues',
      'github',
      'goplaces',
      'mcporter',
      'notion',
      'openai-whisper-api',
      'slack',
      'trello',
    ]) {
      expect(
        AndroidSkillConfigTestPlan.supportForSkill(skillId),
        AndroidSkillConfigTestSupport.liveConnection,
        reason: '$skillId has a production Gateway/AgentSkillServer check.',
      );
    }

    expect(
      AndroidSkillConfigTestPlan.supportForSkill('voice-call'),
      AndroidSkillConfigTestSupport.conditionalSetupStatus,
    );

    for (final skillId in const [
      '1password',
      'eightctl',
      'gog',
      'ordercli',
      'sag',
    ]) {
      expect(
        AndroidSkillConfigTestPlan.supportForSkill(skillId),
        AndroidSkillConfigTestSupport.saveOnly,
        reason: '$skillId has no production Android connection surface yet.',
      );
    }
  });

  test('covers every app-native config service in the Android manifest', () {
    final appNativeConfigSkills = AndroidSkillSupportManifest.instance.entries
        .where(
          (entry) =>
              entry.status == AndroidSkillSupportStatus.needsConfig &&
              entry.ownerLayer == AndroidSkillOwnerLayer.appNativeCapability,
        )
        .map((entry) => entry.skillId)
        .toSet();

    expect(appNativeConfigSkills, {
      'discord',
      'gh-issues',
      'github',
      'goplaces',
      'mcporter',
      'notion',
      'openai-whisper-api',
      'slack',
      'trello',
    });

    for (final skillId in appNativeConfigSkills) {
      expect(
        AndroidSkillConfigTestPlan.forSkill(skillId),
        isNotNull,
        reason: '$skillId has a production app-native service adapter.',
      );
    }
  });

  test('exposes user-facing risk copy for every connection test', () {
    final slack = AndroidSkillConfigTestPlan.forSkill('slack')!;
    expect(slack.riskLabel, 'Safe read');
    expect(slack.riskDescription, contains('metadata'));
    expect(slack.requiresConfirmation, isFalse);

    final notion = AndroidSkillConfigTestPlan.forSkill('notion')!;
    expect(notion.riskLabel, 'Bounded query');
    expect(notion.riskDescription, contains('OpenClaw'));
    expect(notion.requiresConfirmation, isFalse);

    final whisper = AndroidSkillConfigTestPlan.forSkill('openai-whisper-api')!;
    expect(whisper.riskLabel, 'Billable API call');
    expect(whisper.riskDescription, contains('transcription'));
    expect(whisper.requiresConfirmation, isTrue);
  });
}
