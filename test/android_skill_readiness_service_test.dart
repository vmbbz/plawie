import 'package:clawa/services/android_skill_readiness_service.dart';
import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/skill_parity_audit_service.dart';
import 'package:clawa/services/skill_provisioning_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate passes when all ready-required skills are runtime ready',
      () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        readyEntry('battery'),
        readyEntry('sensors'),
        readyEntry('vibrate'),
        readyEntry('weather'),
        readyEntry('taskflow'),
      ]),
      provisioning: provisioningWith([
        readyResult('battery'),
        readyResult('sensors'),
        readyResult('vibrate'),
        readyResult('weather'),
        readyResult('taskflow'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        readyManifestEntry('battery'),
        readyManifestEntry('sensors'),
        readyManifestEntry('vibrate'),
        readyManifestEntry('weather'),
        readyManifestEntry('taskflow'),
        configManifestEntry('github', ['GITHUB_TOKEN']),
        packManifestEntry('openai-whisper', ['android-whisper-runtime']),
        unsupportedManifestEntry('apple-notes'),
        prootManifestEntry('node-connect'),
      ]),
    );

    expect(summary.readyRequiredTotal, 5);
    expect(summary.readyRequiredReady, 5);
    expect(summary.unexpectedMissingDependency, 0);
    expect(summary.releaseGatePass, isTrue);
    expect(summary.countsByClass['needs_config'], 1);
    expect(summary.countsByClass['needs_pack'], 1);

    final health = summary.toHealthJson();
    expect(health['readyRequired'], {'ready': 5, 'total': 5});
    expect(health['unexpectedMissingDependency'], 0);
    expect(health['releaseGatePass'], isTrue);
  });

  test(
      'release gate fails only for ready-required skills with unexpected missing dependencies',
      () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        missingEntry('weather', 'missing_native_bin'),
        readyEntry('battery'),
        missingEntry('github', 'missing_native_env'),
        missingEntry('openai-whisper', 'missing_native_bin'),
        missingEntry('apple-notes', 'missing_native_bin'),
      ]),
      provisioning: provisioningWith([
        missingBinaryResult('weather'),
        readyResult('battery'),
        needsConfigResult('github'),
        missingBinaryResult('openai-whisper'),
        unsupportedResult('apple-notes'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        readyManifestEntry('weather'),
        readyManifestEntry('battery'),
        configManifestEntry('github', ['GITHUB_TOKEN']),
        packManifestEntry('openai-whisper', ['android-whisper-runtime']),
        unsupportedManifestEntry('apple-notes'),
      ]),
    );

    expect(summary.readyRequiredTotal, 2);
    expect(summary.readyRequiredReady, 1);
    expect(summary.unexpectedMissingDependency, 1);
    expect(summary.unexpectedMissingDependencySkillIds, ['weather']);
    expect(summary.releaseGatePass, isFalse);
    expect(summary.countsByClass['unsupported_on_android'], 1);
  });

  test('app-native bridge skills are ready outside the OpenClaw skill matrix',
      () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith(const <SkillExecutionMatrixEntry>[]),
      provisioning: provisioningWith(const <SkillProvisioningSkillResult>[]),
      manifest: AndroidSkillSupportManifest.forTesting([
        bridgeManifestEntry('battery'),
        bridgeManifestEntry('sensors'),
        appNativeManifestEntry('healthcheck'),
      ]),
    );

    expect(summary.readyRequiredTotal, 3);
    expect(summary.readyRequiredReady, 3);
    expect(summary.unexpectedMissingDependency, 0);
    expect(summary.releaseGatePass, isTrue);
    expect(
      summary.skills.map((skill) => skill['runtimeStatus']).toSet(),
      {'app_native_ready'},
    );
  });

  test('app-native launch skills ignore stale OpenClaw dependency gates', () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        missingEntry('canvas', 'missing_native_bin'),
        missingEntry('weather', 'missing_native_bin'),
      ]),
      provisioning: provisioningWith([
        missingBinaryResult('canvas'),
        missingBinaryResult('meme-maker'),
        missingBinaryResult('weather'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        appNativeManifestEntry('canvas'),
        appNativeManifestEntry('meme-maker'),
        appNativeManifestEntry('weather'),
      ]),
    );

    expect(summary.readyRequiredTotal, 3);
    expect(summary.readyRequiredReady, 3);
    expect(summary.unexpectedMissingDependency, 0);
    expect(summary.releaseGatePass, isTrue);
    expect(
      summary.skills.map((skill) => skill['runtimeStatus']).toSet(),
      {'app_native_ready'},
    );
    expect(
      summary.skills.map((skill) => skill['provisioningStatus']).toSet(),
      {'app_native_not_required'},
    );
    expect(
      summary.skills.any((skill) => skill.containsKey('primaryGate')),
      isFalse,
    );
  });

  test('instruction-only launch skills ignore commands shown in prose', () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        missingEntry('skill-creator', 'missing_native_bin'),
      ]),
      provisioning: provisioningWith([
        missingBinaryResult('skill-creator'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        instructionOnlyManifestEntry('skill-creator'),
      ]),
    );

    final skill = summary.skills.single;
    expect(summary.releaseGatePass, isTrue);
    expect(summary.readyRequiredReady, 1);
    expect(skill['runtimeStatus'], 'instruction_only_ready');
    expect(skill['provisioningStatus'], 'instruction_only_not_required');
    expect(skill['ready'], isTrue);
    expect(skill.containsKey('primaryGate'), isFalse);
    expect(skill.containsKey('gates'), isFalse);
    expect(skill.containsKey('missingBins'), isFalse);
  });

  test('app-native config-gated skills stay blocked until config is satisfied',
      () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        missingEntry('github', 'missing_native_config'),
      ]),
      provisioning: provisioningWith([
        needsConfigResult('github'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        appNativeConfigManifestEntry('github', ['GITHUB_TOKEN']),
      ]),
    );

    final github = summary.skills.single;
    expect(github['runtimeStatus'], 'needs_config');
    expect(github['provisioningStatus'], 'needs_user_config');
    expect(github['ready'], isFalse);
    expect(github['requiredConfig'], ['GITHUB_TOKEN']);
    expect(github.containsKey('primaryGate'), isFalse);
    expect(github.containsKey('gates'), isFalse);
  });

  test('app-native config gate beats stale missing binary audit', () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        missingEntry('github', 'missing_native_bin'),
      ]),
      provisioning: provisioningWith([
        missingBinaryResult('github'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        appNativeConfigManifestEntry('github', ['GITHUB_TOKEN']),
      ]),
    );

    final github = summary.skills.single;
    expect(github['runtimeStatus'], 'needs_config');
    expect(github['provisioningStatus'], 'needs_user_config');
    expect(github['ready'], isFalse);
    expect(github.containsKey('primaryGate'), isFalse);
    expect(github.containsKey('gates'), isFalse);
  });

  test('app-native env-configured skills ignore stale OpenClaw binary gates',
      () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith(
        [
          missingEntry('github', 'missing_native_bin'),
        ],
        nativeEnvKeys: ['GITHUB_TOKEN'],
      ),
      provisioning: provisioningWith([
        missingBinaryResult('github'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        appNativeConfigManifestEntry('github', ['GITHUB_TOKEN']),
      ]),
    );

    final github = summary.skills.single;
    expect(github['runtimeStatus'], 'app_native_ready');
    expect(github['provisioningStatus'], 'app_native_config_ready');
    expect(github['ready'], isTrue);
  });

  test(
      'app-native mixed env and config gates use satisfied provisioning status',
      () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        missingEntry('slack', 'missing_native_config'),
      ]),
      provisioning: provisioningWith([
        provisioningResult('slack', SkillProvisioningStatus.satisfied),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        appNativeConfigManifestEntry(
          'slack',
          ['SLACK_BOT_TOKEN', 'channels.slack'],
        ),
      ]),
    );

    final slack = summary.skills.single;
    expect(slack['ready'], isTrue);
    expect(slack['runtimeStatus'], 'app_native_ready');
    expect(slack['provisioningStatus'], 'app_native_config_ready');
    expect(slack['requiredConfig'], ['SLACK_BOT_TOKEN', 'channels.slack']);
    expect(slack.containsKey('primaryGate'), isFalse);
    expect(slack.containsKey('gates'), isFalse);
  });

  test('app-native config gates ignore stale matrix-only required keys', () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        matrixEntry(
          'goplaces',
          status: SkillExecutionStatus.needsConfig,
          primaryGate: 'missing_native_config',
          gates: const ['missing_native_config'],
          requiredEnv: const ['NEXT_PAGE_TOKEN'],
          requiredConfig: const [
            'GOOGLE_PLACES_API_KEY',
            'GOOGLE_PLACES_NEXT_PAGE_TOKEN',
          ],
        ),
      ]),
      provisioning: provisioningWith([
        needsConfigResult('goplaces'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        appNativeConfigManifestEntry('goplaces', ['GOOGLE_PLACES_API_KEY']),
      ]),
    );

    final goplaces = summary.skills.single;
    expect(goplaces['requiredEnv'], isNull);
    expect(goplaces['requiredConfig'], ['GOOGLE_PLACES_API_KEY']);
    expect(goplaces['runtimeStatus'], 'needs_config');
    expect(goplaces['provisioningStatus'], 'needs_user_config');
  });

  test('clawhub owner layer is app-native ready despite npm gates', () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        missingEntry('clawhub', 'missing_native_bin'),
      ]),
      provisioning: provisioningWith([
        missingBinaryResult('clawhub'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        clawHubManifestEntry(),
      ]),
    );

    expect(summary.readyRequiredTotal, 1);
    expect(summary.readyRequiredReady, 1);
    expect(summary.unexpectedMissingDependency, 0);
    expect(summary.releaseGatePass, isTrue);
    expect(summary.skills.single['runtimeStatus'], 'app_native_ready');
    expect(
      summary.skills.single['provisioningStatus'],
      'app_native_not_required',
    );
  });

  test('ready-optional skills count as Android-ready without release blocking',
      () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        readyEntry('weather'),
        missingEntry('xurl', 'missing_native_bin'),
      ]),
      provisioning: provisioningWith([
        readyResult('weather'),
        missingBinaryResult('xurl'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        readyOptionalManifestEntry('xurl'),
        readyManifestEntry('weather'),
      ]),
    );

    expect(summary.readyRequiredTotal, 1);
    expect(summary.readyRequiredReady, 1);
    expect(summary.releaseGatePass, isTrue);
    expect(summary.countsByClass['ready_optional'], 1);
    expect(summary.unexpectedMissingDependency, 0);

    final optional = summary.skills.firstWhere(
      (skill) => skill['skillId'] == 'xurl',
    );
    expect(optional['ready'], isTrue);
    expect(optional['releaseBlocking'], isFalse);
    expect(optional['runtimeStatus'], 'app_native_ready');
  });

  test('pack-gated skills expose concrete missing pack payload details', () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        missingEntry('openhue', 'missing_native_bin'),
      ]),
      provisioning: provisioningWith([
        provisioningResult(
          'openhue',
          SkillProvisioningStatus.missingBinary,
          actions: const [
            SkillProvisioningAction(
              type: SkillProvisioningActionType.dependencyPack,
              key: 'android-cli-core-pack:openhue',
              status: SkillProvisioningActionStatus.missingPack,
              message:
                  'Android CLI-core payload is missing "openhue". Bundle assets/openclaw/cli-core/bin/openhue in the APK or publish a signed dependency pack for arm64-v8a.',
            ),
            SkillProvisioningAction(
              type: SkillProvisioningActionType.binary,
              key: 'openhue',
              status: SkillProvisioningActionStatus.missingBinary,
              message: 'openhue is not available in Native.',
            ),
          ],
        ),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        packManifestEntry('openhue', ['android-cli-core-pack']),
      ]),
    );

    final openhue = summary.skills.single;
    expect(openhue['ready'], isFalse);
    expect(openhue['dependencyGateStatus'], 'missing_pack');
    expect(openhue['missingPacks'], ['android-cli-core-pack']);
    expect(openhue['missingBins'], ['openhue']);
    expect(
      openhue['dependencyGateMessage'],
      contains('assets/openclaw/cli-core/bin/openhue'),
    );
  });

  test('pack-gated skills expose alternative binary requirements', () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        matrixEntry(
          'spotify-player',
          status: SkillExecutionStatus.missingDependency,
          primaryGate: 'missing_native_bin',
          gates: const ['missing_native_bin'],
          requiredAnyBins: const [
            ['spogo', 'spotify_player'],
          ],
        ),
      ]),
      provisioning: provisioningWith([
        provisioningResult(
          'spotify-player',
          SkillProvisioningStatus.missingBinary,
          actions: const [
            SkillProvisioningAction(
              type: SkillProvisioningActionType.dependencyPack,
              key: 'bin:spogo',
              status: SkillProvisioningActionStatus.missingPack,
              message:
                  'No Native dependency pack advertises binary "spogo" for arm64-v8a.',
            ),
          ],
        ),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        packManifestEntry('spotify-player', ['android-audio-runtime']),
      ]),
    );

    final spotify = summary.skills.single;

    expect(spotify['ready'], isFalse);
    expect(spotify['requiredAnyBins'], [
      ['spogo', 'spotify_player'],
    ]);
  });

  test('pack-satisfied config gates expose live required env and config keys',
      () {
    final summary = AndroidSkillReadinessService.instance.summarize(
      snapshot: snapshotWith([
        matrixEntry(
          'eightctl',
          status: SkillExecutionStatus.needsConfig,
          primaryGate: 'missing_native_env',
          gates: const ['missing_native_env'],
          requiredEnv: const ['EIGHTCTL_EMAIL', 'EIGHTCTL_PASSWORD'],
        ),
      ]),
      provisioning: provisioningWith([
        needsConfigResult('eightctl'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        packManifestEntry('eightctl', ['android-cli-core-pack']),
      ]),
    );

    final eightctl = summary.skills.single;

    expect(eightctl['androidSupport'], 'needs_pack');
    expect(eightctl['runtimeStatus'], 'needs_config');
    expect(eightctl['provisioningStatus'], 'needs_user_config');
    expect(eightctl['requiredEnv'], ['EIGHTCTL_EMAIL', 'EIGHTCTL_PASSWORD']);
    expect(eightctl['requiredConfig'], isNull);
    expect(eightctl['ready'], isFalse);
  });
}

