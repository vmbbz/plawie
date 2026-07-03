import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'native_bridge.dart';
import 'dependency_pack_manifest.dart';
import 'skill_execution_descriptor.dart';
import 'skill_parity_audit_service.dart';

class SkillProvisioningService {
  SkillProvisioningService._();
  static final SkillProvisioningService instance = SkillProvisioningService._();
  static const _pythonRuntimeVersion = '3.11';
  static const _pythonTag = 'cp311';
  static const _pythonAbiTag = 'cp311';
  static const _androidWheelAbi = 'arm64_v8a';
  static const _androidCliCorePackId = 'android-cli-core-pack';
  static const _androidCliCorePackVersion = 'apk-bundled-v1';
  static const _androidCliCorePackBins = <String>{
    'blu',
    'eightctl',
    'himalaya',
    'openhue',
    'sonos',
    'wacli',
  };
  static const _androidVisionMediaPackId = 'android-vision-media-runtime';
  static const _androidVisionMediaPackVersion = 'apk-bundled-v1';
  static const _androidVisionMediaPackBins = <String>{
    'ffmpeg',
    'gifgrep',
  };
  static const _androidAudioRuntimePackId = 'android-audio-runtime';
  static const _androidAudioRuntimePackVersion = 'apk-bundled-v1';
  static const _androidAudioRuntimePackBins = <String>{
    'songsee',
  };
  static const _androidPythonDebugPackId = 'android-python-debug-runtime';
  static const _androidPythonDebugPackVersion = 'debugpy-1.8.21-apk-v1';
  static const _androidPythonDebugVersion = '1.8.21';
  static const _androidPythonDebugPackages = <String>{
    'debugpy',
  };
  static const _androidTerminalPackId = 'android-terminal-pack';
  static const _androidTerminalPackVersion = 'termux-tmux-3.6b-apk-v1';
  static const _androidTerminalPackBins = <String>{
    'tmux',
  };
  static const _androidWhisperRuntimePackId = 'android-whisper-runtime';
  static const _androidWhisperRuntimePackVersion = 'whisper-cpp-v1-2026';
  static const _androidWhisperRuntimePackBins = <String>{
    'whisper',
  };
  static const _androidWhisperRuntimeModels = <String>{
    'ggml-base.bin',
  };
  static const _androidTtsRuntimePackId = 'android-tts-runtime';
  static const _androidTtsRuntimePackVersion = 'sherpa-onnx-v1-2026';
  static const _androidTtsRuntimePackBins = <String>{
    'sherpa-onnx',
  };
  static const _androidTtsRuntimeLibs = <String>{
    'libonnxruntime.so',
    'libsherpa-onnx-core.so',
  };
  static const _androidNodeExecutablePackId = 'android-node-executable-pack';
  static const _androidNodeExecutablePackVersion = 'node-v20-apk-v1';
  static const _androidNodeExecutablePackBins = <String>{
    'node',
  };
  static const _androidAgentCliPackId = 'android-agent-cli-pack';
  static const _androidAgentCliPackVersion = 'agent-cli-v1-apk-v1';
  static const _androidAgentCliPackBins = <String>{
    'coding-agent',
  };
  static const _defaultPythonWheelIndexes = <String>[
    'https://chaquo.com/pypi-13.1/',
    'https://pypi.org/simple/',
    'https://pypi.flet.dev/',
  ];

  Future<SkillProvisioningReport> planSnapshot(
    SkillParitySnapshot snapshot, {
    String? skillId,
  }) {
    return _evaluateSnapshot(
      snapshot,
      skillId: skillId,
      applyValues: false,
      installBundledBinaries: false,
      installDependencyPacks: false,
    );
  }

  Future<SkillProvisioningReport> provisionSnapshot(
    SkillParitySnapshot snapshot, {
    String? skillId,
    Map<String, String> envValues = const <String, String>{},
    Map<String, dynamic> configValues = const <String, dynamic>{},
    bool applyValues = true,
    bool installBundledBinaries = true,
    bool installDependencyPacks = true,
  }) {
    return _evaluateSnapshot(
      snapshot,
      skillId: skillId,
      envValues: envValues,
      configValues: configValues,
      applyValues: applyValues,
      installBundledBinaries: installBundledBinaries,
      installDependencyPacks: installDependencyPacks,
    );
  }

