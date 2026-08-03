import 'android_skill_support_manifest.dart';
import 'skill_parity_audit_service.dart';
import 'skill_provisioning_service.dart';

class AndroidSkillReadinessService {
  AndroidSkillReadinessService._();

  static final AndroidSkillReadinessService instance =
      AndroidSkillReadinessService._();

  AndroidSkillReadinessSummary summarize({
    required SkillParitySnapshot snapshot,
    required SkillProvisioningReport provisioning,
    AndroidSkillSupportManifest? manifest,
  }) {
    final supportManifest = manifest ?? AndroidSkillSupportManifest.instance;
    final matrixBySkillId = {
      for (final entry in snapshot.executionMatrix)
        _normalizeSkillId(entry.skillId): entry,
    };
    final provisioningBySkillId = {
      for (final result in provisioning.results)
        _normalizeSkillId(result.skillId): result,
    };
    final countsByClass = {
      for (final status in AndroidSkillSupportStatus.values) status.wireName: 0,
    };
    final skills = <Map<String, dynamic>>[];
    final unexpectedMissingDependencySkillIds = <String>[];
    var readyRequiredTotal = 0;
    var readyRequiredReady = 0;

    for (final entry in supportManifest.entries) {
      countsByClass.update(
        entry.status.wireName,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      final normalizedSkillId = _normalizeSkillId(entry.skillId);
      final matrixEntry = matrixBySkillId[normalizedSkillId];
      final provisioningResult = provisioningBySkillId[normalizedSkillId];
      final ready = _isReady(entry, snapshot, matrixEntry, provisioningResult);
      final releaseRelevant =
          entry.status == AndroidSkillSupportStatus.readyRequired;
      final runtimeIndependent = _isRuntimeIndependent(entry);
      final dependencyGateDetails = runtimeIndependent
          ? const <String, dynamic>{}
          : _dependencyGateDetails(provisioningResult);
      final liveRequiredEnv = _requiredEnv(entry, matrixEntry);
      final liveRequiredConfig = _requiredConfig(entry, matrixEntry);
      if (releaseRelevant) {
        readyRequiredTotal += 1;
        if (ready) {
          readyRequiredReady += 1;
        } else {
          unexpectedMissingDependencySkillIds.add(entry.skillId);
        }
      }

      skills.add({
        ...entry.toJson(),
        'runtimeStatus':
            _runtimeStatus(entry, snapshot, matrixEntry, provisioningResult),
        if (!runtimeIndependent && matrixEntry?.primaryGate != null)
          'primaryGate': matrixEntry!.primaryGate,
        if (!runtimeIndependent &&
            matrixEntry != null &&
            matrixEntry.gates.isNotEmpty)
          'gates': matrixEntry.gates,
        if (!runtimeIndependent &&
            matrixEntry != null &&
            matrixEntry.requiredAnyBins.isNotEmpty)
          'requiredAnyBins': matrixEntry.requiredAnyBins,
        if (liveRequiredEnv.isNotEmpty) 'requiredEnv': liveRequiredEnv,
        if (liveRequiredConfig.isNotEmpty) 'requiredConfig': liveRequiredConfig,
        'provisioningStatus': _provisioningStatus(
          entry,
          snapshot,
          provisioningResult,
        ),
        ...dependencyGateDetails,
        'ready': ready,
        'releaseBlocking': releaseRelevant && !ready,
      });
    }

    unexpectedMissingDependencySkillIds.sort();
    return AndroidSkillReadinessSummary(
      totalManifestSkills: supportManifest.entries.length,
      installedNativeSkills: snapshot.nativeSkillCount,
      readyRequiredTotal: readyRequiredTotal,
      readyRequiredReady: readyRequiredReady,
      unexpectedMissingDependency: unexpectedMissingDependencySkillIds.length,
      releaseGatePass: readyRequiredReady == readyRequiredTotal &&
          unexpectedMissingDependencySkillIds.isEmpty,
      countsByClass: countsByClass,
      unexpectedMissingDependencySkillIds: unexpectedMissingDependencySkillIds,
      skills: skills,
    );
  }

  static bool _isReady(
    AndroidSkillSupportEntry manifestEntry,
    SkillParitySnapshot snapshot,
    SkillExecutionMatrixEntry? matrixEntry,
    SkillProvisioningSkillResult? provisioningResult,
  ) {
    if (_isAppNativeConfigGated(manifestEntry)) {
      if (_appNativeConfigSatisfied(
        manifestEntry,
        snapshot,
        provisioningResult,
      )) {
        return true;
      }
      if (matrixEntry?.status == SkillExecutionStatus.ready) return true;
      return switch (provisioningResult?.status) {
        SkillProvisioningStatus.ready ||
        SkillProvisioningStatus.satisfied =>
          true,
        _ => false,
      };
    }
    if (_isInstructionOnlyReady(manifestEntry)) return true;
    if (_isAppNativeOwned(manifestEntry)) return true;
    if (matrixEntry?.status == SkillExecutionStatus.ready) return true;
    return switch (provisioningResult?.status) {
      SkillProvisioningStatus.ready ||
      SkillProvisioningStatus.satisfied =>
        true,
      _ => false,
    };
  }

  static String _runtimeStatus(
    AndroidSkillSupportEntry manifestEntry,
    SkillParitySnapshot snapshot,
    SkillExecutionMatrixEntry? matrixEntry,
    SkillProvisioningSkillResult? provisioningResult,
  ) {
    if (_isAppNativeConfigGated(manifestEntry)) {
      if (_appNativeConfigSatisfied(
        manifestEntry,
        snapshot,
        provisioningResult,
      )) {
        return 'app_native_ready';
      }
      return 'needs_config';
    }
    if (_isInstructionOnlyReady(manifestEntry)) {
      return 'instruction_only_ready';
    }
    if (_isAppNativeOwned(manifestEntry)) return 'app_native_ready';
    if (matrixEntry == null) return 'not_installed';
    return _executionStatusWireName(matrixEntry.status);
  }

  static String _provisioningStatus(
    AndroidSkillSupportEntry manifestEntry,
    SkillParitySnapshot snapshot,
    SkillProvisioningSkillResult? provisioningResult,
  ) {
    final appNativeOwned = _isAppNativeOwned(manifestEntry);
    final appNativeConfigGated = _isAppNativeConfigGated(manifestEntry);
    if (_isInstructionOnlyReady(manifestEntry)) {
      return 'instruction_only_not_required';
    }
    if (appNativeOwned && !appNativeConfigGated) {
      return 'app_native_not_required';
    }
    if (appNativeConfigGated &&
        _appNativeConfigSatisfied(
          manifestEntry,
          snapshot,
          provisioningResult,
        )) {
      return 'app_native_config_ready';
    }
    if (appNativeConfigGated) return 'needs_user_config';
    return provisioningResult?.status.wireName ?? 'not_planned';
  }

  static Map<String, dynamic> _dependencyGateDetails(
    SkillProvisioningSkillResult? provisioningResult,
  ) {
    if (provisioningResult == null) return const <String, dynamic>{};
    if (provisioningResult.status == SkillProvisioningStatus.ready ||
        provisioningResult.status == SkillProvisioningStatus.satisfied) {
      // A previous failed pack action may remain in the action history after
      // the package is satisfied by the embedded/runtime inventory. Do not
      // publish that stale failure beside a ready status.
      return const <String, dynamic>{};
    }
    final missingBins = <String>{};
    final missingPacks = <String>{};
    final messages = <String>[];
    String? status;

    for (final action in provisioningResult.actions) {
      final key = action.key.trim();
      if (action.type == SkillProvisioningActionType.dependencyPack &&
          action.status == SkillProvisioningActionStatus.missingPack) {
        status ??= action.status.wireName;
        final colon = key.indexOf(':');
        if (colon > 0) {
          final prefix = key.substring(0, colon).trim();
          final suffix = key.substring(colon + 1).trim();
          if (prefix == 'bin') {
            if (suffix.isNotEmpty) missingBins.add(suffix);
          } else if (prefix != 'runtime' && prefix != 'python-package') {
            missingPacks.add(prefix);
            if (suffix.isNotEmpty) missingBins.add(suffix);
          }
        } else if (key.isNotEmpty) {
          missingPacks.add(key);
        }
        if (action.message.trim().isNotEmpty) {
          messages.add(action.message.trim());
        }
      }
      if (action.type == SkillProvisioningActionType.binary &&
          action.status == SkillProvisioningActionStatus.missingBinary &&
          key.isNotEmpty) {
        status ??= action.status.wireName;
        missingBins.add(key);
      }
    }

    if (status == null && missingBins.isEmpty && missingPacks.isEmpty) {
      return const <String, dynamic>{};
    }
    return {
      if (status != null) 'dependencyGateStatus': status,
      if (missingPacks.isNotEmpty)
        'missingPacks': missingPacks.toList()..sort(),
      if (missingBins.isNotEmpty) 'missingBins': missingBins.toList()..sort(),
      if (messages.isNotEmpty) 'dependencyGateMessage': messages.first,
    };
  }

  static List<String> _requiredEnv(
    AndroidSkillSupportEntry manifestEntry,
    SkillExecutionMatrixEntry? matrixEntry,
  ) {
    if (_isAppNativeConfigGated(manifestEntry)) return const <String>[];
    if (matrixEntry == null) return const <String>[];
    return _uniqueStrings(matrixEntry.requiredEnv);
  }

  static List<String> _requiredConfig(
    AndroidSkillSupportEntry manifestEntry,
    SkillExecutionMatrixEntry? matrixEntry,
  ) {
    if (_isAppNativeConfigGated(manifestEntry)) {
      return _uniqueStrings(manifestEntry.requiredConfig);
    }
    return _uniqueStrings([
      ...manifestEntry.requiredConfig,
      ...?matrixEntry?.requiredConfig,
    ]);
  }

  static List<String> _uniqueStrings(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (!seen.add(normalized)) continue;
      result.add(trimmed);
    }
    return List.unmodifiable(result);
  }