SkillParitySnapshot snapshotWith(
  List<SkillExecutionMatrixEntry> entries, {
  List<String> nativeEnvKeys = const <String>[],
}) {
  return SkillParitySnapshot(
    filesDir: 'test-files',
    nativeSkillCount: entries.length,
    prootSkillCount: 0,
    nativeSkillNames: entries.map((entry) => entry.skillId).toList(),
    prootSkillNames: const <String>[],
    missingInNative: const <String>[],
    missingInProot: const <String>[],
    nativePluginCount: 0,
    prootPluginCount: 0,
    nativePluginNames: const <String>[],
    prootPluginNames: const <String>[],
    nativeToolsAllow: const <String>[],
    prootToolsAllow: const <String>[],
    nativeEnvKeys: nativeEnvKeys,
    prootEnvKeys: const <String>[],
    nativeBins: const <String>[],
    prootBins: const <String>[],
    gates: [
      for (final entry in entries)
        for (final gate in entry.gates)
          SkillParityGate(
            skillId: entry.skillId,
            gate: gate,
            owner: 'native',
            detail: 'test gate',
          ),
    ],
    executionMatrix: entries,
    repair: const SkillMirrorRepairResult(),
    auditedAt: DateTime.utc(2026, 6, 7),
  );
}

SkillExecutionMatrixEntry readyEntry(String skillId) {
  return matrixEntry(
    skillId,
    status: SkillExecutionStatus.ready,
  );
}