  Future<SkillProvisioningReport> auditAndProvision({
    String? filesDir,
    String? skillId,
    Map<String, String> envValues = const <String, String>{},
    Map<String, dynamic> configValues = const <String, dynamic>{},
    bool repairNativeFromProot = false,
    bool applyValues = true,
    bool installBundledBinaries = true,
    bool installDependencyPacks = true,
  }) async {
    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: filesDir ?? await NativeBridge.getFilesDir(),
      repairNativeFromProot: repairNativeFromProot,
      cacheTtl: Duration.zero,
    );
    return provisionSnapshot(
      snapshot,
      skillId: skillId,
      envValues: envValues,
      configValues: configValues,
      applyValues: applyValues,
      installBundledBinaries: installBundledBinaries,
      installDependencyPacks: installDependencyPacks,
    );
  }

  Future<SkillProvisioningReport> _evaluateSnapshot(
    SkillParitySnapshot snapshot, {
    String? skillId,
    Map<String, String> envValues = const <String, String>{},
    Map<String, dynamic> configValues = const <String, dynamic>{},
    required bool applyValues,
    required bool installBundledBinaries,
    required bool installDependencyPacks,
  }) async {
    final targetSkill = _normalizeSkillId(skillId);
    final layout = _SkillProvisioningLayout(snapshot.filesDir);
    final entries = snapshot.executionMatrix.where((entry) {
      return targetSkill == null ||
          _normalizeSkillId(entry.skillId) == targetSkill;
    }).toList();

    final results = <SkillProvisioningSkillResult>[];
    var changed = false;
    var reloadRecommended = false;
    Future<List<_DependencyPack>>? dependencyPackCatalogFuture;
    Future<List<_DependencyPack>> loadDependencyPackCatalog() {
      dependencyPackCatalogFuture ??= _loadDependencyPackCatalog(layout);
      return dependencyPackCatalogFuture!;
    }

    if (entries.isEmpty &&
        targetSkill != null &&
        (envValues.isNotEmpty || configValues.isNotEmpty)) {
      final result = await _applyConfigOnlyValues(
        targetSkill,
        layout,
        envValues: envValues,
        configValues: configValues,
        applyValues: applyValues,
      );
      results.add(result);
      changed = result.changed;
      reloadRecommended = result.reloadRecommended;
    }

    for (final entry in entries) {
      final result = await _evaluateEntry(
        snapshot,
        entry,
        layout,
        dependencyPackCatalogLoader: loadDependencyPackCatalog,
        envValues: envValues,
        configValues: configValues,
        applyValues: applyValues,
        installBundledBinaries: installBundledBinaries,
        installDependencyPacks: installDependencyPacks,
      );
      results.add(result);
      changed = changed || result.changed;
      reloadRecommended = reloadRecommended || result.reloadRecommended;
    }

    return SkillProvisioningReport(
      filesDir: snapshot.filesDir,
      skillId: targetSkill,
      auditedAt: snapshot.auditedAt,
      generatedAt: DateTime.now(),
      results: results,
      changed: changed,
      reloadRecommended: reloadRecommended,
    );
  }

  Future<SkillProvisioningSkillResult> _applyConfigOnlyValues(
    String skillId,
    _SkillProvisioningLayout layout, {
    required Map<String, String> envValues,
    required Map<String, dynamic> configValues,
    required bool applyValues,
  }) async {
    final actions = <SkillProvisioningAction>[];
    var changed = false;
    var reloadRecommended = false;

    for (final entry in envValues.entries) {
      if (!_envKeyLooksSafe(entry.key)) {
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.env,
          key: entry.key,
          status: SkillProvisioningActionStatus.unsupportedNative,
          message: 'Native .env key rejected as unsafe.',
        ));
        continue;
      }

      if (applyValues) {
        await _writeDotEnvValues(
            layout.nativeEnvFile, {entry.key: entry.value});
        changed = true;
        reloadRecommended = true;
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.env,
          key: entry.key,
          status: SkillProvisioningActionStatus.satisfied,
          message: 'Native .env value applied.',
          changed: true,
        ));
      } else {
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.env,
          key: entry.key,
          status: SkillProvisioningActionStatus.needsUserConfig,
          message: 'Native .env value can be applied.',
        ));
      }
    }

    for (final entry in configValues.entries) {
      if (applyValues) {
        await _writeConfigValue(
          layout.nativeConfigFile,
          entry.key,
          entry.value,
        );
        changed = true;
        reloadRecommended = true;
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.config,
          key: entry.key,
          status: SkillProvisioningActionStatus.satisfied,
          message: 'Native openclaw.json value applied.',
          changed: true,
        ));
      } else {
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.config,
          key: entry.key,
          status: SkillProvisioningActionStatus.needsUserConfig,
          message: 'Native openclaw.json value can be applied.',
        ));
      }
    }

    final status = actions.any(
      (action) =>
          action.status == SkillProvisioningActionStatus.unsupportedNative,
    )
        ? SkillProvisioningStatus.unsupportedNative
        : applyValues
            ? SkillProvisioningStatus.satisfied
            : SkillProvisioningStatus.needsUserConfig;

    return SkillProvisioningSkillResult(
      skillId: skillId,
      readiness: 'config_only',
      status: status,
      primaryGate: null,
      actions: actions,
      changed: changed,
      reloadRecommended: reloadRecommended,
    );
  }

  Future<SkillProvisioningSkillResult> _evaluateEntry(
    SkillParitySnapshot snapshot,
    SkillExecutionMatrixEntry entry,
    _SkillProvisioningLayout layout, {
    required Future<List<_DependencyPack>> Function()
        dependencyPackCatalogLoader,
    required Map<String, String> envValues,
    required Map<String, dynamic> configValues,
    required bool applyValues,
    required bool installBundledBinaries,
    required bool installDependencyPacks,
  }) async {
    final actions = <SkillProvisioningAction>[];
    final missingEnv = _gateValues(
      snapshot,
      entry,
      'missing_native_env',
      fallback: entry.requiredEnv,
    );
    final missingConfig = _gateValues(
      snapshot,
      entry,
      'missing_native_config',
      fallback: entry.requiredConfig,
    );
    final missingBins = _gateValues(
      snapshot,
      entry,
      'missing_native_bin',
      fallback: entry.requiredBins,
    );
    var missingRuntimes = _gateValues(
      snapshot,
      entry,
      'missing_native_runtime',
      fallback: const <String>[],
    );
    var missingPythonPackages = _gateValues(
      snapshot,
      entry,
      'missing_native_python_package',
      fallback: entry.requiredPythonPackages,
    );
    var missingNodePackages = _gateValues(
      snapshot,
      entry,
      'missing_native_node_package',
      fallback: entry.requiredNodePackages,
    );
    final missingPlugins = _gateValues(
      snapshot,
      entry,
      'missing_native_plugin',
      fallback: entry.requiredPlugins,
    );
    final gates = entry.gates.toSet();

    var changed = false;
    var reloadRecommended = false;
    var envFullySatisfied = true;
    var configFullySatisfied = true;
    var binaryFullySatisfied = true;
    var runtimeFullySatisfied = true;
    var pythonPackagesFullySatisfied = true;
    var nodePackagesFullySatisfied = true;
    final pythonCommandBins =
        missingBins.where(_isPythonCommandBin).toList(growable: false);
    final nonRuntimeMissingBins = missingBins
        .where((bin) => !_isPythonCommandBin(bin))
        .toList(growable: false);
    final apkProvidedCliCorePack =
        installDependencyPacks ? await _apkProvidedCliCorePack(layout) : null;
    final apkProvidedCliCoreBins =
        apkProvidedCliCorePack?.providesBins ?? const <String>{};
    final apkProvidedVisionMediaPack = installDependencyPacks
        ? await _apkProvidedVisionMediaPack(layout)
        : null;
    final apkProvidedVisionMediaBins =
        apkProvidedVisionMediaPack?.providesBins ?? const <String>{};
    final apkProvidedAudioRuntimePack = installDependencyPacks
        ? await _apkProvidedAudioRuntimePack(layout)
        : null;
    final apkProvidedAudioRuntimeBins =
        apkProvidedAudioRuntimePack?.providesBins ?? const <String>{};
    final apkProvidedTerminalPack =
        installDependencyPacks ? await _apkProvidedTerminalPack(layout) : null;
    final apkProvidedTerminalBins =
        apkProvidedTerminalPack?.providesBins ?? const <String>{};
    if (pythonCommandBins.isNotEmpty &&
        !missingRuntimes.map(_normalizeDependencyName).contains('python')) {
      missingRuntimes = [...missingRuntimes, 'python'];
    }

    for (final envName in missingEnv) {
      final supplied = envValues[envName];
      if (applyValues && supplied != null && _envKeyLooksSafe(envName)) {
        await _writeDotEnvValues(layout.nativeEnvFile, {envName: supplied});
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.env,
          key: envName,
          status: SkillProvisioningActionStatus.satisfied,
          message: 'Native .env value applied.',
          changed: true,
        ));
        changed = true;
        reloadRecommended = true;
      } else {
        envFullySatisfied = false;
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.env,
          key: envName,
          status: SkillProvisioningActionStatus.needsUserConfig,
          message: 'Set $envName in the Native OpenClaw environment.',
        ));
      }
    }

    for (final configKey in missingConfig) {
      final supplied = configValues[configKey];
      if (applyValues && configValues.containsKey(configKey)) {
        await _writeConfigValue(layout.nativeConfigFile, configKey, supplied);
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.config,
          key: configKey,
          status: SkillProvisioningActionStatus.satisfied,
          message: 'Native openclaw.json value applied.',
          changed: true,
        ));
        changed = true;
        reloadRecommended = true;
      } else {
        configFullySatisfied = false;
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.config,
          key: configKey,
          status: SkillProvisioningActionStatus.needsUserConfig,
          message: 'Set $configKey in Native openclaw.json.',
        ));
      }
    }

    var unresolvedNonRuntimeMissingBins = <String>[];
    for (final bin in nonRuntimeMissingBins) {
      final normalizedBin = _normalizeBinRequirement(bin);
      if (apkProvidedCliCoreBins.contains(normalizedBin) ||
          apkProvidedVisionMediaBins.contains(normalizedBin) ||
          apkProvidedAudioRuntimeBins.contains(normalizedBin) ||
          apkProvidedTerminalBins.contains(normalizedBin)) {
        unresolvedNonRuntimeMissingBins.add(bin);
        continue;
      }
      final target =
          File(path.join(layout.nativeManagedBinDir.path, normalizedBin));
      final source = await _findBundledNativeBinary(layout, bin);
      if (installBundledBinaries && source != null) {
        await layout.nativeManagedBinDir.create(recursive: true);
        await source.copy(target.path);
        if (!Platform.isWindows) {
          try {
            await Process.run('chmod', ['755', target.path]);
          } catch (_) {}
        }
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.binary,
          key: bin,
          status: SkillProvisioningActionStatus.satisfied,
          message: 'Bundled native binary installed into managed bin.',
          changed: true,
        ));
        changed = true;
        reloadRecommended = true;
      } else {
        unresolvedNonRuntimeMissingBins.add(bin);
      }
    }

    for (final plugin in missingPlugins) {
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.plugin,
        key: plugin,
        status: SkillProvisioningActionStatus.missingPlugin,
        message:
            'Install or mirror the $plugin plugin into the Native OpenClaw workspace.',
      ));
    }

    final dependencyAuditPackages = missingPythonPackages.isNotEmpty
        ? missingPythonPackages
        : entry.requiredPythonPackages;
    final shouldAuditPythonClosure =
        entry.requiredPythonRequirements.isNotEmpty &&
            dependencyAuditPackages.isNotEmpty;

    if (missingRuntimes.isNotEmpty ||
        missingPythonPackages.isNotEmpty ||
        shouldAuditPythonClosure ||
        unresolvedNonRuntimeMissingBins.isNotEmpty) {
      final dependencyResult = await _provisionDependencyPacks(
        entry,
        layout,
        missingBins: unresolvedNonRuntimeMissingBins,
        missingRuntimes: missingRuntimes,
        missingPythonPackages: dependencyAuditPackages,
        requiredPythonRequirements: entry.requiredPythonRequirements,
        dependencyPackCatalogLoader: dependencyPackCatalogLoader,
        apply: applyValues && installDependencyPacks,
      );
      actions.addAll(dependencyResult.actions);
      changed = changed || dependencyResult.changed;
      reloadRecommended =
          reloadRecommended || dependencyResult.reloadRecommended;
      missingRuntimes = missingRuntimes
          .where((runtime) => !dependencyResult.satisfiedRuntimes
              .contains(_normalizeDependencyName(runtime)))
          .toList();
      final remainingAuditedPythonPackages = dependencyAuditPackages
          .where((package) => !dependencyResult.satisfiedPythonPackages
              .contains(_normalizeDependencyName(package)))
          .toList();
      missingPythonPackages = missingPythonPackages.isNotEmpty
          ? missingPythonPackages
              .where((package) => remainingAuditedPythonPackages
                  .contains(_normalizeDependencyName(package)))
              .toList()
          : remainingAuditedPythonPackages;
      unresolvedNonRuntimeMissingBins = unresolvedNonRuntimeMissingBins
          .where((bin) => !dependencyResult.satisfiedBins
              .contains(_normalizeBinRequirement(bin)))
          .toList();
    }

    for (final bin in unresolvedNonRuntimeMissingBins) {
      binaryFullySatisfied = false;
      final normalizedBin = _normalizeBinRequirement(bin);
      final prootHas = snapshot.prootBins
          .map(_normalizeBinRequirement)
          .contains(normalizedBin);
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.binary,
        key: normalizedBin,
        status: SkillProvisioningActionStatus.missingBinary,
        message: prootHas
            ? '$normalizedBin exists in PRoot, but Native has no bundled/mobile-safe binary to install. PRoot will not be used automatically.'
            : '$normalizedBin is not available in Native and no bundled/mobile-safe binary was found.',
      ));
    }

    for (final runtime in missingRuntimes) {
      runtimeFullySatisfied = false;
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.runtime,
        key: runtime,
        status: SkillProvisioningActionStatus.missingDependency,
        message:
            '$runtime is required by this skill but is not available in the Native managed runtime. Provision a bundled Native runtime; PRoot will not be used automatically.',
      ));
    }

    if (missingNodePackages.isNotEmpty) {
      final nodeResult = await _provisionNodePackages(
        entry,
        layout,
        missingNodePackages: missingNodePackages,
        apply: applyValues && installDependencyPacks,
      );
      actions.addAll(nodeResult.actions);
      changed = changed || nodeResult.changed;
      reloadRecommended = reloadRecommended || nodeResult.reloadRecommended;
      missingNodePackages = missingNodePackages
          .where((package) => !nodeResult.satisfiedNodePackages
              .contains(_normalizeNodePackageName(package)))
          .toList();
    }

    for (final package in missingPythonPackages) {
      pythonPackagesFullySatisfied = false;
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.pythonPackage,
        key: package,
        status: SkillProvisioningActionStatus.missingDependency,
        message:
            '$package is required by requirements.txt but is not installed in a Native Python environment for this skill.',
      ));
    }

    for (final package in missingNodePackages) {
      nodePackagesFullySatisfied = false;
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.nodePackage,
        key: package,
        status: SkillProvisioningActionStatus.missingDependency,
        message:
            '$package is required by package.json but could not be installed in Native node_modules. PRoot was not used.',
      ));
    }

    if (gates.contains('disabled')) {
      actions.add(const SkillProvisioningAction(
        type: SkillProvisioningActionType.config,
        key: 'skills.disabled',
        status: SkillProvisioningActionStatus.disabled,
        message: 'Skill is disabled by Native OpenClaw config.',
      ));
    }

    if (gates.contains('missing_manifest') ||
        gates.contains('missing_native_skill')) {
      actions.add(const SkillProvisioningAction(
        type: SkillProvisioningActionType.manifest,
        key: 'SKILL.md',
        status: SkillProvisioningActionStatus.unsupportedNative,
        message: 'Skill is missing a Native-readable manifest or skill files.',
      ));
    }

    if (gates.contains('manual_proot_required')) {
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.runtime,
        key: entry.requiredRuntimes.isEmpty
            ? 'full-linux-runtime'
            : entry.requiredRuntimes.join(','),
        status: SkillProvisioningActionStatus.manualProotRequired,
        message:
            'Skill requires a full Linux runtime. Native will not silently switch to PRoot; user must choose PRoot/manual compatibility mode.',
      ));
    }

    final status = _statusFor(
      entry,
      gates: gates,
      envFullySatisfied: envFullySatisfied,
      configFullySatisfied: configFullySatisfied,
      binaryFullySatisfied: binaryFullySatisfied,
      runtimeFullySatisfied: runtimeFullySatisfied,
      pythonPackagesFullySatisfied: pythonPackagesFullySatisfied,
      nodePackagesFullySatisfied: nodePackagesFullySatisfied,
      missingPlugins: missingPlugins,
      changed: changed,
    );

    if (actions.isEmpty && status == SkillProvisioningStatus.ready) {
      actions.add(const SkillProvisioningAction(
        type: SkillProvisioningActionType.none,
        key: 'native',
        status: SkillProvisioningActionStatus.ready,
        message: 'Skill is ready in Native.',
      ));
    }

    return SkillProvisioningSkillResult(
      skillId: entry.skillId,
      readiness: _executionStatusName(entry.status),
      status: status,
      primaryGate: entry.primaryGate,
      executionDescriptor: entry.executionDescriptor,
      actions: actions,
      changed: changed,
      reloadRecommended: reloadRecommended,
    );
  }

  SkillProvisioningStatus _statusFor(
    SkillExecutionMatrixEntry entry, {
    required Set<String> gates,
    required bool envFullySatisfied,
    required bool configFullySatisfied,
    required bool binaryFullySatisfied,
    required bool runtimeFullySatisfied,
    required bool pythonPackagesFullySatisfied,
    required bool nodePackagesFullySatisfied,
    required List<String> missingPlugins,
    required bool changed,
  }) {
    if (gates.isEmpty) return SkillProvisioningStatus.ready;
    if (gates.contains('disabled')) return SkillProvisioningStatus.disabled;
    if (gates.contains('missing_manifest') ||
        gates.contains('missing_native_skill')) {
      return SkillProvisioningStatus.unsupportedNative;
    }
    if (gates.contains('manual_proot_required')) {
      return SkillProvisioningStatus.manualProotRequired;
    }
    if (!runtimeFullySatisfied ||
        !pythonPackagesFullySatisfied ||
        !nodePackagesFullySatisfied) {
      return SkillProvisioningStatus.missingDependency;
    }
    if (!binaryFullySatisfied) return SkillProvisioningStatus.missingBinary;
    if (missingPlugins.isNotEmpty) return SkillProvisioningStatus.missingPlugin;
    if (!envFullySatisfied || !configFullySatisfied) {
      return SkillProvisioningStatus.needsUserConfig;
    }
    return changed
        ? SkillProvisioningStatus.satisfied
        : _statusFromExecution(entry.status);
  }

  static SkillProvisioningStatus _statusFromExecution(
    SkillExecutionStatus status,
  ) {
    return switch (status) {
      SkillExecutionStatus.ready => SkillProvisioningStatus.ready,
      SkillExecutionStatus.needsConfig =>
        SkillProvisioningStatus.needsUserConfig,
      SkillExecutionStatus.missingDependency =>
        SkillProvisioningStatus.missingDependency,
      SkillExecutionStatus.disabled => SkillProvisioningStatus.disabled,
      SkillExecutionStatus.unsupportedNative =>
        SkillProvisioningStatus.unsupportedNative,
      SkillExecutionStatus.manualProotRequired =>
        SkillProvisioningStatus.manualProotRequired,
    };
  }

  static String? _normalizeSkillId(String? value) {
    final trimmed = value?.trim().toLowerCase();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _executionStatusName(SkillExecutionStatus status) {
    return switch (status) {
      SkillExecutionStatus.ready => 'ready',
      SkillExecutionStatus.needsConfig => 'needs_config',
      SkillExecutionStatus.missingDependency => 'missing_dependency',
      SkillExecutionStatus.disabled => 'disabled',
      SkillExecutionStatus.unsupportedNative => 'unsupported_native',
      SkillExecutionStatus.manualProotRequired => 'manual_proot_required',
    };
  }

  static List<String> _gateValues(
    SkillParitySnapshot snapshot,
    SkillExecutionMatrixEntry entry,
    String gate, {
    required List<String> fallback,
  }) {
    final values = <String>{};
    if (!entry.gates.contains(gate)) return const <String>[];
    for (final parityGate in snapshot.gates) {
      if (_normalizeSkillId(parityGate.skillId) !=
          _normalizeSkillId(entry.skillId)) {
        continue;
      }
      if (parityGate.gate != gate) continue;
      final parsed = _parseGateValue(parityGate.detail);
      if (parsed != null && parsed.isNotEmpty) {
        values.add(gate == 'missing_native_runtime'
            ? _normalizeRuntimeRequirement(parsed)
            : parsed);
      }
    }
    if (values.isEmpty) {
      values.addAll(gate == 'missing_native_runtime'
          ? fallback.map(_normalizeRuntimeRequirement)
          : fallback);
    }
    return values.toList()..sort();
  }

  static String? _parseGateValue(String detail) {
    final match = RegExp(r'^([A-Za-z0-9_.@/-]+)\b').firstMatch(detail.trim());
    return match?.group(1);
  }

  static Future<_DependencyProvisioningResult> _provisionDependencyPacks(
    SkillExecutionMatrixEntry entry,
    _SkillProvisioningLayout layout, {
    required List<String> missingBins,
    required List<String> missingRuntimes,
    required List<String> missingPythonPackages,
    required Map<String, String> requiredPythonRequirements,
    required Future<List<_DependencyPack>> Function()
        dependencyPackCatalogLoader,
    required bool apply,
  }) async {
    final actions = <SkillProvisioningAction>[];
    final satisfiedBins = <String>{};
    final satisfiedRuntimes = <String>{};
    final satisfiedPythonPackages = <String>{};
    var changed = false;
    var reloadRecommended = false;

    final requiredBins = missingBins.map(_normalizeBinRequirement).toSet();
    final requiredRuntimes =
        missingRuntimes.map(_normalizeDependencyName).toSet();
    final requiredPackages =
        missingPythonPackages.map(_normalizeDependencyName).toSet();
    final packs = await dependencyPackCatalogLoader();
    final selected = _selectDependencyPacks(
      packs,
      requiredBins: requiredBins,
      requiredRuntimes: requiredRuntimes,
      requiredPythonPackages: requiredPackages,
    );
    final needsNativePython = requiredRuntimes.contains('python') ||
        requiredPackages.isNotEmpty ||
        requiredPythonRequirements.isNotEmpty;
    if (needsNativePython) {
      _DependencyPack? pythonCore;
      for (final pack in packs) {
        if (pack.id == 'python-core') {
          pythonCore = pack;
          break;
        }
      }
      if (pythonCore != null &&
          !selected.any((pack) => pack.id == pythonCore!.id) &&
          await _pythonCoreInstallRequired(layout, pythonCore)) {
        selected.add(pythonCore);
        _sortDependencyPacks(selected);
      }
    }

    final coveredBins = <String>{};
    final coveredRuntimes = <String>{};
    final coveredPackages = <String>{};
    for (final pack in selected) {
      coveredBins.addAll(pack.providesBins);
      coveredRuntimes.addAll(pack.providesRuntimes);
      coveredPackages.addAll(pack.providesPythonPackages);
    }

    for (final runtime in requiredRuntimes.difference(coveredRuntimes)) {
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.dependencyPack,
        key: 'runtime:$runtime',
        status: SkillProvisioningActionStatus.missingPack,
        message:
            'No Native dependency pack advertises runtime "$runtime" for arm64-v8a.',
      ));
    }
    for (final bin in requiredBins.difference(coveredBins)) {
      final isCliCoreBin = _androidCliCorePackBins.contains(bin);
      final isVisionMediaBin = _androidVisionMediaPackBins.contains(bin);
      final isAudioRuntimeBin = _androidAudioRuntimePackBins.contains(bin);
      final isTerminalBin = _androidTerminalPackBins.contains(bin);
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.dependencyPack,
        key: isCliCoreBin
            ? '$_androidCliCorePackId:$bin'
            : isVisionMediaBin
                ? '$_androidVisionMediaPackId:$bin'
                : isAudioRuntimeBin
                    ? '$_androidAudioRuntimePackId:$bin'
                    : isTerminalBin
                        ? '$_androidTerminalPackId:$bin'
                        : 'bin:$bin',
        status: SkillProvisioningActionStatus.missingPack,
        message: isCliCoreBin
            ? 'Android CLI-core payload is missing "$bin". Bundle assets/openclaw/cli-core/bin/$bin in the APK or publish a signed dependency pack for arm64-v8a.'
            : isVisionMediaBin
                ? 'Android vision-media payload is missing "$bin". Bundle assets/openclaw/vision-media/bin/$bin in the APK or publish a signed dependency pack for arm64-v8a.'
                : isAudioRuntimeBin
                    ? 'Android audio runtime payload is missing "$bin". Bundle assets/openclaw/audio-runtime/bin/$bin in the APK or publish a signed dependency pack for arm64-v8a.'
                    : isTerminalBin
                        ? 'Android terminal payload is missing "$bin". Bundle assets/openclaw/terminal/bin/$bin plus required assets/openclaw/terminal/lib/ shared libraries in the APK or publish a signed dependency pack for arm64-v8a.'
                        : 'No Native dependency pack advertises binary "$bin" for arm64-v8a.',
      ));
    }
    for (final pack in selected) {
      final receipt = await _readDependencyReceipt(layout, pack.id);
      if (receipt != null &&
          receipt.version == pack.version &&
          receipt.sha256 == pack.sha256 &&
          await _dependencyPackMarkersPresent(layout, pack)) {
        final packSatisfiedPackages = await _satisfiedPythonPackagesForPack(
          layout,
          pack,
          requiredPythonRequirements,
        );
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.dependencyPack,
          key: pack.id,
          status: SkillProvisioningActionStatus.ready,
          message: 'Dependency pack ${pack.id} already installed.',
        ));
        satisfiedBins.addAll(pack.providesBins);
        satisfiedRuntimes.addAll(pack.providesRuntimes);
        satisfiedPythonPackages.addAll(packSatisfiedPackages);
        continue;
      }

      if (!apply) {
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.dependencyPack,
          key: pack.id,
          status: SkillProvisioningActionStatus.missingDependency,
          message: 'Dependency pack ${pack.id} can satisfy this skill.',
        ));
        continue;
      }

      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.dependencyPack,
        key: pack.id,
        status: SkillProvisioningActionStatus.downloading,
        message: pack.source == _DependencyPackSource.apk
            ? 'Installing APK-provided dependency pack ${pack.id}.'
            : 'Downloading dependency pack ${pack.id}.',
      ));
      debugPrint('[DEPS] requested pack=${pack.id} skill=${entry.skillId}');

      final install = await _installDependencyPack(layout, pack, entry);
      actions.add(install.action);
      if (install.ok) {
        changed = true;
        reloadRecommended = true;
        satisfiedBins.addAll(pack.providesBins);
        satisfiedRuntimes.addAll(pack.providesRuntimes);
        satisfiedPythonPackages.addAll(
          await _satisfiedPythonPackagesForPack(
            layout,
            pack,
            requiredPythonRequirements,
          ),
        );
      }
    }

    final remainingPythonPackages =
        requiredPackages.difference(satisfiedPythonPackages);
    if (remainingPythonPackages.isNotEmpty) {
      // Pre-check: smoke-test each package against the full Python path
      // (including Chaquopy's build-time site-packages) before attempting
      // a runtime wheel download. Packages installed at build time via the
      // chaquopy.pip block in build.gradle.kts live in Chaquopy's own
      // site-packages, not the managed directory — a wheel download would
      // produce an ABI-incompatible copy in the managed directory that
      // shadows the working build-time copy.
      final actuallyNeed = <String>{};
      for (final package in remainingPythonPackages) {
        final smoke = await _smokePythonImport(layout, package);
        if (smoke.ok) {
          satisfiedPythonPackages.add(package);
          actions.add(SkillProvisioningAction(
            type: SkillProvisioningActionType.pythonPackage,
            key: package,
            status: SkillProvisioningActionStatus.ready,
            message: 'Python package $package already importable (build-time).',
          ));
        } else {
          actuallyNeed.add(package);
        }
      }
      if (actuallyNeed.isNotEmpty) {
        final wheelResult = await _provisionPythonWheels(
          entry,
          layout,
          requiredPythonRequirements: {
            for (final package in actuallyNeed)
              package: requiredPythonRequirements[package] ?? package,
          },
          apply: apply,
        );
        actions.addAll(wheelResult.actions);
        changed = changed || wheelResult.changed;
        reloadRecommended = reloadRecommended || wheelResult.reloadRecommended;
        satisfiedPythonPackages.addAll(wheelResult.satisfiedPythonPackages);
      }
    }

    final stillUnverified =
        requiredPackages.difference(satisfiedPythonPackages);
    if (apply && stillUnverified.isNotEmpty) {
      final installed = await _scanInstalledPythonPackageVersions(layout);
      for (final package in stillUnverified) {
        final requirement = _pythonRequirementForPackage(
          requiredPythonRequirements,
          package,
        );
        final version = installed[package];
        if (version == null ||
            !_pythonRequirementSatisfied(version, requirement)) {
          continue;
        }
        final smoke = await _smokePythonImport(layout, package);
        if (smoke.ok) {
          satisfiedPythonPackages.add(package);
          actions.add(SkillProvisioningAction(
            type: SkillProvisioningActionType.pythonPackage,
            key: package,
            status: SkillProvisioningActionStatus.ready,
            message:
                'Python package $package $version verified after wheel provisioning.',
          ));
        } else {
          actions.add(SkillProvisioningAction(
            type: SkillProvisioningActionType.pythonPackage,
            key: package,
            status: SkillProvisioningActionStatus.failedSmoke,
            message: 'Python package $package failed import smoke after '
                'wheel provisioning: '
                '${smoke.stderr.isEmpty ? smoke.stdout : smoke.stderr}',
          ));
        }
      }
    }

    for (final package
        in requiredPackages.difference(satisfiedPythonPackages)) {
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.dependencyPack,
        key: 'python-package:$package',
        status: SkillProvisioningActionStatus.missingPack,
        message:
            'No verified Native dependency pack or compatible Android wheel satisfied Python package "$package" for arm64-v8a.',
      ));
    }

    return _DependencyProvisioningResult(
      actions: actions,
      satisfiedBins: satisfiedBins.intersection(requiredBins),
      satisfiedRuntimes: satisfiedRuntimes,
      satisfiedPythonPackages: satisfiedPythonPackages,
      changed: changed,
      reloadRecommended: reloadRecommended,
    );
  }

  static Future<_NodeProvisioningResult> _provisionNodePackages(
    SkillExecutionMatrixEntry entry,
    _SkillProvisioningLayout layout, {
    required List<String> missingNodePackages,
    required bool apply,
  }) async {
    final actions = <SkillProvisioningAction>[];
    final satisfiedPackages = <String>{};
    final rootPackages =
        missingNodePackages.map(_normalizeNodePackageName).toSet();
    final rootRequirements = await _readNodePackageRequirementsForEntry(entry);
    final queue = <_NodePackageRequest>[
      for (final package in rootPackages)
        _NodePackageRequest(
          name: package,
          raw: rootRequirements[package] ?? '*',
          root: true,
          rootPackage: package,
        ),
    ];
    final catalog = await _loadNodePackageCatalog(layout);
    final processed = <String>{};
    final unresolvedPackages = <String>{};
    final unresolvedRootPackages = <String>{};
    var changed = false;
    var reloadRecommended = false;
    var iterations = 0;

    void markUnresolved(_NodePackageRequest request) {
      unresolvedPackages.add(request.name);
      unresolvedRootPackages.add(request.rootPackage ?? request.name);
    }

    Future<void> enqueueInstalledDependencies(
      _NodePackageRequest request,
    ) async {
      final dependencies = await _readInstalledNodePackageDependencies(
        layout,
        request.name,
      );
      for (final dependency in dependencies.entries) {
        final normalized = _normalizeNodePackageName(dependency.key);
        if (await _nodePackageMarkerPresent(layout, normalized)) {
          continue;
        }
        queue.add(_NodePackageRequest(
          name: normalized,
          raw: dependency.value,
          root: false,
          rootPackage: request.rootPackage ?? request.name,
        ));
      }
    }

    while (queue.isNotEmpty && iterations < 240) {
      iterations += 1;
      final request = queue.removeAt(0);
      final key = '${request.name}:${request.raw}';
      if (!processed.add(key)) continue;

      final installed = await _readInstalledNodePackageVersion(
        layout,
        request.name,
      );
      if (installed != null &&
          _nodeRequirementSatisfied(installed, request.raw)) {
        if (rootPackages.contains(request.name)) {
          satisfiedPackages.add(request.name);
        }
        await enqueueInstalledDependencies(request);
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.nodePackage,
          key: request.name,
          status: SkillProvisioningActionStatus.ready,
          message: 'Node package ${request.name} $installed already installed.',
        ));
        continue;
      }

      if (!apply) {
        markUnresolved(request);
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.nodePackage,
          key: request.name,
          status: SkillProvisioningActionStatus.missingDependency,
          message:
              'Node package provisioning can satisfy ${request.name}@${request.raw} when dependency repair is applied.',
        ));
        continue;
      }

      final receipt = await _readNodePackageReceipt(layout, request.name);
      if (receipt != null &&
          _nodeRequirementSatisfied(receipt.version, request.raw) &&
          await _nodePackageMarkerPresent(layout, request.name)) {
        if (rootPackages.contains(request.name)) {
          satisfiedPackages.add(request.name);
        }
        await enqueueInstalledDependencies(request);
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.nodePackage,
          key: request.name,
          status: SkillProvisioningActionStatus.ready,
          message:
              'Node package ${request.name} ${receipt.version} already installed from receipt.',
        ));
        continue;
      }

      final candidate =
          await _resolveNodePackageCandidate(request, catalog: catalog);
      if (candidate == null) {
        markUnresolved(request);
        debugPrint(
          '[DEPS] no compatible npm package skill=${entry.skillId} '
          'package=${request.name} range=${request.raw}',
        );
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.nodePackage,
          key: request.name,
          status: SkillProvisioningActionStatus.missingPack,
          message:
              'No compatible Native npm package tarball found for ${request.name}@${request.raw}.',
        ));
        continue;
      }

      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.nodePackage,
        key: request.name,
        status: SkillProvisioningActionStatus.downloading,
        message:
            'Downloading npm package ${candidate.name}@${candidate.version} from ${candidate.url.host.isEmpty ? candidate.url.scheme : candidate.url.host}.',
      ));
      debugPrint(
        '[DEPS] npm requested skill=${entry.skillId} '
        'package=${candidate.name} version=${candidate.version}',
      );

      final install = await _downloadAndInstallNodePackage(
        layout,
        request,
        candidate,
      );
      actions.add(install.action);
      if (!install.ok) {
        markUnresolved(request);
        continue;
      }

      changed = true;
      reloadRecommended = true;
      if (rootPackages.contains(request.name)) {
        satisfiedPackages.add(request.name);
      }
      for (final dependency in install.dependencies.entries) {
        final normalized = _normalizeNodePackageName(dependency.key);
        if (await _nodePackageMarkerPresent(layout, normalized)) {
          continue;
        }
        queue.add(_NodePackageRequest(
          name: normalized,
          raw: dependency.value,
          root: false,
          rootPackage: request.rootPackage ?? request.name,
        ));
      }
    }

    if (queue.isNotEmpty) {
      for (final request in queue) {
        markUnresolved(request);
      }
      actions.add(const SkillProvisioningAction(
        type: SkillProvisioningActionType.nodePackage,
        key: 'dependency-closure',
        status: SkillProvisioningActionStatus.missingDependency,
        message:
            'Node package dependency closure exceeded the safety limit while resolving npm tarballs.',
      ));
    }

    if (unresolvedRootPackages.isNotEmpty) {
      satisfiedPackages.removeAll(unresolvedRootPackages);
      final roots = unresolvedRootPackages.toList()..sort();
      final unresolved = unresolvedPackages.toList()..sort();
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.nodePackage,
        key: 'dependency-closure',
        status: SkillProvisioningActionStatus.missingDependency,
        message: 'Node dependency closure is incomplete for '
            '${roots.join(', ')}; unresolved packages: '
            '${unresolved.join(', ')}.',
      ));
    }

    return _NodeProvisioningResult(
      actions: actions,
      satisfiedNodePackages: satisfiedPackages,
      changed: changed,
      reloadRecommended: reloadRecommended,
    );
  }

  static Future<Map<String, String>> _readNodePackageRequirementsForEntry(
    SkillExecutionMatrixEntry entry,
  ) async {
    final descriptor = entry.executionDescriptor;
    final root = descriptor?.rootPath;
    if (root == null || root.trim().isEmpty) return const <String, String>{};
    final file = File(path.join(root, 'package.json'));
    final decoded = await _readJson(file);
    if (decoded == null) return const <String, String>{};
    return _nodeDependencyMap(decoded);
  }

  static Future<List<_NodePackageCandidate>> _loadNodePackageCatalog(
    _SkillProvisioningLayout layout,
  ) async {
    final manifest = await _readJson(layout.nodePackageManifestFile);
    final rawPackages = manifest?['packages'] ?? manifest?['items'];
    if (rawPackages is! List) return const <_NodePackageCandidate>[];
    final candidates = <_NodePackageCandidate>[];
    for (final item in rawPackages) {
      if (item is! Map) continue;
      final candidate =
          _NodePackageCandidate.fromJson(Map<String, dynamic>.from(item));
      if (candidate != null) candidates.add(candidate);
    }
    return candidates;
  }

  static Future<_NodePackageCandidate?> _resolveNodePackageCandidate(
    _NodePackageRequest request, {
    required List<_NodePackageCandidate> catalog,
  }) async {
    final local = catalog
        .where((candidate) =>
            candidate.name == request.name &&
            _nodeRequirementSatisfied(candidate.version, request.raw))
        .toList()
      ..sort((a, b) => _compareVersions(b.version, a.version));
    if (local.isNotEmpty) return local.first;

    final encodedName = request.name.startsWith('@')
        ? request.name.replaceFirst('/', '%2f')
        : Uri.encodeComponent(request.name);
    final registry = Uri.parse(
      const String.fromEnvironment(
        'OPENCLAW_NPM_REGISTRY',
        defaultValue: 'https://registry.npmjs.org/',
      ),
    );
    final packageUri = registry.resolve(encodedName);
    try {
      final response =
          await http.get(packageUri).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final metadata = Map<String, dynamic>.from(decoded);
      final versions = metadata['versions'];
      if (versions is! Map) return null;
      final candidates = <_NodePackageCandidate>[];
      for (final entry in versions.entries) {
        if (entry.value is! Map) continue;
        final version = entry.key.toString();
        if (!_nodeRequirementSatisfied(version, request.raw)) continue;
        final item = Map<String, dynamic>.from(entry.value as Map);
        final dist = item['dist'] is Map
            ? Map<String, dynamic>.from(item['dist'] as Map)
            : const <String, dynamic>{};
        final tarball = dist['tarball']?.toString();
        if (tarball == null || tarball.isEmpty) continue;
        candidates.add(_NodePackageCandidate(
          name: request.name,
          version: version,
          url: Uri.parse(tarball),
          integrity: dist['integrity']?.toString(),
          shasum: dist['shasum']?.toString(),
          dependencies: _nodeDependencyMap(item),
          maxBytes: (item['openclawMaxBytes'] as num?)?.toInt(),
        ));
      }
      candidates.sort((a, b) => _compareVersions(b.version, a.version));
      return candidates.isEmpty ? null : candidates.first;
    } catch (error) {
      debugPrint('[DEPS] npm registry unavailable $packageUri: $error');
      return null;
    }
  }

  static Future<_NodePackageInstallResult> _downloadAndInstallNodePackage(
    _SkillProvisioningLayout layout,
    _NodePackageRequest request,
    _NodePackageCandidate candidate,
  ) async {
    Directory? backup;
    final target = layout.nodePackageInstallDir(candidate.name);
    try {
      await layout.nodeModulesDir.create(recursive: true);
      await layout.dependencyTmpDir.create(recursive: true);
      final bytes = await _readDependencyPackBytes(candidate.url.toString());
      if (candidate.maxBytes != null && bytes.length > candidate.maxBytes!) {
        throw StateError(
          'Package ${candidate.name} exceeds maxBytes=${candidate.maxBytes}.',
        );
      }
      final verification = _verifyNodePackageBytes(candidate, bytes);
      if (verification != null) {
        return _NodePackageInstallResult(
          ok: false,
          dependencies: const <String, String>{},
          action: SkillProvisioningAction(
            type: SkillProvisioningActionType.nodePackage,
            key: request.name,
            status: SkillProvisioningActionStatus.failedVerification,
            message: verification,
          ),
        );
      }

      final stage = Directory(path.join(
        layout.dependencyTmpDir.path,
        'npm-${candidate.safeId}-${DateTime.now().microsecondsSinceEpoch}',
      ));
      await stage.create(recursive: true);
      try {
        final archive =
            TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
        for (final archiveFile in archive.files) {
          final stripped = _stripNpmPackagePrefix(archiveFile.name);
          if (stripped == null) continue;
          final targetPath = path.normalize(path.join(stage.path, stripped));
          if (!path.isWithin(stage.path, targetPath) &&
              path.normalize(stage.path) != targetPath) {
            throw StateError('Unsafe npm package path: ${archiveFile.name}');
          }
          if (archiveFile.isFile) {
            final file = File(targetPath);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(
              archiveFile.content as List<int>,
              flush: true,
            );
          } else {
            await Directory(targetPath).create(recursive: true);
          }
        }

        final packageJson = File(path.join(stage.path, 'package.json'));
        if (!await packageJson.exists()) {
          throw StateError('npm tarball missing package.json');
        }
        final installedJson = await _readJson(packageJson);
        final installedName = _normalizeNodePackageName(
          installedJson?['name']?.toString() ?? candidate.name,
        );
        final installedVersion =
            installedJson?['version']?.toString() ?? candidate.version;
        if (installedName != candidate.name) {
          throw StateError(
            'npm tarball name "$installedName" does not match ${candidate.name}',
          );
        }
        if (!_nodeRequirementSatisfied(installedVersion, request.raw)) {
          throw StateError(
            'npm tarball version "$installedVersion" does not satisfy ${request.raw}',
          );
        }

        if (await target.exists()) {
          backup = Directory(path.join(
            layout.dependencyTmpDir.path,
            'npm-backup-${candidate.safeId}-${DateTime.now().microsecondsSinceEpoch}',
          ));
          await target.rename(backup.path);
        }
        await target.parent.create(recursive: true);
        await stage.rename(target.path);

        final dependencies = {
          ...candidate.dependencies,
          ..._nodeDependencyMap(installedJson ?? const <String, dynamic>{}),
        };
        await _writeNodePackageReceipt(
          layout,
          request,
          candidate,
          installedVersion: installedVersion,
          dependencies: dependencies,
        );
        if (backup != null && await backup.exists()) {
          await backup.delete(recursive: true);
        }
        debugPrint(
          '[DEPS] npm installed package=${candidate.name} version=$installedVersion',
        );
        return _NodePackageInstallResult(
          ok: true,
          dependencies: dependencies,
          action: SkillProvisioningAction(
            type: SkillProvisioningActionType.nodePackage,
            key: request.name,
            status: SkillProvisioningActionStatus.installed,
            message:
                'Node package ${candidate.name} $installedVersion installed from verified npm tarball.',
            changed: true,
          ),
        );
      } finally {
        if (await stage.exists()) {
          try {
            await stage.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (error) {
      if (backup != null && await backup.exists() && !await target.exists()) {
        try {
          await backup.rename(target.path);
        } catch (_) {}
      }
      debugPrint(
        '[DEPS] npm install failed ${candidate.name}@${candidate.version}: $error',
      );
      return _NodePackageInstallResult(
        ok: false,
        dependencies: const <String, String>{},
        action: SkillProvisioningAction(
          type: SkillProvisioningActionType.nodePackage,
          key: request.name,
          status: SkillProvisioningActionStatus.missingDependency,
          message:
              'Node package ${candidate.name}@${candidate.version} could not be installed: $error',
        ),
      );
    }
  }

  static String? _verifyNodePackageBytes(
    _NodePackageCandidate candidate,
    List<int> bytes,
  ) {
    final integrity = candidate.integrity?.trim();
    if (integrity != null && integrity.isNotEmpty) {
      final parts = integrity.split('-');
      if (parts.length == 2) {
        final algorithm = parts[0].toLowerCase();
        final expected = parts[1];
        final digest = switch (algorithm) {
          'sha512' => crypto.sha512.convert(bytes).bytes,
          'sha384' => crypto.sha384.convert(bytes).bytes,
          'sha256' => crypto.sha256.convert(bytes).bytes,
          'sha1' => crypto.sha1.convert(bytes).bytes,
          _ => const <int>[],
        };
        if (digest.isNotEmpty && base64.encode(digest) != expected) {
          return 'Integrity verification failed for npm package ${candidate.name}.';
        }
      }
    }
    if (candidate.sha512 != null && candidate.sha512!.isNotEmpty) {
      final digest = crypto.sha512.convert(bytes).toString();
      if (digest.toLowerCase() != candidate.sha512) {
        return 'SHA512 verification failed for npm package ${candidate.name}.';
      }
    }
    if (candidate.sha256 != null && candidate.sha256!.isNotEmpty) {
      final digest = crypto.sha256.convert(bytes).toString();
      if (digest.toLowerCase() != candidate.sha256) {
        return 'SHA256 verification failed for npm package ${candidate.name}.';
      }
    }
    if (candidate.shasum != null && candidate.shasum!.isNotEmpty) {
      final digest = crypto.sha1.convert(bytes).toString();
      if (digest.toLowerCase() != candidate.shasum) {
        return 'SHA1 shasum verification failed for npm package ${candidate.name}.';
      }
    }
    return null;
  }

  static String? _stripNpmPackagePrefix(String rawName) {
    final normalized = rawName.replaceAll('\\', '/');
    if (normalized.isEmpty || normalized == 'package') return null;
    final parts =
        normalized.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    if (parts.first == 'package') parts.removeAt(0);
    if (parts.isEmpty) return null;
    if (parts.any((part) => part == '..' || part.contains(':'))) return null;
    return parts.join('/');
  }

  static Future<String?> _readInstalledNodePackageVersion(
    _SkillProvisioningLayout layout,
    String packageName,
  ) async {
    final json = await _readJson(
      File(path.join(
          layout.nodePackageInstallDir(packageName).path, 'package.json')),
    );
    return json?['version']?.toString();
  }

  static Future<Map<String, String>> _readInstalledNodePackageDependencies(
    _SkillProvisioningLayout layout,
    String packageName,
  ) async {
    final json = await _readJson(
      File(path.join(
          layout.nodePackageInstallDir(packageName).path, 'package.json')),
    );
    return _nodeDependencyMap(json ?? const <String, dynamic>{});
  }

  static Future<bool> _nodePackageMarkerPresent(
    _SkillProvisioningLayout layout,
    String packageName,
  ) async {
    return File(
      path.join(layout.nodePackageInstallDir(packageName).path, 'package.json'),
    ).exists();
  }

  static Future<_DependencyPackReceipt?> _readNodePackageReceipt(
    _SkillProvisioningLayout layout,
    String packageName,
  ) async {
    final file = File(path.join(
      layout.nodePackageReceiptDir.path,
      '${_nodePackageReceiptName(packageName)}.json',
    ));
    final json = await _readJson(file);
    return json == null ? null : _DependencyPackReceipt.fromJson(json);
  }

  static Future<void> _writeNodePackageReceipt(
    _SkillProvisioningLayout layout,
    _NodePackageRequest request,
    _NodePackageCandidate candidate, {
    required String installedVersion,
    required Map<String, String> dependencies,
  }) async {
    await layout.nodePackageReceiptDir.create(recursive: true);
    await File(path.join(
      layout.nodePackageReceiptDir.path,
      '${_nodePackageReceiptName(candidate.name)}.json',
    )).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({
            'id': candidate.name,
            'version': installedVersion,
            'sha256': candidate.sha256 ?? '',
            'sha512': candidate.sha512 ?? '',
            'shasum': candidate.shasum ?? '',
            'integrity': candidate.integrity ?? '',
            'source': 'npm',
            'url': candidate.url.toString(),
            'requestedRequirement': request.raw,
            'dependencies': dependencies,
            'installedAt': DateTime.now().toIso8601String(),
          })}\n',
      flush: true,
    );
  }

  static Map<String, String> _nodeDependencyMap(Map<String, dynamic> json) {
    final dependencies = <String, String>{};
    for (final sectionName in const ['dependencies', 'optionalDependencies']) {
      final section = json[sectionName];
      if (section is! Map) continue;
      for (final entry in section.entries) {
        final name = _normalizeNodePackageName(entry.key.toString());
        final range = entry.value?.toString().trim() ?? '*';
        if (_nodePackageNameLooksSafe(name)) {
          dependencies[name] = range.isEmpty ? '*' : range;
        }
      }
    }
    return dependencies;
  }

  static bool _nodeRequirementSatisfied(String version, String requirement) {
    final raw = requirement.trim();
    if (raw.isEmpty ||
        raw == '*' ||
        raw == 'latest' ||
        raw == 'x' ||
        raw == 'X') {
      return true;
    }
    if (raw.contains('||')) {
      return raw
          .split('||')
          .any((part) => _nodeRequirementSatisfied(version, part));
    }
    final parts = raw
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length > 1) {
      return parts.every((part) => _nodeRequirementSatisfied(version, part));
    }
    final single = parts.isEmpty ? raw : parts.single;
    if (single.startsWith('^')) {
      return _nodeCaretRequirementSatisfied(version, single.substring(1));
    }
    if (single.startsWith('~')) {
      return _nodeTildeRequirementSatisfied(version, single.substring(1));
    }
    final match = RegExp(r'^(>=|<=|>|<|=)?\s*([0-9][A-Za-z0-9.!+_*xX-]*)$')
        .firstMatch(single);
    if (match == null) return true;
    final operator = match.group(1) ?? '=';
    final required = match.group(2) ?? '';
    if (required.contains('*') ||
        required.toLowerCase().contains('x') ||
        required.isEmpty) {
      return true;
    }
    final comparison = _compareVersions(version, required);
    return switch (operator) {
      '>=' => comparison >= 0,
      '>' => comparison > 0,
      '<=' => comparison <= 0,
      '<' => comparison < 0,
      '=' => comparison == 0,
      _ => comparison == 0,
    };
  }

  static bool _nodeCaretRequirementSatisfied(String version, String required) {
    if (!_nodeRequirementSatisfied(version, '>=$required')) return false;
    final parts = _versionParts(required);
    if (parts.isEmpty) return true;
    final upper = <int>[...parts];
    if (upper[0] > 0) {
      upper[0] += 1;
      for (var i = 1; i < upper.length; i++) {
        upper[i] = 0;
      }
    } else if (upper.length > 1 && upper[1] > 0) {
      upper[1] += 1;
      for (var i = 2; i < upper.length; i++) {
        upper[i] = 0;
      }
    } else if (upper.length > 2) {
      upper[2] += 1;
    } else {
      return true;
    }
    return _compareVersions(version, upper.join('.')) < 0;
  }

  static bool _nodeTildeRequirementSatisfied(String version, String required) {
    if (!_nodeRequirementSatisfied(version, '>=$required')) return false;
    final parts = _versionParts(required);
    if (parts.length < 2) return true;
    final upper = <int>[...parts];
    upper[1] += 1;
    for (var i = 2; i < upper.length; i++) {
      upper[i] = 0;
    }
    return _compareVersions(version, upper.join('.')) < 0;
  }

  static String _normalizeNodePackageName(String value) =>
      value.trim().toLowerCase();

  static bool _nodePackageNameLooksSafe(String name) {
    if (name.isEmpty || name.length > 214) return false;
    if (name.startsWith('@')) {
      return RegExp(r'^@[a-z0-9_.-]+/[a-z0-9_.-]+$').hasMatch(name);
    }
    return RegExp(r'^[a-z0-9_.-]+$').hasMatch(name);
  }

  static String _nodePackageReceiptName(String packageName) {
    return _normalizeNodePackageName(packageName)
        .replaceAll('@', '_scope_')
        .replaceAll('/', '__');
  }

  static String _pythonRequirementForPackage(
    Map<String, String> requirements,
    String package,
  ) {
    final direct = requirements[package];
    if (direct != null) return direct;
    for (final entry in requirements.entries) {
      if (_normalizeDependencyName(entry.key) == package) return entry.value;
    }
    return package;
  }

  static List<_DependencyPack> _selectDependencyPacks(
    List<_DependencyPack> packs, {
    required Set<String> requiredBins,
    required Set<String> requiredRuntimes,
    required Set<String> requiredPythonPackages,
  }) {
    final selected = <_DependencyPack>[];
    final remainingBins = {...requiredBins};
    final remainingRuntimes = {...requiredRuntimes};
    final remainingPackages = {...requiredPythonPackages};

    while (remainingBins.isNotEmpty ||
        remainingRuntimes.isNotEmpty ||
        remainingPackages.isNotEmpty) {
      _DependencyPack? best;
      var bestScore = 0;
      for (final pack in packs) {
        if (selected.any((item) => item.id == pack.id)) continue;
        final score =
            pack.providesRuntimes.where(remainingRuntimes.contains).length *
                    10 +
                pack.providesBins.where(remainingBins.contains).length * 5 +
                pack.providesPythonPackages
                    .where(remainingPackages.contains)
                    .length;
        if (score > bestScore) {
          best = pack;
          bestScore = score;
        }
      }
      if (best == null) break;
      selected.add(best);
      remainingBins.removeAll(best.providesBins);
      remainingRuntimes.removeAll(best.providesRuntimes);
      remainingPackages.removeAll(best.providesPythonPackages);
    }

    _sortDependencyPacks(selected);
    return selected;
  }

  static void _sortDependencyPacks(List<_DependencyPack> selected) {
    selected.sort((a, b) {
      if (a.id == 'python-core') return -1;
      if (b.id == 'python-core') return 1;
      return a.id.compareTo(b.id);
    });
  }

  static Future<List<_DependencyPack>> _loadDependencyPackCatalog(
    _SkillProvisioningLayout layout,
  ) async {
    final packs = <_DependencyPack>[
      _DependencyPack.apk(
        id: 'python-core',
        version: '3.11-chaquopy-17.0.0',
        providesRuntimes: const {'python'},
        providesBins: const {'python', 'python3', 'pip'},
      ),
    ];
    final cliCorePack = await _apkProvidedCliCorePack(layout);
    if (cliCorePack != null) {
      packs.add(cliCorePack);
    }
    final visionMediaPack = await _apkProvidedVisionMediaPack(layout);
    if (visionMediaPack != null) {
      packs.add(visionMediaPack);
    }
    final audioRuntimePack = await _apkProvidedAudioRuntimePack(layout);
    if (audioRuntimePack != null) {
      packs.add(audioRuntimePack);
    }
    final pythonDebugPack = await _apkProvidedPythonDebugPack(layout);
    if (pythonDebugPack != null) {
      packs.add(pythonDebugPack);
    }
    final terminalPack = await _apkProvidedTerminalPack(layout);
    if (terminalPack != null) {
      packs.add(terminalPack);
    }
    final whisperPack = await _apkProvidedWhisperRuntimePack(layout);
    if (whisperPack != null) {
      packs.add(whisperPack);
    }
    final ttsPack = await _apkProvidedTtsRuntimePack(layout);
    if (ttsPack != null) {
      packs.add(ttsPack);
    }
    final nodePack = await _apkProvidedNodeExecutablePack(layout);
    if (nodePack != null) {
      packs.add(nodePack);
    }
    final agentPack = await _apkProvidedAgentCliPack(layout);
    if (agentPack != null) {
      packs.add(agentPack);
    }

    Future<void> mergeManifest(Map<String, dynamic>? manifest) async {
      if (manifest == null) return;
      final rawPacks = manifest['packs'] ?? manifest['items'];
      if (rawPacks is! List) return;
      for (final item in rawPacks) {
        if (item is! Map) continue;
        final json = Map<String, dynamic>.from(item);
        final validation = DependencyPackManifestEntry.fromJson(json)
            .validate(DependencyPackManifestPolicy.androidArm64);
        if (!validation.ok) {
          debugPrint(
            '[DEPS] rejected dependency pack manifest '
            '${json['id'] ?? 'unknown'}: ${validation.errorCodes.join(', ')}',
          );
          continue;
        }
        final pack = _DependencyPack.fromJson(json);
        if (pack != null && !packs.any((existing) => existing.id == pack.id)) {
          packs.add(pack);
        }
      }
    }

    await mergeManifest(await _readJson(layout.dependencyPackManifestFile));
    try {
      final uri = Uri.parse(
        const String.fromEnvironment(
          'OPENCLAW_DEPENDENCY_PACK_MANIFEST',
              defaultValue:
                  'https://raw.githubusercontent.com/vmbbz/plawie/native-node-gateway-research/android-arm64-v8a.json',
        ),
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          await mergeManifest(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (error) {
      debugPrint('[DEPS] remote dependency manifest unavailable: $error');
    }

    return packs;
  }

  static Future<_DependencyPackInstallResult> _installDependencyPack(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
    SkillExecutionMatrixEntry entry,
  ) async {
    try {
      await layout.dependencyReceiptDir.create(recursive: true);
      await layout.nativePythonBinDir.create(recursive: true);
      await layout.nativePythonSitePackagesDir.create(recursive: true);

      if (pack.source == _DependencyPackSource.apk) {
        await _installApkProvidedPack(layout, pack, entry);
      } else {
        await _downloadAndExtractPack(layout, pack);
      }
      await _applyDependencyPackFileModes(layout, pack);

      final smoke = await _runDependencyPackSmoke(layout, pack);
      if (!smoke.ok) {
        debugPrint('[DEPS] smoke failed pack=${pack.id} error=${smoke.stderr}');
        await _rollbackDependencyPackInstall(layout, pack);
        return _DependencyPackInstallResult(
          ok: false,
          action: SkillProvisioningAction(
            type: SkillProvisioningActionType.dependencyPack,
            key: pack.id,
            status: SkillProvisioningActionStatus.failedSmoke,
            message: 'Dependency pack ${pack.id} failed smoke test: '
                '${smoke.stderr.isEmpty ? smoke.stdout : smoke.stderr}',
          ),
        );
      }

      await _writeDependencyReceipt(layout, pack);
      debugPrint('[DEPS] installed pack=${pack.id} skill=${entry.skillId}');
      return _DependencyPackInstallResult(
        ok: true,
        action: SkillProvisioningAction(
          type: SkillProvisioningActionType.dependencyPack,
          key: pack.id,
          status: SkillProvisioningActionStatus.installed,
          message: 'Dependency pack ${pack.id} installed and smoke-tested.',
          changed: true,
        ),
      );
    } catch (error) {
      debugPrint('[DEPS] install failed pack=${pack.id} error=$error');
      return _DependencyPackInstallResult(
        ok: false,
        action: SkillProvisioningAction(
          type: SkillProvisioningActionType.dependencyPack,
          key: pack.id,
          status: SkillProvisioningActionStatus.missingDependency,
          message: 'Dependency pack ${pack.id} could not be installed: $error',
        ),
      );
    }
  }

  /// Apply Chaquopy-specific version constraints to certain packages.
  /// pandas >=2.2 has C extensions that fail to load under Chaquopy 13.x
  /// due to incompatible CPython ABI (circular-import-like AttributeError
  /// on _pandas_datetime_CAPI). Always force <2.2 for compatibility,
  /// regardless of what the skill specifies (e.g. pandas>=2.2.0 must be
  /// replaced entirely, not appended to).
  static String _applyChaquopyConstraint(
      String packageName, String requirement) {
    switch (packageName) {
      case 'pandas':
        // Always pin pandas<2.2 for Chaquopy 13.x compatibility
        // Skills may request >=2.2 which is incompatible — force replacement
        return 'pandas<2.2';
      default:
        return requirement;
    }
  }

  static Future<_DependencyProvisioningResult> _provisionPythonWheels(
    SkillExecutionMatrixEntry entry,
    _SkillProvisioningLayout layout, {
    required Map<String, String> requiredPythonRequirements,
    required bool apply,
  }) async {
    final actions = <SkillProvisioningAction>[];
    final satisfiedPackages = <String>{};
    var changed = false;
    var reloadRecommended = false;

    final installed = await _scanInstalledPythonPackageVersions(layout);
    final rootPackages =
        requiredPythonRequirements.keys.map(_normalizeDependencyName).toSet();
    final queue = <_PythonRequirementRequest>[
      for (final entry in requiredPythonRequirements.entries)
        _PythonRequirementRequest.fromRaw(
              _applyChaquopyConstraint(entry.key, entry.value),
              fallbackName: entry.key,
              root: true,
              rootPackage: _normalizeDependencyName(entry.key),
            ) ??
            _PythonRequirementRequest(
              name: _normalizeDependencyName(entry.key),
              raw: _applyChaquopyConstraint(entry.key, entry.value),
              root: true,
              rootPackage: _normalizeDependencyName(entry.key),
            ),
    ];
    final processed = <String>{};
    final unresolvedPackages = <String>{};
    final unresolvedRootPackages = <String>{};
    var iterations = 0;

    void markUnresolved(_PythonRequirementRequest request) {
      unresolvedPackages.add(request.name);
      unresolvedRootPackages.add(request.rootPackage ?? request.name);
    }

    Future<void> enqueueInstalledTransitive(
      _PythonRequirementRequest request,
    ) async {
      final requiresDist = await _readInstalledPythonPackageRequiresDist(
        layout,
        request.name,
      );
      for (final dependency in requiresDist) {
        final normalized = _normalizeDependencyName(dependency.name);
        if (installed.containsKey(normalized) &&
            _pythonRequirementSatisfied(
              installed[normalized]!,
              dependency.raw,
            )) {
          continue;
        }
        queue.add(dependency.withRootPackage(
          request.rootPackage ?? request.name,
        ));
      }
    }

    while (queue.isNotEmpty && iterations < 120) {
      iterations += 1;
      final request = queue.removeAt(0);
      final key = '${request.name}:${request.raw}';
      if (!processed.add(key)) continue;

      final installedVersion = installed[request.name];
      if (installedVersion != null &&
          _pythonRequirementSatisfied(installedVersion, request.raw)) {
        if (rootPackages.contains(request.name)) {
          satisfiedPackages.add(request.name);
        }
        await enqueueInstalledTransitive(request);
        continue;
      }

      if (!apply) {
        markUnresolved(request);
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.pythonPackage,
          key: request.name,
          status: SkillProvisioningActionStatus.missingDependency,
          message:
              'Python wheel provisioning can satisfy ${request.raw} when dependency repair is applied.',
        ));
        continue;
      }

      final receipt = await _readPythonWheelReceipt(layout, request.name);
      if (receipt != null &&
          _pythonWheelReceiptSatisfiesRequest(receipt, request) &&
          await _pythonPackageMarkerPresent(layout, request.name)) {
        installed[request.name] = receipt.version;
        if (rootPackages.contains(request.name)) {
          satisfiedPackages.add(request.name);
        }
        await enqueueInstalledTransitive(request);
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.pythonPackage,
          key: request.name,
          status: SkillProvisioningActionStatus.ready,
          message: receipt.compatibilityOverride
              ? 'Python package ${request.name} ${receipt.version} already '
                  'installed from a verified Android compatibility wheel for '
                  '${receipt.requestedRequirement ?? request.raw}.'
              : 'Python package ${request.name} ${receipt.version} already installed from a verified wheel.',
        ));
        continue;
      }

      final candidate = await _resolvePythonWheelCandidate(request);
      if (candidate == null) {
        debugPrint(
          '[DEPS] no compatible wheel skill=${entry.skillId} '
          'package=${request.name} requirement=${request.raw}',
        );
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.pythonPackage,
          key: request.name,
          status: SkillProvisioningActionStatus.missingPack,
          message:
              'No compatible Android arm64 wheel found for ${request.raw} on approved Native indexes.',
        ));
        markUnresolved(request);
        continue;
      }

      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.pythonPackage,
        key: request.name,
        status: SkillProvisioningActionStatus.downloading,
        message:
            'Downloading ${candidate.fileName} from ${candidate.indexHost}.',
      ));
      debugPrint(
        '[DEPS] wheel requested skill=${entry.skillId} package=${request.name} version=${candidate.version}',
      );

      final install = await _downloadAndInstallPythonWheel(
        layout,
        request,
        candidate,
      );
      actions.add(install.action);
      if (!install.ok) {
        markUnresolved(request);
        debugPrint(
          '[DEPS] wheel not installed skill=${entry.skillId} '
          'package=${request.name} status=${install.action.status.wireName} '
          'message=${install.action.message}',
        );
        continue;
      }

      changed = true;
      reloadRecommended = true;
      installed[request.name] = candidate.version;
      if (rootPackages.contains(request.name)) {
        satisfiedPackages.add(request.name);
      }
      for (final dependency in install.requiresDist) {
        final normalized = _normalizeDependencyName(dependency.name);
        if (installed.containsKey(normalized) &&
            _pythonRequirementSatisfied(
                installed[normalized]!, dependency.raw)) {
          continue;
        }
        queue.add(dependency.withRootPackage(
          request.rootPackage ?? request.name,
        ));
      }
    }

    if (queue.isNotEmpty) {
      for (final request in queue) {
        markUnresolved(request);
      }
      actions.add(const SkillProvisioningAction(
        type: SkillProvisioningActionType.pythonPackage,
        key: 'dependency-closure',
        status: SkillProvisioningActionStatus.missingDependency,
        message:
            'Python dependency closure exceeded the safety limit while resolving wheels.',
      ));
    }

    if (unresolvedRootPackages.isNotEmpty) {
      satisfiedPackages.removeAll(unresolvedRootPackages);
      final roots = unresolvedRootPackages.toList()..sort();
      final unresolved = unresolvedPackages.toList()..sort();
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.pythonPackage,
        key: 'dependency-closure',
        status: SkillProvisioningActionStatus.missingDependency,
        message: 'Python dependency closure is incomplete for '
            '${roots.join(', ')}; unresolved transitive packages: '
            '${unresolved.join(', ')}.',
      ));
    }

    if (apply && satisfiedPackages.isNotEmpty) {
      for (final package in satisfiedPackages.toList()) {
        final smoke = await _smokePythonImport(layout, package);
        if (!smoke.ok) {
          satisfiedPackages.remove(package);
          debugPrint(
            '[DEPS] python import smoke failed skill=${entry.skillId} '
            'package=$package stderr=${smoke.stderr} stdout=${smoke.stdout}',
          );
          actions.add(SkillProvisioningAction(
            type: SkillProvisioningActionType.pythonPackage,
            key: package,
            status: SkillProvisioningActionStatus.failedSmoke,
            message: 'Python package $package failed import smoke: '
                '${smoke.stderr.isEmpty ? smoke.stdout : smoke.stderr}',
          ));
        }
      }
    }

    return _DependencyProvisioningResult(
      actions: actions,
      satisfiedBins: const <String>{},
      satisfiedRuntimes: const <String>{},
      satisfiedPythonPackages: satisfiedPackages,
      changed: changed,
      reloadRecommended: reloadRecommended,
    );
  }

  static Future<_PythonWheelCandidate?> _resolvePythonWheelCandidate(
    _PythonRequirementRequest request, {
    bool validatePinnedDependencies = true,
  }) async {
    final candidates = <_PythonWheelCandidate>[];
    for (final index in _defaultPythonWheelIndexes) {
      final base = Uri.parse(index.endsWith('/') ? index : '$index/');
      final pageUri = base.resolve('${Uri.encodeComponent(request.name)}/');
      try {
        final response =
            await http.get(pageUri).timeout(const Duration(seconds: 12));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        candidates.addAll(_parseWheelCandidates(
          response.body,
          pageUri,
          request.name,
          index,
        ));
      } catch (error) {
        debugPrint('[DEPS] wheel index unavailable $pageUri: $error');
      }
    }

    var compatible = candidates
        .where((candidate) =>
            _pythonRequirementSatisfied(candidate.version, request.raw))
        .toList();
    var usingCompatibilityFallback = false;
    if (compatible.isEmpty &&
        _androidCompatibilityWheelFallbackAllowed(request.raw)) {
      compatible = candidates.toList();
      usingCompatibilityFallback = compatible.isNotEmpty;
    }
    if (!_requirementAllowsPrerelease(request.raw)) {
      final stable = compatible
          .where((candidate) => !_isPrereleaseVersion(candidate.version))
          .toList();
      if (stable.isNotEmpty) compatible = stable;
    }
    compatible.sort((a, b) => _compareVersions(b.version, a.version));
    if (!validatePinnedDependencies) {
      return compatible.isEmpty ? null : compatible.first;
    }
    for (final candidate in compatible) {
      if (usingCompatibilityFallback) {
        debugPrint(
          '[DEPS] Android compatibility wheel selected package=${request.name} '
          'requested=${request.raw} actual=${candidate.version}',
        );
      }
      if (await _wheelCandidatePinnedDependenciesResolvable(candidate)) {
        return candidate;
      }
      debugPrint(
        '[DEPS] wheel candidate skipped package=${candidate.name} '
        'version=${candidate.version}: exact pinned dependency unavailable',
      );
    }
    return null;
  }

  static bool _pythonWheelReceiptSatisfiesRequest(
    _DependencyPackReceipt receipt,
    _PythonRequirementRequest request,
  ) {
    if (_pythonRequirementSatisfied(receipt.version, request.raw)) return true;
    return receipt.compatibilityOverride &&
        receipt.smokePassed &&
        receipt.requestedRequirement == request.raw;
  }

  static bool _androidCompatibilityWheelFallbackAllowed(String requirement) {
    final constraints = _pythonVersionConstraints(requirement);
    if (constraints.isEmpty) return false;
    return constraints.every((constraint) =>
        constraint.operator == '>=' || constraint.operator == '>');
  }

  static Future<bool> _wheelCandidatePinnedDependenciesResolvable(
    _PythonWheelCandidate candidate,
  ) async {
    final metadata = await _fetchWheelMetadata(candidate);
    if (metadata == null) return true;
    for (final dependency in _readWheelRequiresDist(metadata)) {
      if (!_hasExactPythonVersionConstraint(dependency.raw)) continue;
      final resolved = await _resolvePythonWheelCandidate(
        dependency,
        validatePinnedDependencies: false,
      );
      if (resolved == null) {
        debugPrint(
          '[DEPS] exact dependency unavailable parent=${candidate.name} '
          'parentVersion=${candidate.version} dependency=${dependency.raw}',
        );
        return false;
      }
    }
    return true;
  }

  static Future<Map<String, String>?> _fetchWheelMetadata(
    _PythonWheelCandidate candidate,
  ) async {
    try {
      final response = await http.get(candidate.url).timeout(
            const Duration(minutes: 2),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (candidate.sha256 != null) {
        final digest = crypto.sha256.convert(response.bodyBytes).toString();
        if (digest != candidate.sha256) return null;
      }
      return _readWheelMetadata(ZipDecoder().decodeBytes(response.bodyBytes));
    } catch (error) {
      debugPrint(
        '[DEPS] wheel metadata preflight failed '
        '${candidate.fileName}: $error',
      );
      return null;
    }
  }

  static List<_PythonWheelCandidate> _parseWheelCandidates(
    String html,
    Uri pageUri,
    String packageName,
    String index,
  ) {
    final candidates = <_PythonWheelCandidate>[];
    final anchorPattern = RegExp(
      r'''<a\s+[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in anchorPattern.allMatches(html)) {
      final href = (match.group(1) ?? '').replaceAll('&amp;', '&');
      if (href.isEmpty) continue;
      final urlWithFragment = pageUri.resolve(href);
      final url = urlWithFragment.replace(fragment: '');
      final fileName = path.basename(Uri.decodeComponent(url.path));
      if (!fileName.toLowerCase().endsWith('.whl')) continue;
      final wheel = _parseWheelFileName(fileName);
      if (wheel == null) continue;
      if (wheel.name != _normalizeDependencyName(packageName)) continue;
      if (!_wheelIsCompatible(wheel)) continue;
      final fragment = urlWithFragment.fragment;
      String? sha256;
      if (fragment.toLowerCase().startsWith('sha256=')) {
        sha256 = fragment.substring('sha256='.length).toLowerCase();
      }
      candidates.add(_PythonWheelCandidate(
        name: wheel.name,
        version: wheel.version,
        fileName: fileName,
        url: url,
        sha256: sha256,
        indexHost: Uri.parse(index).host,
      ));
    }
    return candidates;
  }

  static _PythonWheelName? _parseWheelFileName(String fileName) {
    final stem =
        fileName.replaceFirst(RegExp(r'\.whl$', caseSensitive: false), '');
    final parts = stem.split('-');
    if (parts.length < 5) return null;
    final name = _normalizeDependencyName(parts[0]);
    final version = parts[1];
    final pythonTag = parts[parts.length - 3];
    final abiTag = parts[parts.length - 2];
    final platformTag = parts[parts.length - 1];
    return _PythonWheelName(
      name: name,
      version: version,
      pythonTags: pythonTag.split('.').toSet(),
      abiTags: abiTag.split('.').toSet(),
      platformTags: platformTag.split('.').toSet(),
    );
  }

  static bool _wheelIsCompatible(_PythonWheelName wheel) {
    final pythonOk = wheel.pythonTags.any((tag) =>
        tag == 'py3' || tag == 'py2.py3' || tag == _pythonTag || tag == 'cp3');
    if (!pythonOk) return false;

    final abiOk = wheel.abiTags.any(
      (tag) => tag == 'none' || tag == 'abi3' || tag == _pythonAbiTag,
    );
    if (!abiOk) return false;

    return wheel.platformTags.any((tag) {
      if (tag == 'any') return true;
      final lower = tag.toLowerCase();
      return lower.startsWith('android_') && lower.endsWith(_androidWheelAbi);
    });
  }

  static Future<_PythonWheelInstallResult> _downloadAndInstallPythonWheel(
    _SkillProvisioningLayout layout,
    _PythonRequirementRequest request,
    _PythonWheelCandidate candidate,
  ) async {
    try {
      await layout.nativePythonSitePackagesDir.create(recursive: true);
      await layout.dependencyTmpDir.create(recursive: true);
      final wheelBytes = await _readPythonWheelCandidateBytes(candidate);
      final digest = crypto.sha256.convert(wheelBytes).toString();
      if (candidate.sha256 != null && digest != candidate.sha256) {
        return _PythonWheelInstallResult(
          ok: false,
          requiresDist: const <_PythonRequirementRequest>[],
          action: SkillProvisioningAction(
            type: SkillProvisioningActionType.pythonPackage,
            key: request.name,
            status: SkillProvisioningActionStatus.failedVerification,
            message:
                'SHA256 verification failed for wheel ${candidate.fileName}.',
          ),
        );
      }

      final archive = ZipDecoder().decodeBytes(wheelBytes);
      final metadata = _readWheelMetadata(archive);
      final metadataName = _normalizeDependencyName(
        metadata['name'] ?? candidate.name,
      );
      final metadataVersion = metadata['version'] ?? candidate.version;
      if (metadataName != candidate.name) {
        return _PythonWheelInstallResult(
          ok: false,
          requiresDist: const <_PythonRequirementRequest>[],
          action: SkillProvisioningAction(
            type: SkillProvisioningActionType.pythonPackage,
            key: request.name,
            status: SkillProvisioningActionStatus.missingPack,
            message:
                'Wheel ${candidate.fileName} metadata name "$metadataName" '
                'does not match ${candidate.name}.',
          ),
        );
      }
      if (!_pythonRequirementSatisfied(metadataVersion, request.raw)) {
        if (!_androidCompatibilityWheelFallbackAllowed(request.raw)) {
          return _PythonWheelInstallResult(
            ok: false,
            requiresDist: const <_PythonRequirementRequest>[],
            action: SkillProvisioningAction(
              type: SkillProvisioningActionType.pythonPackage,
              key: request.name,
              status: SkillProvisioningActionStatus.missingPack,
              message: 'Wheel ${candidate.fileName} metadata version '
                  '"$metadataVersion" does not satisfy ${request.raw}.',
            ),
          );
        }
      }

      final stage = Directory(path.join(
        layout.dependencyTmpDir.path,
        'wheel-${candidate.name}-${DateTime.now().microsecondsSinceEpoch}',
      ));
      await stage.create(recursive: true);
      try {
        for (final archiveFile in archive.files) {
          final target = File(path.join(stage.path, archiveFile.name));
          final normalizedTarget = path.normalize(target.path);
          if (!path.isWithin(stage.path, normalizedTarget) &&
              path.normalize(stage.path) != normalizedTarget) {
            throw StateError('Unsafe wheel path: ${archiveFile.name}');
          }
          if (archiveFile.isFile) {
            await target.parent.create(recursive: true);
            await target.writeAsBytes(
              archiveFile.content as List<int>,
              flush: true,
            );
          } else {
            await Directory(target.path).create(recursive: true);
          }
        }

        await _removeExistingPythonPackageInstall(
          layout.nativePythonSitePackagesDir,
          candidate.name,
        );
        await _mergeDirectory(stage, layout.nativePythonSitePackagesDir);
      } finally {
        if (await stage.exists()) {
          try {
            await stage.delete(recursive: true);
          } catch (_) {}
        }
      }

      final compatibilityOverride =
          !_pythonRequirementSatisfied(metadataVersion, request.raw);
      if (compatibilityOverride) {
        final smoke = await _smokePythonImport(layout, candidate.name);
        if (!smoke.ok) {
          await _removeExistingPythonPackageInstall(
            layout.nativePythonSitePackagesDir,
            candidate.name,
          );
          return _PythonWheelInstallResult(
            ok: false,
            requiresDist: const <_PythonRequirementRequest>[],
            action: SkillProvisioningAction(
              type: SkillProvisioningActionType.pythonPackage,
              key: request.name,
              status: SkillProvisioningActionStatus.failedSmoke,
              message: 'Android compatibility wheel ${candidate.fileName} '
                  'failed import smoke for ${request.raw}: '
                  '${smoke.stderr.isEmpty ? smoke.stdout : smoke.stderr}',
            ),
          );
        }
        debugPrint(
          '[DEPS] compatibility smoke passed package=${candidate.name} '
          'requested=${request.raw} actual=$metadataVersion',
        );
      }

      await _writePythonWheelReceipt(
        layout,
        request,
        candidate,
        sha256: digest,
        metadataVersion: metadataVersion,
        compatibilityOverride: compatibilityOverride,
      );
      debugPrint(
        '[DEPS] wheel installed package=${candidate.name} version=$metadataVersion',
      );
      return _PythonWheelInstallResult(
        ok: true,
        requiresDist: _readWheelRequiresDist(metadata),
        action: SkillProvisioningAction(
          type: SkillProvisioningActionType.pythonPackage,
          key: request.name,
          status: SkillProvisioningActionStatus.installed,
          message: compatibilityOverride
              ? 'Python package ${candidate.name} $metadataVersion installed '
                  'from a verified Android compatibility wheel for ${request.raw}.'
              : 'Python package ${candidate.name} $metadataVersion installed from verified wheel.',
          changed: true,
        ),
      );
    } catch (error) {
      debugPrint('[DEPS] wheel install failed ${candidate.fileName}: $error');
      return _PythonWheelInstallResult(
        ok: false,
        requiresDist: const <_PythonRequirementRequest>[],
        action: SkillProvisioningAction(
          type: SkillProvisioningActionType.pythonPackage,
          key: request.name,
          status: SkillProvisioningActionStatus.missingDependency,
          message:
              'Python wheel ${candidate.fileName} could not be installed: $error',
        ),
      );
    }
  }

  static Map<String, String> _readWheelMetadata(Archive archive) {
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (!file.name.toLowerCase().endsWith('.dist-info/metadata')) continue;
      final text = utf8.decode(file.content as List<int>, allowMalformed: true);
      final result = <String, String>{};
      final requires = <String>[];
      for (final line in text.split(RegExp(r'\r?\n'))) {
        if (line.trim().isEmpty) break;
        if (line.startsWith(' ') || line.startsWith('\t')) continue;
        final index = line.indexOf(':');
        if (index <= 0) continue;
        final key = line.substring(0, index).trim().toLowerCase();
        final value = line.substring(index + 1).trim();
        if ((key == 'name' || key == 'version') && !result.containsKey(key)) {
          result[key] = value;
        }
        if (key == 'requires-dist') requires.add(value);
      }
      if (requires.isNotEmpty) result['requires-dist'] = jsonEncode(requires);
      return result;
    }
    return const <String, String>{};
  }

  static List<_PythonRequirementRequest> _readWheelRequiresDist(
    Map<String, String> metadata,
  ) {
    final raw = metadata['requires-dist'];
    if (raw == null || raw.isEmpty) return const <_PythonRequirementRequest>[];
    final result = <_PythonRequirementRequest>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          final line = item?.toString() ?? '';
          if (!_pythonDependencyMarkerApplies(line)) continue;
          final request = _PythonRequirementRequest.fromRaw(line, root: false);
          if (request != null) result.add(request);
        }
      }
    } catch (_) {}
    return result;
  }

  static bool _pythonDependencyMarkerApplies(String requirement) {
    final markerIndex = requirement.indexOf(';');
    if (markerIndex < 0) return true;
    final marker = requirement.substring(markerIndex + 1).toLowerCase();
    if (marker.contains('extra ==') || marker.contains('extra==')) {
      return false;
    }
    final pyMatch = RegExp(
      r'''python_version\s*([<>=!~]{1,2})\s*["']([0-9.]+)["']''',
    ).firstMatch(marker);
    if (pyMatch != null) {
      final operator = pyMatch.group(1) ?? '';
      final version = pyMatch.group(2) ?? '';
      return _pythonRequirementSatisfied(
        _pythonRuntimeVersion,
        'python$operator$version',
      );
    }
    return true;
  }

  static Future<Map<String, String>> _scanInstalledPythonPackageVersions(
    _SkillProvisioningLayout layout,
  ) async {
    final result = <String, String>{};
    // Scan the managed site-packages directory (runtime wheel installs).
    final root = layout.nativePythonSitePackagesDir;
    // Also scan Chaquopy's build-time site-packages (packages installed via
    // the chaquopy.pip block in build.gradle.kts live here, not in the
    // managed directory).
    final chaquopyRoot = Directory(path.join(
      root.parent.parent.parent.parent.parent.parent.path,
      'chaquopy',
      'AssetFinder',
      'app',
      'site-packages',
    ));
    for (final scanRoot in [root, chaquopyRoot]) {
      try {
        if (!await scanRoot.exists()) continue;
        await for (final entity in scanRoot.list(recursive: false)) {
          final name = path.basename(entity.path);
          final lower = name.toLowerCase();
          if (entity is Directory &&
              (lower.endsWith('.dist-info') || lower.endsWith('.egg-info'))) {
            final metadata = await _readPythonPackageMetadata(entity);
            final parsed = _parsePythonDistInfoName(lower);
            final packageName = _normalizeDependencyName(
              metadata['name'] ?? parsed?.name ?? lower.split('-').first,
            );
            final version = metadata['version'] ?? parsed?.version ?? '';
            result[packageName] = version;
          }
        }
      } catch (_) {}
    }
    return result;
  }

  static Future<Map<String, String>> _readPythonPackageMetadata(
    Directory distInfo,
  ) async {
    final metadata = File(path.join(distInfo.path, 'METADATA'));
    try {
      if (!await metadata.exists()) return const <String, String>{};
      final result = <String, String>{};
      for (final line in await metadata.readAsLines()) {
        if (line.trim().isEmpty) break;
        final index = line.indexOf(':');
        if (index <= 0) continue;
        final key = line.substring(0, index).trim().toLowerCase();
        if (key != 'name' && key != 'version') continue;
        final value = line.substring(index + 1).trim();
        if (value.isNotEmpty) result.putIfAbsent(key, () => value);
      }
      return result;
    } catch (_) {
      return const <String, String>{};
    }
  }

  static Future<List<_PythonRequirementRequest>>
      _readInstalledPythonPackageRequiresDist(
    _SkillProvisioningLayout layout,
    String packageName,
  ) async {
    final normalized = _normalizeDependencyName(packageName);
    final root = layout.nativePythonSitePackagesDir;
    try {
      if (!await root.exists()) return const <_PythonRequirementRequest>[];
      await for (final entity in root.list(recursive: false)) {
        if (entity is! Directory) continue;
        final name = path.basename(entity.path).toLowerCase();
        if (!name.endsWith('.dist-info') && !name.endsWith('.egg-info')) {
          continue;
        }
        final parsed = _parsePythonDistInfoName(name);
        final metadata = await _readPythonPackageMetadata(entity);
        final actualName = _normalizeDependencyName(
          metadata['name'] ?? parsed?.name ?? name.split('-').first,
        );
        if (actualName != normalized) continue;
        final metadataFile = File(path.join(entity.path, 'METADATA'));
        if (!await metadataFile.exists()) {
          return const <_PythonRequirementRequest>[];
        }
        final requires = <String>[];
        for (final line in await metadataFile.readAsLines()) {
          if (line.trim().isEmpty) break;
          if (line.startsWith(' ') || line.startsWith('\t')) continue;
          final index = line.indexOf(':');
          if (index <= 0) continue;
          final key = line.substring(0, index).trim().toLowerCase();
          if (key == 'requires-dist') {
            requires.add(line.substring(index + 1).trim());
          }
        }
        if (requires.isEmpty) return const <_PythonRequirementRequest>[];
        return _readWheelRequiresDist({
          'requires-dist': jsonEncode(requires),
        });
      }
    } catch (_) {}
    return const <_PythonRequirementRequest>[];
  }

  static _PythonInstalledPackage? _parsePythonDistInfoName(String name) {
    final cleaned = name.replaceFirst(
        RegExp(r'\.(dist|egg)-info$', caseSensitive: false), '');
    final match =
        RegExp(r'^(.+)-([0-9][A-Za-z0-9.!+_-]*)$').firstMatch(cleaned);
    if (match == null) return null;
    return _PythonInstalledPackage(
      name: _normalizeDependencyName(match.group(1) ?? ''),
      version: match.group(2) ?? '',
    );
  }

  static Future<void> _removeExistingPythonPackageInstall(
    Directory sitePackages,
    String packageName,
  ) async {
    final normalized = _normalizeDependencyName(packageName);
    final underscore = normalized.replaceAll('-', '_');
    if (!await sitePackages.exists()) return;

    final payloadNames = <String>{
      normalized,
      underscore,
      '$normalized.py',
      '$underscore.py',
      '$normalized.libs',
      '$underscore.libs',
    };
    final metadataDirs = <Directory>[];

    await for (final entity in sitePackages.list(recursive: false)) {
      final name = path.basename(entity.path).toLowerCase();
      if (entity is Directory &&
          (name.endsWith('.dist-info') || name.endsWith('.egg-info'))) {
        final parsed = _parsePythonDistInfoName(name);
        final metadata = await _readPythonPackageMetadata(entity);
        final actualName = _normalizeDependencyName(
          metadata['name'] ?? parsed?.name ?? '',
        );
        final prefixMatches =
            name.startsWith('$normalized-') || name.startsWith('$underscore-');
        if (actualName == normalized || prefixMatches) {
          metadataDirs.add(entity);
          final record = File(path.join(entity.path, 'RECORD'));
          if (await record.exists()) {
            try {
              for (final line in await record.readAsLines()) {
                final rawPath = line.split(',').first.trim();
                if (rawPath.isEmpty || rawPath.contains('..')) continue;
                final firstSegment = rawPath.split('/').first.trim();
                if (_pythonWheelPayloadNameLooksSafe(firstSegment)) {
                  payloadNames.add(firstSegment);
                }
              }
            } catch (_) {}
          }
        }
      }
    }

    for (final name in payloadNames) {
      if (!_pythonWheelPayloadNameLooksSafe(name)) continue;
      final targetPath = path.normalize(path.join(sitePackages.path, name));
      if (!path.isWithin(sitePackages.path, targetPath)) continue;
      final file = File(targetPath);
      final dir = Directory(targetPath);
      try {
        if (await file.exists()) {
          await file.delete();
        } else if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (error) {
        debugPrint(
          '[DEPS] failed removing stale Python package payload '
          '$packageName path=$targetPath error=$error',
        );
      }
    }

    for (final dir in metadataDirs) {
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  static bool _pythonWheelPayloadNameLooksSafe(String name) {
    if (name.isEmpty || name == '.' || name == '..') return false;
    if (name.contains('/') || name.contains(r'\')) return false;
    if (name == 'bin' || name == '__pycache__') return false;
    return RegExp(r'^[A-Za-z0-9_.+-]+$').hasMatch(name);
  }

  static Future<void> _mergeDirectory(
      Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final targetPath = path.join(target.path, path.basename(entity.path));
      if (entity is Directory) {
        final targetDir = Directory(targetPath);
        if (await targetDir.exists()) {
          await _mergeDirectory(entity, targetDir);
        } else {
          await entity.rename(targetPath);
        }
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        if (await File(targetPath).exists()) {
          await File(targetPath).delete();
        }
        await entity.rename(targetPath);
      }
    }
  }

  static Future<bool> _pythonPackageMarkerPresent(
    _SkillProvisioningLayout layout,
    String packageName,
  ) async {
    final normalized = _normalizeDependencyName(packageName);
    final installed = await _scanInstalledPythonPackageVersions(layout);
    return installed.containsKey(normalized);
  }

  static Future<_DependencyPackReceipt?> _readPythonWheelReceipt(
    _SkillProvisioningLayout layout,
    String packageName,
  ) async {
    final file = File(path.join(
      layout.pythonWheelReceiptDir.path,
      '${_normalizeDependencyName(packageName)}.json',
    ));
    final json = await _readJson(file);
    return json == null ? null : _DependencyPackReceipt.fromJson(json);
  }

  static Future<void> _writePythonWheelReceipt(
    _SkillProvisioningLayout layout,
    _PythonRequirementRequest request,
    _PythonWheelCandidate candidate, {
    required String sha256,
    required String metadataVersion,
    required bool compatibilityOverride,
  }) async {
    await layout.pythonWheelReceiptDir.create(recursive: true);
    await File(path.join(
      layout.pythonWheelReceiptDir.path,
      '${candidate.name}.json',
    )).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({
            'id': candidate.name,
            'version': metadataVersion,
            'sha256': sha256,
            'source': 'wheel',
            'url': candidate.url.toString(),
            'fileName': candidate.fileName,
            'python': _pythonRuntimeVersion,
            'requestedRequirement': request.raw,
            'compatibilityOverride': compatibilityOverride,
            'smokePassed': true,
            'installedAt': DateTime.now().toIso8601String(),
          })}\n',
      flush: true,
    );
  }

  static Future<_PythonSmokeResult> _smokePythonImport(
    _SkillProvisioningLayout layout,
    String packageName,
  ) async {
    if (!Platform.isAndroid) {
      return const _PythonSmokeResult(ok: true, stdout: '', stderr: '');
    }
    final module = packageName.replaceAll('-', '_');

    Future<_PythonSmokeResult> runImport(String importStatement) async {
      final result = await NativeBridge.runNativePython({
        'args': ['-c', importStatement],
        'cwd': layout.nativeStateRoot,
        'env': {
          'HOME': layout.nativeStateRoot,
          'OPENCLAW_NATIVE_PYTHON_HOME': layout.nativePythonRoot.path,
          'OPENCLAW_NATIVE_PYTHON_SITE_PACKAGES':
              layout.nativePythonSitePackagesDir.path,
        },
        'pythonPaths': [layout.nativePythonSitePackagesDir.path],
      });
      return _PythonSmokeResult(
        ok: result['ok'] == true || result['exitCode'] == 0,
        stdout: result['stdout']?.toString() ?? '',
        stderr: result['stderr']?.toString() ?? '',
      );
    }

    final topLevel = await runImport('import $module');
    if (!topLevel.ok) return topLevel;

    for (final submodule in _pythonSubmoduleSmokeImports(packageName)) {
      final nested = await runImport('import $submodule');
      if (!nested.ok) return nested;
    }
    return topLevel;
  }

  /// Chaquopy fails on PEP-562 lazy submodule loads (e.g. `from dateutil
  /// import parser`). It also fails when pandas C extensions are compiled
  /// against an incompatible CPython ABI (circular-import-like AttributeError
  /// on _pandas_datetime_CAPI). Pin pandas to <2.2 for Chaquopy 13.x.
  static List<String> _pythonSubmoduleSmokeImports(String packageName) {
    switch (packageName) {
      case 'python-dateutil':
      case 'dateutil':
        return const ['dateutil.parser'];
      case 'pandas':
        // Chaquopy loads pandas C extensions lazily; verify the core API
        // (DataFrame, Series) resolves without circular-import crashes.
        return const ['pandas'];
      case 'yfinance':
        return const ['yfinance'];
      default:
        return const [];
    }
  }

  static bool _pythonRequirementSatisfied(
    String installedVersion,
    String requirement,
  ) {
    final constraints = _pythonVersionConstraints(requirement);
    if (constraints.isEmpty) return true;
    if (installedVersion.trim().isEmpty) return false;
    for (final constraint in constraints) {
      final operator = constraint.operator;
      final required = constraint.version;
      if (operator == '==') {
        if (required.endsWith('.*')) {
          final prefix = required.substring(0, required.length - 2);
          if (!installedVersion.startsWith(prefix)) return false;
        } else if (_compareVersions(installedVersion, required) != 0) {
          return false;
        }
      } else if (operator == '!=') {
        if (_compareVersions(installedVersion, required) == 0) return false;
      } else if (operator == '>=') {
        if (_compareVersions(installedVersion, required) < 0) return false;
      } else if (operator == '>') {
        if (_compareVersions(installedVersion, required) <= 0) return false;
      } else if (operator == '<=') {
        if (_compareVersions(installedVersion, required) > 0) return false;
      } else if (operator == '<') {
        if (_compareVersions(installedVersion, required) >= 0) return false;
      } else if (operator == '~=') {
        if (_compareVersions(installedVersion, required) < 0) return false;
        final upper = _compatibleReleaseUpperBound(required);
        if (upper != null && _compareVersions(installedVersion, upper) >= 0) {
          return false;
        }
      }
    }
    return true;
  }

  static List<_PythonVersionConstraint> _pythonVersionConstraints(
    String requirement,
  ) {
    final markerIndex = requirement.indexOf(';');
    final withoutMarker =
        markerIndex >= 0 ? requirement.substring(0, markerIndex) : requirement;
    final constraints = <_PythonVersionConstraint>[];
    final pattern = RegExp(r'(===|==|~=|!=|<=|>=|<|>)\s*([A-Za-z0-9.!+_*+-]+)');
    for (final match in pattern.allMatches(withoutMarker)) {
      final operator = match.group(1);
      final version = match.group(2);
      if (operator != null && version != null && version.isNotEmpty) {
        constraints.add(_PythonVersionConstraint(operator, version));
      }
    }
    return constraints;
  }

  static String? _compatibleReleaseUpperBound(String version) {
    final parts = version
        .split('.')
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? ''))
        .toList();
    if (parts.isEmpty || parts.any((part) => part == null)) return null;
    final numbers = parts.cast<int>().toList();
    final bumpIndex = numbers.length > 2 ? numbers.length - 2 : 0;
    numbers[bumpIndex] += 1;
    for (var i = bumpIndex + 1; i < numbers.length; i++) {
      numbers[i] = 0;
    }
    return numbers.join('.');
  }

  static int _compareVersions(String left, String right) {
    final a = _versionParts(left);
    final b = _versionParts(right);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final leftPart = i < a.length ? a[i] : 0;
      final rightPart = i < b.length ? b[i] : 0;
      if (leftPart != rightPart) return leftPart.compareTo(rightPart);
    }
    return 0;
  }

  static List<int> _versionParts(String version) {
    final release = version
        .split(RegExp(r'[+!-]'))
        .first
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    return release.isEmpty ? const [0] : release;
  }

  static Future<void> _installApkProvidedPack(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
    SkillExecutionMatrixEntry entry,
  ) async {
    if (pack.providesRuntimes.contains('python')) {
      await _resetPythonEnvironmentIfRuntimeChanged(layout, pack);
      await _writePythonBridgeMarker(layout, pack);
      await _writePythonCommandShims(layout.nativePythonBinDir);
      await _writePythonCommandShims(layout.nativeManagedBinDir);
      for (final skillDir in layout.nativeSkillDirs(entry.skillId)) {
        if (await skillDir.exists()) {
          await _writePythonCommandShims(
            Directory(path.join(skillDir.path, '.venv', 'bin')),
          );
        }
      }
    }
    for (final bin
        in pack.providesBins.where((bin) => !_isPythonCommandBin(bin))) {
      final copied = await _copyBundledNativeBinary(layout, bin);
      if (!copied) {
        throw StateError(
          'APK-provided dependency pack ${pack.id} is missing bundled binary $bin.',
        );
      }
    }
    if (pack.id == _androidTerminalPackId) {
      await _copyBundledTerminalLibraries(layout);
    }
    for (final package in pack.providesPythonPackages) {
      if (pack.id == _androidPythonDebugPackId) {
        final candidate = await _findBundledPythonWheelCandidate(
          layout,
          package,
          requiredVersion: _androidPythonDebugVersion,
        );
        if (candidate == null) {
          throw StateError(
            'APK-provided dependency pack ${pack.id} is missing bundled wheel for $package.',
          );
        }
        final install = await _downloadAndInstallPythonWheel(
          layout,
          _PythonRequirementRequest(
            name: package,
            raw: '$package==${candidate.version}',
            root: true,
            rootPackage: package,
          ),
          candidate,
        );
        if (!install.ok) {
          throw StateError(install.action.message);
        }
      } else {
        await _writePythonPackageMarker(
          layout.nativePythonSitePackagesDir,
          package,
          pack.version,
        );
      }
    }
  }

  static Future<void> _resetPythonEnvironmentIfRuntimeChanged(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    final marker = await _readJson(layout.nativePythonBridgeMarker);
    final current = marker?['python']?.toString();
    final currentVersion = marker?['version']?.toString();
    if (current == _pythonRuntimeVersion && currentVersion == pack.version) {
      return;
    }
    for (final target in [
      layout.nativePythonSitePackagesDir,
      layout.pythonWheelReceiptDir,
    ]) {
      try {
        if (await target.exists()) {
          await target.delete(recursive: true);
        }
      } catch (error) {
        debugPrint(
          '[DEPS] failed clearing stale Python $current environment '
          '${target.path}: $error',
        );
      }
    }
    await layout.nativePythonSitePackagesDir.create(recursive: true);
    await layout.pythonWheelReceiptDir.create(recursive: true);
    debugPrint(
      '[DEPS] cleared stale Native Python environment '
      'from ${current ?? 'unknown'}:${currentVersion ?? 'unknown'} '
      'to $_pythonRuntimeVersion:${pack.version}',
    );
  }

  static Future<void> _writePythonBridgeMarker(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    await layout.nativePythonBridgeMarker.parent.create(recursive: true);
    await layout.nativePythonBridgeMarker.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({
            'runtime': 'chaquopy',
            'python': _pythonRuntimeVersion,
            'pack': pack.id,
            'version': pack.version,
            'runner': 'http://127.0.0.1:8765/api/python/exec',
            'installedAt': DateTime.now().toIso8601String(),
          })}\n',
      flush: true,
    );
  }

  static Future<void> _writePythonCommandShims(Directory binDir) async {
    await binDir.create(recursive: true);
    for (final name in const ['python', 'python3', 'pip', 'pip3']) {
      final file = File(path.join(binDir.path, name));
      await file.writeAsString(
        '#!/system/bin/sh\n'
        'echo "OpenClaw Native Python is executed through the Gateway bridge; direct shell execution is not supported." >&2\n'
        'exit 126\n',
        flush: true,
      );
      if (!Platform.isWindows) {
        try {
          await Process.run('chmod', ['755', file.path]);
        } catch (_) {}
      }
    }
  }

  static Future<void> _writePythonPackageMarker(
    Directory sitePackages,
    String package,
    String version,
  ) async {
    final normalized = _normalizeDependencyName(package);
    final dir =
        Directory(path.join(sitePackages.path, '$normalized.dist-info'));
    await dir.create(recursive: true);
    await File(path.join(dir.path, 'METADATA')).writeAsString(
      'Name: $normalized\nVersion: $version\nInstaller: openclaw-native-deps\n',
      flush: true,
    );
  }

  static Future<void> _downloadAndExtractPack(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    final url = pack.url;
    if (url == null || url.isEmpty) {
      throw StateError('Pack ${pack.id} does not include a download URL.');
    }
    await layout.dependencyTmpDir.create(recursive: true);
    final bytes = await _readDependencyPackBytes(url);
    if (pack.maxBytes != null && bytes.length > pack.maxBytes!) {
      throw StateError('Pack ${pack.id} exceeds maxBytes=${pack.maxBytes}.');
    }
    final digest = crypto.sha256.convert(bytes).toString();
    if (pack.sha256.isNotEmpty && digest.toLowerCase() != pack.sha256) {
      throw StateError('SHA256 mismatch for ${pack.id}.');
    }

    final stage = Directory(path.join(
      layout.dependencyTmpDir.path,
      '${pack.id}-${DateTime.now().microsecondsSinceEpoch}',
    ));
    await stage.create(recursive: true);
    try {
      final archive = _decodeDependencyArchive(pack, bytes);
      for (final file in archive.files) {
        final target = File(path.join(stage.path, file.name));
        final normalizedTarget = path.normalize(target.path);
        if (!path.isWithin(stage.path, normalizedTarget) &&
            path.normalize(stage.path) != normalizedTarget) {
          throw StateError('Unsafe archive path: ${file.name}');
        }
        if (file.isFile) {
          await target.parent.create(recursive: true);
          await target.writeAsBytes(file.content as List<int>, flush: true);
        } else {
          await Directory(target.path).create(recursive: true);
        }
      }

      final installDir = layout.resolveInstallPath(pack.installPath);
      if (path.equals(
            path.normalize(installDir.path),
            path.normalize(layout.nativePythonSitePackagesDir.path),
          ) ||
          path.equals(
            path.normalize(installDir.path),
            path.normalize(layout.nativeManagedBinDir.path),
          )) {
        await _mergeDirectory(stage, installDir);
      } else {
        if (await installDir.exists()) {
          await installDir.delete(recursive: true);
        }
        await installDir.parent.create(recursive: true);
        await stage.rename(installDir.path);
      }
    } finally {
      if (await stage.exists()) {
        try {
          await stage.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  static Future<List<int>> _readDependencyPackBytes(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme == 'file') {
      return File.fromUri(uri).readAsBytes();
    }
    final response = await http.get(uri).timeout(const Duration(minutes: 4));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HTTP ${response.statusCode} while downloading $url');
    }
    return response.bodyBytes;
  }

  static Future<List<int>> _readPythonWheelCandidateBytes(
    _PythonWheelCandidate candidate,
  ) async {
    if (candidate.url.scheme == 'file') {
      if (candidate.indexHost != 'apk') {
        throw StateError(
          'Local Python wheel candidates are only allowed from APK assets.',
        );
      }
      return File.fromUri(candidate.url).readAsBytes();
    }
    final response = await http.get(candidate.url).timeout(
          const Duration(minutes: 4),
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'HTTP ${response.statusCode} while downloading ${candidate.url}',
      );
    }
    return response.bodyBytes;
  }

  static Archive _decodeDependencyArchive(
    _DependencyPack pack,
    List<int> bytes,
  ) {
    final lower = (pack.archiveType ?? pack.url ?? '').toLowerCase();
    if (lower.endsWith('.zip') || lower == 'zip') {
      return ZipDecoder().decodeBytes(bytes);
    }
    if (lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz') ||
        lower == 'tar.gz' ||
        lower == 'tgz') {
      return TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    }
    throw StateError('Unsupported dependency archive type for ${pack.id}.');
  }

  static Future<void> _applyDependencyPackFileModes(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    if (Platform.isWindows) return;
    final installDir = layout.resolveInstallPath(pack.installPath);
    for (final file in pack.files.where((file) => file.executable)) {
      final target = _dependencyPackInstalledFile(layout, pack, file.pathValue);
      if (target == null || !await target.exists()) continue;
      try {
        await Process.run('chmod', ['755', target.path]);
      } catch (error) {
        debugPrint(
          '[DEPS] failed chmod executable pack=${pack.id} '
          'file=${path.relative(target.path, from: installDir.path)}: $error',
        );
      }
    }
  }

  static Future<void> _rollbackDependencyPackInstall(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    final installDir = layout.resolveInstallPath(pack.installPath);
    final installPath = path.normalize(installDir.path);
    final sharedInstallPath = [
      layout.nativeManagedBinDir.path,
      layout.nativePythonSitePackagesDir.path,
    ].map(path.normalize).any((shared) => path.equals(shared, installPath));

    if (pack.rollbackStrategy == 'remove_install_path' &&
        !sharedInstallPath &&
        await installDir.exists()) {
      await installDir.delete(recursive: true);
      return;
    }

    for (final file in pack.files) {
      final target = _dependencyPackInstalledFile(layout, pack, file.pathValue);
      if (target == null) continue;
      try {
        if (await target.exists()) {
          await target.delete();
        }
      } catch (error) {
        debugPrint(
          '[DEPS] failed rollback pack=${pack.id} file=${target.path}: $error',
        );
      }
    }
  }

  static File? _dependencyPackInstalledFile(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
    String relativePath,
  ) {
    final installDir = layout.resolveInstallPath(pack.installPath);
    final normalizedInstallDir = path.normalize(installDir.path);
    final target = File(path.join(installDir.path, relativePath));
    final normalizedTarget = path.normalize(target.path);
    if (!path.isWithin(normalizedInstallDir, normalizedTarget) &&
        !path.equals(normalizedInstallDir, normalizedTarget)) {
      return null;
    }
    return target;
  }

  static Future<_PythonSmokeResult> _runDependencyPackSmoke(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    if (pack.smokeImports.isNotEmpty) {
      if (!Platform.isAndroid) {
        return const _PythonSmokeResult(ok: true, stdout: '', stderr: '');
      }
      final code = pack.smokeImports.map((name) => 'import $name').join('; ');
      final result = await NativeBridge.runNativePython({
        'args': ['-c', code],
        'cwd': layout.nativeStateRoot,
        'env': {
          'HOME': layout.nativeStateRoot,
          'OPENCLAW_NATIVE_PYTHON_HOME': layout.nativePythonRoot.path,
          'OPENCLAW_NATIVE_PYTHON_SITE_PACKAGES':
              layout.nativePythonSitePackagesDir.path,
        },
        'pythonPaths': [layout.nativePythonSitePackagesDir.path],
      });
      return _PythonSmokeResult(
        ok: result['ok'] == true || result['exitCode'] == 0,
        stdout: result['stdout']?.toString() ?? '',
        stderr: result['stderr']?.toString() ?? '',
      );
    }

    final command = pack.smokeCommand;
    if (command == null) {
      return const _PythonSmokeResult(ok: true, stdout: '', stderr: '');
    }
    if (_isPythonCommandBin(command.command) &&
        (pack.providesRuntimes.contains('python') ||
            pack.providesPythonPackages.isNotEmpty)) {
      return const _PythonSmokeResult(ok: true, stdout: '', stderr: '');
    }

    final normalizedCommand = _normalizeBinRequirement(command.command);
    if (!_smokeCommandLooksSafe(command.command)) {
      return _PythonSmokeResult(
        ok: false,
        stdout: '',
        stderr: 'Unsafe dependency pack smoke command: ${command.command}',
      );
    }
    if (!pack.providesBins.contains(normalizedCommand)) {
      return _PythonSmokeResult(
        ok: false,
        stdout: '',
        stderr: 'Dependency pack ${pack.id} smoke command "$normalizedCommand" '
            'is not advertised in provides.bins.',
      );
    }
    final executable =
        await _findManagedNativeBinary(layout, normalizedCommand);
    if (executable == null) {
      return _PythonSmokeResult(
        ok: false,
        stdout: '',
        stderr: 'Dependency pack ${pack.id} smoke command "$normalizedCommand" '
            'is missing from managed Native bin.',
      );
    }

    await Directory(layout.nativeStateRoot).create(recursive: true);
    final env = {
      'HOME': layout.nativeStateRoot,
      'OPENCLAW_HOME': layout.nativeStateRoot,
      'OPENCLAW_NATIVE_BIN': layout.nativeManagedBinDir.path,
      'OPENCLAW_NATIVE_LIB': layout.nativeManagedLibDir.path,
      'LD_LIBRARY_PATH': [
        layout.nativeManagedLibDir.path,
        Platform.environment['LD_LIBRARY_PATH'] ?? '',
      ].where((item) => item.isNotEmpty).join(Platform.isWindows ? ';' : ':'),
      'PATH': [
        layout.nativeManagedBinDir.path,
        Platform.environment['PATH'] ?? '',
      ].where((item) => item.isNotEmpty).join(Platform.isWindows ? ';' : ':'),
    };
    try {
      final process = await Process.start(
        executable.path,
        command.args,
        workingDirectory: layout.nativeStateRoot,
        environment: env,
        runInShell: false,
      );
      final stdoutFuture = _readBoundedProcessStream(process.stdout);
      final stderrFuture = _readBoundedProcessStream(process.stderr);
      var timedOut = false;
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          timedOut = true;
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      return _PythonSmokeResult(
        ok: !timedOut && exitCode == 0,
        stdout: stdout,
        stderr: timedOut
            ? 'Dependency pack ${pack.id} smoke command timed out.'
            : stderr,
      );
    } catch (error) {
      return _PythonSmokeResult(
        ok: false,
        stdout: '',
        stderr: 'Dependency pack ${pack.id} smoke command failed to start: '
            '$error',
      );
    }
  }

  static Future<String> _readBoundedProcessStream(Stream<List<int>> stream) {
    final completer = Completer<String>();
    const maxChars = 4096;
    final buffer = StringBuffer();
    late final StreamSubscription<String> subscription;
    subscription = stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((chunk) {
      if (buffer.length >= maxChars) return;
      final remaining = maxChars - buffer.length;
      buffer.write(
          chunk.length > remaining ? chunk.substring(0, remaining) : chunk);
    }, onError: (Object error) {
      if (!completer.isCompleted) completer.complete(buffer.toString());
    }, onDone: () {
      subscription.cancel();
      if (!completer.isCompleted) completer.complete(buffer.toString());
    }, cancelOnError: true);
    return completer.future;
  }

  static bool _smokeCommandLooksSafe(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty || trimmed.contains('/') || trimmed.contains(r'\')) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9._+-]+$').hasMatch(trimmed);
  }

  static Future<bool> _dependencyPackMarkersPresent(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    if (pack.providesRuntimes.contains('python')) {
      if (!await _pythonBridgeMarkerMatchesPack(layout, pack)) {
        return false;
      }
    }
    for (final bin in pack.providesBins) {
      if (!await _managedNativeBinaryPresent(layout, bin)) return false;
    }
    for (final package in pack.providesPythonPackages) {
      if (!await _pythonPackageMarkerPresent(layout, package)) return false;
    }
    return true;
  }

  static Future<bool> _pythonCoreInstallRequired(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    if (!pack.providesRuntimes.contains('python')) return false;
    if (!await _pythonBridgeMarkerMatchesPack(layout, pack)) return true;
    final receipt = await _readDependencyReceipt(layout, pack.id);
    if (receipt == null ||
        receipt.version != pack.version ||
        receipt.sha256 != pack.sha256) {
      return true;
    }
    return !await _dependencyPackMarkersPresent(layout, pack);
  }

  static Future<bool> _pythonBridgeMarkerMatchesPack(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    final marker = await _readJson(layout.nativePythonBridgeMarker);
    return marker?['python']?.toString() == _pythonRuntimeVersion &&
        marker?['pack']?.toString() == pack.id &&
        marker?['version']?.toString() == pack.version;
  }

  static Future<Set<String>> _satisfiedPythonPackagesForPack(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
    Map<String, String> requiredPythonRequirements,
  ) async {
    if (pack.providesPythonPackages.isEmpty) return const <String>{};
    final installed = await _scanInstalledPythonPackageVersions(layout);
    final satisfied = <String>{};
    for (final package in pack.providesPythonPackages) {
      final requirement = requiredPythonRequirements[package] ?? package;
      final version = installed[package];
      if (version != null &&
          _pythonRequirementSatisfied(version, requirement)) {
        satisfied.add(package);
      }
    }
    return satisfied;
  }

  static Future<_DependencyPackReceipt?> _readDependencyReceipt(
    _SkillProvisioningLayout layout,
    String id,
  ) async {
    final file = File(path.join(layout.dependencyReceiptDir.path, '$id.json'));
    final json = await _readJson(file);
    return json == null ? null : _DependencyPackReceipt.fromJson(json);
  }

  static Future<void> _writeDependencyReceipt(
    _SkillProvisioningLayout layout,
    _DependencyPack pack,
  ) async {
    await layout.dependencyReceiptDir.create(recursive: true);
    await File(path.join(layout.dependencyReceiptDir.path, '${pack.id}.json'))
        .writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({
            'id': pack.id,
            'version': pack.version,
            'sha256': pack.sha256,
            'source': pack.source.name,
            'provides': {
              'runtimes': pack.providesRuntimes.toList()..sort(),
              'bins': pack.providesBins.toList()..sort(),
              'pythonPackages': pack.providesPythonPackages.toList()..sort(),
            },
            'installedAt': DateTime.now().toIso8601String(),
          })}\n',
      flush: true,
    );
  }

  static String _normalizeDependencyName(String value) =>
      value.trim().toLowerCase().replaceAll('_', '-');

  static String _normalizeBinRequirement(String value) =>
      _normalizeDependencyName(path.basename(value));

  static String _normalizeRuntimeRequirement(String value) {
    final normalized = _normalizeDependencyName(path.basename(value));
    if (_isPythonCommandBin(normalized)) return 'python';
    return normalized;
  }

  static bool _isPythonCommandBin(String value) {
    final normalized = _normalizeDependencyName(path.basename(value));
    return normalized == 'python' ||
        normalized == 'python3' ||
        normalized == 'pip' ||
        normalized == 'pip3';
  }

  static bool _requirementAllowsPrerelease(String requirement) {
    return _pythonVersionConstraints(
      requirement,
    ).any((constraint) => _isPrereleaseVersion(constraint.version));
  }

  static bool _hasExactPythonVersionConstraint(String requirement) {
    return _pythonVersionConstraints(requirement).any((constraint) {
      if (constraint.operator != '==' && constraint.operator != '===') {
        return false;
      }
      return !constraint.version.endsWith('.*');
    });
  }

  static bool _isPrereleaseVersion(String version) {
    return RegExp(
      r'(?:\d(?:a|b|rc)\d*)|(?:[._-](?:alpha|beta|pre|preview|dev)\d*)',
      caseSensitive: false,
    ).hasMatch(version);
  }

  static Future<_DependencyPack?> _apkProvidedCliCorePack(
    _SkillProvisioningLayout layout,
  ) async {
    final providedBins = <String>{};
    for (final bin in _androidCliCorePackBins) {
      if (await _findBundledNativeBinary(layout, bin) != null) {
        providedBins.add(bin);
      }
    }
    if (providedBins.isEmpty) return null;
    return _DependencyPack.apk(
      id: _androidCliCorePackId,
      version: _androidCliCorePackVersion,
      providesBins: providedBins,
    );
  }

  static Future<_DependencyPack?> _apkProvidedVisionMediaPack(
    _SkillProvisioningLayout layout,
  ) async {
    final providedBins = <String>{};
    for (final bin in _androidVisionMediaPackBins) {
      if (await _findBundledNativeBinary(layout, bin) != null) {
        providedBins.add(bin);
      }
    }
    if (providedBins.isEmpty) return null;
    return _DependencyPack.apk(
      id: _androidVisionMediaPackId,
      version: _androidVisionMediaPackVersion,
      providesBins: providedBins,
    );
  }

  static Future<_DependencyPack?> _apkProvidedAudioRuntimePack(
    _SkillProvisioningLayout layout,
  ) async {
    final providedBins = <String>{};
    for (final bin in _androidAudioRuntimePackBins) {
      if (await _findBundledNativeBinary(layout, bin) != null) {
        providedBins.add(bin);
      }
    }
    if (providedBins.isEmpty) return null;
    return _DependencyPack.apk(
      id: _androidAudioRuntimePackId,
      version: _androidAudioRuntimePackVersion,
      providesBins: providedBins,
    );
  }

  static Future<_DependencyPack?> _apkProvidedPythonDebugPack(
    _SkillProvisioningLayout layout,
  ) async {
    final providedPackages = <String>{};
    for (final package in _androidPythonDebugPackages) {
      final candidate = await _findBundledPythonWheelCandidate(
        layout,
        package,
        requiredVersion: _androidPythonDebugVersion,
      );
      if (candidate != null) {
        providedPackages.add(package);
      }
    }
    if (providedPackages.isEmpty) return null;
    return _DependencyPack.apk(
      id: _androidPythonDebugPackId,
      version: _androidPythonDebugPackVersion,
      providesPythonPackages: providedPackages,
      smokeImports: const ['debugpy'],
    );
  }

  static Future<_DependencyPack?> _apkProvidedTerminalPack(
    _SkillProvisioningLayout layout,
  ) async {
    final providedBins = <String>{};
    for (final bin in _androidTerminalPackBins) {
      if (await _findBundledNativeBinary(layout, bin) != null) {
        providedBins.add(bin);
      }
    }
    if (providedBins.isEmpty) return null;
    return _DependencyPack.apk(
      id: _androidTerminalPackId,
      version: _androidTerminalPackVersion,
      providesBins: providedBins,
    );
  }

  static Future<_DependencyPack?> _apkProvidedWhisperRuntimePack(
    _SkillProvisioningLayout layout,
  ) async {
    final providedBins = <String>{};
    for (final bin in _androidWhisperRuntimePackBins) {
      if (await _findBundledNativeBinary(layout, bin) != null) {
        providedBins.add(bin);
      }
    }
    if (providedBins.isEmpty) return null;
    return _DependencyPack.apk(
      id: _androidWhisperRuntimePackId,
      version: _androidWhisperRuntimePackVersion,
      providesBins: providedBins,
    );
  }

  static Future<_DependencyPack?> _apkProvidedTtsRuntimePack(
    _SkillProvisioningLayout layout,
  ) async {
    final providedBins = <String>{};
    for (final bin in _androidTtsRuntimePackBins) {
      if (await _findBundledNativeBinary(layout, bin) != null) {
        providedBins.add(bin);
      }
    }
    if (providedBins.isEmpty) return null;
    return _DependencyPack.apk(
      id: _androidTtsRuntimePackId,
      version: _androidTtsRuntimePackVersion,
      providesBins: providedBins,
    );
  }

  static Future<_DependencyPack?> _apkProvidedNodeExecutablePack(
    _SkillProvisioningLayout layout,
  ) async {
    final providedBins = <String>{};
    for (final bin in _androidNodeExecutablePackBins) {
      if (await _findBundledNativeBinary(layout, bin) != null) {
        providedBins.add(bin);
      }
    }
    if (providedBins.isEmpty) return null;
    return _DependencyPack.apk(
      id: _androidNodeExecutablePackId,
      version: _androidNodeExecutablePackVersion,
      providesBins: providedBins,
    );
  }

  static Future<_DependencyPack?> _apkProvidedAgentCliPack(
    _SkillProvisioningLayout layout,
  ) async {
    final providedBins = <String>{};
    for (final bin in _androidAgentCliPackBins) {
      if (await _findBundledNativeBinary(layout, bin) != null) {
        providedBins.add(bin);
      }
    }
    if (providedBins.isEmpty) return null;
    return _DependencyPack.apk(
      id: _androidAgentCliPackId,
      version: _androidAgentCliPackVersion,
      providesBins: providedBins,
    );
  }

  static Future<_PythonWheelCandidate?> _findBundledPythonWheelCandidate(
    _SkillProvisioningLayout layout,
    String packageName, {
    String? requiredVersion,
  }) async {
    final normalizedPackage = _normalizeDependencyName(packageName);
    final candidates = <_PythonWheelCandidate>[];
    for (final root in layout.bundledPythonDebugWheelRoots) {
      try {
        if (!await root.exists()) continue;
        await for (final entity in root.list(recursive: false)) {
          if (entity is! File) continue;
          final fileName = path.basename(entity.path);
          if (!_pythonWheelAssetNameLooksSafe(fileName)) continue;
          final wheel = _parseWheelFileName(fileName);
          if (wheel == null) continue;
          if (wheel.name != normalizedPackage) continue;
          if (requiredVersion != null && wheel.version != requiredVersion) {
            continue;
          }
          if (!_wheelIsCompatible(wheel)) continue;
          final bytes = await entity.readAsBytes();
          candidates.add(_PythonWheelCandidate(
            name: wheel.name,
            version: wheel.version,
            fileName: fileName,
            url: Uri.file(entity.path),
            sha256: crypto.sha256.convert(bytes).toString(),
            indexHost: 'apk',
          ));
        }
      } catch (_) {}
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => _compareVersions(b.version, a.version));
    return candidates.first;
  }

  static bool _pythonWheelAssetNameLooksSafe(String fileName) {
    if (fileName.isEmpty || fileName.startsWith('.')) return false;
    if (!fileName.toLowerCase().endsWith('.whl')) return false;
    if (fileName.contains('..') ||
        fileName.contains('/') ||
        fileName.contains(r'\') ||
        fileName.contains(':')) {
      return false;
    }
    return true;
  }

  static Future<File?> _findBundledNativeBinary(
    _SkillProvisioningLayout layout,
    String bin,
  ) async {
    if (bin.trim().isEmpty || bin.contains('/') || bin.contains(r'\')) {
      return null;
    }
    final normalizedBin = _normalizeBinRequirement(bin);
    for (final root in layout.bundledBinaryRoots) {
      final candidate = File(path.join(root.path, normalizedBin));
      try {
        if (await candidate.exists()) return candidate;
      } catch (_) {}
    }
    return null;
  }

  static Future<bool> _copyBundledNativeBinary(
    _SkillProvisioningLayout layout,
    String bin,
  ) async {
    final normalizedBin = _normalizeBinRequirement(bin);
    final source = await _findBundledNativeBinary(layout, normalizedBin);
    if (source == null) return false;
    await layout.nativeManagedBinDir.create(recursive: true);
    final target =
        File(path.join(layout.nativeManagedBinDir.path, normalizedBin));
    await source.copy(target.path);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['755', target.path]);
      } catch (_) {}
    }
    return true;
  }

  static Future<int> _copyBundledTerminalLibraries(
    _SkillProvisioningLayout layout,
  ) async {
    await layout.nativeManagedLibDir.create(recursive: true);
    var copied = 0;
    for (final root in layout.bundledTerminalLibraryRoots) {
      try {
        if (!await root.exists()) continue;
        await for (final entity in root.list(recursive: false)) {
          if (entity is! File) continue;
          final name = path.basename(entity.path);
          if (!_terminalLibraryAssetNameLooksSafe(name)) continue;
          await entity.copy(path.join(layout.nativeManagedLibDir.path, name));
          copied++;
        }
      } catch (_) {}
    }
    return copied;
  }

  static bool _terminalLibraryAssetNameLooksSafe(String fileName) {
    if (fileName.isEmpty || fileName.startsWith('.')) return false;
    if (!fileName.startsWith('lib') || !fileName.contains('.so')) {
      return false;
    }
    if (fileName.contains('..') ||
        fileName.contains('/') ||
        fileName.contains(r'\') ||
        fileName.contains(':')) {
      return false;
    }
    return true;
  }

  static Future<bool> _managedNativeBinaryPresent(
    _SkillProvisioningLayout layout,
    String bin,
  ) async =>
      await _findManagedNativeBinary(layout, bin) != null;

  static Future<File?> _findManagedNativeBinary(
    _SkillProvisioningLayout layout,
    String bin,
  ) async {
    final normalizedBin = _normalizeBinRequirement(bin);
    final names = <String>[
      normalizedBin,
      if (Platform.isWindows) '$normalizedBin.exe',
      if (Platform.isWindows) '$normalizedBin.cmd',
      if (Platform.isWindows) '$normalizedBin.bat',
    ];
    final root = path.normalize(layout.nativeManagedBinDir.path);
    for (final name in names) {
      final candidate = File(path.join(root, name));
      final normalizedCandidate = path.normalize(candidate.path);
      if (!path.isWithin(root, normalizedCandidate) &&
          !path.equals(root, normalizedCandidate)) {
        continue;
      }
      if (await candidate.exists()) return candidate;
    }
    return null;
  }

  static bool _envKeyLooksSafe(String key) {
    return RegExp(r'^[A-Z][A-Z0-9_]{1,80}$').hasMatch(key);
  }

  static Future<void> _writeDotEnvValues(
    File file,
    Map<String, String> values,
  ) async {
    await file.parent.create(recursive: true);
    final lines =
        await file.exists() ? await file.readAsLines() : const <String>[];
    final pending = Map<String, String>.from(values);
    final updated = <String>[];
    for (final line in lines) {
      final match = RegExp(r'^\s*([A-Z][A-Z0-9_]{1,80})\s*=').firstMatch(line);
      final key = match?.group(1);
      if (key != null && pending.containsKey(key)) {
        updated.add('$key=${_formatDotEnvValue(pending.remove(key)!)}');
      } else {
        updated.add(line);
      }
    }
    for (final entry in pending.entries) {
      updated.add('${entry.key}=${_formatDotEnvValue(entry.value)}');
    }
    await file.writeAsString('${updated.join('\n')}\n', flush: true);
  }

  static String _formatDotEnvValue(String value) {
    if (value.isEmpty ||
        value.contains(RegExp(r'\s')) ||
        value.contains('#') ||
        value.contains('"') ||
        value.contains("'")) {
      return jsonEncode(value);
    }
    return value;
  }

  static Future<void> _writeConfigValue(
    File file,
    String key,
    dynamic value,
  ) async {
    final config = await _readJson(file) ?? <String, dynamic>{};
    _setNestedConfigValue(config, key, value);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(config)}\n',
      flush: true,
    );
  }

  static Future<Map<String, dynamic>?> _readJson(File file) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      debugPrint('[SkillProvisioning] config read failed ${file.path}: $error');
    }
    return null;
  }

  static void _setNestedConfigValue(
    Map<String, dynamic> config,
    String key,
    dynamic value,
  ) {
    final parts = key
        .split('.')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty ||
        parts.any((part) => !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(part))) {
      throw ArgumentError('Unsafe config key: $key');
    }
    Map<String, dynamic> current = config;
    for (final part in parts.take(parts.length - 1)) {
      final next = current[part];
      if (next is Map<String, dynamic>) {
        current = next;
      } else if (next is Map) {
        final converted = Map<String, dynamic>.from(next);
        current[part] = converted;
        current = converted;
      } else {
        final created = <String, dynamic>{};
        current[part] = created;
        current = created;
      }
    }
    current[parts.last] = value;
  }
}

