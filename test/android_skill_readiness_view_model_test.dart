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
        'ready_optional': 2,
        'needs_config': 16,
        'needs_pack': 20,
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
          'androidSupport': 'ready_optional',
          'runtimeStatus': 'ready',
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
          'skillId': 'openhue',
          'androidSupport': 'needs_pack',
          'requiredPacks': ['android-cli-core-pack'],
          'runtimeStatus': 'ready',
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
    expect(model.readyOptionalCount, 2);
    expect(model.readyOptionalLabel, '2');
    expect(model.androidRelevantReady, 4);
    expect(model.releaseGatePass, isTrue);
    expect(model.topNeedsConfig.single.skillId, 'github');
    expect(model.topNeedsConfig.single.detail, contains('GITHUB_TOKEN'));
    expect(model.topNeedsConfig.single.detail, contains('missing_native_bin'));
    expect(model.needsConfigTaxonomyCount, 16);
    expect(model.needsPackTaxonomyCount, 20);
    expect(model.blockedNeedsConfigCount, 1);
    expect(model.blockedNeedsPackCount, 0);
    expect(model.topNeedsPack, isEmpty);
  });

  test('keeps every blocked config and pack gate visible to the UI', () {
    final model = AndroidSkillReadinessViewModel.fromReadiness({
      'totalManifestSkills': 12,
      'readyRequired': {'ready': 1, 'total': 1},
      'releaseGatePass': true,
      'unexpectedMissingDependency': 0,
      'countsByClass': {
        'ready_required': 1,
        'ready_optional': 0,
        'needs_config': 5,
        'needs_pack': 6,
        'unsupported_on_android': 0,
        'manual_proot_compat': 0,
        'hidden_desktop_only': 0,
      },
      'skills': [
        {
          'skillId': 'weather',
          'androidSupport': 'ready_required',
          'ready': true,
        },
        for (var i = 1; i <= 5; i++)
          {
            'skillId': 'config-$i',
            'androidSupport': 'needs_config',
            'requiredConfig': ['CONFIG_$i'],
            'ready': false,
          },
        for (var i = 1; i <= 6; i++)
          {
            'skillId': 'pack-$i',
            'androidSupport': 'needs_pack',
            'requiredPacks': ['pack-$i-runtime'],
            'ready': false,
          },
      ],
    });

    expect(
      model.topNeedsConfig.map((item) => item.skillId),
      ['config-1', 'config-2', 'config-3', 'config-4', 'config-5'],
    );
    expect(
      model.topNeedsPack.map((item) => item.skillId),
      ['pack-1', 'pack-2', 'pack-3', 'pack-4', 'pack-5', 'pack-6'],
    );
    expect(model.blockedNeedsConfigCount, 5);
    expect(model.blockedNeedsPackCount, 6);
  });

  test('pack gate detail prefers concrete missing payload data', () {
    final model = AndroidSkillReadinessViewModel.fromReadiness({
      'totalManifestSkills': 1,
      'readyRequired': {'ready': 0, 'total': 0},
      'releaseGatePass': true,
      'unexpectedMissingDependency': 0,
      'countsByClass': {
        'needs_pack': 1,
      },
      'skills': [
        {
          'skillId': 'openhue',
          'androidSupport': 'needs_pack',
          'requiredPacks': ['android-cli-core-pack'],
          'missingPacks': ['android-cli-core-pack'],
          'missingBins': ['openhue'],
          'dependencyGateMessage':
              'Android CLI-core payload is missing "openhue". Bundle assets/openclaw/cli-core/bin/openhue in the APK or publish a signed dependency pack for arm64-v8a.',
          'ready': false,
        },
      ],
    });

    expect(model.topNeedsPack.single.skillId, 'openhue');
    expect(
      model.topNeedsPack.single.detail,
      contains('pack unavailable: android-cli-core-pack'),
    );
    expect(
      model.topNeedsPack.single.detail,
      contains('missing binaries: openhue'),
    );
    expect(
      model.topNeedsPack.single.detail,
      contains('assets/openclaw/cli-core/bin/openhue'),
    );
  });
}
