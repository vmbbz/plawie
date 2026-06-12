import 'dart:convert';

enum AndroidSkillConfigTestRisk {
  safeRead,
  queryRead,
  billableRead,
}

enum AndroidSkillConfigTestSupport {
  liveConnection,
  conditionalSetupStatus,
  saveOnly,
}

class AndroidSkillConfigTestPlan {
  final String skillId;
  final String toolName;
  final Map<String, dynamic> input;
  final AndroidSkillConfigTestRisk risk;
  final String successActionLabel;
  final String buttonLabel;
  final bool acceptsSetupStatusPayload;

  const AndroidSkillConfigTestPlan({
    required this.skillId,
    required this.toolName,
    required this.input,
    required this.risk,
    required this.successActionLabel,
    this.buttonLabel = 'Test Connection',
    this.acceptsSetupStatusPayload = false,
  });

  String get riskLabel {
    return switch (risk) {
      AndroidSkillConfigTestRisk.safeRead => 'Safe read',
      AndroidSkillConfigTestRisk.queryRead => 'Bounded query',
      AndroidSkillConfigTestRisk.billableRead => 'Billable API call',
    };
  }

  String get riskDescription {
    return switch (risk) {
      AndroidSkillConfigTestRisk.safeRead =>
        'Reads account metadata only and does not create or update remote data.',
      AndroidSkillConfigTestRisk.queryRead =>
        'Runs a bounded read query using the visible OpenClaw test input.',
      AndroidSkillConfigTestRisk.billableRead =>
        'Sends a tiny local fixture to the configured transcription API and may use paid API quota.',
    };
  }

  bool get requiresConfirmation =>
      risk == AndroidSkillConfigTestRisk.billableRead;

  String get visibleInputSummary {
    return switch (skillId) {
      'gh-issues' => 'Repository: ${input['owner']}/${input['repo']}, '
          'state: ${input['state']}, limit: ${input['limit']}',
      'goplaces' => 'Query: ${input['query']}, limit: ${input['limit']}',
      'notion' => 'Query: ${input['query']}, limit: ${input['limit']}',
      'openai-whisper-api' =>
        'Fixture: ${input['filename']}, model: ${input['model']}',
      'voice-call' => 'Provider: Twilio, method: ${input['method']}',
      _ => '',
    };
  }