class SkillProvisioningReport {
  final String filesDir;
  final String? skillId;
  final DateTime auditedAt;
  final DateTime generatedAt;
  final List<SkillProvisioningSkillResult> results;
  final bool changed;
  final bool reloadRecommended;

  const SkillProvisioningReport({
    required this.filesDir,
    required this.skillId,
    required this.auditedAt,
    required this.generatedAt,
    required this.results,
    required this.changed,
    required this.reloadRecommended,
  });

  Map<String, int> get summaryCounts {
    final counts = <String, int>{};
    for (final result in results) {
      counts.update(result.status.wireName, (value) => value + 1,
          ifAbsent: () => 1);
    }
    return counts;
  }

  int get blockedCount =>
      results.where((result) => result.status.isBlocking).length;

  String get compactLogLine {
    final counts = summaryCounts.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
    return '[SKILL-PROVISION] skills=${results.length} changed=$changed reloadRecommended=$reloadRecommended blocked=$blockedCount status=${counts.isEmpty ? 'none' : counts}';
  }

  String toPromptBlock({int maxSkills = 12}) {
    if (results.isEmpty) return '';
    final counts = summaryCounts.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    final lines = results
        .where((result) => result.status != SkillProvisioningStatus.ready)
        .take(maxSkills)
        .map((result) {
      final actions = result.actions
          .where((action) =>
              action.status != SkillProvisioningActionStatus.ready &&
              action.status != SkillProvisioningActionStatus.satisfied)
          .take(4)
          .map((action) => '${action.key}: ${action.status.wireName}')
          .join('; ');
      return '- ${result.skillId}: ${result.status.wireName}${actions.isEmpty ? '' : ' ($actions)'}';
    }).join('\n');

    return '''
Native skill provisioning:
- Counts: ${counts.isEmpty ? 'none' : counts}.
- Changed files: $changed; Gateway reload recommended: $reloadRecommended.
- PRoot is manual fallback only; Native never silently switches owners for blocked skills.
${lines.isEmpty ? '' : lines}
''';
  }

