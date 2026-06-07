import 'package:clawa/services/android_skill_config_form_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds config forms from readiness gates', () {
    final readiness = {
      'skills': [
        {
          'skillId': 'discord',
          'androidSupport': 'needs_config',
          'requiredConfig': ['DISCORD_BOT_TOKEN'],
          'primaryGate': 'missing_native_config',
        },
        {
          'skillId': 'slack',
          'androidSupport': 'needs_config',
          'requiredConfig': ['SLACK_BOT_TOKEN', 'channels.slack'],
          'primaryGate': 'missing_native_config',
        },
        {
          'skillId': 'voice-call',
          'androidSupport': 'needs_config',
          'requiredConfig': ['TWILIO_ACCOUNT_SID'],
          'primaryGate': 'missing_native_bin',
        },
      ],
    };

    final discord = AndroidSkillConfigFormModel.fromReadiness(
      readiness,
      'discord',
    );
    expect(discord, isNotNull);
    expect(discord!.envKeys, ['DISCORD_BOT_TOKEN']);
    expect(discord.configKeys, isEmpty);
    expect(discord.configOnlyCanSatisfy, isTrue);

    final slack = AndroidSkillConfigFormModel.fromReadiness(
      readiness,
      'slack',
    );
    expect(slack, isNotNull);
    expect(slack!.envKeys, ['SLACK_BOT_TOKEN']);
    expect(slack.configKeys, ['channels.slack']);
    expect(slack.configOnlyCanSatisfy, isTrue);

    final voiceCall = AndroidSkillConfigFormModel.fromReadiness(
      readiness,
      'voice-call',
    );
    expect(voiceCall, isNotNull);
    expect(voiceCall!.envKeys, ['TWILIO_ACCOUNT_SID']);
    expect(voiceCall.runtimeGate, 'missing_native_bin');
    expect(voiceCall.configOnlyCanSatisfy, isFalse);
  });
}
