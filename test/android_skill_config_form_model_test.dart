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

  test('slack config form exposes service-aware credential and channel fields',
      () {
    final readiness = {
      'skills': [
        {
          'skillId': 'slack',
          'androidSupport': 'needs_config',
          'requiredConfig': ['SLACK_BOT_TOKEN', 'channels.slack'],
          'primaryGate': 'missing_native_config',
        },
      ],
    };

    final form = AndroidSkillConfigFormModel.fromReadiness(readiness, 'slack')!;

    expect(form.title, 'Slack');
    expect(form.fields.map((field) => field.key), [
      'SLACK_BOT_TOKEN',
      'channels.slack',
    ]);

    final token = form.fields.firstWhere(
      (field) => field.key == 'SLACK_BOT_TOKEN',
    );
    expect(token.label, 'Bot token');
    expect(token.group, 'Credentials');
    expect(token.target, AndroidSkillConfigFieldTarget.env);
    expect(token.inputKind, AndroidSkillConfigInputKind.secret);
    expect(token.secret, isTrue);

    final channel = form.fields.firstWhere(
      (field) => field.key == 'channels.slack',
    );
    expect(channel.label, 'Default Slack channel');
    expect(channel.group, 'Workspace');
    expect(channel.target, AndroidSkillConfigFieldTarget.config);
    expect(channel.inputKind, AndroidSkillConfigInputKind.channelId);
    expect(channel.secret, isFalse);
  });

  test('mcporter fields use URL endpoint and secret token metadata', () {
    final readiness = {
      'skills': [
        {
          'skillId': 'mcporter',
          'androidSupport': 'needs_config',
          'requiredConfig': ['MCPORTER_ENDPOINT', 'MCPORTER_TOKEN'],
          'primaryGate': 'missing_native_config',
        },
      ],
    };

    final form =
        AndroidSkillConfigFormModel.fromReadiness(readiness, 'mcporter')!;
    final endpoint = form.fields.firstWhere(
      (field) => field.key == 'MCPORTER_ENDPOINT',
    );
    final token = form.fields.firstWhere(
      (field) => field.key == 'MCPORTER_TOKEN',
    );

    expect(endpoint.label, 'MCPorter endpoint');
    expect(endpoint.inputKind, AndroidSkillConfigInputKind.url);
    expect(endpoint.secret, isFalse);
    expect(token.label, 'MCPorter token');
    expect(token.inputKind, AndroidSkillConfigInputKind.secret);
    expect(token.secret, isTrue);
  });

  test('voice call fields expose provider choices and account metadata', () {
    final readiness = {
      'skills': [
        {
          'skillId': 'voice-call',
          'androidSupport': 'needs_config',
          'requiredConfig': [
            'VOICE_CALL_PROVIDER',
            'VOICE_CALL_ACCOUNT',
            'plugins.entries.voice-call.enabled',
          ],
          'primaryGate': 'missing_native_config',
        },
      ],
    };

    final form = AndroidSkillConfigFormModel.fromReadiness(
      readiness,
      'voice-call',
    )!;
    final provider = form.fields.firstWhere(
      (field) => field.key == 'VOICE_CALL_PROVIDER',
    );
    final account = form.fields.firstWhere(
      (field) => field.key == 'VOICE_CALL_ACCOUNT',
    );
    final enabled = form.fields.firstWhere(
      (field) => field.key == 'plugins.entries.voice-call.enabled',
    );

    expect(provider.inputKind, AndroidSkillConfigInputKind.provider);
    expect(provider.enumOptions, ['twilio', 'telnyx', 'custom']);
    expect(account.inputKind, AndroidSkillConfigInputKind.accountId);
    expect(account.secret, isFalse);
    expect(enabled.label, 'Enable voice-call skill');
    expect(enabled.group, 'Skill');
    expect(enabled.inputKind, AndroidSkillConfigInputKind.toggle);
    expect(enabled.secret, isFalse);
  });

  test('unknown required config keys get safe fallback metadata', () {
    final readiness = {
      'skills': [
        {
          'skillId': 'custom-service',
          'androidSupport': 'needs_config',
          'requiredConfig': ['CUSTOM_API_KEY', 'channels.custom'],
          'primaryGate': 'missing_native_config',
        },
      ],
    };

    final form = AndroidSkillConfigFormModel.fromReadiness(
      readiness,
      'custom-service',
    )!;
    final apiKey = form.fields.firstWhere(
      (field) => field.key == 'CUSTOM_API_KEY',
    );
    final channel = form.fields.firstWhere(
      (field) => field.key == 'channels.custom',
    );

    expect(form.title, 'Custom Service');
    expect(apiKey.target, AndroidSkillConfigFieldTarget.env);
    expect(apiKey.inputKind, AndroidSkillConfigInputKind.secret);
    expect(apiKey.secret, isTrue);
    expect(channel.target, AndroidSkillConfigFieldTarget.config);
    expect(channel.inputKind, AndroidSkillConfigInputKind.text);
    expect(channel.secret, isFalse);
  });

  test('unknown dotted secret-like config keys are masked safely', () {
    final readiness = {
      'skills': [
        {
          'skillId': 'custom-service',
          'androidSupport': 'needs_config',
          'requiredConfig': ['providers.custom.apiKey', 'auth.token'],
          'primaryGate': 'missing_native_config',
        },
      ],
    };

    final form = AndroidSkillConfigFormModel.fromReadiness(
      readiness,
      'custom-service',
    )!;

    for (final field in form.fields) {
      expect(field.target, AndroidSkillConfigFieldTarget.config);
      expect(field.inputKind, AndroidSkillConfigInputKind.secret);
      expect(field.secret, isTrue);
    }
  });

  test('pack-class skills with runtime config gates are still configurable',
      () {
    final readiness = {
      'skills': [
        {
          'skillId': 'eightctl',
          'androidSupport': 'needs_pack',
          'runtimeStatus': 'needs_config',
          'provisioningStatus': 'needs_user_config',
          'requiredEnv': ['EIGHTCTL_PASSWORD'],
          'ready': false,
        },
        {
          'skillId': 'openai-whisper',
          'androidSupport': 'needs_pack',
          'runtimeStatus': 'missing_dependency',
          'requiredPacks': ['android-whisper-runtime'],
          'ready': false,
        },
      ],
    };

    final forms = AndroidSkillConfigFormModel.allFromReadiness(readiness);
    expect(forms.map((form) => form.skillId), ['eightctl']);

    final eightctl = forms.single;
    expect(eightctl.title, 'Eight Sleep');
    expect(eightctl.envKeys, ['EIGHTCTL_PASSWORD']);
    expect(eightctl.configKeys, isEmpty);
    expect(eightctl.runtimeGate, 'needs_config');
    expect(eightctl.configOnlyCanSatisfy, isTrue);

    final password = eightctl.fields.firstWhere(
      (field) => field.key == 'EIGHTCTL_PASSWORD',
    );
    expect(password.label, 'Eight Sleep password');
    expect(password.group, 'Credentials');
    expect(password.inputKind, AndroidSkillConfigInputKind.secret);
    expect(password.secret, isTrue);
  });

  test('mixed pack and config gates stay out of config unlock list', () {
    final readiness = {
      'skills': [
        {
          'skillId': 'eightctl',
          'androidSupport': 'needs_pack',
          'runtimeStatus': 'needs_config',
          'provisioningStatus': 'needs_user_config',
          'requiredEnv': ['EIGHTCTL_PASSWORD'],
          'ready': false,
        },
        {
          'skillId': 'spotify-player',
          'androidSupport': 'needs_pack',
          'runtimeStatus': 'needs_config',
          'provisioningStatus': 'needs_user_config',
          'primaryGate': 'missing_native_env',
          'gates': ['missing_native_env', 'missing_native_bin'],
          'missingBins': ['spogo'],
          'requiredEnv': ['SPOTIFY_COOKIE'],
          'requiredPacks': ['android-audio-runtime'],
          'ready': false,
        },
      ],
    };

    final forms = AndroidSkillConfigFormModel.allFromReadiness(readiness);
    expect(forms.map((form) => form.skillId), ['eightctl']);

    final spotify = AndroidSkillConfigFormModel.fromReadiness(
      readiness,
      'spotify-player',
    )!;
    expect(spotify.configOnlyCanSatisfy, isFalse);
  });
}
