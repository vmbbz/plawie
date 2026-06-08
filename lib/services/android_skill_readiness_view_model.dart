class AndroidSkillReadinessViewModel {
  final int manifestTotal;
  final int readyRequiredReady;
  final int readyRequiredTotal;
  final int androidRelevantTotal;
  final int androidRelevantReady;
  final int unexpectedMissingDependency;
  final bool releaseGatePass;
  final Map<String, int> countsByClass;
  final List<AndroidSkillGateSummary> topNeedsConfig;
  final List<AndroidSkillGateSummary> topNeedsPack;

  const AndroidSkillReadinessViewModel({
    required this.manifestTotal,
    required this.readyRequiredReady,
    required this.readyRequiredTotal,
    required this.androidRelevantTotal,
    required this.androidRelevantReady,
    required this.unexpectedMissingDependency,
    required this.releaseGatePass,
    required this.countsByClass,
    required this.topNeedsConfig,
    required this.topNeedsPack,
  });

  String get readyRequiredLabel => '$readyRequiredReady/$readyRequiredTotal';

  String get androidRelevantLabel =>
      '$androidRelevantReady/$androidRelevantTotal';

  int get readyOptionalCount => _count(countsByClass, 'ready_optional');

  String get readyOptionalLabel => '$readyOptionalCount';

  factory AndroidSkillReadinessViewModel.fromReadiness(
    Map<String, dynamic> readiness,
  ) {
    final counts = _intMap(readiness['countsByClass']);
    final readyRequired = _mapValue(readiness['readyRequired']);
    final skills = _mapList(readiness['skills']);
    final excluded = _count(counts, 'unsupported_on_android') +
        _count(counts, 'manual_proot_compat') +
        _count(counts, 'hidden_desktop_only');
    final manifestTotal = _intValue(readiness['totalManifestSkills']);
    final androidRelevantTotal = (manifestTotal - excluded).clamp(0, 1000000);

    final androidRelevantReady = skills.where((skill) {
      if (skill['ready'] != true) return false;
      return !_excludedAndroidSupport(skill['androidSupport']?.toString());
    }).length;

    return AndroidSkillReadinessViewModel(
      manifestTotal: manifestTotal,
      readyRequiredReady: _intValue(readyRequired['ready']),
      readyRequiredTotal: _intValue(readyRequired['total']),
      androidRelevantTotal: androidRelevantTotal,
      androidRelevantReady: androidRelevantReady,
      unexpectedMissingDependency:
          _intValue(readiness['unexpectedMissingDependency']),
      releaseGatePass: readiness['releaseGatePass'] == true,
      countsByClass: counts,
      topNeedsConfig: _topGateSummaries(skills, 'needs_config'),
      topNeedsPack: _topGateSummaries(skills, 'needs_pack'),
    );
  }

  static List<AndroidSkillGateSummary> _topGateSummaries(
    List<Map<String, dynamic>> skills,
    String androidSupport,
  ) {
    return skills
        .where((skill) => skill['androidSupport']?.toString() == androidSupport)
        .where((skill) => skill['ready'] != true)
        .map(AndroidSkillGateSummary.fromSkill)
        .toList(growable: false);
  }

  static bool _excludedAndroidSupport(String? support) {
    return support == 'unsupported_on_android' ||
        support == 'manual_proot_compat' ||
        support == 'hidden_desktop_only';
  }
}

class AndroidSkillGateSummary {
  final String skillId;
  final String detail;
  final List<String> missingBins;
  final List<String> missingPacks;
  final String? dependencyGateMessage;

  const AndroidSkillGateSummary({
    required this.skillId,
    required this.detail,
    this.missingBins = const <String>[],
    this.missingPacks = const <String>[],
    this.dependencyGateMessage,
  });

  factory AndroidSkillGateSummary.fromSkill(Map<String, dynamic> skill) {
    final config = _stringList(skill['requiredConfig']);
    final packs = _stringList(skill['requiredPacks']);
    final missingBins = _stringList(skill['missingBins']);
    final missingPacks = _stringList(skill['missingPacks']);
    final dependencyGateMessage =
        skill['dependencyGateMessage']?.toString().trim();
    final runtime = skill['runtimeStatus']?.toString().trim();
    final gate = skill['primaryGate']?.toString().trim();
    final parts = <String>[
      if (config.isNotEmpty) 'config: ${config.join(', ')}',
      if (missingPacks.isNotEmpty)
        'pack unavailable: ${missingPacks.join(', ')}'
      else if (packs.isNotEmpty)
        'pack: ${packs.join(', ')}',
      if (missingBins.isNotEmpty) 'missing binaries: ${missingBins.join(', ')}',
      if (dependencyGateMessage != null && dependencyGateMessage.isNotEmpty)
        dependencyGateMessage,
      if (gate != null && gate.isNotEmpty) gate,
      if (gate == null || gate.isEmpty)
        if (runtime != null && runtime.isNotEmpty) runtime,
    ];
    return AndroidSkillGateSummary(
      skillId: skill['skillId']?.toString().trim() ?? 'unknown',
      detail: parts.isEmpty ? 'gate pending' : parts.join(' | '),
      missingBins: missingBins,
      missingPacks: missingPacks,
      dependencyGateMessage:
          dependencyGateMessage == null || dependencyGateMessage.isEmpty
              ? null
              : dependencyGateMessage,
    );
  }
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, int> _intMap(dynamic value) {
  final map = _mapValue(value);
  return {
    for (final entry in map.entries) entry.key: _intValue(entry.value),
  };
}

int _count(Map<String, int> counts, String key) => counts[key] ?? 0;

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
