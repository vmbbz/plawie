class AndroidSkillProvisioningBadgeOverride {
  final String status;
  final String label;
  final String detail;

  const AndroidSkillProvisioningBadgeOverride({
    required this.status,
    required this.label,
    required this.detail,
  });
}

/// Returns a clean READY override only for skills whose *live* state
/// (from /device/health or equivalent) shows runtimeStatus + provisioningStatus
/// indicate they are actually runnable without further user/pack actions.
///
/// This is the key enforcement of the GTM plan rule:
///   "Skills page now shows current gates, not just static taxonomy"
AndroidSkillProvisioningBadgeOverride? classifyAndroidSkillProvisioningBadge(
  Map<String, dynamic> skill,
) {
  final androidSupport = skill['androidSupport']?.toString() ?? '';
  final runtimeStatus = skill['runtimeStatus']?.toString() ?? '';
  final provisioningStatus = skill['provisioningStatus']?.toString() ?? '';
  final unsupportedReason = skill['unsupportedReason']?.toString().trim() ?? '';
  final isLiveReady = (runtimeStatus == 'ready') &&
      (provisioningStatus == 'ready' || skill['ready'] == true);

  // Highest precedence: live truth from device/health says this skill
  // is fully ready (not just classifiable as ready).
  if (isLiveReady && !_isExcludedAndroidSupport(androidSupport)) {
    return const AndroidSkillProvisioningBadgeOverride(
      status: 'ready',
      label: 'READY',
      detail: 'Ready on device (live status)',
    );
  }

  // Legacy app-native ready path (still supported for pure native bridges)
  if (skill['ready'] == true && runtimeStatus == 'app_native_ready') {
    return const AndroidSkillProvisioningBadgeOverride(
      status: 'app_native_ready',
      label: 'READY',
      detail: 'Android app-native path ready',
    );
  }

  final isConfigGate = androidSupport == 'needs_config' ||
      (androidSupport == 'needs_pack' &&
          (runtimeStatus == 'needs_config' ||
              provisioningStatus == 'needs_user_config'));
  if (isConfigGate && !_skillNeedsMoreThanConfig(skill)) {
    return AndroidSkillProvisioningBadgeOverride(
      status: 'needs_user_config',
      label: 'NEEDS CONFIG',
      detail: _configGateDetail(skill),
    );
  }

  return switch (androidSupport) {
    'unsupported_on_android' => AndroidSkillProvisioningBadgeOverride(
        status: androidSupport,
        label: 'OUTSIDE GTM',
        detail: unsupportedReason.isNotEmpty
            ? unsupportedReason
            : 'Not supported by Android native runtime.',
      ),
    'manual_proot_compat' => AndroidSkillProvisioningBadgeOverride(
        status: androidSupport,
        label: 'MANUAL PROOT',
        detail: unsupportedReason.isNotEmpty
            ? unsupportedReason
            : 'Available only through a manual PRoot compatibility path.',
      ),
    'hidden_desktop_only' => AndroidSkillProvisioningBadgeOverride(
        status: androidSupport,
        label: 'DESKTOP ONLY',
        detail: unsupportedReason.isNotEmpty
            ? unsupportedReason
            : 'desktop-only skill hidden from the Android GTM lane.',
      ),
    _ => null,
  };
}

bool _isExcludedAndroidSupport(String support) {
  return support == 'unsupported_on_android' ||
      support == 'manual_proot_compat' ||
      support == 'hidden_desktop_only';
}

bool _skillNeedsMoreThanConfig(Map<String, dynamic> skill) {
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

bool _gateNeedsMoreThanConfig(String? gate) {
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

String _configGateDetail(Map<String, dynamic> skill) {
  final env = _stringList(skill['requiredEnv']);
  final config = _stringList(skill['requiredConfig']);
  if (env.isNotEmpty) return 'Configure ${env.join(', ')}';
  if (config.isNotEmpty) return 'Configure ${config.join(', ')}';
  return 'User configuration required';
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
