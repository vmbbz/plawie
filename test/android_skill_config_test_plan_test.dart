import 'package:clawa/services/android_skill_config_test_plan.dart';
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

    final github = AndroidSkillConfigTestPlan.forSkill('gh-issues')!;
    expect(github.toolName, 'github');
    expect(github.input, {
      'source': 'android-skill-config-test',
      'action': 'user',
    });
    expect(github.successActionLabel, 'GitHub user');

    final notion = AndroidSkillConfigTestPlan.forSkill('notion')!;
    expect(notion.toolName, 'notion');
    expect(notion.input, {
      'source': 'android-skill-config-test',
      'query': 'OpenClaw',
      'limit': 1,
    });
    expect(notion.risk, AndroidSkillConfigTestRisk.queryRead);

    final whisper = AndroidSkillConfigTestPlan.forSkill('openai-whisper-api')!;
    expect(whisper.toolName, 'openai-whisper-api');
    expect(whisper.risk, AndroidSkillConfigTestRisk.billableRead);
    expect(whisper.input.keys, containsAll(['audioBase64', 'filename']));
    expect(whisper.input.values.join(' '), isNot(contains('OPENAI_API_KEY')));

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

  test('does not offer connection checks for config-only placeholders yet', () {
    expect(AndroidSkillConfigTestPlan.forSkill('1password'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('ordercli'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('sag'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('voice-call'), isNull);
  });
}
