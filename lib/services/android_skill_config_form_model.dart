class AndroidSkillConfigFormModel {
  final String skillId;
  final List<String> envKeys;
  final List<String> configKeys;
  final String? runtimeGate;
  final bool configOnlyCanSatisfy;

  const AndroidSkillConfigFormModel({
    required this.skillId,
    required this.envKeys,
    required this.configKeys,
    required this.runtimeGate,
    required this.configOnlyCanSatisfy,
  });

  List<String> get allKeys => [
        ...envKeys,
        ...configKeys,
      ];

  bool get hasFields => envKeys.isNotEmpty || configKeys.isNotEmpty;

  String get runtimeGateLabel {
    if (runtimeGate == null || runtimeGate!.isEmpty) return 'config';
    return runtimeGate!.replaceAll('_', ' ');
  }

  factory AndroidSkillConfigFormModel.fromSkill(
    Map<String, dynamic> skill,
  ) {
    final requiredConfig = _stringList(skill['requiredConfig']);
    final envKeys = <String>[];
    final configKeys = <String>[];
    for (final key in requiredConfig) {
      if (_looksLikeEnvKey(key)) {
        envKeys.add(key);
      } else {
        configKeys.add(key);
      }
    }

    final gate = _firstNonEmpty([
      skill['primaryGate'],
      skill['runtimeStatus'],
    ]);

    return AndroidSkillConfigFormModel(
      skillId: skill['skillId']?.toString().trim() ?? 'unknown',
      envKeys: envKeys,
      configKeys: configKeys,
      runtimeGate: gate,
      configOnlyCanSatisfy: requiredConfig.isNotEmpty &&
          !_gateNeedsMoreThanConfig(gate) &&
          skill['androidSupport']?.toString() != 'needs_pack',
    );
  }

  static AndroidSkillConfigFormModel? fromReadiness(
    Map<String, dynamic> readiness,
    String skillId,
  ) {
    final normalized = _normalizeSkillId(skillId);
    for (final skill in _mapList(readiness['skills'])) {
      if (_normalizeSkillId(skill['skillId']?.toString() ?? '') == normalized) {
        return AndroidSkillConfigFormModel.fromSkill(skill);
      }
    }
    return null;
  }

  static List<AndroidSkillConfigFormModel> allFromReadiness(
    Map<String, dynamic> readiness,
  ) {
    return _mapList(readiness['skills'])
        .where((skill) => skill['androidSupport']?.toString() == 'needs_config')
        .map(AndroidSkillConfigFormModel.fromSkill)
        .where((form) => form.hasFields)
        .toList(growable: false);
  }

  static bool _gateNeedsMoreThanConfig(String? gate) {
    final normalized = gate?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return normalized == 'missing_native_bin' ||
        normalized == 'missing_binary' ||
        normalized == 'missing_dependency' ||
        normalized == 'missing_plugin' ||
        normalized == 'missing_pack' ||
        normalized == 'dependency_pack' ||
        normalized == 'manual_proot_required' ||
        normalized == 'unsupported_native' ||
        normalized == 'unsupported_on_android';
  }
}

String _normalizeSkillId(String value) =>
    value.trim().toLowerCase().replaceAll('_', '-');

bool _looksLikeEnvKey(String key) {
  final trimmed = key.trim();
  if (trimmed.contains('.')) return false;
  return RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(trimmed);
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
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
