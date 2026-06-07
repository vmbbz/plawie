import 'package:clawa/services/android_skill_readiness_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computes Android relevant ceiling and ready count from readiness JSON',
      () {
    final model = AndroidSkillReadinessViewModel.fromReadiness({
      'totalManifestSkills': 61,
      'readyRequired': {'ready': 13, 'total': 13},
      'releaseGatePass': true,
      'unexpectedMissingDependency': 0,
      'countsByClass': {
        'ready_required': 13,
        'ready_optional': 1,
        'needs_config': 16,
        'needs_pack': 21,
        'unsupported_on_android': 6,
        'manual_proot_compat': 2,
        'hidden_desktop_only': 2,
      },
      'skills': [
        {
          'skillId': 'weather',
          'androidSupport': 'ready_required',
          'ready': true,
        },
        {
          'skillId': 'diagram-maker',
          'androidSupport': 'needs_pack',
          'requiredPacks': ['android-cli-core-pack'],
          'ready': true,
        },
        {
          'skillId': 'github',
          'androidSupport': 'needs_config',
          'requiredConfig': ['GITHUB_TOKEN'],
          'runtimeStatus': 'missing_dependency',
          'primaryGate': 'missing_native_bin',
          'ready': false,
        },
        {
          'skillId': 'xurl',
          'androidSupport': 'ready_optional',
          'runtimeStatus': 'app_native_ready',
          'ready': true,
        },
        {
          'skillId': 'apple-notes',
          'androidSupport': 'unsupported_on_android',
          'ready': false,
        },
        {
          'skillId': 'node-connect',
          'androidSupport': 'manual_proot_compat',
          'ready': true,
        },
        {
          'skillId': 'obsidian',
          'androidSupport': 'hidden_desktop_only',
          'ready': false,
        },
      ],
    });

    expect(model.manifestTotal, 61);
    expect(model.androidRelevantTotal, 51);
    expect(model.readyRequiredLabel, '13/13');
    expect(model.readyOptionalCount, 1);
    expect(model.readyOptionalLabel, '1');
    expect(model.androidRelevantReady, 3);
    expect(model.releaseGatePass, isTrue);
    expect(model.topNeedsConfig.single.skillId, 'github');
    expect(model.topNeedsConfig.single.detail, contains('GITHUB_TOKEN'));
    expect(model.topNeedsConfig.single.detail, contains('missing_native_bin'));
    expect(model.topNeedsPack, isEmpty);
  });
}
