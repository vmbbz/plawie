import 'package:clawa/services/android_skill_provisioning_badge_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies app-native ready skills as ready badge overrides', () {
    final override = classifyAndroidSkillProvisioningBadge({
      'skillId': 'xurl',
      'androidSupport': 'ready_optional',
      'runtimeStatus': 'app_native_ready',
      'ready': true,
    });

    expect(override, isNotNull);
    expect(override!.status, 'app_native_ready');
    expect(override.label, 'READY');
    expect(override.detail, 'Android app-native path ready');
  });

  test('classifies unsupported Android skills outside the GTM lane', () {
    final override = classifyAndroidSkillProvisioningBadge({
      'skillId': 'apple-notes',
      'androidSupport': 'unsupported_on_android',
      'unsupportedReason': 'Requires macOS Notes APIs.',
      'ready': false,
    });

    expect(override, isNotNull);
    expect(override!.status, 'unsupported_on_android');
    expect(override.label, 'OUTSIDE GTM');
    expect(override.detail, 'Requires macOS Notes APIs.');
  });

  test('classifies manual proot skills separately from missing deps', () {
    final override = classifyAndroidSkillProvisioningBadge({
      'skillId': 'desktop-bridge',
      'androidSupport': 'manual_proot_compat',
      'ready': false,
    });

    expect(override, isNotNull);
    expect(override!.status, 'manual_proot_compat');
    expect(override.label, 'MANUAL PROOT');
    expect(override.detail, contains('manual PRoot'));
  });

  test('classifies hidden desktop skills separately from missing deps', () {
    final override = classifyAndroidSkillProvisioningBadge({
      'skillId': 'obsidian',
      'androidSupport': 'hidden_desktop_only',
      'ready': false,
    });

    expect(override, isNotNull);
    expect(override!.status, 'hidden_desktop_only');
    expect(override.label, 'DESKTOP ONLY');
    expect(override.detail, contains('desktop-only'));
  });

  test('leaves unresolved Android-relevant skills to provisioning status', () {
    final override = classifyAndroidSkillProvisioningBadge({
      'skillId': 'spotify-player',
      'androidSupport': 'needs_pack',
      'runtimeStatus': 'missing_binary',
      'provisioningStatus': 'missing_binary',
      'ready': false,
    });

    expect(override, isNull);
  });

  test('config-only rows are shown as config gates, not missing deps', () {
    for (final skillId in const [
      'sag',
      'slack',
      'discord',
      'eightctl',
      'gemini',
      'gh-issues',
      'spotify-player',
      'trello',
      'github',
      'goplaces',
      'mcporter',
      'notion',
      'openai-whisper-api',
      '1password',
    ]) {
      final override = classifyAndroidSkillProvisioningBadge({
        'skillId': skillId,
        'androidSupport': skillId == 'eightctl' ? 'needs_pack' : 'needs_config',
        'runtimeStatus': 'missing_dependency',
        'provisioningStatus': 'needs_user_config',
        'requiredEnv': ['CONFIG_FOR_$skillId'],
        'ready': false,
      });

      expect(override, isNotNull, reason: skillId);
      expect(override!.status, 'needs_user_config', reason: skillId);
      expect(override.label, 'NEEDS CONFIG', reason: skillId);
    }
  });

  test('true runtime pack rows still fall through as missing deps', () {
    for (final skillId in const [
      'sherpa-onnx-tts',
      'coding-agent',
      'node-inspect-debugger',
      'openai-whisper',
    ]) {
      final override = classifyAndroidSkillProvisioningBadge({
        'skillId': skillId,
        'androidSupport': 'needs_pack',
        'runtimeStatus': 'missing_dependency',
        'provisioningStatus': 'missing_dependency',
        'requiredPacks': ['runtime-pack-for-$skillId'],
        'missingPacks': ['runtime-pack-for-$skillId'],
        'ready': false,
      });

      expect(override, isNull, reason: skillId);
    }
  });

  // --- NEW live readiness oracle tests (Workstream D / GTM plan fidelity) ---

  test('live ready status overrides static taxonomy for needs_pack skills', () {
    final override = classifyAndroidSkillProvisioningBadge({
      'skillId': 'gifgrep',
      'androidSupport': 'needs_pack',
      'runtimeStatus': 'ready',
      'provisioningStatus': 'ready',
      'ready': true,
    });

    expect(override, isNotNull);
    expect(override!.status, 'ready');
    expect(override.label, 'READY');
    expect(override.detail, contains('live status'));
  });

  test(
      'live ready status forces READY even when static androidSupport is needs_config',
      () {
    final override = classifyAndroidSkillProvisioningBadge({
      'skillId': 'himalaya',
      'androidSupport': 'needs_config',
      'runtimeStatus': 'ready',
      'provisioningStatus': 'ready',
      'ready': true,
    });

    expect(override, isNotNull);
    expect(override!.label, 'READY');
  });

  test('live ready + app_native path still produces clean READY', () {
    final override = classifyAndroidSkillProvisioningBadge({
      'skillId': 'xurl-v2',
      'androidSupport': 'ready_optional',
      'runtimeStatus': 'ready',
      'provisioningStatus': 'ready',
      'ready': true,
    });

    expect(override, isNotNull);
    expect(override!.label, 'READY');
  });

  test(
      'live-ready row with excluded androidSupport still does not override to READY',
      () {
    final override = classifyAndroidSkillProvisioningBadge({
      'skillId': 'some-prroot-thing',
      'androidSupport': 'manual_proot_compat',
      'runtimeStatus': 'ready',
      'provisioningStatus': 'ready',
    });

    // It should fall through to the manual_proot case (or null if not handled), never generic ready
    expect(override?.status ?? '', isNot('ready'));
  });
}
