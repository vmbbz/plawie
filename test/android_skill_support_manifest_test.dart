import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest covers every bundled default and Android bridge skill once',
      () {
    const expectedIds = <String>{
      '1password',
      'apple-notes',
      'apple-reminders',
      'avatar_forge',
      'battery',
      'bear-notes',
      'blogwatcher',
      'blucli',
      'camsnap',
      'canvas',
      'clawhub',
      'coding-agent',
      'diagram-maker',
      'discord',
      'eightctl',
      'gemini',
      'gh-issues',
      'gifgrep',
      'github',
      'gog',
      'goplaces',
      'healthcheck',
      'himalaya',
      'imsg',
      'mcporter',
      'meme-maker',
      'model-usage',
      'nano-pdf',
      'node-connect',
      'node-inspect-debugger',
      'notion',
      'obsidian',
      'openai-whisper',
      'openai-whisper-api',
      'openhue',
      'oracle',
      'ordercli',
      'peekaboo',
      'python-debugpy',
      'sag',
      'sensors',
      'session-logs',
      'sherpa-onnx-tts',
      'skill-creator',
      'slack',
      'songsee',
      'sonoscli',
      'spike',
      'spotify-player',
      'summarize',
      'taskflow',
      'taskflow-inbox-triage',
      'things-mac',
      'tmux',
      'trello',
      'vibrate',
      'video-frames',
      'voice-call',
      'wacli',
      'weather',
      'xurl',
    };

    final manifest = AndroidSkillSupportManifest.instance;
    expect(manifest.skillIds.toSet(), expectedIds);
    expect(manifest.skillIds.length, expectedIds.length);
    expect(manifest.duplicateSkillIds, isEmpty);
    expect(manifest.unclassifiedSkillIds(expectedIds), isEmpty);
  });

  test(
      'manifest separates Android launch skills from config pack and desktop gates',
      () {
    final manifest = AndroidSkillSupportManifest.instance;

    expect(
      manifest
          .entriesForStatus(AndroidSkillSupportStatus.readyRequired)
          .map((entry) => entry.skillId),
      containsAll(['battery', 'sensors', 'vibrate', 'weather', 'taskflow']),
    );
    expect(
      manifest.entryFor('github')!.status,
      AndroidSkillSupportStatus.needsConfig,
    );
    expect(
      manifest.entryFor('openai-whisper')!.status,
      AndroidSkillSupportStatus.needsPack,
    );
    expect(
      manifest.entryFor('node-inspect-debugger')!.requiredPacks,
      ['android-node-executable-pack'],
    );
    expect(
      manifest.entryFor('gemini')!.requiredPacks,
      ['android-gemini-cli-pack'],
    );
    expect(
      manifest.entryFor('coding-agent')!.requiredPacks,
      ['android-agent-cli-pack'],
    );
    expect(manifest.entryFor('xurl')!.toJson(), {
      'skillId': 'xurl',
      'androidSupport': 'ready_optional',
      'ownerLayer': 'appNativeCapability',
      'executionMode': 'httpAdapter',
      'launchCritical': false,
      'smokePrompt': 'Run xurl GET against a local HTTP fixture.',
    });
    expect(manifest.entryFor('diagram-maker')!.toJson(), {
      'skillId': 'diagram-maker',
      'androidSupport': 'ready_optional',
      'ownerLayer': 'openclawSkill',
      'executionMode': 'instructionOnly',
      'launchCritical': false,
      'smokePrompt':
          'Create a tiny standalone diagram artifact from instructions.',
    });
    expect(
      manifest.entryFor('apple-notes')!.status,
      AndroidSkillSupportStatus.unsupportedOnAndroid,
    );
    expect(
      manifest.entryFor('node-connect')!.status,
      AndroidSkillSupportStatus.manualProotCompat,
    );
  });

  test('manifest emits stable health JSON for launch diagnostics', () {
    final weather = AndroidSkillSupportManifest.instance.entryFor('weather')!;
    final github = AndroidSkillSupportManifest.instance.entryFor('github')!;
    final whisper =
        AndroidSkillSupportManifest.instance.entryFor('openai-whisper')!;

    expect(weather.toJson()['androidSupport'], 'ready_required');
    expect(weather.toJson()['launchCritical'], isTrue);
    expect(github.toJson()['requiredConfig'], isNotEmpty);
    expect(
      whisper.toJson()['requiredPacks'],
      contains('android-whisper-runtime'),
    );
  });
}