  static AndroidSkillConfigTestPlan? forSkill(
    String skillId, {
    Map<String, String> envValues = const <String, String>{},
    Map<String, dynamic> configValues = const <String, dynamic>{},
  }) {
    final normalized = _normalizeSkillId(skillId);
    const source = 'android-skill-config-test';
    switch (normalized) {
      case 'discord':
        return const AndroidSkillConfigTestPlan(
          skillId: 'discord',
          toolName: 'discord',
          input: {'source': source, 'action': 'me'},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Discord bot',
        );
      case '1password':
        return const AndroidSkillConfigTestPlan(
          skillId: '1password',
          toolName: '1password',
          input: {'source': source, 'action': 'vaults', 'limit': 10},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: '1Password vaults',
        );
      case 'gemini':
        return const AndroidSkillConfigTestPlan(
          skillId: 'gemini',
          toolName: 'gemini',
          input: {'source': source, 'action': 'models', 'limit': 10},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Gemini models',
        );
      case 'github':
        return AndroidSkillConfigTestPlan(
          skillId: normalized,
          toolName: 'github',
          input: const {'source': source, 'action': 'user'},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'GitHub user',
        );
      case 'gh-issues':
        return const AndroidSkillConfigTestPlan(
          skillId: 'gh-issues',
          toolName: 'gh-issues',
          input: {
            'source': source,
            'owner': 'openai',
            'repo': 'codex',
            'state': 'open',
            'limit': 1,
          },
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'GitHub issues',
        );
      case 'goplaces':
        return const AndroidSkillConfigTestPlan(
          skillId: 'goplaces',
          toolName: 'goplaces',
          input: {'source': source, 'query': 'OpenClaw', 'limit': 1},
          risk: AndroidSkillConfigTestRisk.queryRead,
          successActionLabel: 'Google Places search',
        );
      case 'mcporter':
        return const AndroidSkillConfigTestPlan(
          skillId: 'mcporter',
          toolName: 'mcporter',
          input: {'source': source, 'action': 'health'},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'MCPorter health',
        );
      case 'notion':
        return const AndroidSkillConfigTestPlan(
          skillId: 'notion',
          toolName: 'notion',
          input: {'source': source, 'query': 'OpenClaw', 'limit': 1},
          risk: AndroidSkillConfigTestRisk.queryRead,
          successActionLabel: 'Notion search',
        );
      case 'openai-whisper-api':
        return AndroidSkillConfigTestPlan(
          skillId: 'openai-whisper-api',
          toolName: 'openai-whisper-api',
          input: {
            'source': source,
            'audioBase64': _tinySilentWavBase64,
            'filename': 'openclaw-config-test.wav',
            'model': 'gpt-4o-mini-transcribe',
          },
          risk: AndroidSkillConfigTestRisk.billableRead,
          successActionLabel: 'OpenAI transcription',
        );
      case 'sag':
        return const AndroidSkillConfigTestPlan(
          skillId: 'sag',
          toolName: 'sag',
          input: {'source': source, 'action': 'voices', 'limit': 10},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'ElevenLabs voices',
        );
      case 'slack':
        return const AndroidSkillConfigTestPlan(
          skillId: 'slack',
          toolName: 'slack',
          input: {'source': source, 'action': 'me'},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Slack auth',
        );
      case 'spotify-player':
        return const AndroidSkillConfigTestPlan(
          skillId: 'spotify-player',
          toolName: 'spotify-player',
          input: {'source': source, 'action': 'profile'},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Spotify profile',
        );
      case 'trello':
        return const AndroidSkillConfigTestPlan(
          skillId: 'trello',
          toolName: 'trello',
          input: {'source': source, 'action': 'boards', 'limit': 1},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Trello boards',
        );
      case 'voice-call':
        final provider = _configValue(
          'VOICE_CALL_PROVIDER',
          envValues: envValues,
          configValues: configValues,
        ).toLowerCase();
        if (provider != 'twilio') return null;
        return const AndroidSkillConfigTestPlan(
          skillId: 'voice-call',
          toolName: 'twilio-voice',
          input: {'source': source, 'method': 'get_status'},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Twilio Voice setup status',
          buttonLabel: 'Check Setup Status',
          acceptsSetupStatusPayload: true,
        );
    }
    return null;
  }

  static AndroidSkillConfigTestSupport supportForSkill(String skillId) {
    final normalized = _normalizeSkillId(skillId);
    switch (normalized) {
      case '1password':
      case 'discord':
      case 'gemini':
      case 'github':
      case 'gh-issues':
      case 'goplaces':
      case 'mcporter':
      case 'notion':
      case 'openai-whisper-api':
      case 'sag':
      case 'slack':
      case 'spotify-player':
      case 'trello':
        return AndroidSkillConfigTestSupport.liveConnection;
      case 'voice-call':
        return AndroidSkillConfigTestSupport.conditionalSetupStatus;
    }
    return AndroidSkillConfigTestSupport.saveOnly;
  }
}

String _normalizeSkillId(String value) =>
    value.trim().toLowerCase().replaceAll('_', '-');

String _configValue(
  String key, {
  required Map<String, String> envValues,
  required Map<String, dynamic> configValues,
}) {
  return envValues[key]?.trim() ?? configValues[key]?.toString().trim() ?? '';
}

final String _tinySilentWavBase64 = base64Encode(_tinySilentWavBytes);

const List<int> _tinySilentWavBytes = <int>[
  82,
  73,
  70,
  70,
  36,
  0,
  0,
  0,
  87,
  65,
  86,
  69,
  102,
  109,
  116,
  32,
  16,
  0,
  0,
  0,
  1,
  0,
  1,
  0,
  64,
  31,
  0,
  0,
  128,
  62,
  0,
  0,
  1,
  0,
  16,
  0,
  100,
  97,
  116,
  97,
  0,
  0,
  0,
  0,
];
