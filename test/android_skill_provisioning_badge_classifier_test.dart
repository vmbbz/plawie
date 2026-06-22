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