  Map<String, dynamic> toHealthJson({int maxResults = 20}) => {
        'counts': summaryCounts,
        'blockedCount': blockedCount,
        'changed': changed,
        'reloadRecommended': reloadRecommended,
        'generatedAt': generatedAt.toIso8601String(),
        'results':
            results.take(maxResults).map((result) => result.toJson()).toList(),
      };

  Map<String, dynamic> toJson() => {
        'filesDir': filesDir,
        if (skillId != null) 'skillId': skillId,
        'auditedAt': auditedAt.toIso8601String(),
        'generatedAt': generatedAt.toIso8601String(),
        'changed': changed,
        'reloadRecommended': reloadRecommended,
        'blockedCount': blockedCount,
        'summaryCounts': summaryCounts,
        'results': results.map((result) => result.toJson()).toList(),
      };
}

class SkillProvisioningSkillResult {
  final String skillId;
  final String readiness;
  final SkillProvisioningStatus status;
  final String? primaryGate;
  final SkillExecutionDescriptor? executionDescriptor;
  final List<SkillProvisioningAction> actions;
  final bool changed;
  final bool reloadRecommended;

  const SkillProvisioningSkillResult({
    required this.skillId,
    required this.readiness,
    required this.status,
    required this.primaryGate,
    this.executionDescriptor,
    required this.actions,
    required this.changed,
    required this.reloadRecommended,
  });

  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'readiness': readiness,
        'status': status.wireName,
        if (primaryGate != null) 'primaryGate': primaryGate,
        if (executionDescriptor != null)
          'executionDescriptor': executionDescriptor!.toJson(),
        'changed': changed,
        'reloadRecommended': reloadRecommended,
        'actions': actions.map((action) => action.toJson()).toList(),
      };
}