SkillExecutionMatrixEntry missingEntry(String skillId, String gate) {
  return matrixEntry(
    skillId,
    status: SkillExecutionStatus.missingDependency,
    primaryGate: gate,
    gates: [gate],
  );
}

SkillExecutionMatrixEntry matrixEntry(
  String skillId, {
  required SkillExecutionStatus status,
  String? primaryGate,
  List<String> gates = const <String>[],
  List<List<String>> requiredAnyBins = const <List<String>>[],
  List<String> requiredEnv = const <String>[],
  List<String> requiredConfig = const <String>[],
}) {
  return SkillExecutionMatrixEntry(
    skillId: skillId,
    status: status,
    primaryGate: primaryGate,
    gates: gates,
    requiredBins: const <String>[],
    requiredAnyBins: requiredAnyBins,
    requiredEnv: requiredEnv,
    requiredRuntimes: const <String>[],
    requiredPythonPackages: const <String>[],
    requiredPlugins: const <String>[],
    requiredConfig: requiredConfig,
  );
}

SkillProvisioningReport provisioningWith(
  List<SkillProvisioningSkillResult> results,
) {
  return SkillProvisioningReport(
    filesDir: 'test-files',
    skillId: null,
    auditedAt: DateTime.utc(2026, 6, 7),
    generatedAt: DateTime.utc(2026, 6, 7, 1),
    results: results,
    changed: false,
    reloadRecommended: false,
  );
}

