import 'android_skill_config_test_plan.dart';

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

  int get needsConfigTaxonomyCount => _count(countsByClass, 'needs_config');

  int get needsPackTaxonomyCount => _count(countsByClass, 'needs_pack');

  String get configPackTaxonomyLabel =>
      '$needsConfigTaxonomyCount config class / '
      '$needsPackTaxonomyCount pack class';

  int get blockedNeedsConfigCount => topNeedsConfig.length;

  int get blockedNeedsPackCount => topNeedsPack.length;

  int get liveConnectionTestCount => topNeedsConfig
      .where(
        (item) =>
            item.configTestSupport ==
            AndroidSkillConfigTestSupport.liveConnection,
      )
      .length;

  int get conditionalSetupStatusCount => topNeedsConfig
      .where(
        (item) =>
            item.configTestSupport ==
            AndroidSkillConfigTestSupport.conditionalSetupStatus,
      )
      .length;

  int get saveOnlyConfigCount => topNeedsConfig
      .where(
        (item) =>
            item.configTestSupport == AndroidSkillConfigTestSupport.saveOnly &&
            !item.hasNativeRuntimeGate,
      )
      .length;

  int get mixedConfigRuntimeGateCount => topNeedsConfig
      .where(
        (item) =>
            item.configTestSupport == AndroidSkillConfigTestSupport.saveOnly &&
            item.hasNativeRuntimeGate,
      )
      .length;

  String get configTestCoverageLabel =>
      '$liveConnectionTestCount live + $conditionalSetupStatusCount setup / '
      '$blockedNeedsConfigCount';

  String get saveOnlyConfigLabel {
    if (mixedConfigRuntimeGateCount == 0) {
      return '$saveOnlyConfigCount save-only';
    }
    return '$saveOnlyConfigCount save-only + '
        '$mixedConfigRuntimeGateCount mixed runtime';
  }

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
      topNeedsConfig: _topNeedsConfigSummaries(skills),
      topNeedsPack: _topNeedsPackSummaries(skills),
    );
  }

  static List<AndroidSkillGateSummary> _topNeedsConfigSummaries(
    List<Map<String, dynamic>> skills,
  ) {
    return skills
        .where((skill) => skill['ready'] != true)
        .where(_isConfigGate)
        .map(AndroidSkillGateSummary.fromSkill)
        .toList(growable: false);
  }

  static List<AndroidSkillGateSummary> _topNeedsPackSummaries(
    List<Map<String, dynamic>> skills,
  ) {
    return skills
        .where((skill) => skill['androidSupport']?.toString() == 'needs_pack')
        .where((skill) => skill['ready'] != true)
        .where((skill) => !_isConfigGate(skill))
        .map(AndroidSkillGateSummary.fromSkill)
        .toList(growable: false);
  }

  static bool _isConfigGate(Map<String, dynamic> skill) {
    if (skill['androidSupport']?.toString() == 'needs_config') return true;
    if (skill['androidSupport']?.toString() != 'needs_pack') return false;
    final isConfigGate = skill['runtimeStatus']?.toString() == 'needs_config' ||
        skill['provisioningStatus']?.toString() == 'needs_user_config';
    return isConfigGate && !_skillNeedsMoreThanConfig(skill);
  }

  static bool _skillNeedsMoreThanConfig(Map<String, dynamic> skill) {
    if (_stringList(skill['missingBins']).isNotEmpty ||
        _stringList(skill['missingPacks']).isNotEmpty) {
      return true;
    }
    if (_gateNeedsMoreThanConfig(skill['dependencyGateStatus']?.toString())) {
      return true;
    }
    if (_gateNeedsMoreThanConfig(skill['primaryGate']?.toString())) {
      return true;
    }
    return _stringList(skill['gates']).any(_gateNeedsMoreThanConfig);
  }

  static bool _gateNeedsMoreThanConfig(String? gate) {
    final normalized = gate?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return normalized == 'missing_native_bin' ||
        normalized == 'missing_native_runtime' ||
        normalized == 'missing_native_python_package' ||
        normalized == 'missing_native_node_package' ||
        normalized == 'missing_native_plugin' ||
        normalized == 'missing_native_skill' ||
        normalized == 'missing_binary' ||
        normalized == 'missing_dependency' ||
        normalized == 'missing_plugin' ||
        normalized == 'missing_pack' ||
        normalized == 'missing_manifest' ||
        normalized == 'dependency_pack' ||
        normalized == 'manual_proot_required' ||
        normalized == 'unsupported_native' ||
        normalized == 'unsupported_on_android';
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
  final AndroidSkillConfigTestSupport configTestSupport;
  final List<String> missingBins;
  final List<String> missingPacks;
  final String? dependencyGateMessage;
  final bool hasNativeRuntimeGate;

  const AndroidSkillGateSummary({
    required this.skillId,
    required this.detail,
    required this.configTestSupport,
    this.missingBins = const <String>[],
    this.missingPacks = const <String>[],
    this.dependencyGateMessage,
    this.hasNativeRuntimeGate = false,
  });

  factory AndroidSkillGateSummary.fromSkill(Map<String, dynamic> skill) {
    final skillId = skill['skillId']?.toString().trim() ?? 'unknown';
    final env = _stringList(skill['requiredEnv']);
    final config = _stringList(skill['requiredConfig']);
    final packs = _stringList(skill['requiredPacks']);
    final missingBins = _stringList(skill['missingBins']);
    final missingPacks = _stringList(skill['missingPacks']);
    final dependencyGateMessage =
        skill['dependencyGateMessage']?.toString().trim();
    final runtime = skill['runtimeStatus']?.toString().trim();
    final gate = skill['primaryGate']?.toString().trim();
    final parts = <String>[
      if (env.isNotEmpty) 'env: ${env.join(', ')}',
      if (config.isNotEmpty) 'config: ${config.join(', ')}',
      if (missingPacks.isNotEmpty)
        'pack unavailable: ${_packListLabel(missingPacks)}'
      else if (packs.isNotEmpty)
        'pack: ${_packListLabel(packs)}',
      if (missingBins.isNotEmpty) 'missing binaries: ${missingBins.join(', ')}',
      if (dependencyGateMessage != null && dependencyGateMessage.isNotEmpty)
        dependencyGateMessage,
      if (gate != null && gate.isNotEmpty) gate,
      if (gate == null || gate.isEmpty)
        if (runtime != null && runtime.isNotEmpty) runtime,
    ];
    return AndroidSkillGateSummary(
      skillId: skillId,
      detail: parts.isEmpty ? 'gate pending' : parts.join(' | '),
      configTestSupport: AndroidSkillConfigTestPlan.supportForSkill(skillId),
      missingBins: missingBins,
      missingPacks: missingPacks,
      dependencyGateMessage:
          dependencyGateMessage == null || dependencyGateMessage.isEmpty
              ? null
              : dependencyGateMessage,
      hasNativeRuntimeGate:
          AndroidSkillReadinessViewModel._skillNeedsMoreThanConfig(skill),
    );
  }
}

String _packListLabel(List<String> packs) => packs.map(_packLabel).join(', ');

String _packLabel(String packId) {
  switch (packId.trim()) {
    case 'android-cli-core-pack':
      return 'Android CLI core pack';
    case 'android-vision-media-runtime':
      return 'Android vision media runtime';
    case 'android-python-debug-runtime':
      return 'Android Python debug runtime';
    case 'android-terminal-pack':
      return 'Android terminal pack';
    case 'android-node-executable-pack':
      return 'Standalone Node executable pack';
    case 'android-gemini-cli-pack':
      return 'Android Gemini CLI pack';
    case 'android-agent-cli-pack':
      return 'Android agent CLI pack';
    case 'android-whisper-runtime':
      return 'Android Whisper runtime';
    case 'android-tts-runtime':
      return 'Android TTS runtime';
    case 'android-audio-runtime':
      return 'Android audio runtime';
  }
  return packId.trim().replaceAll('-', ' ');
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
