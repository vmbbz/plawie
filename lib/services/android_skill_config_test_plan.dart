import 'dart:convert';

enum AndroidSkillConfigTestRisk {
  safeRead,
  queryRead,
  billableRead,
}

class AndroidSkillConfigTestPlan {
  final String skillId;
  final String toolName;
  final Map<String, dynamic> input;
  final AndroidSkillConfigTestRisk risk;
  final String successActionLabel;
  final String buttonLabel;

  const AndroidSkillConfigTestPlan({
    required this.skillId,
    required this.toolName,
    required this.input,
    required this.risk,
    required this.successActionLabel,
    this.buttonLabel = 'Test Connection',
  });

  static AndroidSkillConfigTestPlan? forSkill(String skillId) {
    final normalized = _normalizeSkillId(skillId);
    const source = 'android-skill-config-test';
    switch (normalized) {
      case 'discord':
        return const AndroidSkillConfigTestPlan(
          skillId: 'discord',
          toolName: 'discord',
          input: {'source': source},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Discord bot',
        );
      case 'github':
      case 'gh-issues':
        return AndroidSkillConfigTestPlan(
          skillId: normalized,
          toolName: 'github',
          input: const {'source': source},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'GitHub user',
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
          input: {'source': source},
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
      case 'slack':
        return const AndroidSkillConfigTestPlan(
          skillId: 'slack',
          toolName: 'slack',
          input: {'source': source},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Slack auth',
        );
      case 'trello':
        return const AndroidSkillConfigTestPlan(
          skillId: 'trello',
          toolName: 'trello',
          input: {'source': source, 'limit': 1},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Trello boards',
        );
    }
    return null;
  }
}

String _normalizeSkillId(String value) =>
    value.trim().toLowerCase().replaceAll('_', '-');

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
