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
      final appNativeOwned = _isAppNativeOwned(entry);
      final dependencyGateDetails = appNativeOwned
          ? const <String, dynamic>{}
          : _dependencyGateDetails(provisioningResult);
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
        if (!appNativeOwned && matrixEntry?.primaryGate != null)
          'primaryGate': matrixEntry!.primaryGate,
        if (!appNativeOwned &&
            matrixEntry != null &&
            matrixEntry.gates.isNotEmpty)
          'gates': matrixEntry.gates,
        if (!appNativeOwned &&
            matrixEntry != null &&
            matrixEntry.requiredAnyBins.isNotEmpty)
          'requiredAnyBins': matrixEntry.requiredAnyBins,
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
      if (_appNativeConfigSatisfied(manifestEntry, snapshot)) return true;
      if (matrixEntry?.status == SkillExecutionStatus.ready) return true;
      return switch (provisioningResult?.status) {
        SkillProvisioningStatus.ready ||
        SkillProvisioningStatus.satisfied =>
          true,
        _ => false,
      };
    }
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
      if (_appNativeConfigSatisfied(manifestEntry, snapshot)) {
        return 'app_native_ready';
      }
      return 'needs_config';
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
    if (appNativeOwned && !appNativeConfigGated) {
      return 'app_native_not_required';
    }
    if (appNativeConfigGated &&
        _appNativeConfigSatisfied(manifestEntry, snapshot)) {
      return 'app_native_config_ready';
    }
    if (appNativeConfigGated) return 'needs_user_config';
    return provisioningResult?.status.wireName ?? 'not_planned';
  }

  static Map<String, dynamic> _dependencyGateDetails(
    SkillProvisioningSkillResult? provisioningResult,
  ) {
    if (provisioningResult == null) return const <String, dynamic>{};
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

  static bool _isAppNativeOwned(AndroidSkillSupportEntry manifestEntry) {
    return manifestEntry.ownerLayer == AndroidSkillOwnerLayer.androidBridge ||
        manifestEntry.ownerLayer ==
            AndroidSkillOwnerLayer.appNativeCapability ||
        manifestEntry.ownerLayer == AndroidSkillOwnerLayer.clawhubSkill;
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
  ) {
    if (!_isAppNativeConfigGated(manifestEntry)) return true;
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