  static bool _isAppNativeOwned(AndroidSkillSupportEntry manifestEntry) {
    return manifestEntry.ownerLayer == AndroidSkillOwnerLayer.androidBridge ||
        manifestEntry.ownerLayer ==
            AndroidSkillOwnerLayer.appNativeCapability ||
        manifestEntry.ownerLayer == AndroidSkillOwnerLayer.clawhubSkill;
  }

  static bool _isInstructionOnlyReady(
    AndroidSkillSupportEntry manifestEntry,
  ) {
    final readyClass =
        manifestEntry.status == AndroidSkillSupportStatus.readyRequired ||
            manifestEntry.status == AndroidSkillSupportStatus.readyOptional;
    return readyClass &&
        manifestEntry.ownerLayer == AndroidSkillOwnerLayer.openclawSkill &&
        manifestEntry.executionMode ==
            AndroidSkillExecutionMode.instructionOnly;
  }

  static bool _isRuntimeIndependent(AndroidSkillSupportEntry manifestEntry) {
    return _isAppNativeOwned(manifestEntry) ||
        _isInstructionOnlyReady(manifestEntry);
  }

  static bool _isAppNativeConfigGated(
    AndroidSkillSupportEntry manifestEntry,
  ) {
    return _isAppNativeOwned(manifestEntry) &&
        manifestEntry.requiredConfig.isNotEmpty;
  }

