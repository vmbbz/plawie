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
        missingBinaryResult('weather'),
      ]),
      manifest: AndroidSkillSupportManifest.forTesting([
        appNativeManifestEntry('canvas'),
        appNativeManifestEntry('weather'),
      ]),
    );

    expect(summary.readyRequiredTotal, 2);
    expect(summary.readyRequiredReady, 2);
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
}

SkillParitySnapshot snapshotWith(List<SkillExecutionMatrixEntry> entries) {
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
    nativeEnvKeys: const <String>[],
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
}) {
  return SkillExecutionMatrixEntry(
    skillId: skillId,
    status: status,
    primaryGate: primaryGate,
    gates: gates,
    requiredBins: const <String>[],
    requiredEnv: const <String>[],
    requiredRuntimes: const <String>[],
    requiredPythonPackages: const <String>[],
    requiredPlugins: const <String>[],
    requiredConfig: const <String>[],
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
  SkillProvisioningStatus status,
) {
  return SkillProvisioningSkillResult(
    skillId: skillId,
    readiness: status.wireName,
    status: status,
    primaryGate: null,
    actions: const <SkillProvisioningAction>[],
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