SkillProvisioningSkillResult readyResult(String skillId) {
  return provisioningResult(skillId, SkillProvisioningStatus.ready);
}

SkillProvisioningSkillResult missingBinaryResult(String skillId) {
  return provisioningResult(skillId, SkillProvisioningStatus.missingBinary);
}

SkillProvisioningSkillResult needsConfigResult(String skillId) {
  return provisioningResult(skillId, SkillProvisioningStatus.needsUserConfig);
}

SkillProvisioningSkillResult unsupportedResult(String skillId) {
  return provisioningResult(skillId, SkillProvisioningStatus.unsupportedNative);
}

SkillProvisioningSkillResult provisioningResult(
  String skillId,
  SkillProvisioningStatus status, {
  List<SkillProvisioningAction> actions = const <SkillProvisioningAction>[],
}) {
  return SkillProvisioningSkillResult(
    skillId: skillId,
    readiness: status.wireName,
    status: status,
    primaryGate: null,
    actions: actions,
    changed: false,
    reloadRecommended: false,
  );
}

AndroidSkillSupportEntry readyManifestEntry(String skillId) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.readyRequired,
    ownerLayer: AndroidSkillOwnerLayer.openclawSkill,
    executionMode: AndroidSkillExecutionMode.gatewayTool,
    smokePrompt: 'smoke $skillId',
    launchCritical: true,
  );
}