  static bool _appNativeConfigSatisfied(
    AndroidSkillSupportEntry manifestEntry,
    SkillParitySnapshot snapshot,
    SkillProvisioningSkillResult? provisioningResult,
  ) {
    if (!_isAppNativeConfigGated(manifestEntry)) return true;
    if (_provisioningSatisfied(provisioningResult)) return true;
    final nativeEnvKeys = snapshot.nativeEnvKeys
        .map((key) => key.trim().toUpperCase())
        .where((key) => key.isNotEmpty)
        .toSet();
    for (final key in manifestEntry.requiredConfig) {
      final trimmed = key.trim();
      if (trimmed.isEmpty) return false;
      if (_looksLikeEnvKey(trimmed)) {
        if (!nativeEnvKeys.contains(trimmed.toUpperCase())) return false;
        continue;
      }
      return false;
    }
    return true;
  }

  static bool _provisioningSatisfied(
    SkillProvisioningSkillResult? provisioningResult,
  ) {
    return provisioningResult?.status == SkillProvisioningStatus.ready ||
        provisioningResult?.status == SkillProvisioningStatus.satisfied;
  }

  static bool _looksLikeEnvKey(String key) {
    if (key.contains('.')) return false;
    return RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(key);
  }

  static String _executionStatusWireName(SkillExecutionStatus status) {
    return switch (status) {
      SkillExecutionStatus.ready => 'ready',
      SkillExecutionStatus.needsConfig => 'needs_config',
      SkillExecutionStatus.missingDependency => 'missing_dependency',
      SkillExecutionStatus.disabled => 'disabled',
      SkillExecutionStatus.unsupportedNative => 'unsupported_native',
      SkillExecutionStatus.manualProotRequired => 'manual_proot_required',
    };
  }

  static String _normalizeSkillId(String value) => value.trim().toLowerCase();
}

class AndroidSkillReadinessSummary {
  final int totalManifestSkills;
  final int installedNativeSkills;
  final int readyRequiredTotal;
  final int readyRequiredReady;
  final int unexpectedMissingDependency;
  final bool releaseGatePass;
  final Map<String, int> countsByClass;
  final List<String> unexpectedMissingDependencySkillIds;
  final List<Map<String, dynamic>> skills;

  const AndroidSkillReadinessSummary({
    required this.totalManifestSkills,
    required this.installedNativeSkills,
    required this.readyRequiredTotal,
    required this.readyRequiredReady,
    required this.unexpectedMissingDependency,
    required this.releaseGatePass,
    required this.countsByClass,
    required this.unexpectedMissingDependencySkillIds,
    required this.skills,
  });

  Map<String, dynamic> toHealthJson() => {
        'totalManifestSkills': totalManifestSkills,
        'installedNativeSkills': installedNativeSkills,
        'readyRequired': {
          'ready': readyRequiredReady,
          'total': readyRequiredTotal,
        },
        'countsByClass': countsByClass,
        'unexpectedMissingDependency': unexpectedMissingDependency,
        'unexpectedMissingDependencySkillIds':
            unexpectedMissingDependencySkillIds,
        'releaseGatePass': releaseGatePass,
        'skills': skills,
      };
}
