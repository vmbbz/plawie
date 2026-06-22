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