AndroidSkillSupportEntry bridgeManifestEntry(String skillId) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.readyRequired,
    ownerLayer: AndroidSkillOwnerLayer.androidBridge,
    executionMode: AndroidSkillExecutionMode.androidBridge,
    smokePrompt: 'smoke $skillId',
    launchCritical: true,
  );
}

AndroidSkillSupportEntry appNativeManifestEntry(String skillId) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.readyRequired,
    ownerLayer: AndroidSkillOwnerLayer.appNativeCapability,
    executionMode: AndroidSkillExecutionMode.appNativeTool,
    smokePrompt: 'smoke $skillId',
    launchCritical: true,
  );
}

AndroidSkillSupportEntry instructionOnlyManifestEntry(String skillId) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.readyRequired,
    ownerLayer: AndroidSkillOwnerLayer.openclawSkill,
    executionMode: AndroidSkillExecutionMode.instructionOnly,
    smokePrompt: 'smoke $skillId',
    launchCritical: true,
  );
}

AndroidSkillSupportEntry appNativeConfigManifestEntry(
  String skillId,
  List<String> config,
) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.needsConfig,
    ownerLayer: AndroidSkillOwnerLayer.appNativeCapability,
    executionMode: AndroidSkillExecutionMode.httpAdapter,
    requiredConfig: config,
    smokePrompt: 'smoke $skillId',
  );
}

AndroidSkillSupportEntry clawHubManifestEntry() {
  return AndroidSkillSupportEntry(
    skillId: 'clawhub',
    status: AndroidSkillSupportStatus.readyRequired,
    ownerLayer: AndroidSkillOwnerLayer.clawhubSkill,
    executionMode: AndroidSkillExecutionMode.httpAdapter,
    smokePrompt: 'smoke clawhub',
    launchCritical: true,
  );
}

AndroidSkillSupportEntry readyOptionalManifestEntry(String skillId) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.readyOptional,
    ownerLayer: AndroidSkillOwnerLayer.appNativeCapability,
    executionMode: AndroidSkillExecutionMode.httpAdapter,
    smokePrompt: 'smoke $skillId',
  );
}

AndroidSkillSupportEntry configManifestEntry(
  String skillId,
  List<String> config,
) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.needsConfig,
    ownerLayer: AndroidSkillOwnerLayer.openclawSkill,
    executionMode: AndroidSkillExecutionMode.gatewayTool,
    requiredConfig: config,
    smokePrompt: 'smoke $skillId',
  );
}

AndroidSkillSupportEntry packManifestEntry(
  String skillId,
  List<String> packs,
) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.needsPack,
    ownerLayer: AndroidSkillOwnerLayer.openclawSkill,
    executionMode: AndroidSkillExecutionMode.dependencyPack,
    requiredPacks: packs,
    smokePrompt: 'smoke $skillId',
  );
}

AndroidSkillSupportEntry unsupportedManifestEntry(String skillId) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.unsupportedOnAndroid,
    ownerLayer: AndroidSkillOwnerLayer.openclawSkill,
    executionMode: AndroidSkillExecutionMode.unsupported,
    unsupportedReason: 'desktop only',
    smokePrompt: '',
  );
}

AndroidSkillSupportEntry prootManifestEntry(String skillId) {
  return AndroidSkillSupportEntry(
    skillId: skillId,
    status: AndroidSkillSupportStatus.manualProotCompat,
    ownerLayer: AndroidSkillOwnerLayer.gatewayRuntime,
    executionMode: AndroidSkillExecutionMode.prootCompat,
    unsupportedReason: 'compat mode',
    smokePrompt: 'manual proot',
  );
}