class SkillProvisioningAction {
  final SkillProvisioningActionType type;
  final String key;
  final SkillProvisioningActionStatus status;
  final String message;
  final bool changed;

  const SkillProvisioningAction({
    required this.type,
    required this.key,
    required this.status,
    required this.message,
    this.changed = false,
  });

  Map<String, dynamic> toJson() => {
        'type': type.wireName,
        'key': key,
        'status': status.wireName,
        'message': message,
        'changed': changed,
      };
}

enum SkillProvisioningStatus {
  ready,
  satisfied,
  needsUserConfig,
  missingDependency,
  missingBinary,
  missingPlugin,
  disabled,
  unsupportedNative,
  manualProotRequired,
}

extension SkillProvisioningStatusName on SkillProvisioningStatus {
  String get wireName {
    return switch (this) {
      SkillProvisioningStatus.ready => 'ready',
      SkillProvisioningStatus.satisfied => 'satisfied',
      SkillProvisioningStatus.needsUserConfig => 'needs_user_config',
      SkillProvisioningStatus.missingDependency => 'missing_dependency',
      SkillProvisioningStatus.missingBinary => 'missing_binary',
      SkillProvisioningStatus.missingPlugin => 'missing_plugin',
      SkillProvisioningStatus.disabled => 'disabled',
      SkillProvisioningStatus.unsupportedNative => 'unsupported_native',
      SkillProvisioningStatus.manualProotRequired => 'manual_proot_required',
    };
  }

