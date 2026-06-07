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
      final ready = _isReady(entry, matrixEntry, provisioningResult);
      final releaseRelevant =
          entry.status == AndroidSkillSupportStatus.readyRequired;
      final appNativeOwned = _isAppNativeOwned(entry);
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
        'runtimeStatus': _runtimeStatus(entry, matrixEntry),
        if (!appNativeOwned && matrixEntry?.primaryGate != null)
          'primaryGate': matrixEntry!.primaryGate,
        if (!appNativeOwned &&
            matrixEntry != null &&
            matrixEntry.gates.isNotEmpty)
          'gates': matrixEntry.gates,
        'provisioningStatus': appNativeOwned
            ? 'app_native_not_required'
            : provisioningResult?.status.wireName ?? 'not_planned',
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
    SkillExecutionMatrixEntry? matrixEntry,
    SkillProvisioningSkillResult? provisioningResult,
  ) {
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
    SkillExecutionMatrixEntry? matrixEntry,
  ) {
    if (_isAppNativeOwned(manifestEntry)) return 'app_native_ready';
    if (matrixEntry == null) return 'not_installed';
    return _executionStatusWireName(matrixEntry.status);
  }

  static bool _isAppNativeOwned(AndroidSkillSupportEntry manifestEntry) {
    return manifestEntry.ownerLayer == AndroidSkillOwnerLayer.androidBridge ||
        manifestEntry.ownerLayer == AndroidSkillOwnerLayer.appNativeCapability;
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