  bool get isBlocking {
    return switch (this) {
      SkillProvisioningStatus.ready ||
      SkillProvisioningStatus.satisfied =>
        false,
      _ => true,
    };
  }
}

enum SkillProvisioningActionType {
  none,
  env,
  config,
  binary,
  dependencyPack,
  pythonPackage,
  nodePackage,
  plugin,
  manifest,
  runtime,
}

extension SkillProvisioningActionTypeName on SkillProvisioningActionType {
  String get wireName {
    return switch (this) {
      SkillProvisioningActionType.none => 'none',
      SkillProvisioningActionType.env => 'env',
      SkillProvisioningActionType.config => 'config',
      SkillProvisioningActionType.binary => 'binary',
      SkillProvisioningActionType.dependencyPack => 'dependency_pack',
      SkillProvisioningActionType.pythonPackage => 'python_package',
      SkillProvisioningActionType.nodePackage => 'node_package',
      SkillProvisioningActionType.plugin => 'plugin',
      SkillProvisioningActionType.manifest => 'manifest',
      SkillProvisioningActionType.runtime => 'runtime',
    };
  }
}

enum SkillProvisioningActionStatus {
  ready,
  satisfied,
  downloading,
  verified,
  installed,
  needsUserConfig,
  missingDependency,
  missingBinary,
  missingPack,
  failedVerification,
  failedSmoke,
  missingPlugin,
  disabled,
  unsupportedNative,
  manualProotRequired,
}

extension SkillProvisioningActionStatusName on SkillProvisioningActionStatus {
  String get wireName {
    return switch (this) {
      SkillProvisioningActionStatus.ready => 'ready',
      SkillProvisioningActionStatus.satisfied => 'satisfied',
      SkillProvisioningActionStatus.downloading => 'downloading',
      SkillProvisioningActionStatus.verified => 'verified',
      SkillProvisioningActionStatus.installed => 'installed',
      SkillProvisioningActionStatus.needsUserConfig => 'needs_user_config',
      SkillProvisioningActionStatus.missingDependency => 'missing_dependency',
      SkillProvisioningActionStatus.missingBinary => 'missing_binary',
      SkillProvisioningActionStatus.missingPack => 'missing_pack',
      SkillProvisioningActionStatus.failedVerification => 'failed_verification',
      SkillProvisioningActionStatus.failedSmoke => 'failed_smoke',
      SkillProvisioningActionStatus.missingPlugin => 'missing_plugin',
      SkillProvisioningActionStatus.disabled => 'disabled',
      SkillProvisioningActionStatus.unsupportedNative => 'unsupported_native',
      SkillProvisioningActionStatus.manualProotRequired =>
        'manual_proot_required',
    };
  }
}

class _SkillProvisioningLayout {
  final String filesDir;

  _SkillProvisioningLayout(this.filesDir);

  String get nativeStateRoot =>
      path.join(filesDir, 'native-node-embedded', 'native-home', '.openclaw');
  File get nativeEnvFile => File(path.join(nativeStateRoot, '.env'));
  File get nativeConfigFile =>
      File(path.join(nativeStateRoot, 'openclaw.json'));
  Directory get nativeManagedBinDir =>
      Directory(path.join(nativeStateRoot, 'bin'));
  Directory get nativeManagedLibDir =>
      Directory(path.join(nativeStateRoot, 'lib'));
  Directory get nativePythonRoot =>
      Directory(path.join(nativeStateRoot, 'runtimes', 'python'));
  Directory get nativePythonBinDir =>
      Directory(path.join(nativePythonRoot.path, 'bin'));
  Directory get nativePythonSitePackagesDir =>
      Directory(path.join(nativePythonRoot.path, 'site-packages'));
  File get nativePythonBridgeMarker =>
      File(path.join(nativePythonRoot.path, 'bridge.json'));
  Directory get dependencyRoot =>
      Directory(path.join(nativeStateRoot, 'dependencies'));
  Directory get dependencyReceiptDir =>
      Directory(path.join(dependencyRoot.path, 'receipts'));
  Directory get pythonWheelReceiptDir =>
      Directory(path.join(dependencyReceiptDir.path, 'python-wheels'));
  Directory get nodePackageReceiptDir =>
      Directory(path.join(dependencyReceiptDir.path, 'node-packages'));
  Directory get dependencyTmpDir =>
      Directory(path.join(dependencyRoot.path, 'tmp'));
  File get dependencyPackManifestFile =>
      File(path.join(dependencyRoot.path, 'dependency_packs.json'));
  File get nodePackageManifestFile =>
      File(path.join(dependencyRoot.path, 'node_packages.json'));
  Directory get nodeModulesDir =>
      Directory(path.join(nativeStateRoot, 'node_modules'));

  List<Directory> nativeSkillDirs(String skillId) => [
        Directory(path.join(nativeStateRoot, 'skills', skillId)),
        Directory(path.join(nativeStateRoot, 'workspace', 'skills', skillId)),
      ];

  Directory resolveInstallPath(String? installPath) {
    final relative = (installPath == null || installPath.trim().isEmpty)
        ? path.join('dependencies', 'packs')
        : installPath.trim();
    if (path.isAbsolute(relative) ||
        relative.contains('..') ||
        relative.contains(RegExp(r'^[A-Za-z]:'))) {
      throw ArgumentError('Unsafe dependency pack installPath: $installPath');
    }
    return Directory(path.normalize(path.join(nativeStateRoot, relative)));
  }

  Directory nodePackageInstallDir(String packageName) {
    final normalized = SkillProvisioningService._normalizeNodePackageName(
      packageName,
    );
    if (!SkillProvisioningService._nodePackageNameLooksSafe(normalized)) {
      throw ArgumentError('Unsafe node package name: $packageName');
    }
    if (normalized.startsWith('@')) {
      final parts = normalized.split('/');
      return Directory(path.join(nodeModulesDir.path, parts[0], parts[1]));
    }
    return Directory(path.join(nodeModulesDir.path, normalized));
  }

  List<Directory> get bundledBinaryRoots => [
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'provisioning',
          'bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'bundled-bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'full-openclaw',
          'provisioning',
          'bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'provisioning',
          'audio-runtime',
          'bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'bundled-audio-runtime',
          'bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'full-openclaw',
          'provisioning',
          'audio-runtime',
          'bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'provisioning',
          'terminal',
          'bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'bundled-terminal',
          'bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'full-openclaw',
          'provisioning',
          'terminal',
          'bin',
        )),
      ];
  List<Directory> get bundledTerminalLibraryRoots => [
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'provisioning',
          'terminal',
          'lib',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'bundled-terminal',
          'lib',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'full-openclaw',
          'provisioning',
          'terminal',
          'lib',
        )),
      ];
  List<Directory> get bundledPythonDebugWheelRoots => [
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'provisioning',
          'python-debug',
          'wheels',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'bundled-python-debug',
          'wheels',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'full-openclaw',
          'provisioning',
          'python-debug',
          'wheels',
        )),
      ];
}

enum _DependencyPackSource { apk, remote }

class _DependencyProvisioningResult {
  final List<SkillProvisioningAction> actions;
  final Set<String> satisfiedBins;
  final Set<String> satisfiedRuntimes;
  final Set<String> satisfiedPythonPackages;
  final bool changed;
  final bool reloadRecommended;

  const _DependencyProvisioningResult({
    required this.actions,
    required this.satisfiedBins,
    required this.satisfiedRuntimes,
    required this.satisfiedPythonPackages,
    required this.changed,
    required this.reloadRecommended,
  });
}

class _NodeProvisioningResult {
  final List<SkillProvisioningAction> actions;
  final Set<String> satisfiedNodePackages;
  final bool changed;
  final bool reloadRecommended;

  const _NodeProvisioningResult({
    required this.actions,
    required this.satisfiedNodePackages,
    required this.changed,
    required this.reloadRecommended,
  });
}

class _DependencyPackInstallResult {
  final bool ok;
  final SkillProvisioningAction action;

  const _DependencyPackInstallResult({
    required this.ok,
    required this.action,
  });
}

class _PythonSmokeResult {
  final bool ok;
  final String stdout;
  final String stderr;

  const _PythonSmokeResult({
    required this.ok,
    required this.stdout,
    required this.stderr,
  });
}

class _PythonRequirementRequest {
  final String name;
  final String raw;
  final bool root;
  final String? rootPackage;

  const _PythonRequirementRequest({
    required this.name,
    required this.raw,
    required this.root,
    this.rootPackage,
  });

  static _PythonRequirementRequest? fromRaw(
    String raw, {
    String? fallbackName,
    bool root = false,
    String? rootPackage,
  }) {
    var line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      final fallback = fallbackName?.trim();
      if (fallback == null || fallback.isEmpty) return null;
      return _PythonRequirementRequest(
        name: SkillProvisioningService._normalizeDependencyName(fallback),
        raw: fallback,
        root: root,
        rootPackage: rootPackage,
      );
    }
    final hash = line.indexOf('#');
    if (hash >= 0) line = line.substring(0, hash).trim();
    if (line.isEmpty ||
        line.startsWith('-') ||
        line.startsWith('git+') ||
        line.startsWith('http://') ||
        line.startsWith('https://') ||
        line == '.') {
      return null;
    }
    final match = RegExp(r'^([A-Za-z0-9_.-]+)(?:\[[^\]]+\])?').firstMatch(line);
    final name = match?.group(1);
    if (name == null || name.isEmpty) {
      final fallback = fallbackName?.trim();
      if (fallback == null || fallback.isEmpty) return null;
      return _PythonRequirementRequest(
        name: SkillProvisioningService._normalizeDependencyName(fallback),
        raw: line,
        root: root,
        rootPackage: rootPackage,
      );
    }
    return _PythonRequirementRequest(
      name: SkillProvisioningService._normalizeDependencyName(name),
      raw: line,
      root: root,
      rootPackage: rootPackage,
    );
  }

  _PythonRequirementRequest withRootPackage(String rootPackage) {
    return _PythonRequirementRequest(
      name: name,
      raw: raw,
      root: root,
      rootPackage: SkillProvisioningService._normalizeDependencyName(
        rootPackage,
      ),
    );
  }
}

class _PythonWheelCandidate {
  final String name;
  final String version;
  final String fileName;
  final Uri url;
  final String? sha256;
  final String indexHost;

  const _PythonWheelCandidate({
    required this.name,
    required this.version,
    required this.fileName,
    required this.url,
    required this.sha256,
    required this.indexHost,
  });
}

class _PythonWheelName {
  final String name;
  final String version;
  final Set<String> pythonTags;
  final Set<String> abiTags;
  final Set<String> platformTags;

  const _PythonWheelName({
    required this.name,
    required this.version,
    required this.pythonTags,
    required this.abiTags,
    required this.platformTags,
  });
}

class _PythonWheelInstallResult {
  final bool ok;
  final SkillProvisioningAction action;
  final List<_PythonRequirementRequest> requiresDist;

  const _PythonWheelInstallResult({
    required this.ok,
    required this.action,
    required this.requiresDist,
  });
}

class _PythonInstalledPackage {
  final String name;
  final String version;

  const _PythonInstalledPackage({
    required this.name,
    required this.version,
  });
}

class _PythonVersionConstraint {
  final String operator;
  final String version;

  const _PythonVersionConstraint(this.operator, this.version);
}

class _NodePackageRequest {
  final String name;
  final String raw;
  final bool root;
  final String? rootPackage;

  const _NodePackageRequest({
    required this.name,
    required this.raw,
    required this.root,
    this.rootPackage,
  });
}

class _NodePackageCandidate {
  final String name;
  final String version;
  final Uri url;
  final String? integrity;
  final String? sha512;
  final String? sha256;
  final String? shasum;
  final int? maxBytes;
  final Map<String, String> dependencies;

  const _NodePackageCandidate({
    required this.name,
    required this.version,
    required this.url,
    this.integrity,
    this.sha512,
    this.sha256,
    this.shasum,
    this.maxBytes,
    this.dependencies = const <String, String>{},
  });

  String get safeId => SkillProvisioningService._nodePackageReceiptName(name);

  static _NodePackageCandidate? fromJson(Map<String, dynamic> json) {
    final name = SkillProvisioningService._normalizeNodePackageName(
      json['name']?.toString() ?? json['id']?.toString() ?? '',
    );
    final version = json['version']?.toString().trim() ?? '';
    final url = json['url']?.toString().trim() ??
        json['tarball']?.toString().trim() ??
        '';
    if (!SkillProvisioningService._nodePackageNameLooksSafe(name) ||
        version.isEmpty ||
        url.isEmpty) {
      return null;
    }
    return _NodePackageCandidate(
      name: name,
      version: version,
      url: Uri.parse(url),
      integrity: json['integrity']?.toString(),
      sha512: json['sha512']?.toString().toLowerCase(),
      sha256: json['sha256']?.toString().toLowerCase(),
      shasum: json['shasum']?.toString().toLowerCase() ??
          json['sha1']?.toString().toLowerCase(),
      maxBytes: (json['maxBytes'] as num?)?.toInt(),
      dependencies: SkillProvisioningService._nodeDependencyMap(json),
    );
  }
}

class _NodePackageInstallResult {
  final bool ok;
  final SkillProvisioningAction action;
  final Map<String, String> dependencies;

  const _NodePackageInstallResult({
    required this.ok,
    required this.action,
    required this.dependencies,
  });
}

class _DependencyPackReceipt {
  final String id;
  final String version;
  final String sha256;
  final String? requestedRequirement;
  final bool compatibilityOverride;
  final bool smokePassed;

  const _DependencyPackReceipt({
    required this.id,
    required this.version,
    required this.sha256,
    this.requestedRequirement,
    this.compatibilityOverride = false,
    this.smokePassed = false,
  });

  factory _DependencyPackReceipt.fromJson(Map<String, dynamic> json) {
    return _DependencyPackReceipt(
      id: json['id']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      sha256: json['sha256']?.toString() ?? '',
      requestedRequirement: json['requestedRequirement']?.toString(),
      compatibilityOverride: json['compatibilityOverride'] == true,
      smokePassed: json['smokePassed'] == true,
    );
  }
}

class _DependencyPackFile {
  final String pathValue;
  final bool executable;

  const _DependencyPackFile({
    required this.pathValue,
    required this.executable,
  });

  static _DependencyPackFile? fromJson(Map<String, dynamic> json) {
    final pathValue = json['path']?.toString().trim();
    if (pathValue == null || pathValue.isEmpty) return null;
    return _DependencyPackFile(
      pathValue: pathValue,
      executable: json['executable'] == true,
    );
  }
}

class _DependencyPackCommand {
  final String command;
  final List<String> args;

  const _DependencyPackCommand({
    required this.command,
    required this.args,
  });

  static _DependencyPackCommand? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final command = json['command']?.toString().trim();
    if (command == null || command.isEmpty) return null;
    return _DependencyPackCommand(
      command: command,
      args: _DependencyPack._stringList(json['args']),
    );
  }
}

class _DependencyPack {
  final String id;
  final String version;
  final _DependencyPackSource source;
  final String? url;
  final String sha256;
  final int? maxBytes;
  final String? archiveType;
  final String? installPath;
  final Set<String> providesRuntimes;
  final Set<String> providesBins;
  final Set<String> providesPythonPackages;
  final List<String> smokeImports;
  final List<_DependencyPackFile> files;
  final _DependencyPackCommand? smokeCommand;
  final String rollbackStrategy;

  const _DependencyPack({
    required this.id,
    required this.version,
    required this.source,
    required this.url,
    required this.sha256,
    required this.maxBytes,
    required this.archiveType,
    required this.installPath,
    required this.providesRuntimes,
    required this.providesBins,
    required this.providesPythonPackages,
    required this.smokeImports,
    required this.files,
    required this.smokeCommand,
    required this.rollbackStrategy,
  });

  factory _DependencyPack.apk({
    required String id,
    required String version,
    Set<String> providesRuntimes = const <String>{},
    Set<String> providesBins = const <String>{},
    Set<String> providesPythonPackages = const <String>{},
    List<String> smokeImports = const <String>[],
  }) {
    return _DependencyPack(
      id: id,
      version: version,
      source: _DependencyPackSource.apk,
      url: null,
      sha256: 'apk',
      maxBytes: null,
      archiveType: null,
      installPath: null,
      providesRuntimes: providesRuntimes
          .map(SkillProvisioningService._normalizeDependencyName)
          .toSet(),
      providesBins: providesBins
          .map(SkillProvisioningService._normalizeDependencyName)
          .toSet(),
      providesPythonPackages: providesPythonPackages
          .map(SkillProvisioningService._normalizeDependencyName)
          .toSet(),
      smokeImports: smokeImports,
      files: const <_DependencyPackFile>[],
      smokeCommand: null,
      rollbackStrategy: '',
    );
  }

  static _DependencyPack? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim();
    final version = json['version']?.toString().trim();
    if (id == null || id.isEmpty || version == null || version.isEmpty) {
      return null;
    }
    final provides = json['provides'] is Map
        ? Map<String, dynamic>.from(json['provides'] as Map)
        : <String, dynamic>{};
    final sourceName = json['source']?.toString().toLowerCase();
    final source = sourceName == 'apk'
        ? _DependencyPackSource.apk
        : _DependencyPackSource.remote;
    final smokeCommandJson = json['smokeCommand'] is Map
        ? Map<String, dynamic>.from(json['smokeCommand'] as Map)
        : null;
    final rollbackJson = json['rollback'] is Map
        ? Map<String, dynamic>.from(json['rollback'] as Map)
        : const <String, dynamic>{};
    return _DependencyPack(
      id: id,
      version: version,
      source: source,
      url: json['url']?.toString(),
      sha256: json['sha256']?.toString().toLowerCase() ?? '',
      maxBytes: (json['maxBytes'] as num?)?.toInt(),
      archiveType: json['archiveType']?.toString(),
      installPath: json['installPath']?.toString(),
      providesRuntimes: _stringSet(provides['runtimes']),
      providesBins: _stringSet(provides['bins']),
      providesPythonPackages: _stringSet(provides['pythonPackages']),
      smokeImports: _stringList(json['smokeImports']),
      files: json['files'] is List
          ? (json['files'] as List)
              .whereType<Map>()
              .map((item) => _DependencyPackFile.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .whereType<_DependencyPackFile>()
              .toList(growable: false)
          : const <_DependencyPackFile>[],
      smokeCommand: _DependencyPackCommand.fromJson(smokeCommandJson),
      rollbackStrategy: rollbackJson['strategy']?.toString().trim() ?? '',
    );
  }

  static Set<String> _stringSet(dynamic value) => _stringList(value)
      .map(SkillProvisioningService._normalizeDependencyName)
      .toSet();

  static List<String> _stringList(dynamic value) {
    if (value is String) return [value];
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }
}
